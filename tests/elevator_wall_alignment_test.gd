extends SceneTree

const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	if value:
		print("PASS: ", label)
	else:
		failures.append(label)
		printerr("FAIL: ", label)


func _run() -> void:
	var world = WORLD.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	_check(world.regenerate(41001), "Authored office floor generates")
	var door_edge: Dictionary = world._elevator_sliding_door_edge()
	_check(not door_edge.is_empty(), "Elevator doorway has an authoritative wall edge")
	var floor_door = world.elevator_floor_door
	_check(floor_door != null, "Floor door exists without an in-floor cab")
	if not door_edge.is_empty() and floor_door != null:
		var axis := String(door_edge.get("axis", ""))
		var tangent_local := Vector3.RIGHT if axis == "H" else Vector3.BACK
		var tangent_world: Vector3 = (world.global_basis * tangent_local).normalized()
		_check(absf(floor_door.global_basis.x.normalized().dot(tangent_world)) > 0.999,
			"Door leaves are parallel to the rotated wall opening")
		var expected_centre: Vector3 = world.to_global(world._door_root_world_position(door_edge))
		_check(floor_door.global_position.distance_to(expected_centre) < 0.001,
			"Door centre matches the wall opening centre")
		var expected_width: float = world._door_width_for_edge(door_edge)
		var backing := floor_door.frame_root.get_node_or_null("ShaftBacking") as MeshInstance3D
		_check(backing != null and absf((backing.mesh as QuadMesh).size.x - expected_width) < 0.1,
			"Door backing follows the generated opening width")
		var visible_jambs := 0
		var other_elevator_walls := 0
		for wall in world.wall_root.get_children():
			if not wall.has_meta(&"edge"):
				continue
			var edge: Dictionary = wall.get_meta(&"edge")
			if not world._edge_touches_elevator(edge):
				continue
			if world._edge_on_elevator_door_wall(edge):
				visible_jambs += 1
				_check(absf(wall.global_basis.x.normalized().dot(tangent_world)) > 0.999,
					"Visible jamb follows door wall axis")
				_check(absf((wall.global_position - floor_door.global_position).dot(floor_door.global_basis.z)) < 0.001,
					"Visible jamb and elevator door share a wall plane")
			else:
				other_elevator_walls += 1
		_check(visible_jambs >= 2, "Both sides of the doorway have visible wall")
		if world._has_elevator_reception():
			_check(other_elevator_walls > 0, "Formal reception retains its real room perimeter walls")
		else:
			_check(other_elevator_walls == 0, "Bare elevator facade has no additional enclosure walls")
		_check(floor_door.get_node_or_null("Cab") == null, "Cab remains an isolated transition scene")
	world.queue_free()
	await process_frame
	print("Elevator wall alignment: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
