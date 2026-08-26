extends Control

# 粒子（元素）のデータを保持する構造体
class ElementItem:
	var name: String
	var color: Color
	var sprite: Sprite2D
	var position: Vector2
	var velocity: Vector2
	var is_attracted: bool = false
	var lifetime: float = 0.0
	var max_lifetime: float = 0.0
	var age: float = 0.0 # ★生まれてからの経過時間（グループ等で寿命が止まっていても常に増え続ける）
	
	var has_bounced: bool = false
	var bounce_timer: float = 0.0
	
	var close_particles: Array = []
	var stable_time: float = 0.0
	var is_grouped: bool = false
	var ungroup_timer: float = 0.0 # ★グループ範囲から外れてからの経過時間（1秒でグループ解除）
	var photon_bonus_cooldown: float = 0.0 # ★反発による光子ボーナスの連発を防ぐクールダウン
	var was_repelling: bool = false # ★直前まで反発状態だったか（1	反発イベントにつき1回だけ抽選するため）
	var repelling_now: bool = false # ★今フレームの反発状態（内部スクラッチ用）
	
	# ★【追加】クォーク3個1組の合体判定用：近くにクォークが2個以上いる状態が続いた時間
	var quark_group_time: float = 0.0

# 画面上の粒子たちを記録するリスト
var elements: Array[ElementItem] = []

# ★【追加】磁気トラップ画面が開いている間はマウスによる吸い寄せ・回収を止める
var mouse_interaction_enabled: bool = true

# ★【追加】反発による光子ボーナスの全体クールダウン（グループ全体で共有）
# ペアごとのクールダウンだけだと、ペアの数が多いグループでは
# 「どれかのペアは必ず当たる」状態になってしまうため、これで頻度に上限をかける
var global_photon_bonus_cooldown: float = 0.0

const ATTRACT_RADIUS: float = 150.0
const FLY_SPEED: float = 800.0
# ★速度に応じた2段階の摩擦
# 一定の速さ(FRICTION_THRESHOLD)を超えている間だけ強めの摩擦(FRICTION_COEFF_HIGH)がかかり、
# それ以下の遅い粒子はほとんど減速しない(FRICTION_COEFF_LOW)ようにする
const FRICTION_THRESHOLD: float = 250.0
const FRICTION_COEFF_LOW: float = 0.15
const FRICTION_COEFF_HIGH: float = 3.0

# ★【追加】クォーク3個1組 → 陽子(Proton)への合体条件
const QUARK_FUSION_DISTANCE: float = 70.0 # この距離以内なら「近くにいる」とみなす
const QUARK_FUSION_TIME: float = 3.0      # この秒数だけ3個以上でまとまり続けたら合体する

# HPに応じた出現数の調整用パラメータ
# 「壊れた瞬間のHP(round_capacity)」が少ないほど出現数を少なく、
# 多いほど出現数を多くする（＝HPに比例）
const CAPACITY_MIN: int = 1   # このラウンドの到達HPの最小値
const CAPACITY_MAX: int = 5   # GlowingCubeのMAX_HPと合わせる
const SPAWN_COUNT_MIN: int = 2   # HPが低い(=回復途中)で壊した時の最小出現数
const SPAWN_COUNT_MAX: int = 8   # HPが高い(=満タン付近)で壊した時の最大出現数（約30%減）

# キューブへ飛んでいく白い光の演出パラメータ
const STREAK_SIZE: float = 14.0
const STREAK_DURATION: float = 0.35

# ★【追加】画面右端に確保するサイドバー(UIタブ)幅ぶん、遊び場を狭める
# ※ magnetic_trap_ui.gd の SIDEBAR_WIDTH と必ず同じ値にすること
const RESERVED_RIGHT_WIDTH: float = 190.0

const tex_quark = preload("res://quark.png")
const tex_electron = preload("res://electron.png")
const tex_photon = preload("res://photon.png")

func _ready() -> void:
	# ★【追加】磁気トラップ画面を開いた時に、遊び場側から粒子を隠せるようにする
	add_to_group("game_field")
	
	# このノード(Main)自身の当たり判定を画面全体に広げる
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# ★【追加】"Background"(黒い背景のColorRect)がデフォルトのmouse_filter(STOP)
	# のままだと、何もない黒い空間でのドラッグ&ドロップをこのノードが横取りしてしまい、
	# 親であるmain(このスクリプト)の _drop_data() まで届かない。
	# → マウス判定を無視するようにして、ちゃんと下(main)まで通す。
	var background = get_node_or_null("Background")
	if background:
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var screen_size = get_viewport_rect().size
	# ★【追加】右端のサイドバー分を引いて、粒子がその下に潜り込まないようにする
	screen_size.x -= RESERVED_RIGHT_WIDTH
	var radius = 24.0
	
	const FADE_DURATION: float = 3.0
	
	# --- 0. クォーク3個1組の合体判定（陽子への変化） ---
	_process_quark_fusion(delta)
	
	# --- 1. 密着状態の事前調査カウンター ---
	for item in elements:
		item.close_particles.clear()
		item.photon_bonus_cooldown = max(0.0, item.photon_bonus_cooldown - delta) # ★光子ボーナスのクールダウン更新
		item.repelling_now = false # ★このフレームの反発状態をいったんリセット
	
	global_photon_bonus_cooldown = max(0.0, global_photon_bonus_cooldown - delta) # ★光子ボーナスの全体クールダウン更新
		
	for i in range(elements.size()):
		var item_a = elements[i]
		for j in range(i + 1, elements.size()):
			var item_b = elements[j]
			# ★光子はグループを作らない（他の粒子のグループにもカウントされない）
			if item_a.name == "Photon" or item_b.name == "Photon":
				continue
			if item_a.position.distance_to(item_b.position) < 80.0:
				item_a.close_particles.append(item_b)
				item_b.close_particles.append(item_a)

	for item in elements:
		if item.close_particles.size() >= 2:
			item.stable_time += delta
			item.ungroup_timer = 0.0 # ★範囲内に戻ったので解除タイマーをリセット
			if item.stable_time >= 3.0:
				item.is_grouped = true
		else:
			# ★即座に解除せず、範囲外の状態が1秒間続いて初めてグループを解除する
			# （1秒以内に範囲へ戻ればグループは継続する）
			item.ungroup_timer += delta
			if item.ungroup_timer >= 1.0:
				item.stable_time = 0.0
				item.is_grouped = false
				if item.sprite: item.sprite.modulate = item.color

	# --- 2. 磁力 ＆ 反発計算 ---
	for i in range(elements.size()):
		var item_a = elements[i]
		
		if item_a.has_bounced:
			item_a.bounce_timer += delta
			
		if not item_a.has_bounced or item_a.bounce_timer < 3.0:
			continue
		
		# ★光子は何にも引き寄せられず、何も引き寄せず、反発もしない（完全に無関係でいる）
		if item_a.name == "Photon":
			continue
			
		for j in range(i + 1, elements.size()):
			var item_b = elements[j]
			if not item_b.has_bounced or item_b.bounce_timer < 3.0:
				continue
			
			if item_b.name == "Photon":
				continue
				
			var to_b = item_b.position - item_a.position
			var distance = to_b.length()
			
			if distance < 30.0 and item_a.name != item_b.name:
				if item_a.age > 0.3 and item_b.age > 0.3 and randf() < 0.1:
					var mid_pos = item_a.position + (to_b / 2)
					create_chemical_spark(mid_pos)
			
			# ★【修正】距離の下限を10.0→0.5に緩和。
			# 密集しすぎて距離が10未満になると力が一切働かず、グループが固まって
			# 動かなくなってしまい、（別の場所で）光子が生まれたタイミングだけ
			# たまたま動き出したように見えるバグの原因だったため。
			if distance > 0.5 and distance < 400.0:
				var direction = to_b.normalized()
				var base_force = 4000.0 / (distance * distance)
				base_force = clamp(base_force, 0.1, 8.0)
				
				var a_is_ready = item_a.is_grouped
				var b_is_ready = item_b.is_grouped
				
				var should_repel = false
				if (a_is_ready and item_a.close_particles.size() >= 3 and i >= 3) or \
				   (b_is_ready and item_b.close_particles.size() >= 3 and j >= 3):
					should_repel = true
				
				if should_repel:
					var repel_force = -base_force * 5.0
					var alert_flash = sin(Time.get_ticks_msec() * 0.05)
					var alert_color = Color(5.0, 0.2, 0.2, 1.0) if alert_flash > 0.0 else item_a.color
					
					if item_a.sprite: item_a.sprite.modulate = alert_color
					if item_b.sprite: item_b.sprite.modulate = alert_color
					
					item_a.velocity += direction * repel_force * 60.0 * delta
					item_b.velocity -= direction * repel_force * 60.0 * delta
					
					# ★【修正】「反発している間ずっと毎フレーム抽選」だと、数十フレームのうちに
					# ほぼ確実に成功してしまい実質「反発したら必ず光子が生まれる」状態になっていた。
					# → 反発イベントが「新しく始まった瞬間」だけ1回だけ抽選するように変更。
					# 反発が続いている間は再抽選せず、一度止まってから再度反発が始まった時だけ
					# また抽選のチャンスが来る。
					var is_new_repel_event = not item_a.was_repelling and not item_b.was_repelling
					item_a.repelling_now = true
					item_b.repelling_now = true
					
					if is_new_repel_event:
						# クォークか電子どうしの反発の時だけ、5%の確率でご褒美として光子が1個生まれる
						# （陽子が絡む反発では出さない）
						var a_is_qe = item_a.name == "Quark" or item_a.name == "Electron"
						var b_is_qe = item_b.name == "Quark" or item_b.name == "Electron"
						var bonus_eligible = a_is_qe and b_is_qe
						
						if bonus_eligible and global_photon_bonus_cooldown <= 0.0 and randf() < 0.05:
							var mid_pos_repel = item_a.position + (to_b / 2)
							_create_and_register_element("Photon", mid_pos_repel)
							global_photon_bonus_cooldown = 4.0 # ★次に光子が生まれるまで最低4秒は空ける
				else:
					if item_a.sprite and item_a.stable_time < 3.0: item_a.sprite.modulate = item_a.color
					if item_b.sprite and item_b.stable_time < 3.0: item_b.sprite.modulate = item_b.color
					
					item_a.velocity += direction * base_force * 60.0 * delta
					item_b.velocity -= direction * base_force * 60.0 * delta

	# ★次フレームで「反発が新しく始まった瞬間」を判定できるよう、今フレームの反発状態を記録しておく
	for item in elements:
		item.was_repelling = item.repelling_now

	# --- 3. 通常の移動・壁バウンド・マウス吸い込み処理 ---
	const PAIR_STILL_SPEED: float = 6.0 # ★ペア(2個1組)がこの速さを下回ったら「ほぼ止まった」とみなす
	
	for i in range(elements.size() - 1, -1, -1):
		var item = elements[i]
		
		# ★寿命の進み方のルール:
		#   ・光子(Photon)：安定しているので寿命そのものが尽きない
		#   ・3個以上の安定グループ(is_grouped)：グループでいる間は寿命が尽きない（従来通り）
		#   ・2個1組のペア（close_particles.size()==1）：お互いの動きがほとんど止まるまでは
		#     寿命が尽きず、ほぼ止まったら（PAIR_STILL_SPEED未満）寿命カウントが再始動する
		#   ・それ以外：通常通り毎フレーム寿命が進む
		var life_paused: bool = false
		if item.name == "Photon":
			life_paused = true
		elif item.is_grouped:
			life_paused = true
		elif item.close_particles.size() == 1 and item.velocity.length() > PAIR_STILL_SPEED:
			life_paused = true
		
		if not life_paused:
			item.lifetime += delta
		item.age += delta # ★吸い寄せ解禁などの判定用に、寿命が止まっていても常に加算
		
		# ★寿命を迎えて粒子が消滅したときのペナルティ処理
		if item.lifetime >= item.max_lifetime:
			var vanish_pos = item.position
			if item.sprite:
				item.sprite.queue_free()
			elements.remove_at(i)
			
			# 消えた場所からキューブへ向けて白い光をぴゅーんと飛ばす
			create_repair_streak(vanish_pos)
			
			# 裏で待機している四角形（GlowingCube）にHPを1回復させる
			get_tree().call_group("cubes", "repair")
			
			# 全ての粒子が消え去った場合、四角形を完全に復活させてリトライ可能に
			if elements.size() == 0:
				get_tree().call_group("cubes", "revive")
			continue
		
		var dist_to_mouse = item.position.distance_to(mouse_pos)
		
		if item.age > 0.3:
			if mouse_interaction_enabled and dist_to_mouse < ATTRACT_RADIUS:
				item.is_attracted = true
			else:
				item.is_attracted = false
			
		if item.is_attracted:
			var direction = (mouse_pos - item.position).normalized()
			item.velocity = item.velocity.move_toward(direction * FLY_SPEED, delta * 3000.0)
			item.position += item.velocity * delta
			
			# ★【追加】吸い寄せ中でも、右のサイドバーUIや画面外へはみ出さないように制限する
			item.position.x = clamp(item.position.x, radius, screen_size.x - radius)
			item.position.y = clamp(item.position.y, radius, screen_size.y - radius)
			
			if item.sprite:
				item.sprite.global_position = item.position
				item.sprite.modulate = item.color # 吸い込み時は元の鮮やかな色に固定
				item.sprite.modulate.a = 1.0
			
			if dist_to_mouse < 15.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				# ★【変更】回収した粒子は磁気トラップを経由せず、直接インベントリーへ入れる。
				# インベントリーが満杯の場合は回収せず、その場に漂わせたままにする。
				var inventory = get_tree().get_first_node_in_group("inventory_bar")
				var stored: bool = false
				if inventory and inventory.has_method("add_item"):
					stored = inventory.add_item(item.name)
				
				# ★【追加】通常のインベントリーが満杯だった場合、
				# 磁気トラップの粒子インベントリー（1枠10個までスタック）へ回す
				if not stored:
					var trap = get_tree().get_first_node_in_group("magnetic_trap_ui")
					if trap and trap.has_method("add_item"):
						stored = trap.add_item(item.name)
				
				if stored:
					var collect_pos = item.position
					if item.sprite:
						item.sprite.queue_free()
					elements.remove_at(i)
					
					# 回収した場所からキューブへ向けて白い光をぴゅーんと飛ばす
					create_repair_streak(collect_pos)
					
					# 回収されて粒子が1つ消えた分だけ、キューブを下から復活させる
					get_tree().call_group("cubes", "repair")
					
					# 回収しきった時は勝手に2つの白い物体（spawn_next_stage）を出さないようにします
					if elements.size() == 0:
						# ❌ 削除: print("すべての粒子を完璧に回収した！")
						# ⭕ 競合を避けるため AppLogger.info を使用してログを出力
						AppLogger.info("全粒子回収完了 - ゲームループへ")
						# ※ここに将来、次の創造レシピ（水素の誕生など）の処理を入れます
						get_tree().call_group("cubes", "revive") # 一旦ループのためにキューブを戻します
					continue
				# 通常のインベントリーも磁気トラップも満杯 → 回収しない（そのまま漂い続ける）

		else:
			if item.position.x < radius:
				item.position.x = radius
				item.velocity.x = abs(item.velocity.x)
				item.has_bounced = true
				create_wall_bounce_effect(item.position, item.color)
			elif item.position.x > screen_size.x - radius:
				item.position.x = screen_size.x - radius
				item.velocity.x = -abs(item.velocity.x)
				item.has_bounced = true
				create_wall_bounce_effect(item.position, item.color)
				
			if item.position.y < radius:
				item.position.y = radius
				item.velocity.y = abs(item.velocity.y)
				item.has_bounced = true
				create_wall_bounce_effect(item.position, item.color)
			elif item.position.y > screen_size.y - radius:
				item.position.y = screen_size.y - radius
				item.velocity.y = -abs(item.velocity.y)
				item.has_bounced = true
				create_wall_bounce_effect(item.position, item.color)

			# ★【変更】一定の速さ(FRICTION_THRESHOLD)を超えている時だけ強めの摩擦をかける
			# → ゆっくり動いている粒子はほぼそのまま漂い続け、速い粒子だけしっかりブレーキがかかる
			var speed: float = item.velocity.length()
			var friction_coeff: float = FRICTION_COEFF_HIGH if speed > FRICTION_THRESHOLD else FRICTION_COEFF_LOW
			item.velocity -= item.velocity * friction_coeff * delta
			item.position += item.velocity * delta
			
			if item.sprite:
				item.sprite.global_position = item.position
				
				var base_alpha: float = 1.0
				var pulse = sin(item.lifetime * 3.5 + i * 0.5)
				var pulse_alpha = remap(pulse, -1.0, 1.0, 0.4, 1.0)
				
				if item.lifetime > (item.max_lifetime - FADE_DURATION):
					var time_left = item.max_lifetime - item.lifetime
					base_alpha = time_left / FADE_DURATION
				
				var final_color = item.color
				final_color.a = pulse_alpha * base_alpha
				item.sprite.modulate = final_color

func _draw() -> void:
	pass

# ★【追加】クォークが3個以上近くでまとまっている状態が一定時間続いたら、
# そのうち3個を陽子(Proton)1個に変化させる。
func _process_quark_fusion(delta: float) -> void:
	var quark_items: Array = []
	for item in elements:
		if item.name == "Quark":
			quark_items.append(item)
	
	# 各クォークについて、近くにいる「他のクォーク」の数を数え、
	# 2個以上近くにいれば（＝自分を含めて3個以上のまとまり）継続時間を進める。
	# 条件から外れたら継続時間はリセットする。
	for i in range(quark_items.size()):
		var item_a = quark_items[i]
		var nearby_quark_count: int = 0
		for j in range(quark_items.size()):
			if i == j:
				continue
			if item_a.position.distance_to(quark_items[j].position) < QUARK_FUSION_DISTANCE:
				nearby_quark_count += 1
		
		if nearby_quark_count >= 2:
			item_a.quark_group_time += delta
		else:
			item_a.quark_group_time = 0.0
	
	# 継続時間の条件を満たしたクォークどうしを3個1組にまとめて合体させる
	var used: Array = []
	for i in range(quark_items.size()):
		var item_a = quark_items[i]
		if item_a.quark_group_time < QUARK_FUSION_TIME or item_a in used:
			continue
		
		var partners: Array = []
		for j in range(quark_items.size()):
			if i == j:
				continue
			var item_b = quark_items[j]
			if item_b in used or item_b.quark_group_time < QUARK_FUSION_TIME:
				continue
			if item_a.position.distance_to(item_b.position) < QUARK_FUSION_DISTANCE:
				partners.append(item_b)
			if partners.size() >= 2:
				break
		
		if partners.size() >= 2:
			var trio: Array = [item_a, partners[0], partners[1]]
			used.append_array(trio)
			_fuse_quarks_into_proton(trio)

# クォーク3個をまとめて消し、その中心位置に陽子(Proton)を1個生成する
func _fuse_quarks_into_proton(trio: Array) -> void:
	var center_pos: Vector2 = Vector2.ZERO
	for item in trio:
		center_pos += item.position
	center_pos /= trio.size()
	
	for item in trio:
		if item.sprite:
			item.sprite.queue_free()
		elements.erase(item)
	
	create_chemical_spark(center_pos) # 合体の瞬間を光の火花で目立たせる（流用）
	_create_and_register_element("Proton", center_pos)

# ★【追加】磁気トラップ画面（別画面切り替え）を開いている間、
# 浮遊中の粒子スプライトを隠す/戻すための切り替え関数。
# キューブ自体は magnetic_trap_ui.gd 側から call_group("cubes","hide"/"show") で制御する。
func set_particles_visible(v: bool) -> void:
	mouse_interaction_enabled = v # ★【追加】非表示＝マウスでの吸い寄せ・回収も同時に無効化
	for item in elements:
		if item.sprite:
			item.sprite.visible = v

# countにはGlowingCubeから渡された「壊れた瞬間の到達HP(round_capacity)」が入る
# HPが低いほど少なく、高いほど多く粒子が出るように比例配分する
func spawn_elements(start_pos: Vector2, count: int) -> void:
	var capacity: int = clampi(count, CAPACITY_MIN, CAPACITY_MAX)
	var ratio: float = 0.0
	if CAPACITY_MAX > CAPACITY_MIN:
		ratio = float(capacity - CAPACITY_MIN) / float(CAPACITY_MAX - CAPACITY_MIN)
	
	var base_count: int = int(round(lerp(float(SPAWN_COUNT_MIN), float(SPAWN_COUNT_MAX), ratio)))
	# 多少のランダム性を持たせつつ、最終的にHPに応じた範囲内へクランプ
	var random_count: int = clampi(base_count + randi_range(-1, 1), SPAWN_COUNT_MIN, SPAWN_COUNT_MAX)
	
	for i in range(random_count):
		var roll = randf_range(0.0, 100.0)
		var type_name = ""
		
		# ★【変更】光子の出現率を10%→1%に引き下げ、浮いた9%はクォークと電子に均等配分
		#   Quark: 50% → 54.5% / Electron: 40% → 44.5% / Photon: 10% → 1%
		if roll < 54.5:
			type_name = "Quark"
		elif roll < 99.0:
			type_name = "Electron"
		else:
			type_name = "Photon"
		
		_create_and_register_element(type_name, start_pos)

# ★【追加】インベントリーからドラッグ&ドロップされた粒子を1個だけ、
# 指定位置にそのまま「放出」する（また物理演算に戻す）
func spawn_single_element(type_name: String, start_pos: Vector2) -> void:
	_create_and_register_element(type_name, start_pos)

# 粒子1個ぶんの生成処理（spawn_elements / spawn_single_element の共通処理）
func _create_and_register_element(type_name: String, start_pos: Vector2) -> void:
	var item = ElementItem.new()
	item.position = start_pos
	# ★陽子(Proton)は安定した粒子なので、他の粒子よりずっと長く（3分）存在し続ける
	item.max_lifetime = 180.0 if type_name == "Proton" else randf_range(30.0, 50.0)
	
	var type_color: Color
	var type_tex
	
	match type_name:
		"Quark":
			type_color = Color(4.0, 1.0, 1.0, 1.0)
			type_tex = tex_quark
		"Electron":
			type_color = Color(1.0, 4.0, 1.0, 1.0)
			type_tex = tex_electron
		"Photon":
			type_color = Color(4.0, 4.0, 1.0, 1.0)
			type_tex = tex_photon
		"Proton":
			# ★【追加】陽子専用の画像がまだ無いので、当面はクォークの画像を
			# 少し大きく・金色っぽい色味で流用する（画像を用意でき次第、専用テクスチャに差し替え可）
			type_color = Color(4.0, 2.6, 0.6, 1.0)
			type_tex = tex_quark
		_:
			type_color = Color(3.0, 3.0, 3.0, 1.0)
			type_tex = tex_quark
	
	item.name = type_name
	item.color = type_color
	
	var sp = Sprite2D.new()
	sp.texture = type_tex
	sp.global_position = start_pos
	sp.modulate = Color(3.0, 3.0, 3.0, 1.0)
	
	if sp.texture:
		var tex_size = sp.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			var target_size: float = 64.0 if type_name == "Proton" else 48.0 # ★陽子は一回り大きく表示
			sp.scale = Vector2(target_size / tex_size.x, target_size / tex_size.y)
	
	add_child(sp)
	item.sprite = sp
	
	var angle = randf() * TAU
	var speed = randf_range(80.0, 200.0)
	item.velocity = Vector2(cos(angle), sin(angle)) * speed
	
	elements.append(item)

# ★【追加】インベントリーのアイテムを画面（空間）にドラッグ&ドロップできるようにする
func _can_drop_data(_at_position: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("particle_type")

func _drop_data(_at_position: Vector2, data) -> void:
	if typeof(data) != TYPE_DICTIONARY or not data.has("particle_type"):
		return
	
	var type_name: String = data["particle_type"]
	var drop_pos: Vector2 = get_global_mouse_position()
	
	spawn_single_element(type_name, drop_pos)
	
	if data.has("source_slot") and is_instance_valid(data["source_slot"]):
		data["source_slot"].clear()

# spawn_next_stage() 内の2つのキューブ生成処理を削除
func spawn_next_stage() -> void:
	pass

func create_new_cube(spawn_position: Vector2) -> void:
	var new_cube = ColorRect.new()
	new_cube.name = "GlowingCube"
	new_cube.size = Vector2(100, 100)
	new_cube.position = spawn_position - Vector2(50, 50)
	new_cube.modulate = Color(3.0, 3.0, 3.0, 1.0)
	
	var cube_script = load("res://glowing_cube.gd")
	new_cube.set_script(cube_script)
	add_child(new_cube)

func create_chemical_spark(spark_position: Vector2) -> void:
	# ★磁気トラップ画面が開いている間（＝粒子が非表示の間）は火花も出さない
	if not mouse_interaction_enabled:
		return
	
	var spark = CPUParticles2D.new()
	spark.global_position = spark_position
	spark.z_index = 1000 # ★磁気トラップ画面などのUIより手前に描画されるようにする
	
	spark.amount = 5
	spark.lifetime = 0.4
	spark.one_shot = true
	spark.explosiveness = 0.9
	
	spark.direction = Vector2.ZERO
	spark.gravity = Vector2.ZERO
	spark.initial_velocity_min = 30.0
	spark.initial_velocity_max = 80.0
	
	spark.modulate = Color(4.0, 4.0, 4.0, 1.0) 
	
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(spark.queue_free)
	
	add_child(spark)

# ★【追加】粒子が画面端の壁に反射した瞬間に出す小さな光のエフェクト
func create_wall_bounce_effect(bounce_position: Vector2, particle_color: Color) -> void:
	# ★磁気トラップ画面が開いている間（＝粒子が非表示の間）はこの火花も出さない
	if not mouse_interaction_enabled:
		return
	
	var spark = CPUParticles2D.new()
	spark.global_position = bounce_position
	
	spark.amount = 6
	spark.lifetime = 0.3
	spark.one_shot = true
	spark.explosiveness = 1.0
	
	spark.direction = Vector2.ZERO
	spark.spread = 180.0
	spark.gravity = Vector2.ZERO
	spark.initial_velocity_min = 40.0
	spark.initial_velocity_max = 110.0
	spark.scale_amount_min = 0.5
	spark.scale_amount_max = 1.0
	
	spark.modulate = particle_color
	
	add_child(spark)
	
	var timer = get_tree().create_timer(0.4)
	timer.timeout.connect(spark.queue_free)

# 粒子が消えた地点(from_pos)から、待機中のキューブへ向かって
# 白い光の球をぴゅーんと飛ばす演出。到達後は自動的に消える。
func create_repair_streak(from_pos: Vector2) -> void:
	var cubes = get_tree().get_nodes_in_group("cubes")
	if cubes.is_empty():
		return
	
	# 対象のキューブ（現状は1体運用想定なので先頭を採用）
	var target_cube = cubes[0]
	if not (target_cube is Control):
		return
	
	var target_pos: Vector2 = target_cube.global_position + (target_cube.size / 2)
	
	var streak = ColorRect.new()
	streak.color = Color(3.0, 3.0, 3.0, 1.0) # 発光させたいので1.0を超える値にしてブルームが乗るようにする
	streak.size = Vector2(STREAK_SIZE, STREAK_SIZE)
	streak.pivot_offset = streak.size / 2
	streak.global_position = from_pos - streak.size / 2
	streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(streak)
	
	# 飛んでいく方向にほんの少し伸びる「尾」を出すため、進行方向に合わせて初期スケールを縦長に
	var to_target = target_pos - from_pos
	streak.rotation = to_target.angle()
	streak.scale = Vector2(1.6, 0.5)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 加速しながらキューブへ吸い込まれるように移動（EASE_IN = だんだん速くなる）
	tween.tween_property(streak, "global_position", target_pos - streak.size / 2, STREAK_DURATION)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# 到達直前でキュッと小さくしぼませて消す
	tween.tween_property(streak, "scale", Vector2(0.1, 0.1), STREAK_DURATION)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	tween.chain().tween_callback(streak.queue_free)
