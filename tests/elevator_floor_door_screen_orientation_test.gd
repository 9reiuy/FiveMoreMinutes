extends SceneTree

const FLOOR_DOOR := preload("res://scripts/dream/elevator_floor_door_3d.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)
	else:
		print("PASS: ", message)


func _run() -> void:
	var map_root := Node3D.new()
	map_root.rotation.y = -PI * 0.25
	root.add_child(map_root)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.global_rotation.y = 0.0
	var collision_root := Node2D.new()
	root.add_child(collision_root)
	var trigger_root := Node2D.new()
	root.add_child(trigger_root)

	for orientation in [FLOOR_DOOR.Orientation.UP, FLOOR_DOOR.Orientation.DOWN]:
		var door := FLOOR_DOOR.new(orientation, 1)
		map_root.add_child(door)
		var inward := Vector2.RIGHT if orientation == FLOOR_DOOR.Orientation.UP else Vector2.LEFT
		var opening_width := 2.0 if orientation == FLOOR_DOOR.Orientation.UP else 4.0
		door.configure_opening(opening_width, 0.5)
		door.configure_entrance(inward, camera)
		door.setup_gameplay_2d(collision_root, trigger_root, Vector2(160, 96))
		var leaf_box := door.left_door_mesh.mesh as BoxMesh
		var opening_collider := door.door_shape_2d.shape as RectangleShape2D
		_check(is_equal_approx(leaf_box.size.x, opening_width * 0.5 + 0.02),
			"Sliding leaves match %s-cell opening" % opening_width)
		_check(is_equal_approx(opening_collider.size.x, opening_width * door.CELL_PIXELS + 8.0),
			"Door collision matches %s-cell opening" % opening_width)
		var wall_outward := (map_root.global_basis * Vector3(-inward.x, 0.0, -inward.y)).normalized()
		_check(door.global_basis.z.normalized().dot(wall_outward) > 0.999,
			"Facade lies in the rotated doorway wall for %s" % orientation)
		var backing := door.frame_root.get_node(^"ShaftBacking") as Node3D
		_check(backing.position.z < 0.0,
			"Opaque shaft stays behind visible leaves for %s" % orientation)
		_check(door.get_inward_2d().is_equal_approx(inward), "Explicit map doorway direction for %s" % orientation)
		_check(door.get_doorway_threshold_position_2d().is_equal_approx(Vector2(160, 96) + inward * 25.6),
			"Threshold follows map doorway for %s" % orientation)
		_check(door.get_corridor_approach_position_2d().is_equal_approx(Vector2(160, 96) - inward * 48.0),
			"Landing follows map doorway for %s" % orientation)
		_check(absf(absf(wrapf(door.door_collider_2d.rotation, -PI, PI)) - PI * 0.5) < 0.001,
			"Collider rotates with east/west map opening for %s" % orientation)
		_check(door.approach_trigger_2d.position.is_equal_approx(Vector2(160, 96) - inward * 41.6),
			"Approach trigger follows crossing direction for %s" % orientation)
		_check(door.approach_trigger_2d.rotation == door.door_collider_2d.rotation,
			"Trigger and collider share orientation for %s" % orientation)
		var shaft := door.frame_root.get_node("ShaftBacking") as MeshInstance3D
		_check(shaft.mesh is QuadMesh and absf(shaft.position.z) <= door.WALL_THICKNESS
			and (shaft.material_override as StandardMaterial3D).cull_mode == BaseMaterial3D.CULL_BACK,
			"One-sided recessed shaft backing cannot hide reverse door face for %s" % orientation)
		_check(door.get_node_or_null("Cab") == null, "No in-floor cab for %s" % orientation)
		await door.open_doors(0.01)
		await physics_frame
		_check(door.doors_open and door.door_collider_2d.collision_layer == 0,
			"Open facade and gameplay collision agree for %s" % orientation)
		_check(door.left_door_mesh.position.x < -opening_width * 0.5 and door.right_door_mesh.position.x > opening_width * 0.5,
			"Both leaves slide apart for %s" % orientation)
		await door.close_doors(0.01)
		await physics_frame
		_check(not door.doors_open and door.door_collider_2d.collision_layer == door.WORLD_WALL_LAYER,
			"Closed facade and gameplay collision agree for %s" % orientation)
		door.free()

	# The wall, not the camera, owns the facade yaw. Check the other wall axis too.
	camera.global_rotation.y = deg_to_rad(30.0)
	var angled_door := FLOOR_DOOR.new(FLOOR_DOOR.Orientation.UP, 0)
	map_root.add_child(angled_door)
	angled_door.configure_entrance(Vector2.UP, camera)
	var north_wall_outward := (map_root.global_basis * Vector3.BACK).normalized()
	_check(angled_door.global_basis.z.normalized().dot(north_wall_outward) > 0.999,
		"Facade aligns with north/south wall despite camera heading")
	map_root.rotation.y += deg_to_rad(12.0)
	north_wall_outward = (map_root.global_basis * Vector3.BACK).normalized()
	_check(angled_door.global_basis.z.normalized().dot(north_wall_outward) > 0.999,
		"Facade continues following the wall when map rotation changes")
	angled_door.free()
	map_root.free()
	camera.free()
	collision_root.free()
	trigger_root.free()
	print("Elevator floor door wall alignment: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
