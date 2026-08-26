# game/game_logic.gd
# GameLogic - 粒子の物理演算とグループ管理
class_name GameLogic
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
	var age: float = 0.0
	
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

# 物理パラメータ
const ATTRACT_RADIUS: float = 150.0
const FLY_SPEED: float = 800.0
const FRICTION_THRESHOLD: float = 250.0
const FRICTION_COEFF_LOW: float = 0.15
const FRICTION_COEFF_HIGH: float = 3.0
const QUARK_FUSION_DISTANCE: float = 70.0
const QUARK_FUSION_TIME: float = 3.0
const PAIR_STILL_SPEED: float = 6.0

var elements: Array[ElementItem] = []
var global_photon_bonus_cooldown: float = 0.0

# コールバック（エフェクト生成用）
var on_chemical_spark: Callable
var on_wall_bounce: Callable
var on_cube_repair: Callable
var on_cube_revive: Callable

func _init() -> void:
	on_chemical_spark = func(_pos): pass
	on_wall_bounce = func(_pos, _color): pass
	on_cube_repair = func(): pass
	on_cube_revive = func(): pass

# クォーク3個1組の合体判定
func process_quark_fusion(delta: float) -> void:
	var quark_items: Array = []
	for item in elements:
		if item.name == "Quark":
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

# グループ化・密着判定
func process_grouping(delta: float) -> void:
	for item in elements:
		item.close_particles.clear()
		item.photon_bonus_cooldown = max(0.0, item.photon_bonus_cooldown - delta)
		item.repelling_now = false
	
	global_photon_bonus_cooldown = max(0.0, global_photon_bonus_cooldown - delta)
	
	for i in range(elements.size()):
		var item_a = elements[i]
		for j in range(i + 1, elements.size()):
			var item_b = elements[j]
			if item_a.name == "Photon" or item_b.name == "Photon":
				continue
			if item_a.position.distance_to(item_b.position) < 80.0:
				item_a.close_particles.append(item_b)
				item_b.close_particles.append(item_a)
	
	for item in elements:
		if item.close_particles.size() >= 2:
			item.stable_time += delta
			item.ungroup_timer = 0.0
			if item.stable_time >= 3.0:
				item.is_grouped = true
		else:
			item.ungroup_timer += delta
			if item.ungroup_timer >= 1.0:
				item.stable_time = 0.0
				item.is_grouped = false
				if item.sprite: 
					item.sprite.modulate = item.color

# 磁力・反発力計算
func process_forces(delta: float, on_photon_spawn: Callable) -> void:
	for i in range(elements.size()):
		var item_a = elements[i]
		
		if item_a.has_bounced:
			item_a.bounce_timer += delta
		
		if not item_a.has_bounced or item_a.bounce_timer < 3.0:
			continue
		
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
					on_chemical_spark.call(mid_pos)
			
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
					
					if item_a.sprite: 
						item_a.sprite.modulate = alert_color
					if item_b.sprite: 
						item_b.sprite.modulate = alert_color
					
					item_a.velocity += direction * repel_force * 60.0 * delta
					item_b.velocity -= direction * repel_force * 60.0 * delta
					
					var is_new_repel_event = not item_a.was_repelling and not item_b.was_repelling
					item_a.repelling_now = true
					item_b.repelling_now = true
					
					if is_new_repel_event:
						var a_is_qe = item_a.name == "Quark" or item_a.name == "Electron"
						var b_is_qe = item_b.name == "Quark" or item_b.name == "Electron"
						var bonus_eligible = a_is_qe and b_is_qe
						
						if bonus_eligible and global_photon_bonus_cooldown <= 0.0 and randf() < 0.05:
							var mid_pos_repel = item_a.position + (to_b / 2)
							global_photon_bonus_cooldown = 4.0
							on_photon_spawn.call(mid_pos_repel)
				else:
					if item_a.sprite and item_a.stable_time < 3.0: 
						item_a.sprite.modulate = item_a.color
					if item_b.sprite and item_b.stable_time < 3.0: 
						item_b.sprite.modulate = item_b.color
					
					item_a.velocity += direction * base_force * 60.0 * delta
					item_b.velocity -= direction * base_force * 60.0 * delta
	
	for item in elements:
		item.was_repelling = item.repelling_now

# 寿命・壁反射・移動処理（★後半部分を完全補完）
func process_particles(delta: float, screen_size: Vector2) -> void:
	var radius = 24.0
	const FADE_DURATION: float = 3.0
	
	for i in range(elements.size() - 1, -1, -1):
		var item = elements[i]
		
		# 吸い寄せ中の粒子は通常の物理・寿命処理をスキップ（UIEventHandlerが処理するため）
		if item.is_attracted:
			continue
		
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
		
		# 寿命消滅時のペナルティ処理
		if item.lifetime >= item.max_lifetime:
			var vanish_pos = item.position
			if item.sprite:
				item.sprite.queue_free()
			elements.remove_at(i)
			
			on_cube_repair.call(vanish_pos)
			
			if elements.size() == 0:
				on_cube_revive.call()
			continue
		
		# 壁反射処理 (X軸)
		if item.position.x < radius:
			item.position.x = radius
			item.velocity.x = abs(item.velocity.x)
			item.has_bounced = true
			on_wall_bounce.call(item.position, item.color)
		elif item.position.x > screen_size.x - radius:
			item.position.x = screen_size.x - radius
			item.velocity.x = -abs(item.velocity.x)
			item.has_bounced = true
			on_wall_bounce.call(item.position, item.color)
		
		# 壁反射処理 (Y軸)
		if item.position.y < radius:
			item.position.y = radius
			item.velocity.y = abs(item.velocity.y)
			item.has_bounced = true
			on_wall_bounce.call(item.position, item.color)
		elif item.position.y > screen_size.y - radius:
			item.position.y = screen_size.y - radius
			item.velocity.y = -abs(item.velocity.y)
			item.has_bounced = true
			on_wall_bounce.call(item.position, item.color)

		# 摩擦と移動の適用
		var speed: float = item.velocity.length()
		var friction_coeff: float = FRICTION_COEFF_HIGH if speed > FRICTION_THRESHOLD else FRICTION_COEFF_LOW
		item.velocity -= item.velocity * friction_coeff * delta
		item.position += item.velocity * delta
		
		# スプライトのビジュアル（パルス・フェードアウト）同期
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
