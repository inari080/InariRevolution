extends Control

# 各種コンポーネント
var game_logic: GameLogic
var particle_pool: ParticlePool
var ui_event_handler: UIEventHandler

# ★右端に確保するサイドバーの幅（遊び場の制限用）
const RESERVED_RIGHT_WIDTH: float = 190.0

func _ready() -> void:
	# 1. 磁気トラップ等からの画面切り替え用グループに登録
	add_to_group("game_field")
	
	# 2. 自分自身の当たり判定を画面全体に広げる
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 3. 各種コンポーネントを初期化してリンク
	game_logic = GameLogic.new()
	particle_pool = ParticlePool.new(game_logic, self)
	ui_event_handler = UIEventHandler.new(game_logic, particle_pool, self)
	
	# 4. GameLogic 内で発生した物理イベントを ParticlePool の演出関数に接続（コールバック）
	game_logic.on_chemical_spark = Callable(particle_pool, "create_chemical_spark")
	game_logic.on_wall_bounce = Callable(particle_pool, "create_wall_bounce_effect")
	game_logic.on_cube_repair = Callable(particle_pool, "create_repair_streak")
	game_logic.on_cube_revive = func():
		AppLogger.info("全粒子消滅 - キューブ自動復活")
		get_tree().call_group("cubes", "revive")

	# 5. 黒い背景（Background）がドラッグ＆ドロップを横取りするバグを防止
	var background = get_node_or_null("Background")
	if background:
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var screen_size = get_viewport_rect().size
	# 右端のサイドバーUIの領域を引いて、粒子が潜り込まないようにする
	screen_size.x -= RESERVED_RIGHT_WIDTH
	
	# --- 各コンポーネントの処理を順番に実行 ---
	
	# 1. クォークの合体・陽子誕生判定
	game_logic.process_quark_fusion(delta)
	
	# 2. 粒子の近接・グループ化の判定
	game_logic.process_grouping(delta)
	
	# 3. 粒子同士の磁力・反発の物理演算
	#    （反発による光子ボーナス発生時は ParticlePool に生成を依頼）
	game_logic.process_forces(delta, Callable(particle_pool, "spawn_single_element"))
	
	# 4. マウスによる吸い寄せ ＆ インベントリ等への回収処理
	ui_event_handler.process_mouse_attraction(delta, mouse_pos, screen_size, 24.0)
	
	# 5. 粒子の通常の移動・壁反射・寿命消滅処理
	game_logic.process_particles(delta, screen_size)

# ★ 外部（GlowingCube等）から呼び出される粒子の初期スポーン窓口
func spawn_elements(start_pos: Vector2, count: int) -> void:
	particle_pool.spawn_elements(start_pos, count)

# ★ 磁気トラップUI画面の開閉に連動して、粒子と吸い寄せの有効化/無効化を切り替える関数
func set_particles_visible(v: bool) -> void:
	ui_event_handler.mouse_interaction_enabled = v
	particle_pool.mouse_interaction_enabled = v
	for item in game_logic.elements:
		if item.sprite:
			item.sprite.visible = v

# --- ドラッグ＆ドロップのイベントを UIEventHandler に丸投げして仲介 ---

func _can_drop_data(at_position: Vector2, data) -> bool:
	return ui_event_handler.can_drop_data_on_field(at_position, data)

func _drop_data(at_position: Vector2, data) -> void:
	ui_event_handler.drop_data_on_field(at_position, data)

# 将来のレシピ拡張用のスタブ関数
func spawn_next_stage() -> void:
	pass
