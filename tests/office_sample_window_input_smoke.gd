extends SceneTree

const WORLD = preload("res://scenes/dream/Dream3D_OfficeSample.tscn")

func _initialize() -> void:
	call_deferred("run")

func send_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	var world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	if not world.regenerate(120):
		quit(1)
		return
	for frame in 4:
		await physics_frame
	Input.action_press("move_up")
	for frame in 145:
		await physics_frame
	Input.action_release("move_up")
	var before: Vector2 = world.player.global_position
	var windows := get_nodes_in_group(&"breakable_glass_windows")
	var preview: Dictionary = world.player.resolve_dash_path(Vector2.UP)
	print("SAMPLE WINDOW APPROACH position=", before, " room=", world.current_room_id, " windows=", windows.size(), " dash_enabled=", world.player.dash_enabled, " path=", preview)
	Input.action_press("move_up")
	send_action(&"dash", true)
	for frame in 2:
		await physics_frame
	print("SAMPLE DASH PENDING state=", world.player.dash_input_state, " can=", world.player.can_start_dash_aim(), " elapsed=", world.player._dash_pending_elapsed_seconds(), " move=", world.player.movement_enabled, " punch=", world.player.punch_active)
	send_action(&"dash", false)
	for frame in 2:
		await physics_frame
	print("SAMPLE DASH RELEASE state=", world.player.dash_input_state, " dashing=", world.player.dashing, " charges=", world.player.dash_charges, " position=", world.player.global_position)
	Input.action_release("move_up")
	for frame in 180:
		await physics_frame
		if not world.player.dashing and world.player.dash_input_state == 0:
			break
	var shattered := 0
	for window in windows:
		if is_instance_valid(window) and window.is_shattered:
			shattered += 1
	print("SAMPLE WINDOW DASH after=", world.player.global_position, " shattered=", shattered, " vault=", world.player.vault_active, " room=", world.current_room_id, " preview_delta=", world.player.global_position.distance_to(preview.get("end", before)))
	var passed: bool = world.player.global_position.y < before.y - world.CELL_PIXELS and shattered > 0
	world.queue_free()
	await process_frame
	quit(0 if passed else 1)
