extends SceneTree

## Validates the ceiling-light rule across 30 seeds: ordinary small rooms get
## exactly one light on their center cell with the fixture footprint clear of
## every wall; large rectangle, irregular and courtyard rooms get zero.

const GENERATOR_SCRIPT := preload("res://scripts/dream/dream_3d_random_dungeon.gd")
const LIGHTING_SCRIPT := preload("res://scripts/dream/dream_3d_ceiling_lighting.gd")
const TEST_SEED_COUNT := 30
const FIRST_TEST_SEED := 41001
const FIXTURE_SIZE := Vector2(1.35, 0.46)
const WALL_CLEARANCE := 0.5


func _init() -> void:
	var failures: Array[String] = []
	var summaries: Array[String] = []
	var small_rooms := 0
	var large_rectangle_rooms := 0
	var irregular_rooms := 0
	var courtyard_rooms := 0
	var total_lights := 0
	var worst_clearance := INF
	var half_diagonals: Array[float] = []

	for index in range(TEST_SEED_COUNT):
		var test_seed := FIRST_TEST_SEED + index
		var generator: Node = GENERATOR_SCRIPT.new()
		generator.generate_on_ready = false
		generator.room_count = 12
		var light_root: Node3D = LIGHTING_SCRIPT.new()
		if not generator.generate_layout_only(test_seed):
			failures.append("seed %d: layout generation failed" % test_seed)
			light_root.free()
			generator.free()
			continue
		light_root.build_for_world(generator)

		var lights_per_room: Dictionary = {}
		for holder in light_root.get_children():
			var room_id := int(holder.get_meta("dream_room_id", -1))
			lights_per_room[room_id] = int(lights_per_room.get(room_id, 0)) + 1
			var cell := Vector2i(roundi(holder.position.x), roundi(holder.position.z))
			var room: Dictionary = generator.rooms[room_id]
			if bool(room.get("is_large", false)):
				failures.append("seed %d: large room %d has a ceiling light" % [test_seed, room_id])
			var shape: StringName = room.get("shape", &"rectangle")
			if shape != &"rectangle":
				failures.append("seed %d: %s room %d has a ceiling light" % [test_seed, shape, room_id])
			if cell != Vector2i(room.get("center_cell", Vector2i.ZERO)):
				failures.append("seed %d: room %d light cell %s is not the center cell %s" % [test_seed, room_id, cell, room.get("center_cell")])
			if not generator.floor_cells.has(cell) or int(generator.room_cells.get(cell, -1)) != room_id:
				failures.append("seed %d: room %d light cell is not its usable floor" % [test_seed, room_id])
			var rect: Rect2i = room.get("grid_rect")
			var clearance := _fixture_wall_clearance(cell, rect)
			worst_clearance = minf(worst_clearance, clearance)
			if clearance < 0.0:
				failures.append("seed %d: room %d light footprint violates wall clearance by %.2f" % [test_seed, room_id, clearance])
			half_diagonals.append(Vector2(rect.size).length() * 0.5)

		for room in generator.rooms:
			var room_id := int(room.get("id", -1))
			var expected := 0 if bool(room.get("is_large", false)) else 1
			if int(lights_per_room.get(room_id, 0)) != expected:
				failures.append("seed %d: room %d (%s large=%s) has %d lights, expected %d" % [
					test_seed, room_id, room.get("shape", &"rectangle"), room.get("is_large", false),
					int(lights_per_room.get(room_id, 0)), expected,
				])
			if bool(room.get("is_large", false)):
				var shape: StringName = room.get("shape", &"rectangle")
				if shape == &"courtyard":
					courtyard_rooms += 1
				elif shape == &"irregular":
					irregular_rooms += 1
				else:
					large_rectangle_rooms += 1
			else:
				small_rooms += 1
		total_lights += light_root.get_child_count()

		if index == 0:
			_check_fixture_visuals(light_root, test_seed, failures)
		summaries.append("seed=%d lights=%d" % [test_seed, light_root.get_child_count()])
		light_root.free()
		generator.free()

	for summary in summaries:
		print(summary)

	print("TYPE_TOTALS small=%d large_rectangle=%d irregular=%d courtyard=%d lights=%d" % [
		small_rooms, large_rectangle_rooms, irregular_rooms, courtyard_rooms, total_lights,
	])
	if small_rooms != total_lights:
		failures.append("light total %d does not match small room total %d" % [total_lights, small_rooms])
	var ceiling_y := float(GENERATOR_SCRIPT.TALL_WALL_HEIGHT) + LIGHTING_SCRIPT.CEILING_LIGHT_HEIGHT_OFFSET
	print("WORST_CLEARANCE_MARGIN=%.2f" % worst_clearance)
	half_diagonals.sort()
	var median_diagonal := half_diagonals[half_diagonals.size() / 2]
	var p90_diagonal := half_diagonals[mini(half_diagonals.size() - 1, int(ceil(half_diagonals.size() * 0.9)) - 1)]
	var max_diagonal := half_diagonals[half_diagonals.size() - 1]
	for entry: Array in [["median", median_diagonal], ["p90", p90_diagonal], ["max", max_diagonal]]:
		var slant := sqrt(entry[1] * entry[1] + ceiling_y * ceiling_y)
		var cone := rad_to_deg(atan(entry[1] / ceiling_y))
		print("COVERAGE %s half_diagonal=%.2f required_slant_range=%.2f required_cone_angle=%.1f" % [entry[0], entry[1], slant, cone])

	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return

	print("PASS: validated %d ceiling-light rule seeds." % TEST_SEED_COUNT)
	quit(0)


func _fixture_wall_clearance(cell: Vector2i, rect: Rect2i) -> float:
	var margin_x := FIXTURE_SIZE.x * 0.5 + WALL_CLEARANCE
	var margin_z := FIXTURE_SIZE.y * 0.5 + WALL_CLEARANCE
	return minf(
		float(cell.x - rect.position.x) + 0.5 - margin_x,
		minf(float(rect.end.x - cell.x) - 0.5 - margin_x,
			minf(float(cell.y - rect.position.y) + 0.5 - margin_z,
				float(rect.end.y - cell.y) - 0.5 - margin_z)))


func _check_fixture_visuals(light_root: Node3D, test_seed: int, failures: Array[String]) -> void:
	if light_root.get_child_count() == 0:
		failures.append("seed %d: no ceiling light built for the visual check" % test_seed)
		return
	var holder: Node = light_root.get_child(0)
	var fixture := holder.get_node_or_null("FixtureMesh") as MeshInstance3D
	if fixture == null:
		failures.append("seed %d: fixture mesh missing" % test_seed)
	else:
		var material := fixture.material_override as StandardMaterial3D
		if material == null:
			failures.append("seed %d: fixture has no StandardMaterial3D override" % test_seed)
		else:
			if not material.albedo_color.is_equal_approx(Color(0.0, 0.0, 0.0, 0.30)):
				failures.append("seed %d: fixture albedo %s is not black at 0.30 alpha" % [test_seed, material.albedo_color])
			if material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
				failures.append("seed %d: fixture transparency mode is not alpha blending" % test_seed)
			if material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				failures.append("seed %d: fixture is not unshaded" % test_seed)
			if material.emission_enabled:
				failures.append("seed %d: fixture still enables emission" % test_seed)
		if fixture.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			failures.append("seed %d: fixture still casts shadows" % test_seed)
	var lamp := holder.get_node_or_null("RoomLight") as SpotLight3D
	if lamp == null:
		failures.append("seed %d: room light is not a SpotLight3D" % test_seed)
	else:
		if not lamp.shadow_enabled:
			failures.append("seed %d: room light lost its shadows" % test_seed)
		if not is_equal_approx(lamp.light_energy, light_root.light_energy):
			failures.append("seed %d: room light energy does not match the lighting config" % test_seed)
