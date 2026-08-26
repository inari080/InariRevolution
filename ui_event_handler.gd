# game/ui_event_handler.gd
# UIEventHandler - マウスインタラクションとドラッグ&ドロップ管理
class_name UIEventHandler
extends Control

var game_logic: GameLogic
var particle_pool: ParticlePool
var parent_node: Control

# 磁気トラップ画面が開いている間などは、外部からこれを false にしてインタラクションを止められます
var mouse_interaction_enabled: bool = true

func _init(p_game_logic: GameLogic, p_particle_pool: ParticlePool, p_parent: Control) -> void:
	game_logic = p_game_logic
	particle_pool = p_particle_pool
	parent_node = p_parent

# マウスによる粒子の吸い寄せ ＆ 回収処理の計算
func process_mouse_attraction(delta: float, mouse_pos: Vector2, screen_size: Vector2, radius: float) -> void:
	for i in range(game_logic.elements.size() - 1, -1, -1):
		var item = game_logic.elements[i]
		
		# 👈 状態遷移の明確化：ACTIVE 状態の粒子のみマウスインタラクションを受け付ける
		if item.current_state != GameLogic.ParticleState.ACTIVE:
			item.is_attracted = false
			continue
			
		var dist_to_mouse = item.position.distance_to(mouse_pos)
		
		# 生まれてすぐ（0.3秒未満）は吸い寄せない
		if item.age > 0.3:
			if mouse_interaction_enabled and dist_to_mouse < game_logic.ATTRACT_RADIUS:
				item.is_attracted = true
			else:
				item.is_attracted = false
			
		if item.is_attracted:
			# マウス座標に向かって加速移動
			var direction = (mouse_pos - item.position).normalized()
			item.velocity = item.velocity.move_toward(direction * game_logic.FLY_SPEED, delta * 3000.0)
			item.position += item.velocity * delta
			
			# 画面外や右サイドバーの下へ潜り込まないように制限
			item.position.x = clamp(item.position.x, radius, screen_size.x - radius)
			item.position.y = clamp(item.position.y, radius, screen_size.y - radius)
			
			if item.sprite:
				item.sprite.global_position = item.position
				# 吸い込み時は元の鮮やかな色（不透明度100%）に固定して引き立たせる
				item.sprite.modulate = item.color
				item.sprite.modulate.a = 1.0
			
			# 密着状態で左クリックが押されていたら「回収」を実行
			if dist_to_mouse < 15.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_collect_particle(item, i)

# 粒子を回収してインベントリ等に収納する内部関数
func _collect_particle(item: GameLogic.ElementItem, index: int) -> void:
	# 1. まずは画面下部の通常のインベントリーバーを試す
	var inventory = parent_node.get_tree().get_first_node_in_group("inventory_bar")
	var stored: bool = false
	if inventory and inventory.has_method("add_item"):
		stored = inventory.add_item(item.name)
	
	# 2. 通常インベントリが満杯なら、右側の磁気トラップUIのスタックへ回す
	if not stored:
		var trap = parent_node.get_tree().get_first_node_in_group("magnetic_trap_ui")
		if trap and trap.has_method("add_item"):
			stored = trap.add_item(item.name)
	
	# 収納に成功した場合のクリーンアップと演出連動
	if stored:
		var collect_pos = item.position
		if item.sprite:
			item.sprite.queue_free()
		game_logic.elements.remove_at(index)
		
		# 演出やキューブの復活ロジックへ仲介（シグナル的コールバック）
		particle_pool.create_repair_streak(collect_pos)
		parent_node.get_tree().call_group("cubes", "repair")
		
		if game_logic.elements.size() == 0:
			AppLogger.info("全粒子回収完了 - ゲームループへ")
			parent_node.get_tree().call_group("cubes", "revive")

# インベントリ等からのドラッグデータをこの画面が受け取れるか判定
func can_drop_data_on_field(_at_position: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("particle_type")

# 画面上の何もない空間にドロップされた時の粒子放出処理
func drop_data_on_field(_at_position: Vector2, data) -> void:
	if typeof(data) != TYPE_DICTIONARY or not data.has("particle_type"):
		return
	
	var type_name: String = data["particle_type"]
	var drop_pos: Vector2 = parent_node.get_global_mouse_position()
	
	# ドロップされた位置に粒子を1個実体化
	particle_pool.spawn_single_element(type_name, drop_pos)
	
	# ドラッグ元のスロットの中身を空にする
	if data.has("source_slot") and is_instance_valid(data["source_slot"]):
		data["source_slot"].clear()
