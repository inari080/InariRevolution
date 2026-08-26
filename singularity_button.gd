extends Control

const SIDEBAR_WIDTH: float = 190.0
const SIDEBAR_TOP_MARGIN: float = 0.0
const ROW_HEIGHT: float = 60.0
const ICON_CIRCLE_SIZE: float = 36.0

var button: Button

func _ready() -> void:
	add_to_group("singularity_ui")
	_build_button()
	_reposition_ui()
	get_viewport().size_changed.connect(_reposition_ui)

func _build_button() -> void:
	button = Button.new()
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = Vector2(SIDEBAR_WIDTH, ROW_HEIGHT)
	button.text = ""

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	hbox.offset_left = 14
	hbox.offset_right = -10
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_badge := Panel.new()
	icon_badge.custom_minimum_size = Vector2(ICON_CIRCLE_SIZE, ICON_CIRCLE_SIZE)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.55, 0.35, 0.85)
	bs.corner_radius_top_left = int(ICON_CIRCLE_SIZE / 2)
	bs.corner_radius_top_right = int(ICON_CIRCLE_SIZE / 2)
	bs.corner_radius_bottom_left = int(ICON_CIRCLE_SIZE / 2)
	bs.corner_radius_bottom_right = int(ICON_CIRCLE_SIZE / 2)
	icon_badge.add_theme_stylebox_override("panel", bs)
	icon_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_label := Label.new()
	icon_label.text = "◉"
	icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 16)
	icon_badge.add_child(icon_label)

	var text_label := Label.new()
	text_label.text = "特異点"
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 15)
	text_label.add_theme_color_override("font_color", Color(0.92,0.92,0.94))
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	hbox.add_child(icon_badge)
	hbox.add_child(text_label)
	button.add_child(hbox)
	add_child(button)

	button.pressed.connect(_on_pressed)

func _reposition_ui() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var sidebar_x: float = vp_size.x - SIDEBAR_WIDTH
	var sidebar_y: float = SIDEBAR_TOP_MARGIN
	button.position = Vector2(sidebar_x, sidebar_y)
	button.size = Vector2(SIDEBAR_WIDTH, ROW_HEIGHT)

func _on_pressed() -> void:
	get_tree().call_group("magnetic_trap_ui", "_close_trap_screen")
	get_tree().call_group("micro_ui", "_close_micro_screen")
