extends Control

const SIDEBAR_WIDTH: float = 190.0
const SIDEBAR_TOP_MARGIN: float = 0.0
const ROW_HEIGHT: float = 60.0
const ICON_CIRCLE_SIZE: float = 36.0
const ANIM_DURATION: float = 0.28
const CLOSED_Y_OFFSET: float = -24.0

var is_open: bool = false
var button: Button
var panel: Panel
var panel_width: float = 0.0
var panel_height: float = 0.0

func _ready() -> void:
	add_to_group("micro_ui")
	_build_sidebar_button()
	_build_panel()
	_reposition_ui()
	get_viewport().size_changed.connect(_reposition_ui)

func _build_sidebar_button() -> void:
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
	bs.bg_color = Color(0.95, 0.7, 0.25)
	bs.corner_radius_top_left = int(ICON_CIRCLE_SIZE / 2)
	bs.corner_radius_top_right = int(ICON_CIRCLE_SIZE / 2)
	bs.corner_radius_bottom_left = int(ICON_CIRCLE_SIZE / 2)
	bs.corner_radius_bottom_right = int(ICON_CIRCLE_SIZE / 2)
	icon_badge.add_theme_stylebox_override("panel", bs)
	icon_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_label := Label.new()
	icon_label.text = "⚙"
	icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 16)
	icon_badge.add_child(icon_label)

	var text_label := Label.new()
	text_label.text = "ミクロの法則"
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 15)
	text_label.add_theme_color_override("font_color", Color(0.92,0.92,0.94))
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	hbox.add_child(icon_badge)
	hbox.add_child(text_label)
	button.add_child(hbox)
	add_child(button)

	button.pressed.connect(_on_button_pressed)

func _build_panel() -> void:
	panel = Panel.new()
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.99)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	var title := Label.new()
	title.text = "ミクロの法則"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.7, 0.25))
	header.add_child(title)

	var back := Button.new()
	back.text = "戻る"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_on_back_pressed)
	header.add_child(back)
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var placeholder := Label.new()
	placeholder.text = "ここにスキルツリー（ミクロの法則）を実装してください"
	placeholder.add_theme_font_size_override("font_size", 16)
	placeholder.add_theme_color_override("font_color", Color(0.85,0.85,0.85))
	center.add_child(placeholder)
	vbox.add_child(center)

	add_child(panel)

func _reposition_ui() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var sidebar_x: float = vp_size.x - SIDEBAR_WIDTH
	# 既存のサイドバー行数に合わせてYを調整してください（ここでは2行目付近）
	var sidebar_y: float = SIDEBAR_TOP_MARGIN + ROW_HEIGHT * 1
	button.position = Vector2(sidebar_x, sidebar_y)
	button.size = Vector2(SIDEBAR_WIDTH, ROW_HEIGHT)

	panel_width = sidebar_x
	panel_height = vp_size.y
	panel.size = Vector2(panel_width, panel_height)
	panel.position = Vector2(0.0, 0.0 if is_open else CLOSED_Y_OFFSET)
	panel.modulate.a = 1.0 if is_open else 0.0
	panel.visible = is_open
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if is_open else Control.MOUSE_FILTER_IGNORE

func _on_button_pressed() -> void:
	if is_open:
		_close_micro_screen()
	else:
		_open_micro_screen()

func _on_back_pressed() -> void:
	_close_micro_screen()

func _open_micro_screen() -> void:
	is_open = true
	get_tree().call_group("magnetic_trap_ui", "_close_trap_screen")
	panel.visible = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position:y", 0.0, ANIM_DURATION)
	tween.tween_property(panel, "modulate:a", 1.0, ANIM_DURATION)

func _close_micro_screen() -> void:
	is_open = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "position:y", CLOSED_Y_OFFSET, ANIM_DURATION)
	tween.tween_property(panel, "modulate:a", 0.0, ANIM_DURATION)
	tween.chain().tween_callback(func(): panel.visible = false)
