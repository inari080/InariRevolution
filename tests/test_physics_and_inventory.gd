# tests/test_physics_and_inventory.gd
extends GutTest

var game_logic: GameLogic
var particle_pool: ParticlePool
var dummy_parent: Node

func before_each() -> void:
	game_logic = GameLogic.new()
	dummy_parent = Node.new()
	add_child(dummy_parent)
	particle_pool = ParticlePool.new(game_logic, dummy_parent)

func after_each() -> void:
	# 1. 登録された粒子のスプライトを即時解放
	for item in game_logic.elements:
		if is_instance_valid(item.sprite):
			item.sprite.free()
	
	# 2. ダミー親ノードと、その中に溜まったエフェクト等の子ノードをすべて強制解放
	if is_instance_valid(dummy_parent):
		for child in dummy_parent.get_children():
			child.free()
		dummy_parent.free()
		
	# 3. 【Orphans完全消滅化】
	# テスト用に追加した TrapSlot や、その内部で自動生成された UIラベル（icon_label, count_label）を
	# 階層の末端から1つ残らず根こそぎ即時メモリ解放します。
	for child in get_children():
		if is_instance_valid(child):
			for sub_child in child.get_children():
				if is_instance_valid(sub_child):
					sub_child.free()
			child.free()
	
	if is_instance_valid(game_logic):
		game_logic.free()

# ===== 1. 粒子グループ判定 (クォーク3個1組の条件) のテスト =====
func test_quark_fusion_triggers_with_three_quarks() -> void:
	particle_pool.spawn_single_element("Quark", Vector2(100, 100))
	particle_pool.spawn_single_element("Quark", Vector2(110, 105))
	particle_pool.spawn_single_element("Quark", Vector2(105, 115))
	
	game_logic.process_quark_fusion(1.0)
	game_logic.process_quark_fusion(1.0)
	game_logic.process_quark_fusion(1.1)
	
	assert_eq(game_logic.elements.size(), 0, "3つが近接して3秒以上経つと、クォークは消滅（融合）すべき")

func test_quark_fusion_does_not_trigger_if_too_far() -> void:
	particle_pool.spawn_single_element("Quark", Vector2(100, 100))
	particle_pool.spawn_single_element("Quark", Vector2(300, 100))
	particle_pool.spawn_single_element("Quark", Vector2(500, 100))
	
	game_logic.process_quark_fusion(3.5)
	
	assert_eq(game_logic.elements.size(), 3, "距離が離れている場合は3秒経っても合体してはならない")

# ===== 2. 反発力の計算（物理演算）のテスト =====
func test_repulsion_force_applied_to_dense_groups() -> void:
	for i in range(4):
		particle_pool.spawn_single_element("Quark", Vector2(200, 200 + i * 5))
	
	for item in game_logic.elements:
		item.has_bounced = true
		item.bounce_timer = 3.5
		item.age = 0.5
	
	game_logic.process_grouping(3.5)
	
	var item_a = game_logic.elements[0]
	var item_b = game_logic.elements[1]
	item_a.velocity = Vector2.ZERO
	item_b.velocity = Vector2.ZERO
	
	game_logic.process_forces(0.016, func(_pos): pass)
	
	assert_true(item_a.velocity.length() > 0.0, "過密グループでは反発力により速度が発生するはず")
	assert_true(item_a.repelling_now, "repelling_now フラグが立っているはず")

# ===== 3. インベントリー容量管理のテスト =====
func test_inventory_capacity_clamping() -> void:
	var mock_slot = MagneticTrapUI.TrapSlot.new()
	add_child(mock_slot) # after_each 内の 3番目のステップで内部UIも含めて完全消去されます
	
	var success = true
	for i in range(10):
		success = mock_slot.add_one("Quark", 10)
		assert_true(success, "%d個目の追加は成功すべき" % (i + 1))
	
	var fail_add = mock_slot.add_one("Quark", 10)
	
	assert_false(fail_add, "容量制限(10個)を超えた追加は拒否されるべき")
	assert_eq(mock_slot.count, 10, "スロット内のカウントは最大容量の10でクランプされるべき")
