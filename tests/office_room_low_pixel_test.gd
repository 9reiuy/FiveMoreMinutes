extends SceneTree

const ART = preload("res://scripts/dream/office_room_low_pixel_art.gd")
const SAMPLE = preload("res://scripts/dream/office_sample_floor.gd")
const CATALOG = preload("res://scripts/dream/office_furniture_catalog.gd")
const WORLD = preload("res://scenes/dream/Dream3D_OfficeSample.tscn")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(ART.texture().get_size() == Vector2(128, 64))
	for room in ["conference", "manager", "archive", "server", "pantry", "restroom", "lounge", "reception"]:
		for spec in SAMPLE.furniture_specs(room):
			var kind := String(spec[0])
			assert(CATALOG.DEFINITIONS.has(kind), "Missing formal furniture kind: " + kind)
			assert(ART.supports(kind) or kind in ["chair", "workstation"], "Missing room art: " + kind)
			var visual: Node3D = ART.make_visual(kind)
			assert(visual != null and visual.get_child_count() >= 1)
			# Approved office chairs/desks retain their original multi-part meshes.
			if kind in ["chair", "workstation"]:
				visual.free()
				continue
			var mesh := visual.get_child(0) as MeshInstance3D
			assert(mesh != null and mesh.mesh != null)
			assert(mesh.mesh.get_aabb().size.x <= CATALOG.size_of(kind).x + .1)
			visual.free()
	for room in ["conference", "manager", "archive", "server", "pantry", "restroom", "lounge", "reception", "lift", "north", "south", "east", "west"]:
		var fixtures: Node3D = ART.room_fixtures(room, Vector2.ZERO)
		assert(fixtures != null and fixtures.get_child_count() > 0, "Missing fixed wall fixtures: " + room)
		fixtures.free()
	assert(ART.room_fixtures("office", Vector2.ZERO) == null)
	var preserved_office: Node3D = CATALOG.make_visual("workstation", true, true)
	assert(preserved_office.name == "LowPixelOfficeVisual_workstation")
	preserved_office.free()
	assert(SAMPLE.furniture_specs("lift").is_empty())
	assert(SAMPLE.enemy_specs("lift").is_empty())
	assert(SAMPLE.furniture_specs("lounge").filter(func(spec): return spec[0] == "coffee_table").size() == 1)
	# Exact authored combat lanes are measured from complete rotated footprints.
	assert(_between(SAMPLE.furniture_specs("server")[0], SAMPLE.furniture_specs("server")[1]) >= 3.0)
	assert(_between(SAMPLE.furniture_specs("archive")[0], SAMPLE.furniture_specs("archive")[1]) >= 3.0)
	assert(_between(SAMPLE.furniture_specs("reception")[0], SAMPLE.furniture_specs("reception")[3]) >= 3.0)
	var conference_table: Array = SAMPLE.furniture_specs("conference")[0]
	assert(float(conference_table[1]) - _half_width(conference_table) - .5 >= 2.0)
	assert(12.0 - .5 - float(conference_table[1]) - _half_width(conference_table) >= 2.0)
	var lounge_sofa: Array = SAMPLE.furniture_specs("lounge")[0]
	assert(float(lounge_sofa[1]) - _half_width(lounge_sofa) - .5 >= 3.0)
	var restroom_partition: Array = SAMPLE.furniture_specs("restroom")[0]
	assert(float(restroom_partition[1]) - _half_width(restroom_partition) - .5 >= 3.0)
	var world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	assert(world.regenerate(120))
	var fixture_baseline := -1
	for room in world.rooms:
		var key := String(room.get("sample_key", ""))
		if key not in ["conference", "manager", "archive", "server", "pantry", "restroom", "lounge", "reception"]:
			continue
		world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
		world.activate_room(room.id)
		await process_frame
		await process_frame
		var live_fixture_count := 0
		var current_fixture_present := false
		for floor_node in world.floor_root.get_children():
			if String(floor_node.name).begins_with("RoomLowPixelFixtures_"):
				live_fixture_count += 1
				current_fixture_present = current_fixture_present or String(floor_node.name) == "RoomLowPixelFixtures_" + key
		if fixture_baseline < 0:
			fixture_baseline = live_fixture_count
		assert(live_fixture_count == fixture_baseline and current_fixture_present, "Stale or duplicate room fixtures: " + key)
		var count := 0
		for node in world.actor_depth_bridges_root.get_children():
			if int(node.get_meta(&"dream_room_id", -1)) != int(room.id) or not node is Furniture3DVisual:
				continue
			var furniture_visual := node as Furniture3DVisual
			assert(furniture_visual.visual_instance.name.begins_with("RoomLowPixel_") or furniture_visual.visual_instance.name.begins_with("LowPixelOfficeVisual_"), "Wrong visual path: " + key)
			count += 1
		assert(count == SAMPLE.furniture_specs(key).size(), "Missing authored furniture in " + key)
	world.queue_free()
	await process_frame
	print("OFFICE ROOM LOW PIXEL PASS")
	quit(0)

func _half_width(spec: Array) -> float:
	var size: Vector3 = CATALOG.size_of(String(spec[0]))
	var angle := deg_to_rad(float(spec[3]))
	return absf(cos(angle)) * size.x * .5 + absf(sin(angle)) * size.z * .5

func _between(left: Array, right: Array) -> float:
	return float(right[1]) - _half_width(right) - float(left[1]) - _half_width(left)
