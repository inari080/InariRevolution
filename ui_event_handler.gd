# game/ui_event_handler.gd
# UIEventHandler - マウスインタラクションとドラッグ&ドロップ管理
class_name UIEventHandler
extends Control

var game_logic: GameLogic
var particle_pool: ParticlePool
var parent_node: Control

# --- インタラクション定数 ---
const SUCTION_ACCEL_SPEED: float = 3000.0        # 吸い寄せ時の秒間加速量
const COLLECT_CLOSE_THRESHOLD: float = 15.0       # 回収判定となるマウスとの距離

var mouse_interaction_enabled: bool = true

func _init(p_game_logic: GameLogic, p_particle_pool: ParticlePool, p_parent: Control) -> void:
	game_logic = p_game_logic
	particle_pool = p_particle_pool
	parent_node = p_parent

func process_mouse_attraction(delta: float, mouse_pos: Vector2, screen_size: Vector2, radius: float) -> void:
	for i in range(game_logic.elements.size() - 1, -1, -1):
		var item = game_logic.elements[i]
		
		if item.current_state != GameLogic.ParticleState.ACTIVE:
			item.is_attracted = false
			continue
			
		var dist_to_mouse = item.position.distance_to(mouse_pos)
		
		if item.age > game_logic.AGE_INTERACTION_THRESHOLD:
			if mouse_interaction_enabled and dist_to_mouse < game_logic.ATTRACT_RADIUS:
				item.is_attracted = true
			else:
				item.is_attracted = false
			
		if item.is_attracted:
			var direction = (mouse_pos - item.position).normalized()
			item.velocity = item.velocity.move_toward(direction * game_logic.FLY_SPEED, delta * SUCTION_ACCEL_SPEED)
			item.position += item.velocity * delta
			
			item.position.x = clamp(item.position.x, radius, screen_size.x - radius)
			item.position.y = clamp(item.position.y, radius, screen_size.y - radius)
			
			if item.sprite:
				item.sprite.global_position = item.position
				item.sprite.modulate = item.color
				item.sprite.modulate.a = 1.0
			
			if dist_to_mouse < COLLECT_CLOSE_THRESHOLD and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_collect_particle(item, i)

func _collect_particle(item: GameLogic.ElementItem, index: int) -> void:
	var inventory = parent_node.get_tree().get_first_node_in_group("inventory_bar")
	var stored: bool = false
	if inventory and inventory.has_method("add_item"):
		stored = inventory.add_item(item.name)
	
	if not stored:
		var trap = parent_node.get_tree().get_first_node_in_group("magnetic_trap_ui")
		if trap and trap.has_method("add_item"):
			stored = trap.add_item(item.name)
	
	if stored:
		var collect_pos = item.position
		if item.sprite:
			item.sprite.queue_free()
		game_logic.elements.remove_at(index)
		
		particle_pool.create_repair_streak(collect_pos)
		parent_node.get_tree().call_group("cubes", "repair")
		
		if game_logic.elements.size() == 0:
			AppLogger.info("全粒子回収完了 - ゲームループへ")
			parent_node.get_tree().call_group("cubes", "revive")

func can_drop_data_on_field(_at_position: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("particle_type")

func drop_data_on_field(_at_position: Vector2, data) -> void:
	if typeof(data) != TYPE_DICTIONARY or not data.has("particle_type"):
		return
	
	var type_name: String = data["particle_type"]
	var drop_pos: Vector2 = parent_node.get_global_mouse_position()
	
	particle_pool.spawn_single_element(type_name, drop_pos)
	
	if data.has("source_slot") and is_instance_valid(data["source_slot"]):
		data["source_slot"].clear()
