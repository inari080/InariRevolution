# game/particle_pool.gd
# ParticlePool - 粒子生成と管理
class_name ParticlePool
extends Control

const CAPACITY_MIN: int = 1
const CAPACITY_MAX: int = 5
const SPAWN_COUNT_MIN: int = 2
const SPAWN_COUNT_MAX: int = 8

const STREAK_SIZE: float = 14.0
const STREAK_DURATION: float = 0.35

# --- 演出用パラメータ定数 ---
const HDR_GLOW_MULTIPLIER: float = 4.0            # エフェクトがブルームに乗るための輝度増幅倍率
const SPRITE_MODULATE_BRIGHTNESS: float = 3.0     # スプライトの標準輝度
const PROTON_DISPLAY_SIZE: float = 64.0           # 陽子の表示サイズ
const NORMAL_PARTICLE_DISPLAY_SIZE: float = 48.0  # 通常粒子の表示サイズ
const INITIAL_SPEED_MIN: float = 80.0             # 生成時の最低初速
const INITIAL_SPEED_MAX: float = 200.0            # 生成時の最高初速

const SPARK_AMOUNT: int = 5                       # 結合火花の粒子数
const SPARK_LIFETIME: float = 0.4                 # 結合火花の寿命
const SPARK_EXPLOSIVENESS: float = 0.9            # 結合火花の爆発度
const SPARK_VELOCITY_MIN: float = 30.0            # 結合火花の最小速度
const SPARK_VELOCITY_MAX: float = 80.0            # 結合火花の最大速度
const SPARK_BRIGHTNESS: float = 4.0               # 結合火花の輝度

const BOUNCE_SPARK_AMOUNT: int = 6                # 壁反射エフェクトの粒子数
const BOUNCE_SPARK_LIFETIME: float = 0.3          # 壁反射エフェクトの寿命
const BOUNCE_SPARK_VELOCITY_MIN: float = 40.0     # 壁反射エフェクトの最小速度
const BOUNCE_SPARK_VELOCITY_MAX: float = 110.0    # 壁反射エフェクトの最大速度
const BOUNCE_SPARK_SCALE_MIN: float = 0.5         # 壁反射エフェクトの最小スケール
const BOUNCE_SPARK_SCALE_MAX: float = 1.0         # 壁反射エフェクトの最大スケール

const STREAK_SCALE_X: float = 1.6                 # 光の線の進行方向の引き伸ばし倍率
const STREAK_SCALE_Y: float = 0.5                 # 光の線の横幅縮小倍率
const STREAK_FINAL_SCALE: float = 0.1             # 光の線の消滅直前のしぼみサイズ
const TWEEN_REVIVE_DURATION: float = 0.3          # キューブ復活のフェードイン秒数
const TWEEN_RESET_DURATION: float = 0.2           # 内枠バーがリセットして消える秒数

const tex_quark = preload("res://quark.png")
const tex_electron = preload("res://electron.png")
const tex_photon = preload("res://photon.png")

var game_logic: GameLogic
var parent_node: Node

var mouse_interaction_enabled: bool = true

func _init(p_game_logic: GameLogic, p_parent: Node) -> void:
	game_logic = p_game_logic
	parent_node = p_parent

func spawn_elements(start_pos: Vector2, count: int) -> void:
	var capacity: int = clampi(count, CAPACITY_MIN, CAPACITY_MAX)
	var ratio: float = 0.0
	if CAPACITY_MAX > CAPACITY_MIN:
		ratio = float(capacity - CAPACITY_MIN) / float(CAPACITY_MAX - CAPACITY_MIN)
	
	var base_count: int = int(round(lerp(float(SPAWN_COUNT_MIN), float(SPAWN_COUNT_MAX), ratio)))
	var random_count: int = clampi(base_count + randi_range(-1, 1), SPAWN_COUNT_MIN, SPAWN_COUNT_MAX)
	
	for i in range(random_count):
		var roll = randf_range(0.0, 100.0)
		var type_name = ""
		
		if roll < 54.5:
			type_name = "Quark"
		elif roll < 99.0:
			type_name = "Electron"
		else:
			type_name = "Photon"
		
		create_and_register_element(type_name, start_pos)

func spawn_single_element(type_name: String, start_pos: Vector2) -> void:
	create_and_register_element(type_name, start_pos)

func create_and_register_element(type_name: String, start_pos: Vector2) -> void:
	var item = GameLogic.ElementItem.new()
	item.position = start_pos
	item.max_lifetime = 180.0 if type_name == "Proton" else randf_range(30.0, 50.0)
	
	var type_tex
	match type_name:
		"Quark":   type_tex = tex_quark
		"Electron":type_tex = tex_electron
		"Photon":  type_tex = tex_photon
		"Proton":  type_tex = tex_quark
		_:         type_tex = tex_quark
	
	var visual: Dictionary = ParticleVisual.visual_for(type_name)
	
	item.name = type_name
	item.color = Color(visual["color"].r * HDR_GLOW_MULTIPLIER, visual["color"].g * HDR_GLOW_MULTIPLIER, visual["color"].b * HDR_GLOW_MULTIPLIER, visual["color"].a)
	
	var sp = Sprite2D.new()
	sp.texture = type_tex
	sp.global_position = start_pos
	sp.modulate = Color(SPRITE_MODULATE_BRIGHTNESS, SPRITE_MODULATE_BRIGHTNESS, SPRITE_MODULATE_BRIGHTNESS, 1.0)
	
	if sp.texture:
		var tex_size = sp.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			var target_size: float = PROTON_DISPLAY_SIZE if type_name == "Proton" else NORMAL_PARTICLE_DISPLAY_SIZE
			sp.scale = Vector2(target_size / tex_size.x, target_size / tex_size.y)
	
	parent_node.add_child(sp)
	item.sprite = sp
	
	var angle = randf() * TAU
	var speed = randf_range(INITIAL_SPEED_MIN, INITIAL_SPEED_MAX)
	item.velocity = Vector2(cos(angle), sin(angle)) * speed
	
	game_logic.elements.append(item)

func spawn_proton(center_pos: Vector2) -> void:
	create_and_register_element("Proton", center_pos)

func create_chemical_spark(spark_position: Vector2) -> void:
	if not mouse_interaction_enabled:
		return
	
	var spark = CPUParticles2D.new()
	spark.global_position = spark_position
	spark.z_index = 1000
	
	spark.amount = SPARK_AMOUNT
	spark.lifetime = SPARK_LIFETIME
	spark.one_shot = true
	spark.explosiveness = SPARK_EXPLOSIVENESS
	
	spark.direction = Vector2.ZERO
	spark.gravity = Vector2.ZERO
	spark.initial_velocity_min = SPARK_VELOCITY_MIN
	spark.initial_velocity_max = SPARK_VELOCITY_MAX
	
	spark.modulate = Color(SPARK_BRIGHTNESS, SPARK_BRIGHTNESS, SPARK_BRIGHTNESS, 1.0) 
	
	parent_node.add_child(spark)
	
	var timer = parent_node.get_tree().create_timer(SPARK_LIFETIME + 0.1)
	timer.timeout.connect(spark.queue_free)

func create_wall_bounce_effect(bounce_position: Vector2, particle_color: Color) -> void:
	if not mouse_interaction_enabled:
		return
	
	var spark = CPUParticles2D.new()
	spark.global_position = bounce_position
	
	spark.amount = BOUNCE_SPARK_AMOUNT
	spark.lifetime = BOUNCE_SPARK_LIFETIME
	spark.one_shot = true
	spark.explosiveness = 1.0
	
	spark.direction = Vector2.ZERO
	spark.spread = 180.0
	spark.gravity = Vector2.ZERO
	spark.initial_velocity_min = BOUNCE_SPARK_VELOCITY_MIN
	spark.initial_velocity_max = BOUNCE_SPARK_VELOCITY_MAX
	spark.scale_amount_min = BOUNCE_SPARK_SCALE_MIN
	spark.scale_amount_max = BOUNCE_SPARK_SCALE_MAX
	
	spark.modulate = particle_color
	
	parent_node.add_child(spark)
	
	var timer = parent_node.get_tree().create_timer(BOUNCE_SPARK_LIFETIME + 0.1)
	timer.timeout.connect(spark.queue_free)

func create_repair_streak(from_pos: Vector2) -> void:
	var cubes = parent_node.get_tree().get_nodes_in_group("cubes")
	if cubes.is_empty():
		return
	
	var target_cube = cubes[0]
	if not (target_cube is Control):
		return
	
	var target_pos: Vector2 = target_cube.global_position + (target_cube.size / 2)
	
	var streak = ColorRect.new()
	streak.color = Color(SPRITE_MODULATE_BRIGHTNESS, SPRITE_MODULATE_BRIGHTNESS, SPRITE_MODULATE_BRIGHTNESS, 1.0)
	streak.size = Vector2(STREAK_SIZE, STREAK_SIZE)
	streak.pivot_offset = streak.size / 2
	streak.global_position = from_pos - streak.size / 2
	streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_node.add_child(streak)
	
	var to_target = target_pos - from_pos
	streak.rotation = to_target.angle()
	streak.scale = Vector2(STREAK_SCALE_X, STREAK_SCALE_Y)
	
	var tween = parent_node.create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(streak, "global_position", target_pos - streak.size / 2, STREAK_DURATION)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	tween.tween_property(streak, "scale", Vector2(STREAK_FINAL_SCALE, STREAK_FINAL_SCALE), STREAK_DURATION)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	tween.chain().tween_callback(streak.queue_free)
