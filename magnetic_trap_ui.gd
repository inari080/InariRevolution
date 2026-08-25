extends Control

# ==============================================================
# 磁気トラップ（Magnetic Trap / 収束器）UI
#
# Idle Revolution 風の「右端固定・縦積みサイドバー」スタイルを想定。
# 今は磁気トラップ1行だけだが、今後タブが増えたら
# _build_sidebar() 内で _add_sidebar_row(...) を呼び足していけば
# 同じ入れ物にそのまま追加できる構造にしてある。
#
# 使い方:
#   1. main.gd が付いているノードの「子」として、このスクリプトを
#      付けた新しい Control ノードを追加する
#      （main.gd のノード自体には付けないこと！）
#   2. main.gd の on_element_collected() から下記のように呼べば
#      自動で表示が更新される（既に main.gd 側に追加済み）:
#         get_tree().call_group("magnetic_trap_ui", "update_counts",
#             collected_quarks, collected_electrons, collected_photons)
#
# ★【現在】保管・送出機能は一旦撤去済み（見た目だけ残した状態）。
#   回収した粒子は main.gd から直接インベントリーへ入るようになっている。
#   後日、ここに正式な保管・送出ロジックを作り直す予定。
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

const PANEL_WIDTH: float = 280.0
const PANEL_HEIGHT: float = 260.0
const PANEL_TOP_GAP: float = 8.0 # サイドバーの下からの隙間
const ANIM_DURATION: float = 0.28

var is_open: bool = false

var reserved_column: Panel
var sidebar_bg: Panel
var trap_row_button: Button
var trap_row_style_normal: StyleBoxFlat
var trap_row_style_selected: StyleBoxFlat

var panel: Panel
var quark_count_label: Label
var electron_count_label: Label
var photon_count_label: Label

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
# サイドバー（参考画像の「革命／無限／永遠…」のような縦積みリスト）
# 今は行が1つだけだが、今後 _add_sidebar_row() を呼び足せば増やせる
# --------------------------------------------------------------
func _build_sidebar() -> void:
	# ★【追加】画面右端を「上から下まで」確保する背景（黒い遊び場と区別する専用エリア）
	# 今後タブが増えても、この帯の中に行を積み足していくだけでよい
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
	
	# 磁気トラップ行のスタイルは開閉トグルで使うので保持しておく
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
# ドロワーパネル（磁場で閉じ込めた粒子の一覧）
# サイドバーのすぐ下から、下方向に開く
# --------------------------------------------------------------
func _build_panel() -> void:
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.modulate.a = 0.0 # 閉じている間は透明にしておく（開閉はフェード＋位置移動）
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.96)
	style.border_color = Color(0.35, 0.85, 1.0, 0.75)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.25, 0.75, 1.0, 0.35)
	style.shadow_size = 14
	panel.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	var title := Label.new()
	title.text = "磁気トラップ"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	vbox.add_child(title)
	
	var subtitle := Label.new()
	subtitle.text = "Magnetic Trap ― 収束器"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
	vbox.add_child(subtitle)
	
	vbox.add_child(HSeparator.new())
	
	var desc := Label.new()
	desc.text = "強力な磁場と電場で素粒子を\n閉じ込める予定のスペースです。\n（機能は準備中）"
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.6, 0.63, 0.68))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)
	
	vbox.add_child(HSeparator.new())
	
	quark_count_label = _create_particle_row(vbox, "クォーク", Color(1.0, 0.35, 0.35))
	electron_count_label = _create_particle_row(vbox, "電子", Color(0.4, 1.0, 0.5))
	photon_count_label = _create_particle_row(vbox, "光子", Color(1.0, 0.95, 0.4))
	
	add_child(panel)

# 粒子種別ごとの1行（色スウォッチ＋名前＋個数）を作成する
# ★保管・送出機能は一旦撤去したため、送るボタンはなし。見た目のみ。
func _create_particle_row(parent: VBoxContainer, particle_name: String, swatch_color: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.color = swatch_color
	
	var name_label := Label.new()
	name_label.text = particle_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	name_label.custom_minimum_size = Vector2(58, 0)
	
	var count_label := Label.new()
	count_label.text = "0"
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", swatch_color)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	row.add_child(swatch)
	row.add_child(name_label)
	row.add_child(count_label)
	parent.add_child(row)
	
	return count_label

# --------------------------------------------------------------
# 実際のビューポートサイズから絶対座標を計算して配置する
# サイドバー＝画面右上固定。パネル＝サイドバーの真下に開く。
# --------------------------------------------------------------
func _reposition_ui() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	
	var sidebar_x: float = vp_size.x - SIDEBAR_WIDTH
	var sidebar_y: float = SIDEBAR_TOP_MARGIN
	
	# ★【追加】画面右端の帯を、常に画面の縦幅いっぱいに広げる
	if reserved_column:
		reserved_column.position = Vector2(sidebar_x, 0)
		reserved_column.size = Vector2(SIDEBAR_WIDTH, vp_size.y)
	
	if sidebar_bg:
		sidebar_bg.position = Vector2(sidebar_x, sidebar_y)
	
	# パネルはサイドバーの右端に合わせて、サイドバーのすぐ下に表示する
	var panel_x: float = sidebar_x + SIDEBAR_WIDTH - PANEL_WIDTH
	var panel_y_open: float = sidebar_y + ROW_HEIGHT + PANEL_TOP_GAP
	var panel_y_closed: float = panel_y_open - 12.0 # 閉じている時は少し上にいてフェードイン風に見せる
	
	if panel:
		panel.position.x = panel_x
		panel.position.y = panel_y_open if is_open else panel_y_closed
		panel.modulate.a = 1.0 if is_open else 0.0
		panel.mouse_filter = Control.MOUSE_FILTER_STOP if is_open else Control.MOUSE_FILTER_IGNORE

# --------------------------------------------------------------
# 開閉トグル（サイドバー行の下にフェード＋スライドしながら開く）
# 開いている間は行を選択状態（明るいグレー）にハイライトする
# --------------------------------------------------------------
func _on_tab_pressed() -> void:
	is_open = not is_open
	
	if trap_row_button:
		trap_row_button.add_theme_stylebox_override(
			"normal",
			trap_row_style_selected if is_open else trap_row_style_normal
		)
	
	var vp_size: Vector2 = get_viewport_rect().size
	var panel_y_open: float = SIDEBAR_TOP_MARGIN + ROW_HEIGHT + PANEL_TOP_GAP
	var panel_y_closed: float = panel_y_open - 12.0
	
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if is_open else Control.MOUSE_FILTER_IGNORE
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT if is_open else Tween.EASE_IN)
	
	if is_open:
		tween.tween_property(panel, "position:y", panel_y_open, ANIM_DURATION)
		tween.tween_property(panel, "modulate:a", 1.0, ANIM_DURATION)
	else:
		tween.tween_property(panel, "position:y", panel_y_closed, ANIM_DURATION)
		tween.tween_property(panel, "modulate:a", 0.0, ANIM_DURATION)

# --------------------------------------------------------------
# main.gd から呼ばれる更新関数
# --------------------------------------------------------------
func update_counts(quarks: int, electrons: int, photons: int) -> void:
	if quark_count_label:
		quark_count_label.text = str(quarks)
	if electron_count_label:
		electron_count_label.text = str(electrons)
	if photon_count_label:
		photon_count_label.text = str(photons)
