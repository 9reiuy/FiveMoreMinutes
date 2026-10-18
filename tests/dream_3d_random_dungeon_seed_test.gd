extends SceneTree

const GENERATOR_SCRIPT := preload("res://scripts/dream/dream_3d_random_dungeon.gd")
const TEST_SEED_COUNT := 20
const FIRST_TEST_SEED := 41001


func _init() -> void:
	var failures: Array[String] = []
	var summaries: Array[String] = []

	for index in range(TEST_SEED_COUNT):
		var test_seed := FIRST_TEST_SEED + index
		var generator: Node = GENERATOR_SCRIPT.new()
		generator.generate_on_ready = false
		generator.room_count = 12
		var generated: bool = generator.generate_layout_only(test_seed)
		var report: Dictionary = generator.get_validation_report()
		var first_signature: String = generator.get_layout_signature()
		var repeated: bool = generator.generate_layout_only(test_seed)
		var repeated_signature: String = generator.get_layout_signature()

		if not generated or not bool(report.get("valid", false)):
			failures.append("seed %d: %s" % [test_seed, report])
		elif not bool(report.get("main_entrance_valid", false)) or not bool(report.get("door_sides_valid", false)) or not bool(report.get("door_topology_valid", false)):
			failures.append("seed %d has invalid entrance/door sides: %s" % [test_seed, report])
		elif int(report.get("main_door_count", -1)) != 0 or not bool(report.get("start_outer_wall_sealed", false)):
			failures.append("seed %d still exposes a Start outer door: %s" % [test_seed, report])
		elif int(report.get("shared_door_violations", 1)) != 0 or int(report.get("multi_region_doors", 1)) != 0 or int(report.get("duplicate_region_pairs", 1)) != 0 or int(report.get("invalid_door_boundary_lengths", 1)) != 0 or int(report.get("door_swing_clearance_failures", 1)) != 0 or int(report.get("door_corner_clearance_failures", 1)) != 0 or int(report.get("door_to_door_clearance_failures", 1)) != 0:
			failures.append("seed %d has invalid Door topology: %s" % [test_seed, report])
		elif not repeated or first_signature != repeated_signature:
			failures.append("seed %d is not deterministic" % test_seed)
		else:
			summaries.append(
				"seed=%d rooms=%d edges=%d loops=%d floor=%d start=%d boss=%d distance=%.1f"
				% [
					test_seed,
					report["room_count"],
					report["connection_count"],
					report["loop_count"],
					report["floor_count"],
					report["spawn_room_id"],
					report["boss_room_id"],
					report["boss_distance"],
				]
			)

		generator.free()

	for summary in summaries:
		print(summary)

	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return

	print("PASS: validated %d deterministic building-layout seeds." % TEST_SEED_COUNT)
	quit(0)
