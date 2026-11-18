extends "res://tests/h06_light_spots_probe.gd"
## Identical real Enemy firearm calls, separated from ordinary room lighting.


func fire_path(label: String, enemy: EmployeeEnemy, mute_mesh: bool, mute_muzzle: bool,
		mute_bullet_light: bool, shooting := true) -> void:
	var fx: Node3D = world._firearm_fx()
	fx.clear()
	fx._hot.visible = not mute_mesh
	fx._smoke.visible = not mute_mesh
	world.night_lighting.set_shadow_transition_paused(mute_muzzle)
	for light: OmniLight3D in world.projectile_local_light_pool:
		light.light_energy = 0.0 if mute_bullet_light else 0.08
	for projectile in get_nodes_in_group(&"dream_projectiles"):
		projectile.queue_free()
	place_feet(PROBE_START)
	world.player.invulnerability_left = 30.0
	world.player.invulnerability_reason = &"light_spots_diagnostic"
	world.camera_aim_offset = Vector3.ZERO
	world._clear_camera_shake()
	await frames(30)
	var folder := evidence.path_join(label)
	DirAccess.make_dir_recursive_absolute(folder)
	enemy.current_ammo = 12
	enemy.reload_left = 0.0
	var shots_fired := 0
	for i in 104:
		if shooting and i in [8, 34, 60, 86]:
			enemy.can_see_target = true
			enemy._remember_target_position(world.player.global_position, int(world.get_current_room_id()))
			enemy.ranged_attack_fire_locked = true
			enemy.ranged_attack_target_snapshot = world.player.global_position
			var before := enemy.current_ammo
			enemy._fire_held_weapon()
			shots_fired += int(enemy.current_ammo < before)
		await physics_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var hot: Array[Dictionary] = []
		for particle in fx._hot_particles:
			hot.append({"origin": particle.origin, "size": particle.size, "age": particle.age,
				"screen": world.camera_3d.unproject_position(particle.origin), "style": particle.style})
		var muzzle_lamps := 0
		for lamp: Light3D in world.night_lighting.muzzle_lights:
			muzzle_lamps += int(lamp.visible)
		records.append({"label": label, "frame": i, "camera": world.camera_3d.global_position,
			"projectiles": get_nodes_in_group(&"dream_projectiles").size(), "hot": hot,
			"muzzle_lamps": muzzle_lamps, "enemy": enemy.global_position,
			"enemy_screen": world.camera_3d.unproject_position(world.get_gameplay_world_position(enemy.global_position, 0.7))})
		if i % 2 == 0:
			root.get_texture().get_image().save_png(folder.path_join("frame_%03d.png" % i))
	check(shots_fired == (4 if shooting else 0), label + " uses the actual enemy firing pipeline")
	print("FIRE_PATH ", label, " shots=", shots_fired)


func run() -> void:
	evidence = OS.get_environment("FLICKER_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await enter_chapter(CHAPTER.Save.PUMP)
	world.restart_queued = true
	for enemy in world.enemy_root.get_children(): enemy.queue_free()
	await frames(4)
	place_feet(PROBE_START)
	var enemy: EmployeeEnemy = world._spawn_regular_employee(int(world.get_current_room_id()),
		Vector2(-22.0, -17.5) * 32.0, &"employee", false, "basic")
	enemy.equip_weapon("basic")
	enemy.set_room_runtime_active(true)
	enemy.set_room_bounds(Rect2(PLAN.UPPER.pump.position * 32.0, PLAN.UPPER.pump.size * 32.0))
	enemy.set_physics_process(false)
	await frames(8)
	await fire_path("original_a", enemy, false, false, false)
	await fire_path("without_effect_meshes", enemy, true, false, false)
	await fire_path("without_muzzle_lights", enemy, false, true, false)
	await fire_path("without_projectile_lights", enemy, false, false, true)
	await fire_path("no_shots", enemy, false, false, false, false)
	check(records.size() == 520, "all diagnostic paths produced their complete frame records")
	var file := FileAccess.open(evidence.path_join("trace.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"records": records, "checks": checks, "failures": failures,
		"pid": OS.get_process_id(), "renderer": RenderingServer.get_current_rendering_method(),
		"audio": AudioServer.get_driver_name(), "scope": "Matched Enemy firing calls with per-effect reversible exclusions. Actual chapter Camera and diagnostic readbacks; no production-source change."}, "\t"))
	verify_audio()
	current_scene.queue_free()
	await frames(4)
	print("LIGHT_SPOTS_FIRE_PROBE frames=", records.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
