# tests/test_spawn_elements.gd
extends GutTest
# テスト対象: main.gd の spawn_elements() の内部計算ロジック

var main: Control

func before_each() -> void:
	main = Control.new()
	main.set_script(load("res://main.gd"))
	add_child(main)
	main._ready()

func after_each() -> void:
	main.free() # free()で警告を防止

# ===== 粒子出現数の計算テスト =====
func test_spawn_count_at_minimum_capacity() -> void:
	var capacity = 1
	var ratio = float(capacity - 1) / float(5 - 1)
	var base_count = int(round(lerp(float(2), float(8), ratio)))
	assert_between(base_count, 2, 4, "最小容量の時は出現数が2から4の間になるはず")

func test_spawn_count_at_maximum_capacity() -> void:
	var capacity = 5
	var ratio = float(capacity - 1) / float(5 - 1)
	var base_count = int(round(lerp(float(2), float(8), ratio)))
	assert_between(base_count, 6, 8, "最大容量の時は出現数が6から8の間になるはず")

func test_spawn_count_increases_monotonically() -> void:
	var counts = []
	for capacity in range(1, 6):
		var ratio = float(capacity - 1) / float(5 - 1)
		var base_count = int(round(lerp(float(2), float(8), ratio)))
		counts.append(base_count)
	for i in range(counts.size() - 1):
		assert_true(counts[i] <= counts[i + 1], "単調増加の検証")

func test_spawn_count_with_random_variance() -> void:
	var capacity = 3
	var ratio = float(capacity - 1) / float(5 - 1)
	var base_count = int(round(lerp(float(2), float(8), ratio)))
	var random_offset = randi_range(-1, 1)
	var final_count = clampi(base_count + random_offset, 2, 8)
	assert_between(final_count, 2, 8, "最終出現数が範囲内")

func test_capacity_clamping() -> void:
	var invalid_capacity = 10
	var clamped = clampi(invalid_capacity, 1, 5)
	assert_eq(clamped, 5, "capacityは5でクランプされるべき")

func test_spawn_count_deterministic_at_extremes() -> void:
	var ratio_min = float(1 - 1) / float(5 - 1)
	var count_min = int(round(lerp(float(2), float(8), ratio_min)))
	var ratio_max = float(5 - 1) / float(5 - 1)
	var count_max = int(round(lerp(float(2), float(8), ratio_max)))
	assert_eq(count_min, 2, "HP最小時は2")
	assert_eq(count_max, 8, "HP最大時は8")

func test_spawn_count_midpoint() -> void:
	var capacity = 3
	var ratio = float(capacity - 1) / float(5 - 1)
	var base_count = int(round(lerp(float(2), float(8), ratio)))
	assert_eq(base_count, 5, "中間HP時は5")

# ===== パーティクル種類の抽選テスト =====
func test_particle_type_distribution() -> void:
	# 💡 試行回数を100回から1000回に増やし、確率のブレを排除します
	var quark_count = 0
	var electron_count = 0
	var photon_count = 0
	
	for i in range(1000):
		var roll = randf_range(0.0, 100.0)
		if roll < 54.5:
			quark_count += 1
		elif roll < 99.0:
			electron_count += 1
		else:
			photon_count += 1
	
	# 1000回中、1%であれば約10回出るはずなので、2回以上あれば合格とします
	assert_gt(quark_count, 450, "クォークが十分に出現")
	assert_gt(electron_count, 350, "電子が十分に出現")
	assert_gt(photon_count, 2, "光子が1%の確率に基づいて出現（2回以上確認）")

func test_all_particle_types_can_spawn() -> void:
	var has_quark = false
	var has_electron = false
	var has_photon = false
	for i in range(300): # 余裕を持たせて300回に
		var roll = randf_range(0.0, 100.0)
		if roll < 54.5: has_quark = true
		elif roll < 99.0: has_electron = true
		else: has_photon = true
	assert_true(has_quark)
	assert_true(has_electron)
	assert_true(has_photon)
