extends SceneTree
const SAMPLE = preload("res://scripts/dream/office_sample_floor.gd")
const WORLD = preload("res://scenes/dream/Dream3D_OfficeSample.tscn")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 120
	var data := SAMPLE.generate(rng)
	check(not data.is_empty(), "sample generated")
	if data.is_empty():
		quit(1)
		return
	check(data.rooms.size() == 14, "ten rooms and four hall sections")
	for room in data.rooms:
		if room.sample_key == "restroom":
			check(room.connections.size() == 1, "restroom only one entrance")
	var world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	check(world.regenerate(120), "world accepts sample")
	check(is_equal_approx(world.wall_thickness, world._cell_world_size() * 0.5), "wall depth is half floor tile")
	for body in world.collision_root.get_children():
		if body.has_meta(&"generated_wall_edge"):
			var shape: RectangleShape2D = body.get_child(0).shape
			check(shape.size == Vector2(32, 16) or shape.size == Vector2(16, 32), "wall physics matches half-tile visual")
	var office_walls := 0
	for wall_node in world.wall_root.get_children():
		var edge: Dictionary = wall_node.get_meta(&"edge", {})
		if world._is_interior_open_office_edge(edge):
			office_walls += 1
	check(office_walls == 0, "open office has zero interior walls")
	for room in world.rooms:
		if not room.has("sample_key"):
			check(false, "runtime entry does not load the authored sample floor")
			break
		if room.archetype in ["corridor", "elevator_lobby"]:
			continue
		world.activate_room(room.id)
		var count := 0
		for prop in world.furniture_root.get_children():
			if int(prop.get_meta(&"dream_room_id", -1)) == int(room.id):
				count += 1
		check(count == SAMPLE.furniture_specs(room.sample_key).size(), "complete authored furniture " + room.sample_key + " actual=" + str(count))
	world.queue_free()
	await process_frame
	print("SAMPLE failures=", failures)
	quit(1 if failures else 0)
