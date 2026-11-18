extends "res://tests/forklift_driving_test.gd"
## Matched healthy/smoking loads in the independent whitebox and production-art lab.


func run_lab() -> void:
	lab = load(LAB).instantiate()
	root.add_child(lab)
	current_scene = lab
	for i in 1200:
		await process_frame
		if lab.ready_world:
			break
	check(lab.ready_world, "independent health lab loads")
	verify_audio()
	lab.checks.furniture.button_pressed = false
	lab.checks.ai.button_pressed = false
	lab.enemies.value = 0
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for mode in [0, 1]:
		lab.mode.select(mode)
		await lab.rebuild()
		verify_audio()
		lab.panel.hide()
		lab.set_process(false)
		world = lab.world
		var label := "whitebox" if mode == 0 else "production-art"
		var at := Vector2(7.0, 19.0)
		var model := MODEL.new()
		model.position = Vector3(at.x, 0.0, at.y)
		world.add_child(model)
		lift = VEHICLE.new()
		lift.configure(world, model)
		lift.floor_support = func(p: Vector2) -> bool: return Rect2(0.5, 14.5, 13.0, 9.0).has_point(p)
		world.collision_root.add_child(lift)
		lift.set_active(true)
		place_feet(at + Vector2(-0.13, 1.20))
		await frames(4)
		check(lift.board(world.player) and lift.hp == 300.0, label + " new vehicle boards at 300 HP")
		if mode == 1:
			for index in 4:
				park(at, index * PI * 0.5)
				await frames(20)
				check(world.player_depth_bridge.is_visible_in_tree()
					and model.body_mesh_instance.get_active_material(0) is StandardMaterial3D,
					"opaque roof and visible driver carrier at heading %d" % index)
				await capture("driver-heading-%d" % index)
		park(at)
		await frames(30)
		await sample(label + "-healthy-parked")
		await sample(label + "-healthy-driving", true)
		park(at)
		lift.take_damage(209.0)
		check(lift.hp == 91.0 and not lift.smoking, label + " 91 HP has no smoke")
		lift.take_damage(1.0)
		await frames(60)
		check(lift.hp == 90.0 and lift.smoking and not lift.damage_effects.effects.particles.is_empty(),
			label + " 90 HP uses the shared smoke pool")
		await capture(label + "-smoking")
		await sample(label + "-smoking-parked")
		await sample(label + "-smoking-driving", true)
		park(at)
		world.player.invulnerability_left = 30.0
		seed(1101602)
		for enemy_at: Vector2 in [at + Vector2(5.0, -2.0), at + Vector2(7.0, -3.0)]:
			world._spawn_regular_employee(0, enemy_at * 32.0, &"employee", false, "assault_rifle")
		await sample(label + "-smoking-driving-with-two-rifle-enemies", true)
		var serial_before: int = lift.damage_effects.effects.explosion.serial
		process_frame.connect(func() -> void: lift.take_damage(999.0), CONNECT_ONE_SHOT)
		await sample(label + "-first-explosion-with-two-rifle-enemies")
		check(lift.destroyed and lift.hp == 0.0 and lift.collision_layer == 0,
			label + " lethal damage destroys the vehicle")
		check(lift.damage_effects.effects.explosion.serial == serial_before + 1,
			label + " one existing CC0 explosion plays")
		check(lift.driver == null and world.player.mounted_vehicle == null and world.player.movement_enabled
			and world.player_depth_bridge.is_visible_in_tree(), label + " destruction restores on-foot control and pose")
		check(not lift.can_board(world.player), label + " destroyed vehicle cannot be reused")
		var old_lift: WeakRef = weakref(lift)
		var old_model: WeakRef = weakref(model)
		await lab.rebuild()
		verify_audio()
		check(not is_instance_valid(old_lift.get_ref()) and not is_instance_valid(old_model.get_ref()),
			label + " reset frees damaged physics and visuals")
	lab.queue_free()
	await frames(3)
