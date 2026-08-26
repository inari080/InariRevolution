# game/game_logic.gd
# GameLogic - 粒子の物理演算とグループ管理
class_name GameLogic
extends Node

enum ParticleState {
	ACTIVE,
	SUSPENDED,
}

class ElementItem:
	var name: String
	var color: Color
	var sprite: Sprite2D
	var position: Vector2
	var velocity: Vector2
	var is_attracted: bool = false
	var lifetime: float = 0.0
	var max_lifetime: float = 0.0
	var age: float = 0.0
	
	var current_state: ParticleState = ParticleState.ACTIVE
	
	var has_bounced: bool = false
	var bounce_timer: float = 0.0
	
	var close_particles: Array = []
	var stable_time: float = 0.0
	var is_grouped: bool = false
	var ungroup_timer: float = 0.0
	var photon_bonus_cooldown: float = 0.0
	var was_repelling: bool = false
	var repelling_now: bool = false
	
	var quark_group_time: float = 0.0

# --- 物理・ロジック定数 (マジックナンバーの排除) ---
const ATTRACT_RADIUS: float = 150.0
const FLY_SPEED: float = 800.0
const FRICTION_THRESHOLD: float = 250.0
const FRICTION_COEFF_LOW: float = 0.15
const FRICTION_COEFF_HIGH: float = 3.0
const QUARK_FUSION_DISTANCE: float = 70.0
const QUARK_FUSION_TIME: float = 3.0
const PAIR_STILL_SPEED: float = 6.0

const PARTICLE_RADIUS: float = 24.0               # 粒子の物理半径
const DETECT_CLOSE_RADIUS: float = 80.0           # 密着判定の距離
const GROUP_STABLE_DURATION: float = 3.0         # グループ化が確定するまでの秒数
const GROUP_UNGROUP_GRACE_PERIOD: float = 1.0     # グループ範囲外で解除を待つ猶予秒数
const BOUNCE_IMMUNITY_DURATION: float = 3.0       # 壁バウンド後の物理免除時間
const CHEMICAL_SPARK_DISTANCE: float = 30.0       # 化学火花が発生する接近距離
const CHEMICAL_SPARK_CHANCE: float = 0.1          # 化学火花が発生するフレーム毎の確率
const MAX_FORCE_DISTANCE: float = 400.0           # 磁力が及ぶ最大距離
const FORCE_MIN_LIMIT: float = 0.5                # 近づきすぎによる計算破綻を防ぐ距離下限
const REPEL_FORCE_MULTIPLIER: float = -5.0        # 反発時の力の倍率
const PHYSICS_ENGINE_TICK_SCALE: float = 60.0     # 物理移動のフレームレート補正スケール
const MIN_REQUIRED_GROUP_SIZE: int = 3             # 反発が発生する最低密着数
const PHOTON_SPAWN_CHANCE: float = 0.05           # 反発イベント時に光子が生まれる確率
const PHOTON_BONUS_GLOBAL_COOLDOWN: float = 4.0   # 次の光子が生まれるまでの全体クールダウン(秒)
const AGE_INTERACTION_THRESHOLD: float = 0.3      # 各種インタラクション(火花・吸い込み)が解禁される年齢
const FADE_OUT_DURATION: float = 3.0             # 寿命間際のフェードアウトにかける秒数

var elements: Array[ElementItem] = []
var global_photon_bonus_cooldown: float = 0.0

var on_chemical_spark: Callable
var on_wall_bounce: Callable
var on_cube_repair: Callable
var on_cube_revive: Callable

func _init() -> void:
	on_chemical_spark = func(_pos): pass
	on_wall_bounce = func(_pos, _color): pass
	on_cube_repair = func(): pass
	on_cube_revive = func(): pass

func set_all_particles_state(new_state: ParticleState) -> void:
	for item in elements:
		item.current_state = new_state
		if item.sprite:
			item.sprite.visible = (new_state == ParticleState.ACTIVE)

func process_quark_fusion(delta: float) -> void:
	var quark_items: Array = []
	for item in elements:
		if item.name == "Quark" and item.current_state == ParticleState.ACTIVE:
			quark_items.append(item)
	
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

func _fuse_quarks_into_proton(trio: Array) -> void:
	var center_pos: Vector2 = Vector2.ZERO
	for item in trio:
		center_pos += item.position
	center_pos /= trio.size()
	
	for item in trio:
		if item.sprite:
			item.sprite.queue_free()
		elements.erase(item)
	
	on_chemical_spark.call(center_pos)

func process_grouping(delta: float) -> void:
	for item in elements:
		item.close_particles.clear()
		item.photon_bonus_cooldown = max(0.0, item.photon_bonus_cooldown - delta)
		item.repelling_now = false
	
	global_photon_bonus_cooldown = max(0.0, global_photon_bonus_cooldown - delta)
	
	for i in range(elements.size()):
		var item_a = elements[i]
		if item_a.current_state != ParticleState.ACTIVE: continue
		
		for j in range(i + 1, elements.size()):
			var item_b = elements[j]
			if item_b.current_state != ParticleState.ACTIVE: continue
			if item_a.name == "Photon" or item_b.name == "Photon":
				continue
			if item_a.position.distance_to(item_b.position) < DETECT_CLOSE_RADIUS:
				item_a.close_particles.append(item_b)
				item_b.close_particles.append(item_a)
	
	for item in elements:
		if item.current_state != ParticleState.ACTIVE: continue
		
		if item.close_particles.size() >= 2:
			item.stable_time += delta
			item.ungroup_timer = 0.0
			if item.stable_time >= GROUP_STABLE_DURATION:
				item.is_grouped = true
		else:
			item.ungroup_timer += delta
			if item.ungroup_timer >= GROUP_UNGROUP_GRACE_PERIOD:
				item.stable_time = 0.0
				item.is_grouped = false
				if item.sprite: 
					item.sprite.modulate = item.color

func process_forces(delta: float, on_photon_spawn: Callable) -> void:
	for i in range(elements.size()):
		var item_a = elements[i]
		if item_a.current_state != ParticleState.ACTIVE: continue
		
		if item_a.has_bounced:
			item_a.bounce_timer += delta
		
		if not item_a.has_bounced or item_a.bounce_timer < BOUNCE_IMMUNITY_DURATION:
			continue
		
		if item_a.name == "Photon":
			continue
		
		for j in range(i + 1, elements.size()):
			var item_b = elements[j]
			if item_b.current_state != ParticleState.ACTIVE: continue
			if not item_b.has_bounced or item_b.bounce_timer < BOUNCE_IMMUNITY_DURATION:
				continue
			
			if item_b.name == "Photon":
				continue
			
			var to_b = item_b.position - item_a.position
			var distance = to_b.length()
			
			if distance < CHEMICAL_SPARK_DISTANCE and item_a.name != item_b.name:
				if item_a.age > AGE_INTERACTION_THRESHOLD and item_b.age > AGE_INTERACTION_THRESHOLD and randf() < CHEMICAL_SPARK_CHANCE:
					var mid_pos = item_a.position + (to_b / 2)
					on_chemical_spark.call(mid_pos)
			
			if distance > FORCE_MIN_LIMIT and distance < MAX_FORCE_DISTANCE:
				var direction = to_b.normalized()
				var base_force = 4000.0 / (distance * distance)
				base_force = clamp(base_force, 0.1, 8.0)
				
				var a_is_ready = item_a.is_grouped
				var b_is_ready = item_b.is_grouped
				
				var should_repel = false
				if (a_is_ready and item_a.close_particles.size() >= MIN_REQUIRED_GROUP_SIZE and i >= MIN_REQUIRED_GROUP_SIZE) or \
				   (b_is_ready and item_b.close_particles.size() >= MIN_REQUIRED_GROUP_SIZE and j >= MIN_REQUIRED_GROUP_SIZE):
					should_repel = true
				
				if should_repel:
					var repel_force = base_force * REPEL_FORCE_MULTIPLIER if typeof(REPEL_FORCE_MULTIPLIER) == TYPE_FLOAT else base_force * -5.0
					var alert_flash = sin(Time.get_ticks_msec() * 0.05)
					var alert_color = Color(5.0, 0.2, 0.2, 1.0) if alert_flash > 0.0 else item_a.color
					
					if item_a.sprite: 
						item_a.sprite.modulate = alert_color
					if item_b.sprite: 
						item_b.sprite.modulate = alert_color
					
					item_a.velocity += direction * repel_force * PHYSICS_ENGINE_TICK_SCALE * delta
					item_b.velocity -= direction * repel_force * PHYSICS_ENGINE_TICK_SCALE * delta
					
					var is_new_repel_event = not item_a.was_repelling and not item_b.was_repelling
					item_a.repelling_now = true
					item_b.repelling_now = true
					
					if is_new_repel_event:
						var a_is_qe = item_a.name == "Quark" or item_a.name == "Electron"
						var b_is_qe = item_b.name == "Quark" or item_b.name == "Electron"
						var bonus_eligible = a_is_qe and b_is_qe
						
						if bonus_eligible and global_photon_bonus_cooldown <= 0.0 and randf() < PHOTON_SPAWN_CHANCE:
							var mid_pos_repel = item_a.position + (to_b / 2)
							global_photon_bonus_cooldown = PHOTON_BONUS_GLOBAL_COOLDOWN
							on_photon_spawn.call(mid_pos_repel)
				else:
					if item_a.sprite and item_a.stable_time < GROUP_STABLE_DURATION: 
						item_a.sprite.modulate = item_a.color
					if item_b.sprite and item_b.stable_time < GROUP_STABLE_DURATION: 
						item_b.sprite.modulate = item_b.color
					
					item_a.velocity += direction * base_force * PHYSICS_ENGINE_TICK_SCALE * delta
					item_b.velocity -= direction * base_force * PHYSICS_ENGINE_TICK_SCALE * delta
	
	for item in elements:
		item.was_repelling = item.repelling_now

func process_particles(delta: float, screen_size: Vector2) -> void:
	for i in range(elements.size() - 1, -1, -1):
		var item = elements[i]
		
		if item.current_state != ParticleState.ACTIVE:
			continue
			
		if item.is_attracted:
			continue
		
		# 1. 寿命の一時停止チェック
		var life_paused: bool = false
		if item.name == "Photon":
			life_paused = true
		elif item.is_grouped:
			life_paused = true
		elif item.close_particles.size() == 1 and item.velocity.length() > PAIR_STILL_SPEED:
			life_paused = true
		
		if not life_paused:
			item.lifetime += delta
		item.age += delta
		
		# 2. 寿命切れ（消滅）の判定
		if item.lifetime >= item.max_lifetime:
			var vanish_pos = item.position
			if item.sprite:
				item.sprite.queue_free()
			elements.remove_at(i)
			
			on_cube_repair.call(vanish_pos)
			
			if elements.size() == 0:
				on_cube_revive.call()
			continue # 寿命が尽きたアイテムはここで処理を終了して次のアイテムへ
		
		# 3. X軸の壁衝突判定（左・右）
		if item.position.x < PARTICLE_RADIUS:
			item.position.x = PARTICLE_RADIUS
			item.velocity.x = abs(item.velocity.x)
			item.has_bounced = true
			on_wall_bounce.call(item.position, item.color)
		elif item.position.x > screen_size.x - PARTICLE_RADIUS:
			item.position.x = screen_size.x - PARTICLE_RADIUS
			item.velocity.x = -abs(item.velocity.x)
			item.has_bounced = true
			on_wall_bounce.call(item.position, item.color)

		# 4. Y軸の壁衝突判定（上・下）
		if item.position.y < PARTICLE_RADIUS:
			item.position.y = PARTICLE_RADIUS
			item.velocity.y = abs(item.velocity.y)
			item.has_bounced = true
			on_wall_bounce.call(item.position, item.color)
		elif item.position.y > screen_size.y - PARTICLE_RADIUS:
			item.position.y = screen_size.y - PARTICLE_RADIUS
			item.velocity.y = -abs(item.velocity.y)
			item.has_bounced = true
			on_wall_bounce.call(item.position, item.color)

		# 5. 摩擦と移動の物理計算
		var speed: float = item.velocity.length()
		var friction_coeff: float = FRICTION_COEFF_HIGH if speed > FRICTION_THRESHOLD else FRICTION_COEFF_LOW
		item.velocity -= item.velocity * friction_coeff * delta
		item.position += item.velocity * delta

		# 6. スプライトの見た目の更新
		if item.sprite:
			item.sprite.global_position = item.position
			
			# アルファ値（透明度）のパルスアニメーション（ループカウンタ 'i' を反映）
			var base_alpha: float = 1.0
			var pulse = sin(item.lifetime * 3.5 + i * 0.5)
			var pulse_alpha = remap(pulse, -1.0, 1.0, 0.4, 1.0)
			
			# 寿命が尽きかける時のフェードアウト処理
			if item.lifetime > (item.max_lifetime - FADE_OUT_DURATION):
				var time_left = item.max_lifetime - item.lifetime
				base_alpha = time_left / FADE_OUT_DURATION
				
			# 最終的な色と透明度の適用
			var final_color = item.color
			final_color.a = pulse_alpha * base_alpha
			item.sprite.modulate = final_color
