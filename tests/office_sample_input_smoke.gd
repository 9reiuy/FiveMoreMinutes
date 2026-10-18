extends SceneTree

# Drives the production Player input path from the fixed-seed elevator spawn.
# This is input-level smoke coverage, not a substitute for a human playthrough.
const WORLD = preload("res://scenes/dream/Dream3D_OfficeSample.tscn")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.elevator_transition_animated = false
	root.add_child(world)
	if not world.regenerate(120):
		quit(1)
		return
	for frame in 4:
		await physics_frame
	var start: Vector2 = world.player.global_position
	var outward: Vector2 = -world.elevator_cab_inward_2d
	var action := "move_up"
	if absf(outward.x) > absf(outward.y):
		action = "move_right" if outward.x > 0 else "move_left"
	else:
		action = "move_down" if outward.y > 0 else "move_up"
	Input.action_press(action)
	for frame in 90:
		await physics_frame
		if frame in [14, 29, 44, 59, 74, 89]:
			print("SAMPLE STEP ", frame, " pos=", world.player.global_position, " left=", world.player_has_left_elevator_cab, " room=", world.current_room_id, " approach_overlap=", world.elevator_approach_trigger.get_overlapping_bodies().size(), " cab_overlap=", world.elevator_trigger.get_overlapping_bodies().size())
	Input.action_release(action)
	var end: Vector2 = world.player.global_position
	print("SAMPLE INPUT start=", start, " end=", end, " outward=", outward, " door=", world.elevator_door_pos_2d, " left_cab=", world.player_has_left_elevator_cab)
	var passed: bool = (end - start).dot(outward) >= world.CELL_PIXELS * 1.5 and world.player_has_left_elevator_cab
	# Grant a badge here only to isolate the return traversal; carrier death and
	# physical pickup have separate coverage. The player must still walk back.
	world.collect_employee_badge()
	var return_action := "move_down" if action == "move_up" else ("move_up" if action == "move_down" else ("move_left" if action == "move_right" else "move_right"))
	Input.action_press(return_action)
	for frame in 135:
		await physics_frame
		if world.floor_index > 0:
			break
	Input.action_release(return_action)
	print("SAMPLE RETURN floor=", world.floor_index, " badge=", world.has_floor_badge, " position=", world.player.global_position)
	passed = passed and world.floor_index == 1 and not world.has_floor_badge
	world.queue_free()
	await process_frame
	quit(0 if passed else 1)
