extends Control

# ==============================================================
# インベントリーバー（画面下部・スロット式）
#
# 磁気トラップの「→」ボタンで送られた粒子が、ここの空きスロットに
# 入る。スロットのアイコンをドラッグして画面（空間）にドロップすると
# main.gd 側で実体の粒子として再度スポーンされ、スロットは空になる。
#
# 使い方:
#   1. main.gd が付いているノードの「子」として、このスクリプトを
#      付けた新しい Control ノードを追加する
#      （main.gd のノード自体には付けないこと！）
#   2. あとは自動で動きます。main.gd 側の request_withdraw() が
#      add_item() を、main.gd の _drop_data() がスロットの clear() を
#      それぞれ呼び出します。
#
# ★位置は magnetic_trap_ui.gd と同様、アンカーに頼らず
#   get_viewport_rect().size から絶対座標で計算する。
# ==============================================================

const SLOT_SIZE: float = 60.0
const SLOT_SPACING: float = 8.0
const SLOT_COUNT: int = 10
const BAR_PADDING: float = 10.0
const BAR_BOTTOM_MARGIN: float = 16.0

var slots: Array = []
var bar_panel: Panel

# --------------------------------------------------------------
# インベントリー1枠ぶんのスロット（アイテムの表示とドラッグ元）
# --------------------------------------------------------------
class InventorySlot:
	extends Panel
	
	var slot_type: String = ""
	var icon_label: Label
	var style_empty: StyleBoxFlat
	
	func _init() -> void:
		custom_minimum_size = Vector2(60, 60)
		size = Vector2(60, 60)
		mouse_filter = Control.MOUSE_FILTER_STOP
		
		style_empty = StyleBoxFlat.new()
		style_empty.bg_color = Color(0.10, 0.10, 0.12, 0.85)
		style_empty.border_color = Color(0.28, 0.3, 0.34, 0.8)
		style_empty.set_border_width_all(2)
		style_empty.corner_radius_top_left = 8
		style_empty.corner_radius_top_right = 8
		style_empty.corner_radius_bottom_left = 8
		style_empty.corner_radius_bottom_right = 8
		add_theme_stylebox_override("panel", style_empty)
		
		icon_label = Label.new()
		icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_label.add_theme_font_size_override("font_size", 22)
		add_child(icon_label)
	
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
	
	func set_item(type_name: String) -> void:
		slot_type = type_name
		var visual: Dictionary = _visual_for(type_name)
		
		var style_filled := StyleBoxFlat.new()
		style_filled.bg_color = Color(0.14, 0.14, 0.17, 0.95)
		style_filled.border_color = visual["color"]
		style_filled.set_border_width_all(2)
		style_filled.corner_radius_top_left = 8
		style_filled.corner_radius_top_right = 8
		style_filled.corner_radius_bottom_left = 8
		style_filled.corner_radius_bottom_right = 8
		add_theme_stylebox_override("panel", style_filled)
		
		icon_label.text = visual["text"]
		icon_label.add_theme_color_override("font_color", visual["color"])
	
	func clear() -> void:
		slot_type = ""
		icon_label.text = ""
		add_theme_stylebox_override("panel", style_empty)
	
	func is_empty() -> bool:
		return slot_type == ""
	
	# ドラッグ開始：中身があるスロットのみドラッグ可能にする
	func _get_drag_data(_at_position: Vector2) -> Variant:
		if slot_type == "":
			return null
		
		var data := {"particle_type": slot_type, "source_slot": self}
		
		var visual: Dictionary = _visual_for(slot_type)
		var preview := Label.new()
		preview.text = visual["text"]
		preview.add_theme_font_size_override("font_size", 30)
		preview.add_theme_color_override("font_color", visual["color"])
		set_drag_preview(preview)
		
		return data
	
	# ★【追加】磁気トラップの粒子インベントリーからのドラッグを、
	# このスロットが空いている時だけ受け入れる
	func _can_drop_data(_at_position: Vector2, data) -> bool:
		if not is_empty():
			return false
		return typeof(data) == TYPE_DICTIONARY and data.has("particle_type")
	
	func _drop_data(_at_position: Vector2, data) -> void:
		if not (typeof(data) == TYPE_DICTIONARY and data.has("particle_type")):
			return
		if not is_empty():
			return
		
		set_item(data["particle_type"])
		
		# 移動元が磁気トラップのスタックスロットなら、そちらを1個減らす
		if data.has("source_trap_slot") and is_instance_valid(data["source_trap_slot"]):
			data["source_trap_slot"].remove_one()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	add_to_group("inventory_bar")
	
	_build_bar()
	_reposition_bar()
	
	get_viewport().size_changed.connect(_reposition_bar)

func _build_bar() -> void:
	var bar_width: float = SLOT_COUNT * SLOT_SIZE + (SLOT_COUNT + 1) * SLOT_SPACING
	var bar_height: float = SLOT_SIZE + SLOT_SPACING * 2.0
	
	bar_panel = Panel.new()
	bar_panel.custom_minimum_size = Vector2(bar_width, bar_height)
	bar_panel.size = Vector2(bar_width, bar_height)
	bar_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.92)
	style.border_color = Color(0.3, 0.35, 0.4, 0.6)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	bar_panel.add_theme_stylebox_override("panel", style)
	
	add_child(bar_panel)
	
	for i in range(SLOT_COUNT):
		var slot := InventorySlot.new()
		slot.position = Vector2(
			SLOT_SPACING + i * (SLOT_SIZE + SLOT_SPACING),
			SLOT_SPACING
		)
		bar_panel.add_child(slot)
		slots.append(slot)

func _reposition_bar() -> void:
	if not bar_panel:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	bar_panel.position = Vector2(
		(vp_size.x - bar_panel.size.x) / 2.0,
		vp_size.y - bar_panel.size.y - BAR_BOTTOM_MARGIN
	)

# 空きスロットに1個追加する。成功したらtrue、満杯ならfalseを返す。
func add_item(type_name: String) -> bool:
	for slot in slots:
		if slot.is_empty():
			slot.set_item(type_name)
			return true
	return false
