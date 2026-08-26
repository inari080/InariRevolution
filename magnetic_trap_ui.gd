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
# 使い方:
#   main.gd が付いているノードの「子」として、このスクリプトを付けた
#   新しい Control ノードを追加する（main.gd のノード自体には付けないこと！）
#
# ★位置はアンカーではなく、実際のビューポートサイズから直接計算する
#   ことで、親ノードのサイズ確定タイミングに左右されないようにしている。
# ==============================================================

# サイドバー本体（右端に張り付く縦積みリスト）
# ★ main.gd の RESERVED_RIGHT_WIDTH と必ず同じ値にすること
#   （この幅ぶん、main.gd側でキューブ・粒子の移動範囲が狭められる）
const SIDEBAR_WIDTH: float = 190.0
const SIDEBAR_TOP_MARGIN: float = 20.0
const ROW_HEIGHT: float = 50.0
const ICON_CIRCLE_SIZE: float = 30.0

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
var trap_row_button: Button
var trap_row_style_normal: StyleBoxFlat
var trap_row_style_selected: StyleBoxFlat

var panel: Panel
var trap_slots: Array = []

var panel_width: float = 0.0
var panel_height: float = 0.0

# --------------------------------------------------------------
# 粒子インベントリー1枠ぶんのスロット（同じ種類を最大10個までスタック）
# --------------------------------------------------------------
class TrapSlot:
	extends Panel
	
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
		
		count_label = Label.new()
		count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count_label.position = Vector2(-32, -22)
		count_label.size = Vector2(28, 18)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		add_child(count_label)
	
	static func _visual_for(type_name: String) -> Dictionary:
		match type_name:
			"Quark":
				return {"text": "Q", "color": Color(1.0, 0.35, 0.35)}
			"Electron":
				return {"text": "e⁻", "color": Color(0.4, 1.0, 0.5)}
			"Photon":
				return {"text": "γ", "color": Color(1.0, 0.95, 0.4)}
			_:
				return {"text": "?", "color": Color(0.8, 0.8, 0.8)}
	
	func _refresh_visual() -> void:
		if slot_type == "":
			icon_label.text = ""
			count_label.text = ""
			add_theme_stylebox_override("panel", style_empty)
			return
		
		var visual: Dictionary = _visual_for(slot_type)
		
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
		count_label.text = "x" + str(count)
	
	# 1個追加を試みる。成功したらtrue。
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
	
	# 1個取り出す（ドラッグで他インベントリーへ移動した時などに呼ぶ）
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
	
	# ドラッグ開始：中身があるスロットのみドラッグ可能（1個ぶんだけ運ぶ）
	func _get_drag_data(_at_position: Vector2) -> Variant:
		if slot_type == "":
			return null
		
		var data := {"particle_type": slot_type, "source_trap_slot": self}
		
		var visual: Dictionary = _visual_for(slot_type)
		var preview := Label.new()
		preview.text = visual["text"]
		preview.add_theme_font_size_override("font_size", 30)
		preview.add_theme_color_override("font_color", visual["color"])
		set_drag_preview(preview)
		
		return data

func _ready() -> void:
	# 自分自身はマウスを奪わない（子のボタン/パネルだけが反応する）
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	add_to_group("magnetic_trap_ui")
	
	_build_panel()
	_build_sidebar()
	
	# アンカーに頼らず、実際のビューポートサイズを見て絶対座標で配置する
	_reposition_ui()
	
	# ウィンドウサイズが変わった時も追従させる
	get_viewport().size_changed.connect(_reposition_ui)

# --------------------------------------------------------------
# サイドバー（右端に張り付く縦積みリスト。今は磁気トラップ1行だけ）
# --------------------------------------------------------------
func _build_sidebar() -> void:
	# 画面右端を「上から下まで」確保する背景（黒い遊び場と区別する専用エリア）
	reserved_column = Panel.new()
	reserved_column.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var column_style := StyleBoxFlat.new()
	column_style.bg_color = Color(0.11, 0.11, 0.13, 1.0) # 黒(遊び場)とは少し区別できる濃いグレー
	column_style.border_width_left = 2
	column_style.border_color = Color(1.0, 1.0, 1.0, 0.06) # 境界線をうっすら
	reserved_column.add_theme_stylebox_override("panel", column_style)
	
	add_child(reserved_column)
	
	# タブの行を積むコンテナ（帯の上部に配置。下は今後タブが増えるまで空のまま）
	sidebar_bg = Panel.new()
	sidebar_bg.custom_minimum_size = Vector2(SIDEBAR_WIDTH, ROW_HEIGHT)
	sidebar_bg.size = Vector2(SIDEBAR_WIDTH, ROW_HEIGHT)
	sidebar_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.13, 0.13, 0.15, 0.0) # 背景は reserved_column に任せるので透明
	sidebar_bg.add_theme_stylebox_override("panel", bg_style)
	
	var rows_vbox := VBoxContainer.new()
	rows_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	rows_vbox.add_theme_constant_override("separation", 0)
	sidebar_bg.add_child(rows_vbox)
	
	trap_row_button = _add_sidebar_row(rows_vbox, "磁気トラップ", "⚛", Color(0.3, 0.75, 1.0))
	trap_row_button.pressed.connect(_on_tab_pressed)
	
	add_child(sidebar_bg)

# サイドバーに1行追加する（アイコン丸バッジ＋テキスト）。押せるButtonを返す。
func _add_sidebar_row(parent: VBoxContainer, label_text: String, icon_text: String, icon_color: Color) -> Button:
	var row := Button.new()
	row.custom_minimum_size = Vector2(SIDEBAR_WIDTH, ROW_HEIGHT)
	row.focus_mode = Control.FOCUS_NONE
	row.flat = true
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.13, 0.13, 0.15, 0.0) # 通常時は透明（サイドバー背景がそのまま見える）
	
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(1.0, 1.0, 1.0, 0.06)
	
	var style_selected := StyleBoxFlat.new()
	style_selected.bg_color = Color(0.55, 0.56, 0.58, 1.0)
	style_selected.corner_radius_top_left = 10
	style_selected.corner_radius_bottom_left = 10
	
	row.add_theme_stylebox_override("normal", style_normal)
	row.add_theme_stylebox_override("hover", style_hover)
	row.add_theme_stylebox_override("pressed", style_hover)
	row.add_theme_stylebox_override("focus", style_normal)
	
	trap_row_style_normal = style_normal
	trap_row_style_selected = style_selected
	
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

# --------------------------------------------------------------
# 粒子インベントリー画面（別画面切り替え・グリッド式・スタック対応）
# 画面全体（右のサイドバー帯を除く）を覆う「画面切り替え」として表示する
# --------------------------------------------------------------
func _build_panel() -> void:
	var grid_width: float = GRID_COLUMNS * GRID_SLOT_SIZE + (GRID_COLUMNS + 1) * GRID_SLOT_SPACING
	
	panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.modulate.a = 0.0 # 閉じている間は透明にしておく（開閉はフェード＋わずかな位置移動）
	
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
	
	# ヘッダー行（タイトル ＋ 戻るボタン）
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
	
	var back_button := Button.new()
	back_button.text = "← 戻る"
	back_button.custom_minimum_size = Vector2(90, 36)
	back_button.focus_mode = Control.FOCUS_NONE
	
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.16, 0.18, 0.21, 1.0)
	back_style.border_color = Color(0.4, 0.9, 1.0, 0.6)
	back_style.set_border_width_all(1)
	back_style.corner_radius_top_left = 8
	back_style.corner_radius_top_right = 8
	back_style.corner_radius_bottom_left = 8
	back_style.corner_radius_bottom_right = 8
	back_button.add_theme_stylebox_override("normal", back_style)
	
	var back_style_hover := back_style.duplicate()
	back_style_hover.bg_color = Color(0.22, 0.25, 0.29, 1.0)
	back_button.add_theme_stylebox_override("hover", back_style_hover)
	back_button.add_theme_stylebox_override("pressed", back_style_hover)
	
	back_button.pressed.connect(_on_tab_pressed)
	header.add_child(back_button)
	
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())
	
	# グリッド本体（中央寄せ）
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

# --------------------------------------------------------------
# main.gd から呼ばれる：通常インベントリーが満杯の時のフォールバック保管先
# 既存の同じ種類でスタックに空きがあるスロットを優先し、無ければ空きスロットへ。
# --------------------------------------------------------------
func add_item(type_name: String) -> bool:
	for slot in trap_slots:
		if slot.slot_type == type_name and slot.count < STACK_CAP:
			return slot.add_one(type_name, STACK_CAP)
	for slot in trap_slots:
		if slot.is_empty():
			return slot.add_one(type_name, STACK_CAP)
	return false # 粒子インベントリーも満杯

# --------------------------------------------------------------
# 実際のビューポートサイズから絶対座標を計算して配置する
# サイドバー＝画面右上固定。パネル＝画面全体（サイドバー帯を除く）を覆う。
# --------------------------------------------------------------
func _reposition_ui() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	
	var sidebar_x: float = vp_size.x - SIDEBAR_WIDTH
	var sidebar_y: float = SIDEBAR_TOP_MARGIN
	
	if reserved_column:
		reserved_column.position = Vector2(sidebar_x, 0)
		reserved_column.size = Vector2(SIDEBAR_WIDTH, vp_size.y)
	
	if sidebar_bg:
		sidebar_bg.position = Vector2(sidebar_x, sidebar_y)
	
	panel_width = sidebar_x # 画面左端からサイドバー帯の手前まで
	panel_height = vp_size.y
	
	if panel:
		panel.size = Vector2(panel_width, panel_height)
		panel.position.x = 0.0
		panel.position.y = 0.0 if is_open else CLOSED_Y_OFFSET
		panel.modulate.a = 1.0 if is_open else 0.0
		panel.mouse_filter = Control.MOUSE_FILTER_STOP if is_open else Control.MOUSE_FILTER_IGNORE

# --------------------------------------------------------------
# 開閉トグル（画面切り替え）
# 開く: 黒い遊び場・キューブ・浮遊中の粒子・下のインベントリーバーを隠す
# 閉じる: すべて元に戻す
# --------------------------------------------------------------
func _on_tab_pressed() -> void:
	is_open = not is_open
	
	if trap_row_button:
		trap_row_button.add_theme_stylebox_override(
			"normal",
			trap_row_style_selected if is_open else trap_row_style_normal
		)
	
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if is_open else Control.MOUSE_FILTER_IGNORE
	
	# ★【追加】画面切り替えなので、裏側（遊び場）を隠す/戻す
	if is_open:
		get_tree().call_group("cubes", "hide")
		get_tree().call_group("inventory_bar", "hide")
		var field = get_tree().get_first_node_in_group("game_field")
		if field and field.has_method("set_particles_visible"):
			field.set_particles_visible(false)
	else:
		get_tree().call_group("cubes", "show")
		get_tree().call_group("inventory_bar", "show")
		var field2 = get_tree().get_first_node_in_group("game_field")
		if field2 and field2.has_method("set_particles_visible"):
			field2.set_particles_visible(true)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT if is_open else Tween.EASE_IN)
	
	if is_open:
		tween.tween_property(panel, "position:y", 0.0, ANIM_DURATION)
		tween.tween_property(panel, "modulate:a", 1.0, ANIM_DURATION)
	else:
		tween.tween_property(panel, "position:y", CLOSED_Y_OFFSET, ANIM_DURATION)
		tween.tween_property(panel, "modulate:a", 0.0, ANIM_DURATION)
