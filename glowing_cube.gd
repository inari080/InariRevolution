extends ColorRect

var hp: int = 5
const MAX_HP: int = 5

# --- アニメーション・UI表現定数 ---
const TWEEN_DAMAGE_SHRINK: Vector2 = Vector2(0.8, 0.8)  # 殴られた瞬間の縮小率
const TWEEN_DAMAGE_RESTORE: Vector2 = Vector2(1.0, 1.0) # 弾性で元に戻るスケール
const TIME_DAMAGE_SHRINK: float = 0.05                 # 縮小アニメーションの秒数
const TIME_DAMAGE_RESTORE: float = 0.15                # 復元アニメーションの秒数
const TIME_REPAIR_PROGRESS: float = 0.4                # 下からせり上がる結晶化バーの秒数
const REPAIR_BAR_ALPHA_MID: float = 0.25               # 結晶化途中の内枠バーの不透明度
const TIME_REVIVE_FADE: float = 0.3                    # 完全復活時のフェードイン秒数
const TIME_REPAIR_BAR_HIDE: float = 0.2                # 復活完了時に内枠バーが消える秒数

var original_size: Vector2
var original_position: Vector2
var repair_content: ColorRect
var round_capacity: int = MAX_HP

func _ready() -> void:
	pivot_offset = size / 2
	add_to_group("cubes")
	
	original_size = size
	original_position = position
	
	repair_content = ColorRect.new()
	repair_content.color = Color(1.0, 1.0, 1.0, 1.0)
	repair_content.size = Vector2(original_size.x, 0)
	repair_content.position = Vector2(0, original_size.y)
	repair_content.modulate.a = 0.0
	
	repair_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(repair_content)

func _gui_input(event: InputEvent) -> void:
	if hp <= 0:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		take_damage()

func _unhandled_input(event: InputEvent) -> void:
	if hp <= 0 or not visible:
		return
	
	if event.is_action_pressed("ui_accept"):
		take_damage()

func take_damage() -> void:
	hp -= 1
	AppLogger.debug("キューブダメージ: HP %d → %d" % [hp + 1, hp])
	
	if hp <= 0:
		explode()
	else:
		play_click_animation()

func play_click_animation() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", TWEEN_DAMAGE_SHRINK, TIME_DAMAGE_SHRINK).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", TWEEN_DAMAGE_RESTORE, TIME_DAMAGE_RESTORE).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func explode() -> void:
	self_modulate.a = 0.0
	
	if repair_content:
		repair_content.size.y = 0
		repair_content.position.y = original_size.y
		repair_content.modulate.a = 0.0

	var center_pos = original_position + (original_size / 2)
	
	var main = get_node("..")
	if main and main.has_method("spawn_elements"):
		main.spawn_elements(center_pos, round_capacity)

func repair() -> void:
	hp = clampi(hp + 1, 0, MAX_HP)
	round_capacity = hp
	
	if hp >= MAX_HP:
		revive()
		return
	
	var hp_ratio = float(hp) / float(MAX_HP)
	var target_height = original_size.y * hp_ratio
	
	if repair_content:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(repair_content, "size:y", target_height, TIME_REPAIR_PROGRESS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(repair_content, "position:y", original_size.y - target_height, TIME_REPAIR_PROGRESS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(repair_content, "modulate:a", REPAIR_BAR_ALPHA_MID, TIME_REPAIR_PROGRESS)
		
	AppLogger.info("キューブ修復中: %.1f%%" % [hp_ratio * 100])

func revive() -> void:
	hp = MAX_HP
	round_capacity = MAX_HP
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "self_modulate:a", 1.0, TIME_REVIVE_FADE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if repair_content:
		tween.tween_property(repair_content, "modulate:a", 0.0, TIME_REPAIR_BAR_HIDE)
		
	AppLogger.info("キューブ復活完了")
