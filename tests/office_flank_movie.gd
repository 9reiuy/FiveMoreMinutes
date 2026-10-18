extends SceneTree
var shots := 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for frame in count:
		await process_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	var world = load("res://scenes/dream/preview/OfficeFlankPreview.tscn").instantiate()
	root.add_child(world)
	world.player.invulnerability_left = 10000
	world.player.weapon_fired.connect(func(_multiplier: float) -> void: shots += 1)
	await frames(240)
	Input.action_press("move_right")
	await frames(45)
	Input.action_release("move_right")
	await frames(30)
	# The second segment is an explicit test fixture placement in the office,
	# not evidence of a complete player-driven route from the lift.
	for room in world.rooms:
		if String(room.archetype) != "open_office":
			continue
		for cell in room.usable_cells:
			var point := Vector2(cell) * 32
			if world._content_position_is_clear(point, 12, true):
				world.player.global_position = point
				break
		break
	await frames(90)
	world.night_lighting.set_flashlight_enabled(false)
	root.warp_mouse(Vector2(900, 300))
	world.player.set_meta(&"force_weapon_attack", true)
	Input.action_press("move_down")
	await frames(60)
	Input.action_release("move_down")
	world.player.set_meta(&"force_weapon_attack", false)
	await frames(120)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/flank_preview/gameplay.png")
	print("FLANK MOVIE shots=", shots, " enemies=", world.enemy_root.get_child_count(), " transition=", world.transition_phase)
	world.queue_free()
	await frames(4)
	quit(0 if shots > 0 else 1)
