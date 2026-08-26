extends Control

# ==============================================================
# 特異点（Singularity）ボタン
#
# サイドバー最上段の「ホームに戻る」ボタン。
# 磁気トラップ画面やミクロの法則画面など、他の画面が開いているときに
# これを押すと、開いている画面を閉じて黒い遊び場（デフォルト画面）に戻る。
#
# ★このノード自体は自分の全画面パネルを持たない（元のコードと同じ挙動）。
#   今後、特異点専用の画面を作りたくなったら _build_panel() 的な処理を
#   ここに追加していけばよい。
#
# 使い方:
#   main.gd が付いているノードの「子」として、このスクリプトを付けた
#   新しい Control ノードを追加する。
#   ★シーンツリー上で、magnetic_trap_ui ノードより「下（後）」に置くこと
#     （先に土台=サイドバーが作られている必要があるため）。
# ==============================================================

var row_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("screen_ui")
	
	var trap_ui = get_tree().get_first_node_in_group("magnetic_trap_ui")
	if trap_ui == null:
		push_warning("SingulallityButton: magnetic_trap_ui が見つかりません。シーンツリーの順番を確認してください。")
		return
	
	row_button = trap_ui.register_sidebar_row("特異点", "◉", Color(0.55, 0.35, 0.85))
	row_button.pressed.connect(_on_pressed)
	
	# ★最初はホーム画面（黒い遊び場）がアクティブなので、選択状態にしておく
	_set_active(true)

func _on_pressed() -> void:
	# 他の画面（磁気トラップ・ミクロの法則）が開いていれば閉じさせる
	get_tree().call_group("screen_ui", "external_close", self)
	_set_active(true)

# 他の画面が開かれた時に呼ばれる（自分には専用画面が無いのでハイライトを外すだけ）
func external_close(requesting_node) -> void:
	if requesting_node != self:
		_set_active(false)

func _set_active(active: bool) -> void:
	if row_button:
		var key := "style_selected" if active else "style_normal"
		row_button.add_theme_stylebox_override("normal", row_button.get_meta(key))
