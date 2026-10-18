extends SceneTree

const WORLD_SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const SAMPLE := preload("res://scripts/dream/office_sample_floor.gd")

var failures := 0
var log_lines: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: " + message)
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	log_lines.append("--- Running Wall, Door & Open Office Verification Test ---")
	
	# 1. Verify Cap Shaders
	var cap_shader: Shader = load("res://shaders/dream3d/architecture_cap.gdshader")
	check(cap_shader != null, "architecture_cap.gdshader exists")
	check(cap_shader.code.contains("ALBEDO = vec3(0.0, 0.0, 0.0);"), "architecture_cap outputs solid black")
	
	var slice_shader: Shader = load("res://shaders/dream3d/architecture_slice_cap.gdshader")
	check(slice_shader != null, "architecture_slice_cap.gdshader exists")
	check(slice_shader.code.contains("ALBEDO = vec3(0.0, 0.0, 0.0);"), "architecture_slice_cap outputs solid black")
	
	# 2. Instantiate World
	var world = WORLD_SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	check(world.regenerate(120), "World regenerated successfully")
	
	# 3. Check Wall Thickness
	check(is_equal_approx(world.wall_thickness, 0.5), "World wall_thickness is 0.5")
	
	# 4. Check Wall Collisions
	var wall_collision_count := 0
	for body in world.collision_root.get_children():
		if body.has_meta(&"generated_wall_edge"):
			wall_collision_count += 1
			var shape: RectangleShape2D = body.get_child(0).shape
			check(shape.size == Vector2(32, 16) or shape.size == Vector2(16, 32), "Wall collider thickness is 16px (0.5m)")
	check(wall_collision_count > 0, "Found %d wall colliders" % wall_collision_count)
	
	# 5. Check Door Properties
	var door_count := 0
	for door in world.door_root.get_children():
		door_count += 1
		check(is_equal_approx(door.wall_thickness, 0.25), "Door wall_thickness is 0.25m")
		check(is_equal_approx(door.door_mass, 1.0), "Door mass is 1.0 (lightweight)")
		check(is_equal_approx(door.door_angular_damping, 0.25), "Door angular damping is 0.25 (easy swing)")
		
		# Test player push perpendicular to door face
		var push_dir: Vector3 = door.global_basis.z
		var contact: Vector3 = door.global_position + door.global_basis.x * 0.5 + Vector3(0, 1.5, 0)
		var push_success: bool = door.apply_door_impact(&"player_push", contact, push_dir, 260.0)
		check(push_success, "Door accepts player_push")
		
		# Test enemy push perpendicular to door face
		var enemy_push_success: bool = door.apply_door_impact(&"enemy_push", contact, -push_dir, 220.0)
		check(enemy_push_success, "Door accepts enemy_push")
	check(door_count > 0, "Found %d doors" % door_count)
	
	# 6. Check Open Office perimeter has ZERO walls, colliders, and frames
	var office_walls := 0
	for wall_node in world.wall_root.get_children():
		var edge: Dictionary = wall_node.get_meta(&"edge", {})
		if world._is_interior_open_office_edge(edge):
			office_walls += 1
	check(office_walls == 0, "Open office has 0 3D walls (actual: %d)" % office_walls)
	
	var office_colliders := 0
	for body in world.collision_root.get_children():
		if body.has_meta(&"generated_wall_edge"):
			var key: String = String(body.get_meta(&"generated_wall_edge"))
			var edge: Dictionary = world.wall_edges.get(key, {})
			if edge.is_empty():
				continue
			if world._is_interior_open_office_edge(edge):
				office_colliders += 1
	check(office_colliders == 0, "Open office has 0 2D wall colliders (actual: %d)" % office_colliders)
	
	var office_frames := 0
	for frame in world.floor_root.get_children():
		if frame.name.begins_with("OfficeOpeningFrame"):
			var edge: Dictionary = frame.get_meta(&"door_edge", {})
			for k in ["region_a_id", "region_b_id"]:
				var rid: int = int(edge.get(k, -1))
				if rid >= 0 and rid < world.rooms.size() and String(world.rooms[rid].get("sample_key", "")) == "office":
					office_frames += 1
	check(office_frames == 0, "Open office has 0 opening frames (actual: %d)" % office_frames)
	
	world.queue_free()
	await process_frame
	log_lines.append("--- TEST SUMMARY: %d FAILURES ---" % failures)
	var f := FileAccess.open("e:/Agent/5MinuteMore/5min more/test_results.txt", FileAccess.WRITE)
	if f != null:
		for line in log_lines:
			f.store_line(line)
		f.close()
	quit(1 if failures > 0 else 0)
