extends ColorRect

# 耐久値の設定
var hp: int = 5
const MAX_HP: int = 5

# ビジュアルの位置とサイズを正しく記録する変数
var original_size: Vector2
var original_position: Vector2

# ★子供の巻き込みバグを避けるため、下から積み重なる実体用の四角形を用意
var repair_content: ColorRect

# このラウンドで到達した耐久値（直近のrepair/reviveで得たHP）を記録
# → explode()時にこの値を粒子の出現数計算に使う
var round_capacity: int = MAX_HP

func _ready() -> void:
	# アニメーションの基準点を四角形の「中心」に設定
	pivot_offset = size / 2
	add_to_group("cubes")
	
	original_size = size
	original_position = position
	
	# 【内枠】下から積み重なる実体用の四角形を作成
	repair_content = ColorRect.new()
	repair_content.color = Color(1.0, 1.0, 1.0, 1.0)
	repair_content.size = Vector2(original_size.x, 0) # 最初は高さゼロ
	repair_content.position = Vector2(0, original_size.y) # 最初は一番下
	repair_content.modulate.a = 0.0                   # 最初は完全に透明
	
	# ★【最重要】この四角形がマウスのクリックを遮断しないように「無視」を設定します
	repair_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	add_child(repair_content)

func _gui_input(event: InputEvent) -> void:
	# 壊れている最中（HPが0以下）はクリックを受け付けない
	if hp <= 0:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		take_damage()

# ★【追加】スペースキー（Godot標準の ui_accept ＝ Space / Enter）でも殴れるようにする
func _unhandled_input(event: InputEvent) -> void:
	# 壊れている最中（HPが0以下）や、磁気トラップ画面などで隠れている時は反応しない
	if hp <= 0 or not visible:
		return
	
	if event.is_action_pressed("ui_accept"):
		take_damage()

func take_damage() -> void:
	hp -= 1
	print("残りHP: ", hp)
	
	if hp <= 0:
		explode()
	else:
		play_click_animation()

func play_click_animation() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# 破壊時の処理
func explode() -> void:
	# 自分自身の「描画そのもの（Self Modulate）」のアルファ値だけを 0 にして完全に隠します。
	# これにより、自分は透明になりつつ、子供である「修復バー」の表示を邪魔しないようになります。
	self_modulate.a = 0.0
	
	# 積み重なる中身を完全にリセット（高さ0にして一番下へ）
	if repair_content:
		repair_content.size.y = 0
		repair_content.position.y = original_size.y
		repair_content.modulate.a = 0.0

	var center_pos = original_position + (original_size / 2)
	
	# 親のmainノードに、このラウンドで到達していた耐久値(round_capacity)を渡す
	# → HPが多い状態で壊されたほど、出現する粒子は多くなる
	var main = get_node("..")
	if main and main.has_method("spawn_elements"):
		main.spawn_elements(center_pos, round_capacity)

# 逃した粒子が消えた分だけ、下からハッキリ積み重なっていく
# ★【変更】HPが満タン(MAX_HP)まで貯まったら、画面上に粒子が残っていても
#   その時点で即座に完全体（revive）にする。
#   「粒子を1個残らず回収しないと完全体にならない」問題を解消するため。
func repair() -> void:
	hp = clampi(hp + 1, 0, MAX_HP)
	
	# このラウンドの到達耐久値を更新
	round_capacity = hp
	
	if hp >= MAX_HP:
		# HPが満タンに到達 → 残りの粒子を待たずに完全復活させる
		revive()
		return
	
	var hp_ratio = float(hp) / float(MAX_HP)
	var target_height = original_size.y * hp_ratio
	
	if repair_content:
		var tween = create_tween().set_parallel(true)
		
		# 独立した repair_content の「縦幅」を伸ばす（これで確実に映ります）
		tween.tween_property(repair_content, "size:y", target_height, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# 下から上にせり上がるように「Y座標」を調整
		tween.tween_property(repair_content, "position:y", original_size.y - target_height, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# 積み重なっている途中は、少し薄め（25%の不透明度）にしてくっきり目立たせる
		tween.tween_property(repair_content, "modulate:a", 0.25, 0.4)
		
	print("四角形が下から結晶化中... 現在の修復度: ", hp_ratio * 100, "%")

# 完全復活（100%完全体に戻る）
# HPが満タンになった瞬間（repair経由）でも、画面上の粒子が全て消えた時（main.gd経由）でも呼ばれる
func revive() -> void:
	hp = MAX_HP
	round_capacity = MAX_HP
	
	var tween = create_tween().set_parallel(true)
	
	# 完全体になったので、自分自身の隠していた姿（Self Modulate）を100%の元の眩しい白に戻す！
	tween.tween_property(self, "self_modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 完全に復活したので、役目を終えた中の修復バーは透明にしてリセット
	if repair_content:
		tween.tween_property(repair_content, "modulate:a", 0.0, 0.2)
		
	print("四角形が100%完全体に復活した！")
