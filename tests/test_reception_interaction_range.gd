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
	root.size=Vector2i(640,360)
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	print("--- Starting Reception Interaction Range Test ---")

	var room: Dream3DReceptionRoom = RECEPTION_SCENE.instantiate() as Dream3DReceptionRoom
	_check(room != null, "Reception Room instantiates cleanly")
	root.add_child(room)

	# Let 10 frames process as requested
	for i in range(10):
		await process_frame

	var player = room.player
	var waitress = room.waitress_npc
	var resolver = room.interaction_resolver

	_check(player != null, "Player exists")
	_check(waitress != null, "Waitress NPC exists")
	_check(resolver != null, "Interaction resolver exists")

	# Test player positions around the desk
	var test_positions: Array[Dictionary] = [
		{"name": "Desk front center", "pos": Vector2(16.0, 4.65) * 32.0},
		{"name": "Desk front left", "pos": Vector2(14.5, 4.65) * 32.0},
		{"name": "Desk front right", "pos": Vector2(17.5, 4.65) * 32.0},
		{"name": "Stepped back slightly", "pos": Vector2(16.0, 5.3) * 32.0},
	]

	for entry in test_positions:
		var pos_name: String = entry["name"]
		var pos: Vector2 = entry["pos"]

		player.global_position = pos
		room._update_camera_and_projection(0.0)
		var target = resolver.update_target()
		_check(resolver.current_target == waitress, "%s: current_target is waitress_npc" % pos_name)
		_check(target == waitress, "%s: update_target() returned waitress_npc" % pos_name)

		room._update_interaction_prompt()
		_check(room.npc_hint_bubble.visible and room.interaction_prompt.visible, "%s: emotion and talk prompt are visible" % pos_name)
		_check(room.interaction_prompt.text=="交流", "%s: passive NPC exposes short talk action" % pos_name)
		_check(room.interaction_prompt.anchor.y+room.interaction_prompt.size.y<room.npc_hint_bubble.position.y,
			"Talk action sits above emotion bubble")

	# Test far away position (entrance)
	var far_pos := Vector2(12.5, 18.5) * 32.0
	player.global_position = far_pos
	var far_target = resolver.update_target()
	_check(far_target == null, "Entrance far away: update_target() returns null")
	_check(resolver.current_target == null, "Entrance far away: current_target is null")

	room._update_interaction_prompt()
	await create_timer(0.22).timeout
	_check(not room.interaction_prompt.visible and not room.npc_hint_bubble.visible, "Entrance far away: both proximity widgets are hidden")

	print("--- Reception Interaction Range Test Completed ---")
	if failures.is_empty():
		print("ALL TESTS PASSED!")
		quit(0)
	else:
		printerr("TESTS FAILED: ", failures)
		quit(1)
