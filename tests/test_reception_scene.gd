extends SceneTree

const RECEPTION_SCENE := preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures.append(label)
		printerr("FAIL: ", label)


func _run() -> void:
	print("--- Starting Reception Scene Test ---")
	
	var room: Node3D = RECEPTION_SCENE.instantiate()
	_check(room != null, "Reception Room instantiates cleanly")
	root.add_child(room)
	
	await process_frame
	await process_frame
	
	# 1. Floor verification
	var expected_floors := 14*8 + 3*3
	_check(room.floor_cells.size()==expected_floors,"Compact lobby and right vestibule occupy 121 cells")
	for cell in [Vector2i(0,0),Vector2i(13,7),Vector2i(14,3),Vector2i(16,5)]:
		_check(room.floor_cells.has(cell),"Expected floor at "+str(cell))
	for cell in [Vector2i(0,8),Vector2i(14,2),Vector2i(17,4)]:
		_check(not room.floor_cells.has(cell),"No floor outside compact perimeter at "+str(cell))
	
	# 2. Player spawn verification
	var expected_player_pos: Vector2 = room.PLAYER_SPAWN
	_check(room.player != null, "Player exists")
	_check(room.player.global_position.distance_to(expected_player_pos) < 0.1, "Player spawns in the right vestibule")
	_check(bool(room.player.get("movement_enabled")) == true, "Player movement is enabled")
	_check(bool(room.player.get("attacking_enabled")) == false, "Player attacking is disabled (safe lobby)")
	_check(bool(room.player.get("dash_enabled")) == true, "Player dash is enabled")
	
	# 3. Elevator verification
	_check(room.elevator_floor_door != null, "ElevatorFloorDoor3D exists")
	_check(room.elevator_floor_door.position.distance_to(Vector3(1.5, 0.0, -0.5)) < 0.01, "Elevator position is Vector3(1.5, 0.0, -0.5)")
	_check(room.elevator_floor_door.door_orientation == ElevatorFloorDoor3D.Orientation.UP, "Elevator orientation is UP")
	
	# 4. Reception Desk & Waitress verification
	_check(room.reception_desk != null, "Reception desk exists")
	_check(room.reception_desk.position.distance_to(Vector3(8.0, 0.0, 2.8)) < 0.01, "Reception desk position is Vector3(8.0, 0.0, 2.8)")
	_check(room.waitress_npc != null, "Waitress NPC exists")
	var expected_npc_pos := Vector2(8.0, 1.8) * 32.0
	_check(room.waitress_npc.global_position.distance_to(expected_npc_pos) < 0.1, "Waitress NPC position is at Vector2(8.0, 1.8)*32.0")
	
	# 5. Walls & cutaways verification
	var cutaway_walls := 0
	for wall in room.wall_root.get_children():
		if wall.get("cutaway_mode") == true:
			cutaway_walls += 1
	_check(cutaway_walls > 0, "Cutaway walls present on South perimeter (%d cutaway segments)" % cutaway_walls)
	
	# 6. 2D Wall Collisions
	var colliders: Array[Node] = room.collision_root.get_children()
	_check(colliders.size() >= 8, "Perimeter and desk 2D collisions created (%d colliders)" % colliders.size())
	for col in colliders:
		if col is StaticBody2D:
			_check(col.collision_layer == 4, "Collision body %s is on WORLD_WALL_LAYER (4)" % col.name)
	
	var desk_col := room.collision_root.get_node_or_null("ReceptionDeskCollider2D") as StaticBody2D
	_check(desk_col != null, "ReceptionDeskCollider2D exists in collision root")
	if desk_col != null:
		var desk_shape_node := desk_col.get_node_or_null("CollisionShape2D") as CollisionShape2D
		_check(desk_shape_node != null and desk_shape_node.shape is RectangleShape2D, "Desk collision shape is RectangleShape2D")
		if desk_shape_node != null and desk_shape_node.shape is RectangleShape2D:
			var rect: RectangleShape2D = desk_shape_node.shape as RectangleShape2D
			var expected_desk_size := Vector2(3.4 * 32.0, 1.1 * 32.0)
			_check(rect.size.distance_to(expected_desk_size) < 0.1, "Desk collision size matches updated ~108.8x35.2 bounds (got %s, expected %s)" % [rect.size, expected_desk_size])
	
	# 7. Elevator Approach Trigger & Prompt
	room.player.global_position=room.elevator_floor_door.get_corridor_approach_position_2d()
	await physics_frame; await process_frame
	room._on_elevator_approach_entered(room.player)
	room._update_interaction_prompt()
	_check(room.interaction_prompt.visible == true, "Interaction prompt is visible on elevator approach")
	_check(room.interaction_prompt.text == "进入", "Interaction prompt text is '进入'")
	
	room.player.global_position=room.PLAYER_SPAWN
	await physics_frame; await process_frame
	room._on_elevator_approach_exited(room.player)
	room._update_interaction_prompt()
	await create_timer(0.12).timeout
	_check(room.interaction_prompt.visible == false, "Interaction prompt hides when leaving elevator approach")
	
	# 8. Elevator Sequence and Signal
	var tracker := {"received": false}
	room.elevator_entered.connect(func(): tracker["received"] = true)
	room.player.global_position=room.elevator_floor_door.get_corridor_approach_position_2d()
	await physics_frame; await process_frame
	room._start_elevator_entry()
	
	# Wait for elevator sequence to finish (open, walk, close, fade)
	var wait_time := 0.0
	while not tracker["received"] and wait_time < 12.0:
		await create_timer(0.1).timeout
		wait_time += 0.1
		
	_check(tracker["received"], "elevator_entered signal emitted after sequence")
	
	print("--- Reception Scene Test Completed ---")
	if failures.is_empty():
		print("ALL TESTS PASSED!")
		quit(0)
	else:
		printerr("TESTS FAILED: ", failures)
		quit(1)
