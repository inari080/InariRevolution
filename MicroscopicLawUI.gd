extends Control

# ==============================================================
# ミクロの法則（Microscopic Law）UI - 第1フェーズ「ビッグバン前夜」
#
# サイドバーに追加されるタブ。押すと専用の全画面パネルが開く。
# パネルの中身は「サブタブバー」で切り替えられる別コンテンツを持つ。
#
# 第1フェーズ「ビッグバン前夜」のサブタブ構成:
#   [0] ミクロの設計図 … スキルツリー（元素・法則を解放して宇宙空間を作る）
#   ★今後フェーズが進むごとに sub_tab_names / sub_tab_pages を増やしていく想定
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
const SUB_TAB_HEIGHT: float = 40.0

var row_button: Button
var panel: Panel
var is_open: bool = false

# --- サブタブ関連 ---
var sub_tab_names: Array = ["ミクロの設計図"] # ★今後ここにフェーズ進行で追加していく
var sub_tab_buttons: Array = []
var sub_tab_pages: Array = []
var current_sub_tab: int = 0

var design_tree: MicroDesignTree # ★「ミクロの設計図」スキルツリー本体


# --------------------------------------------------------------
# 個々のスキルノード（星座の星ひとつぶん）
# --------------------------------------------------------------
class SkillNodeButton:
	extends Panel

	signal pressed_node(id: String)

	const RADIUS: float = 32.0 # ★MicroDesignTree側の配置計算とは独立（見た目のサイズのみ）

	var id: String
	var node_color: Color
	var state: String = "locked" # locked / available / unlocked
	var label: Label

	func _init(node_id: String, symbol: String, color: Color) -> void:
		id = node_id
		node_color = color
		custom_minimum_size = Vector2(RADIUS * 2, RADIUS * 2)
		size = custom_minimum_size
		pivot_offset = size / 2.0
		mouse_filter = Control.MOUSE_FILTER_STOP

		label = Label.new()
		label.text = symbol
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 17)
		add_child(label)

		_refresh_style()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if state != "locked":
				pressed_node.emit(id)

	func set_state(new_state: String) -> void:
		state = new_state
		_refresh_style()

	func _refresh_style() -> void:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(int(RADIUS))

		match state:
			"locked":
				style.bg_color = Color(0.08, 0.08, 0.10, 0.85)
				style.border_color = Color(0.25, 0.25, 0.28, 0.6)
				style.set_border_width_all(1)
				label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
				modulate.a = 0.55
			"available":
				style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
				style.border_color = node_color
				style.set_border_width_all(2)
				style.shadow_color = Color(node_color.r, node_color.g, node_color.b, 0.5)
				style.shadow_size = 8
				label.add_theme_color_override("font_color", node_color)
				modulate.a = 1.0
			"unlocked":
				style.bg_color = node_color.darkened(0.35)
				style.border_color = node_color
				style.set_border_width_all(3)
				style.shadow_color = Color(node_color.r, node_color.g, node_color.b, 0.85)
				style.shadow_size = 14
				label.add_theme_color_override("font_color", Color(1, 1, 1))
				modulate.a = 1.0

		add_theme_stylebox_override("panel", style)


# --------------------------------------------------------------
# 「ミクロの設計図」スキルツリー本体
#
# デザインコンセプト：スタイル2「天体・星座（コズミック・レイアウト）」
# ・中央に「ビッグバンの種」。周囲に元素・法則のスキルノードを星座状に配置。
# ・ノードを解放するたびに種へエネルギーが集まっていくイメージで、
#   背景と種のグロー・脈動が変化していく。
# ・進捗は「ビッグバン臨界値」としてパーセント表示する。
# --------------------------------------------------------------
class MicroDesignTree:
	extends Control

	signal progress_changed(percent: float)
	signal big_bang_ready() # ★臨界値100%到達時に発火（フェーズ2接続用・TODO）

	const SEED_RADIUS: float = 46.0

	# ★スキル定義。requires が全て解放済みなら解放可能（available）になる。
	#   offset は中心(ビッグバンの種)からの相対配置座標。
	var skill_defs: Array = [
		{"id": "quark",        "name": "クォーク",   "symbol": "Q",  "color": Color(1.0, 0.35, 0.35), "requires": [],                        "offset": Vector2(-40, -230)},
		{"id": "electron",     "name": "電子",       "symbol": "e⁻", "color": Color(0.4, 1.0, 0.5),   "requires": ["quark"],                 "offset": Vector2(-230, -90)},
		{"id": "photon",       "name": "光子",       "symbol": "γ",  "color": Color(1.0, 0.95, 0.4),  "requires": ["quark"],                 "offset": Vector2(230, -100)},
		{"id": "strong_force", "name": "強い力",     "symbol": "S",  "color": Color(0.95, 0.5, 1.0),  "requires": ["quark"],                 "offset": Vector2(0, -110)},
		{"id": "proton",       "name": "陽子",       "symbol": "p⁺", "color": Color(1.0, 0.75, 0.3),  "requires": ["strong_force"],          "offset": Vector2(130, 40)},
		{"id": "neutron",      "name": "中性子",     "symbol": "n",  "color": Color(0.75, 0.75, 0.8), "requires": ["strong_force"],          "offset": Vector2(-130, 60)},
		{"id": "hydrogen",     "name": "水素原子",   "symbol": "H",  "color": Color(0.5, 0.75, 1.0),  "requires": ["proton", "electron"],    "offset": Vector2(-250, 190)},
		{"id": "gravity",      "name": "重力",       "symbol": "g",  "color": Color(0.6, 0.5, 0.9),   "requires": ["photon"],                "offset": Vector2(250, 180)},
		{"id": "spacetime",    "name": "時空",       "symbol": "∞",  "color": Color(1.0, 1.0, 1.0),   "requires": ["hydrogen", "gravity"],   "offset": Vector2(0, 260)},
	]

	var unlocked: Dictionary = {}       # id -> bool
	var node_buttons: Dictionary = {}   # id -> SkillNodeButton
	var seed_panel: Panel
	var seed_style: StyleBoxFlat
	var bg_panel: Panel
	var bg_style: StyleBoxFlat
	var progress_label: Label
	var origin: Vector2 = Vector2.ZERO
	var seed_tween: Tween
	var bang_fired: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func _ready() -> void:
		_build_background()
		_build_seed()
		_build_nodes()
		_build_progress_label()
		_recalc_availability()
		_recalc_progress()
		resized.connect(_reposition)
		_reposition()

	func _build_background() -> void:
		bg_panel = Panel.new()
		bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.03, 0.03, 0.05, 1.0) # ★最初は冷たい黒
		bg_style.set_corner_radius_all(6)
		bg_panel.add_theme_stylebox_override("panel", bg_style)
		add_child(bg_panel)

	func _build_seed() -> void:
		seed_panel = Panel.new()
		seed_panel.custom_minimum_size = Vector2(SEED_RADIUS * 2, SEED_RADIUS * 2)
		seed_panel.size = seed_panel.custom_minimum_size
		seed_panel.pivot_offset = seed_panel.size / 2.0
		seed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		seed_style = StyleBoxFlat.new()
		seed_style.bg_color = Color(0.15, 0.1, 0.05, 1.0)
		seed_style.border_color = Color(1.0, 0.85, 0.6, 0.9)
		seed_style.set_border_width_all(2)
		seed_style.set_corner_radius_all(int(SEED_RADIUS))
		seed_style.shadow_color = Color(1.0, 0.7, 0.4, 0.35)
		seed_style.shadow_size = 10
		seed_panel.add_theme_stylebox_override("panel", seed_style)

		var seed_label := Label.new()
		seed_label.text = "◎"
		seed_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		seed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seed_label.add_theme_font_size_override("font_size", 22)
		seed_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.75))
		seed_panel.add_child(seed_label)

		add_child(seed_panel)
		_start_seed_pulse(0.0)

	func _build_nodes() -> void:
		for def in skill_defs:
			var btn := SkillNodeButton.new(def["id"], def["symbol"], def["color"])
			btn.pressed_node.connect(_on_node_pressed)
			add_child(btn)
			node_buttons[def["id"]] = btn

	func _build_progress_label() -> void:
		progress_label = Label.new()
		progress_label.add_theme_font_size_override("font_size", 15)
		progress_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6))
		progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(progress_label)

	func _reposition() -> void:
		origin = size / 2.0

		if seed_panel:
			seed_panel.position = origin - seed_panel.size / 2.0

		# ★画面が狭い時は星座全体を自動で縮小する
		var scale_factor: float = clamp(size.y / 700.0, 0.45, 1.0)

		for def in skill_defs:
			var btn: Panel = node_buttons.get(def["id"])
			if btn:
				var target: Vector2 = origin + def["offset"] * scale_factor
				btn.position = target - btn.size / 2.0

		if progress_label:
			progress_label.position = Vector2(20, 14)

		queue_redraw()

	func _draw() -> void:
		# ★星座ライン：前提スキル → 対象スキルへ線を引く。
		#   前提が無いスキルは、中心（ビッグバンの種）から直接線を引く。
		for def in skill_defs:
			var to_btn: Panel = node_buttons.get(def["id"])
			if to_btn == null:
				continue
			var to_pos: Vector2 = to_btn.position + to_btn.size / 2.0
			var to_unlocked: bool = unlocked.get(def["id"], false)

			if def["requires"].is_empty():
				var line_color: Color = Color(1.0, 0.8, 0.5, 0.7) if to_unlocked else Color(0.3, 0.3, 0.35, 0.5)
				draw_line(origin, to_pos, line_color, 2.0 if to_unlocked else 1.0, true)
			else:
				for req_id in def["requires"]:
					var from_btn: Panel = node_buttons.get(req_id)
					if from_btn == null:
						continue
					var from_pos: Vector2 = from_btn.position + from_btn.size / 2.0
					var from_unlocked: bool = unlocked.get(req_id, false)
					var both_unlocked: bool = from_unlocked and to_unlocked
					var line_color: Color = Color(1.0, 0.8, 0.5, 0.8) if both_unlocked else Color(0.3, 0.3, 0.35, 0.45)
					draw_line(from_pos, to_pos, line_color, 2.2 if both_unlocked else 1.0, true)

	func _on_node_pressed(id: String) -> void:
		if unlocked.get(id, false):
			return
		if not _is_unlockable(id):
			return

		# ★TODO: ここで実際のコスト消費（素粒子の在庫チェックなど）を行う想定
		unlocked[id] = true
		node_buttons[id].set_state("unlocked")
		_recalc_availability()
		_recalc_progress()
		queue_redraw()

	func _is_unlockable(id: String) -> bool:
		for def in skill_defs:
			if def["id"] == id:
				for req in def["requires"]:
					if not unlocked.get(req, false):
						return false
				return true
		return false

	func _recalc_availability() -> void:
		for def in skill_defs:
			var id: String = def["id"]
			if unlocked.get(id, false):
				continue
			node_buttons[id].set_state("available" if _is_unlockable(id) else "locked")

	func _recalc_progress() -> void:
		var total: int = skill_defs.size()
		var count: int = 0
		for def in skill_defs:
			if unlocked.get(def["id"], false):
				count += 1
		var percent: float = 100.0 * float(count) / float(total)

		progress_label.text = "[ビッグバン臨界値: %d%%]" % int(round(percent))

		# ★背景を「冷たい黒 → 熱く輝く色」へ、進捗に応じて補間する
		var cold: Color = Color(0.03, 0.03, 0.05, 1.0)
		var hot: Color = Color(0.35, 0.16, 0.05, 1.0)
		bg_style.bg_color = cold.lerp(hot, percent / 100.0)

		_start_seed_pulse(percent / 100.0)

		progress_changed.emit(percent)

		if percent >= 100.0 and not bang_fired:
			bang_fired = true
			big_bang_ready.emit() # ★フェーズ2（宇宙空間の誕生）への入口・TODO

	func _start_seed_pulse(intensity: float) -> void:
		# ★進捗が上がるほど、種の脈動が「速く・大きく」なっていく
		if seed_tween and seed_tween.is_valid():
			seed_tween.kill()

		var base_shadow: float = lerp(6.0, 26.0, intensity)
		var pulse_amp: float = lerp(4.0, 20.0, intensity)
		var duration: float = lerp(1.6, 0.5, intensity) # ★臨界に近づくほど速くなる

		seed_tween = create_tween()
		seed_tween.set_loops()
		seed_tween.tween_method(_set_seed_shadow, base_shadow, base_shadow + pulse_amp, duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		seed_tween.tween_method(_set_seed_shadow, base_shadow + pulse_amp, base_shadow, duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _set_seed_shadow(value: float) -> void:
		seed_style.shadow_size = int(value)


# --------------------------------------------------------------
# メイン処理（サイドバー登録・パネル開閉）
# --------------------------------------------------------------
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
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "ミクロの法則 ― 第1フェーズ：ビッグバン前夜"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.55))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_build_sub_tabs(vbox)

	var content_area := Control.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_area)

	design_tree = MicroDesignTree.new()
	design_tree.set_anchors_preset(Control.PRESET_FULL_RECT)
	design_tree.visible = true
	content_area.add_child(design_tree)
	sub_tab_pages.append(design_tree)

	# ★今後フェーズが進んだら、ここに新しいサブタブを追加していく
	#   例: sub_tab_names.append("元素合成")
	#       var new_page := SomeNewPage.new()
	#       content_area.add_child(new_page)
	#       sub_tab_pages.append(new_page)

	add_child(panel)

func _build_sub_tabs(parent: VBoxContainer) -> void:
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	parent.add_child(tab_bar)

	for i in range(sub_tab_names.size()):
		var btn := Button.new()
		btn.text = sub_tab_names[i]
		btn.toggle_mode = true
		btn.button_pressed = (i == current_sub_tab)
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(150, SUB_TAB_HEIGHT)

		var style_off := StyleBoxFlat.new()
		style_off.bg_color = Color(0.12, 0.12, 0.14, 0.9)
		style_off.set_corner_radius_all(6)

		var style_on := StyleBoxFlat.new()
		style_on.bg_color = Color(0.85, 0.55, 0.35, 0.95) # ★ミクロの法則のテーマカラーに合わせる
		style_on.set_corner_radius_all(6)

		btn.add_theme_stylebox_override("normal", style_off)
		btn.add_theme_stylebox_override("hover", style_off)
		btn.add_theme_stylebox_override("pressed", style_on)
		btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
		btn.add_theme_color_override("font_color_pressed", Color(0.1, 0.1, 0.1))

		btn.pressed.connect(_on_sub_tab_pressed.bind(i))
		tab_bar.add_child(btn)
		sub_tab_buttons.append(btn)

func _on_sub_tab_pressed(index: int) -> void:
	current_sub_tab = index
	for i in range(sub_tab_buttons.size()):
		sub_tab_buttons[i].button_pressed = (i == index)
	for i in range(sub_tab_pages.size()):
		sub_tab_pages[i].visible = (i == index)

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
