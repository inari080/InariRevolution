extends Control

# ゲームの変数を定義
var total_points: int = 0      # 現在の総ポイント
var employee_count: int = 0    # 雇った社員の数
var point_per_employee: int = 1 # 社員1人あたりが毎秒生産するポイント

# ノードへの参照（パスは実際のシーンツリーに合わせて調整してください）
@onready var label: Label = $Label
@onready var timer: Timer = $Timer

func _ready() -> void:
	update_ui()

# UIの表示を更新する関数
func update_ui() -> void:
	label.text = "ポイント: " + str(total_points)

# 「社員を雇う」ボタンの pressed() シグナルと接続する関数
func _on_button_hire_employee_pressed() -> void:
	# 社員を1人増やす
	employee_count += 1
	print("社員を雇いました。現在: ", employee_count, "人")
	
	# 最初の1人を雇った時にタイマーをスタートさせる
	if timer.is_stopped():
		timer.start()

# Timerノードの timeout() シグナルと接続する関数
func _on_timer_timeout() -> void:
	# 毎秒「社員の数 × 1ポイント」を加算
	total_points += employee_count * point_per_employee
	update_ui()
