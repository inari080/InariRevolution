extends Node2D

# 元素アイテムのデータを保持する構造体
class ElementItem:
	var position: Vector2
	var velocity: Vector2
	var is_attracted: bool = false

# 画面上の元素たちを記録するリスト
var elements: Array[ElementItem] = []

# 吸い込みが始まるマウスとの距離（ピクセル）
const ATTRACT_RADIUS: float = 150.0
# 吸い込まれるスピード
const FLY_SPEED: float = 800.0

func _process(delta: float) -> void:
	# 画面上の全ての元素の動きを計算する
	var mouse_pos = get_global_mouse_position()
	
	# 後で消去するために、逆順でループを回します
	for i in range(elements.size() - 1, -1, -1):
		var item = elements[i]
		var dist_to_mouse = item.position.distance_to(mouse_pos)
		
		# マウスが近づいたら吸い込みフラグをONにする
		if dist_to_mouse < ATTRACT_RADIUS:
			item.is_attracted = true
			
		if item.is_attracted:
			# マウスに向かう方向を計算
			var direction = (mouse_pos - item.position).normalized()
			# 徐々に加速しながらマウスへ向かう
			item.velocity = item.velocity.move_toward(direction * FLY_SPEED, delta * 3000.0)
			item.position += item.velocity * delta
			
			# マウスに十分近づいたら「回収完了」として消す
			if dist_to_mouse < 15.0:
				elements.remove_at(i)
				on_element_collected()
				continue
		else:
			# 吸い込まれていない時は、少しずつその場に漂う（減速）
			item.velocity = item.velocity.move_toward(Vector2.ZERO, delta * 150.0)
			item.position += item.velocity * delta
			
	# 画面の更新（再描画）を要求する
	queue_redraw()

# 元素を画面に描き出す処理
func _draw() -> void:
	for item in elements:
		# 眩しく光る小さな四角（元素）を白い色で描く
		# ※mainノードの下のWorldEnvironmentの効果がここにも乗ります
		draw_rect(Rect2(item.position - Vector2(4,4), Vector2(8,8)), Color(3.0, 3.0, 3.0, 1.0))

# 外部から元素を発生させるための関数
func spawn_elements(start_pos: Vector2, count: int) -> void:
	for i in range(count):
		var item = ElementItem.new()
		item.position = start_pos
		
		# 360度ランダムな方向に飛び散る初速を与える
		var angle = randf() * TAU
		var speed = randf_range(150.0, 300.0)
		item.velocity = Vector2(cos(angle), sin(angle)) * speed
		
		elements.append(item)

# 元素が回収されたときに呼ばれる関数
func on_element_collected() -> void:
	print("元素を1個回収した！ 現在の所持数: ", 10 - elements.size()) # (仮のカウント)
