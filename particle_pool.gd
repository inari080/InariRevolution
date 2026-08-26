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

const tex_quark = preload("res://quark.png")
const tex_electron = preload("res://electron.png")
const tex_photon = preload("res://photon.png")

var game_logic: GameLogic
var parent_node: Node

# 磁気トラップ画面などの開閉状態に連動するフラグ
var mouse_interaction_enabled: bool = true

func _init(p_game_logic: GameLogic, p_parent: Node) -> void:
	game_logic = p_game_logic
	parent_node = p_parent

# 粒子生成（HPに応じた出現数調整）
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
		"Proton":  type_tex = tex_quark # 陽子専用画像が用意できるまでクォークを流用
		_:         type_tex = tex_quark
	
	# ⭕ 共通クラス ParticleVisual から正しい色（ベースライン）を取得
	var visual: Dictionary = ParticleVisual.visual_for(type_name)
	
	item.name = type_name
	# ゲーム内の発光表現（HDR/ブルーム）に合わせるため輝度を増幅（RGB各値を4倍化、アルファは維持）
	item.color = Color(visual["color"].r * 4.0, visual["color"].g * 4.0, visual["color"].b * 4.0, visual["color"].a)
	
	var sp = Sprite2D.new()
	sp.texture = type_tex
	sp.global_position = start_pos
	sp.modulate = Color(3.0, 3.0, 3.0, 1.0)
	
	if sp.texture:
		var tex_size = sp.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			var target_size: float = 64.0 if type_name == "Proton" else 48.0
			sp.scale = Vector2(target_size / tex_size.x, target_size / tex_size.y)
	
	parent_node.add_child(sp)
	item.sprite = sp
	
	var angle = randf() * TAU
	var speed = randf_range(80.0, 200.0)
	item.velocity = Vector2(cos(angle), sin(angle)) * speed
	
	game_logic.elements.append(item)

func spawn_proton(center_pos: Vector2) -> void:
	create_and_register_element("Proton", center_pos)

# ★【追加統合】密着・合体時の火花エフェクト
func create_chemical_spark(spark_position: Vector2) -> void:
	if not mouse_interaction_enabled:
		return
	
	var spark = CPUParticles2D.new()
	spark.global_position = spark_position
	spark.z_index = 1000
	
	spark.amount = 5
	spark.lifetime = 0.4
	spark.one_shot = true
	spark.explosiveness = 0.9
	
	spark.direction = Vector2.ZERO
	spark.gravity = Vector2.ZERO
	spark.initial_velocity_min = 30.0
	spark.initial_velocity_max = 80.0
	
	spark.modulate = Color(4.0, 4.0, 4.0, 1.0) 
	
	parent_node.add_child(spark)
	
	var timer = parent_node.get_tree().create_timer(0.5)
	timer.timeout.connect(spark.queue_free)

# ★【追加統合】壁反射時のエフェクト
func create_wall_bounce_effect(bounce_position: Vector2, particle_color: Color) -> void:
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
	
	parent_node.add_child(spark)
	
	var timer = parent_node.get_tree().create_timer(0.4)
	timer.timeout.connect(spark.queue_free)

# ★【追加統合】キューブへ吸い込まれる光の線の演出
func create_repair_streak(from_pos: Vector2) -> void:
	var cubes = parent_node.get_tree().get_nodes_in_group("cubes")
	if cubes.is_empty():
		return
	
	var target_cube = cubes[0]
	if not (target_cube is Control):
		return
	
	var target_pos: Vector2 = target_cube.global_position + (target_cube.size / 2)
	
	var streak = ColorRect.new()
	streak.color = Color(3.0, 3.0, 3.0, 1.0)
	streak.size = Vector2(STREAK_SIZE, STREAK_SIZE)
	streak.pivot_offset = streak.size / 2
	streak.global_position = from_pos - streak.size / 2
	streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_node.add_child(streak)
	
	var to_target = target_pos - from_pos
	streak.rotation = to_target.angle()
	streak.scale = Vector2(1.6, 0.5)
	
	var tween = parent_node.create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(streak, "global_position", target_pos - streak.size / 2, STREAK_DURATION)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	tween.tween_property(streak, "scale", Vector2(0.1, 0.1), STREAK_DURATION)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	tween.chain().tween_callback(streak.queue_free)
