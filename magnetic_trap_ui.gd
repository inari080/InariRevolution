extends Control

# ==============================================================
# 磁気トラップ（Magnetic Trap / 収束器）UI
#
# ・右上のサイドバータブは従来通り
# ・押すと「粒子インベントリー」グリッド画面が開く
#   （1スロットにつき同じ種類を最大10個までスタック保管）
# ・通常のインベントリー(inventory_bar.gd)が満杯の時、main.gd から
#   ここへ回収した粒子が回される（add_item()）
# ・グリッドのスロットをドラッグして通常のインベントリーの空きスロットへ
#   ドロップすると、1個だけそちらへ移動できる
#   （受け取り側は inventory_bar.gd の InventorySlot._drop_data() 実装済み）
#
# ★【変更】特異点ボタンは SingulallityButton.gd へ移動しました。
#   このスクリプトはサイドバーの「土台」（右端の帯・行を積むVBoxContainer）を
#   引き続き持っており、SingulallityButton / MicrossopicLawUI などの
#   別ノードが register_sidebar_row() を呼ぶことで、同じ土台に行を追加できます。
#
# 使い方:
#   main.gd が付いているノードの「子」として、このスクリプトを付けた
#   新しい Control ノードを追加する（main.gd のノード自体には付けないこと！）
#   ★シーンツリー上で、SingulallityButton や MicrossopicLawUI より
#     「上（先）」に置くこと（土台を先に作る必要があるため）。
#
# ★位置はアンカーではなく、実際のビューポートサイズから直接計算する
#   ことで、親ノードのサイズ確定タイミングに左右されないようにしている。
# ==============================================================

# サイドバー本体（右端に張り付く縦積みリスト）
# ★ main.gd の RESERVED_RIGHT_WIDTH と必ず同じ値にすること
#   （この幅ぶん、main.gd側でキューブ・粒子の移動範囲が狭められる）
const SIDEBAR_WIDTH: float = 190.0
const SIDEBAR_TOP_MARGIN: float = 0.0 # ★一番上のボタン上の余白を無くす
const ROW_HEIGHT: float = 60.0
const ICON_CIRCLE_SIZE: float = 36.0
const SIDEBAR_ROW_GAP: float = 0.0 # ★ボタン同士の隙間を無くす
const SIDEBAR_ROW_PADDING: float = 0.0 # ★余白ゼロ＝ボタンが帯の端まで埋める

# 粒子インベントリー（グリッド画面）
const GRID_COLUMNS: int = 6
const GRID_ROWS: int = 4
const GRID_SLOT_SIZE: float = 80.0
const GRID_SLOT_SPACING: float = 14.0
const STACK_CAP: int = 10 # 1枠につき最大10個

const ANIM_DURATION: float = 0.28
const CLOSED_Y_OFFSET: float = -24.0 # 閉じている間、少し上にずらしてフェードイン風に見せる

var is_open: bool = false

var reserved_column: Panel
var sidebar_bg: Panel
var rows_vbox: VBoxContainer # ★【追加】他ノードがここに行を足せるよう公開する
var trap_row_button: Button

var panel: Panel
var trap_slots: Array = []

var panel_width: float = 0.0
var panel_height: float = 0.0

# --------------------------------------------------------------
# 粒子インベントリー1枠ぶんのスロット（同じ種類を最大10個までスタック）
# --------------------------------------------------------------
class TrapSlot:
	extends Panel
	
	const CAP: int = 10
	
	var slot_type: String = ""
	var count: int = 0
	var icon_label: Label
	var count_label: Label
	var style_empty: StyleBoxFlat
	
	func _init() -> void:
		custom_minimum_size = Vector2(70, 70)
		size = Vector2(70, 70)
		mouse_filter = Control.MOUSE_FILTER_STOP
		
		style_empty = StyleBoxFlat.new()
		style_empty.bg_color = Color(0.10, 0.10, 0.12, 0.85)
		style_empty.border_color = Color(0.28, 0.3, 0.34, 0.8)
		style_empty.set_border_width_all(2)
		style_empty.corner_radius_top_left = 10
		style_empty.corner_radius_top_right = 10
		style_empty.corner_radius_bottom_left = 10
		style_empty.corner_radius_bottom_right = 10
		add_theme_stylebox_override("panel", style_empty)
		
		icon_label = Label.new()
		icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_label.add_theme_font_size_override("font_size", 26)
		add_child(icon_label)
		
				# （_init 関数の count_label 追加処理の直後から置き換えてください）
		add_child(count_label)
	
	# ❌ 古いローカルの static func _visual_for() と内部の match 文は完全に削除しました。
	
	func _refresh_visual() -> void:
		if slot_type == "":
			icon_label.text = ""
			count_label.text = ""
			add_theme_stylebox_override("panel", style_empty)
			return
		
		# ⭕ 共通化した ParticleVisual クラスから表示用データを取得
		var visual: Dictionary = ParticleVisual.visual_for(slot_type)
		
		var style_filled := StyleBoxFlat.new()
		style_filled.bg_color = Color(0.14, 0.14, 0.17, 0.95)
		style_filled.border_color = visual["color"]
		style_filled.set_border_width_all(2)
		style_filled.corner_radius_top_left = 10
		style_filled.corner_radius_top_right = 10
		style_filled.corner_radius_bottom_left = 10
		style_filled.corner_radius_bottom_right = 10
		add_theme_stylebox_override("panel", style_filled)
		
		icon_label.text = visual["text"]
		icon_label.add_theme_color_override("font_color", visual["color"])
		# ⭕ 固有の "x" 付き個数表示ロジックを維持
		count_label.text = "x" + str(count)
	
	func add_one(type_name: String, cap: int) -> bool:
		if slot_type == "":
			slot_type = type_name
			count = 1
			_refresh_visual()
			return true
		elif slot_type == type_name and count < cap:
			count += 1
			_refresh_visual()
			return true
		return false
	
	func remove_one() -> void:
		if count <= 0:
			return
		count -= 1
		if count <= 0:
			slot_type = ""
			count = 0
		_refresh_visual()
	
	func is_empty() -> bool:
		return slot_type == ""
	
	func has_room(type_name: String, cap: int) -> bool:
		return is_empty() or (slot_type == type_name and count < cap)
	
	func _get_drag_data(_at_position: Vector2) -> Variant:
		if slot_type == "":
			return null
		
		var data := {"particle_type": slot_type, "source_trap_slot": self}
		
		# ⭕ ドラッグプレビュー用の見た目も共通化した ParticleVisual クラスを参照
		var visual: Dictionary = ParticleVisual.visual_for(slot_type)
		var preview := Label.new()
		preview.text = visual["text"]
		preview.add_theme_font_size_override("font_size", 30)
		preview.add_theme_color_override("font_color", visual["color"])
		set_drag_preview(preview)
		
		return data
	
	func _can_drop_data(_at_position: Vector2, data) -> bool:
		if typeof(data) != TYPE_DICTIONARY or not data.has("particle_type"):
			return false
		return has_room(data["particle_type"], CAP)

	
	func _drop_data(_at_position: Vector2, data) -> void:
		if not (typeof(data) == TYPE_DICTIONARY and data.has("particle_type")):
			return
		if not add_one(data["particle_type"], CAP):
			return
		
		if data.has("source_slot") and is_instance_valid(data["source_slot"]):
			data["source_slot"].clear()
		elif data.has("source_trap_slot") and is_instance_valid(data["source_trap_slot"]) and data["source_trap_slot"] != self:
			data["source_trap_slot"].remove_one()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	add_to_group("magnetic_trap_ui")
	add_to_group("screen_ui") # ★【追加】他の画面（特異点・ミクロの法則）と排他制御するためのグループ
	
	_build_panel()
	_build_sidebar()
	
	_reposition_ui()
	
	get_viewport().size_changed.connect(_reposition_ui)

# --------------------------------------------------------------
# サイドバー（右端に張り付く縦積みリストの「土台」）
# ★自分の行（磁気トラップ）だけ追加する。他ノードは register_sidebar_row() を使う。
# --------------------------------------------------------------
func _build_sidebar() -> void:
	reserved_column = Panel.new()
	reserved_column.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var column_style := StyleBoxFlat.new()
	column_style.bg_color = Color(0.11, 0.11, 0.13, 1.0)
	column_style.border_width_left = 2
	column_style.border_color = Color(1.0, 1.0, 1.0, 0.06)
	reserved_column.add_theme_stylebox_override("panel", column_style)
	
	add_child(reserved_column)
	
	sidebar_bg = Panel.new()
	sidebar_bg.custom_minimum_size = Vector2(SIDEBAR_WIDTH, ROW_HEIGHT)
	sidebar_bg.size = Vector2(SIDEBAR_WIDTH, ROW_HEIGHT)
	sidebar_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.13, 0.13, 0.15, 0.0)
	sidebar_bg.add_theme_stylebox_override("panel", bg_style)
	
	rows_vbox = VBoxContainer.new()
	rows_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	rows_vbox.offset_left = SIDEBAR_ROW_PADDING
	rows_vbox.offset_right = -SIDEBAR_ROW_PADDING
	rows_vbox.offset_top = SIDEBAR_ROW_PADDING
	rows_vbox.offset_bottom = -SIDEBAR_ROW_PADDING
	rows_vbox.add_theme_constant_override("separation", SIDEBAR_ROW_GAP)
	sidebar_bg.add_child(rows_vbox)
	
	trap_row_button = _add_sidebar_row(rows_vbox, "磁気トラップ", "⚛", Color(0.3, 0.75, 1.0))
	trap_row_button.pressed.connect(_on_tab_pressed)
	
	add_child(sidebar_bg)

# サイドバーに1行追加する（アイコン丸バッジ＋テキスト）。押せるButtonを返す。
func _add_sidebar_row(parent: VBoxContainer, label_text: String, icon_text: String, icon_color: Color) -> Button:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.focus_mode = Control.FOCUS_NONE
	row.flat = false
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.15, 0.17, 0.9)
	style_normal.set_border_width_all(0)
	style_normal.set_corner_radius_all(0)
	
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.20, 0.20, 0.23, 0.95)
	style_hover.set_border_width_all(0)
	style_hover.set_corner_radius_all(0)
	
	var style_selected := StyleBoxFlat.new()
	style_selected.bg_color = Color(0.26, 0.26, 0.30, 1.0)
	style_selected.set_border_width_all(0)
	style_selected.set_corner_radius_all(0)
	
	row.add_theme_stylebox_override("normal", style_normal)
	row.add_theme_stylebox_override("hover", style_hover)
	row.add_theme_stylebox_override("pressed", style_hover)
	row.add_theme_stylebox_override("focus", style_normal)
	
	row.set_meta("style_normal", style_normal)
	row.set_meta("style_selected", style_selected)
	
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	hbox.offset_left = 14
	hbox.offset_right = -10
	
	var icon_badge := Panel.new()
	icon_badge.custom_minimum_size = Vector2(ICON_CIRCLE_SIZE, ICON_CIRCLE_SIZE)
	icon_badge.size = Vector2(ICON_CIRCLE_SIZE, ICON_CIRCLE_SIZE)
	icon_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = icon_color
	badge_style.corner_radius_top_left = int(ICON_CIRCLE_SIZE / 2)
	badge_style.corner_radius_top_right = int(ICON_CIRCLE_SIZE / 2)
	badge_style.corner_radius_bottom_left = int(ICON_CIRCLE_SIZE / 2)
	badge_style.corner_radius_bottom_right = int(ICON_CIRCLE_SIZE / 2)
	icon_badge.add_theme_stylebox_override("panel", badge_style)
	
	var icon_label := Label.new()
	icon_label.text = icon_text
	icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_label.add_theme_font_size_override("font_size", 16)
	icon_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	icon_badge.add_child(icon_label)
	
	var text_label := Label.new()
	text_label.text = label_text
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_font_size_override("font_size", 15)
	text_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.94))
	
	hbox.add_child(icon_badge)
	hbox.add_child(text_label)
	row.add_child(hbox)
	
	parent.add_child(row)
	return row

# ★【追加】他ノード（SingulallityButton / MicrossopicLawUI など）が
#   このサイドバーの土台に自分の行を追加するための公開関数
# 変更後（at_index を追加。デフォルト -1 は今まで通り末尾追加）
func register_sidebar_row(label_text: String, icon_text: String, icon_color: Color, at_index: int = -1) -> Button:
	var btn := _add_sidebar_row(rows_vbox, label_text, icon_text, icon_color)
	if at_index >= 0:
		rows_vbox.move_child(btn, at_index)
	_reposition_ui()
	return btn

# --------------------------------------------------------------
# 粒子インベントリー画面（別画面切り替え・グリッド式・スタック対応）
# --------------------------------------------------------------
func _build_panel() -> void:
	var grid_width: float = GRID_COLUMNS * GRID_SLOT_SIZE + (GRID_COLUMNS + 1) * GRID_SLOT_SPACING
	
	panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.modulate.a = 0.0
	
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
	
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	
	var title := Label.new()
	title.text = "磁気トラップ"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	title_box.add_child(title)
	
	var subtitle := Label.new()
	subtitle.text = "粒子インベントリー ― 1枠あたり最大" + str(STACK_CAP) + "個"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
	title_box.add_child(subtitle)
	
	header.add_child(title_box)
	
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())
	
	var grid_center := CenterContainer.new()
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid_center)
	
	var grid_wrapper := Control.new()
	grid_wrapper.custom_minimum_size = Vector2(grid_width, GRID_ROWS * GRID_SLOT_SIZE + (GRID_ROWS + 1) * GRID_SLOT_SPACING)
	grid_center.add_child(grid_wrapper)
	
	for row in range(GRID_ROWS):
		for col in range(GRID_COLUMNS):
			var slot := TrapSlot.new()
			slot.position = Vector2(
				GRID_SLOT_SPACING + col * (GRID_SLOT_SIZE + GRID_SLOT_SPACING),
				GRID_SLOT_SPACING + row * (GRID_SLOT_SIZE + GRID_SLOT_SPACING)
			)
			grid_wrapper.add_child(slot)
			trap_slots.append(slot)
	
	add_child(panel)

func add_item(type_name: String) -> bool:
	for slot in trap_slots:
		if slot.slot_type == type_name and slot.count < STACK_CAP:
			return slot.add_one(type_name, STACK_CAP)
	for slot in trap_slots:
		if slot.is_empty():
			return slot.add_one(type_name, STACK_CAP)
	return false

# --------------------------------------------------------------
# 実際のビューポートサイズから絶対座標を計算して配置する
# --------------------------------------------------------------
func _reposition_ui() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	
	var sidebar_x: float = vp_size.x - SIDEBAR_WIDTH
	var sidebar_y: float = SIDEBAR_TOP_MARGIN
	
	if reserved_column:
		reserved_column.position = Vector2(sidebar_x, 0)
		reserved_column.size = Vector2(SIDEBAR_WIDTH, vp_size.y)
	
	if sidebar_bg:
		# ★【変更】行数を rows_vbox の実際の子ノード数から動的に計算する
		#   （他ノードが register_sidebar_row() で行を足すたびに再計算される）
		var row_count: int = rows_vbox.get_child_count() if rows_vbox else 1
		var sidebar_content_height: float = ROW_HEIGHT * row_count + SIDEBAR_ROW_GAP * max(row_count - 1, 0) + SIDEBAR_ROW_PADDING * 2
		sidebar_bg.custom_minimum_size = Vector2(SIDEBAR_WIDTH, sidebar_content_height)
		sidebar_bg.size = Vector2(SIDEBAR_WIDTH, sidebar_content_height)
		sidebar_bg.position = Vector2(sidebar_x, sidebar_y)
	
	panel_width = sidebar_x
	panel_height = vp_size.y
	
	if panel:
		panel.size = Vector2(panel_width, panel_height)
		panel.position.x = 0.0
		panel.position.y = 0.0 if is_open else CLOSED_Y_OFFSET
		panel.modulate.a = 1.0 if is_open else 0.0
		panel.mouse_filter = Control.MOUSE_FILTER_STOP if is_open else Control.MOUSE_FILTER_IGNORE
		panel.visible = is_open

# --------------------------------------------------------------
# 開閉トグル（画面切り替え）
# --------------------------------------------------------------
func _on_tab_pressed() -> void:
	if is_open:
		_close_trap_screen()
	else:
		_open_trap_screen()

func _set_trap_row_active(active: bool) -> void:
	if trap_row_button:
		var key := "style_selected" if active else "style_normal"
		trap_row_button.add_theme_stylebox_override("normal", trap_row_button.get_meta(key))

func _open_trap_screen() -> void:
	is_open = true
	
	_set_trap_row_active(true)
	
	# ★【追加】他の画面（特異点・ミクロの法則）が開いていれば閉じてもらう
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

func _close_trap_screen() -> void:
	is_open = false
	
	_set_trap_row_active(false)
	
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

# ★【追加】他の画面（特異点・ミクロの法則）が開かれた時に呼ばれる。
#   自分が開いていれば閉じる。
func external_close(requesting_node) -> void:
	if requesting_node != self and is_open:
		_close_trap_screen()
