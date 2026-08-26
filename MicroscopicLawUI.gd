extends Control

# ==============================================================
# ミクロの法則（Microscopic Law）UI
#
# サイドバーに追加される新しいタブ。押すと専用の全画面パネルが開く。
# ★中身は未実装のため、現状は説明文だけのプレースホルダー。
#   今後、ここに「ミクロの法則」の実際の機能を実装していく想定。
#
# 使い方:
#   main.gd が付いているノードの「子」として、このスクリプトを付けた
#   新しい Control ノードを追加する。
#   ★シーンツリー上で、magnetic_trap_ui ノードより「下（後）」に置くこと。
# ==============================================================

# ★ magnetic_trap_ui.gd の SIDEBAR_WIDTH と必ず同じ値にすること
const SIDEBAR_WIDTH: float = 190.0
const ANIM_DURATION: float = 0.28
const CLOSED_Y_OFFSET: float = -24.0

var row_button: Button
var panel: Panel
var is_open: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("screen_ui")
	
	var trap_ui = get_tree().get_first_node_in_group("magnetic_trap_ui")
	if trap_ui == null:
		push_warning("MicrossopicLawUI: magnetic_trap_ui が見つかりません。シーンツリーの順番を確認してください。")
		return
	
	_build_panel()
	
	row_button = trap_ui.register_sidebar_row("ミクロの法則", "Σ", Color(0.85, 0.55, 0.35))
	row_button.pressed.connect(_on_row_pressed)
	
	get_viewport().size_changed.connect(_reposition_panel)
	_reposition_panel()

func _build_panel() -> void:
	panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.modulate.a = 0.0
	panel.visible = false
	
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
	margin.add_child(vbox)
	
	var title := Label.new()
	title.text = "ミクロの法則"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.55))
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	var desc := Label.new()
	desc.text = "素粒子の世界を支配する法則を解き明かす予定のスペースです。\n（機能は準備中）"
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.7, 0.72, 0.76))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)
	
	add_child(panel)

func _reposition_panel() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var panel_width: float = vp_size.x - SIDEBAR_WIDTH
	var panel_height: float = vp_size.y
	
	if panel:
		panel.size = Vector2(panel_width, panel_height)
		panel.position.x = 0.0
		panel.position.y = 0.0 if is_open else CLOSED_Y_OFFSET

func _on_row_pressed() -> void:
	if is_open:
		_close_screen()
	else:
		_open_screen()

func _open_screen() -> void:
	is_open = true
	_set_active(true)
	
	get_tree().call_group("screen_ui", "external_close", self)
	
	panel.visible = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	get_tree().call_group("cubes", "hide")
	var field = get_tree().get_first_node_in_group("game_field")
	if field and field.has_method("set_particles_visible"):
		field.set_particles_visible(false)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position:y", 0.0, ANIM_DURATION)
	tween.tween_property(panel, "modulate:a", 1.0, ANIM_DURATION)

func _close_screen() -> void:
	is_open = false
	_set_active(false)
	
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	get_tree().call_group("cubes", "show")
	var field = get_tree().get_first_node_in_group("game_field")
	if field and field.has_method("set_particles_visible"):
		field.set_particles_visible(true)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "position:y", CLOSED_Y_OFFSET, ANIM_DURATION)
	tween.tween_property(panel, "modulate:a", 0.0, ANIM_DURATION)
	tween.chain().tween_callback(func(): panel.visible = false)

func external_close(requesting_node) -> void:
	if requesting_node != self and is_open:
		_close_screen()

func _set_active(active: bool) -> void:
	if row_button:
		var key := "style_selected" if active else "style_normal"
		row_button.add_theme_stylebox_override("normal", row_button.get_meta(key))
