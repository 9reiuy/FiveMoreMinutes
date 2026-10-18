extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var settings := root.get_node("SettingsManager")
	var saved: Dictionary = settings.values.duplicate(true)
	var world: Node3D = load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	world.generate_on_ready = false; world.persist_profile = false; world.enable_game_start_cab_exit = false
	var display: Control = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world; display.preview_mode = false
	root.add_child(display)
	check(world.regenerate(120), "Generate sample")
	for index in 30: await process_frame
	var bridges: Array[Node] = [world.player_depth_bridge]
	for bridge in world.actor_depth_bridges_root.get_children():
		if bridge.get("character_projection") == true: bridges.append(bridge)
	check(bridges.size() >= 10, "Insufficient snapshot subjects")
	var office_center := Vector2.ZERO
	var found_office := false
	for room in world.rooms:
		if String(room.get("sample_key", "")) == "office":
			office_center = Vector2(room.grid_rect.get_center()) * 32.0
			found_office = true
			break
	check(found_office, "Missing authored office")
	for index in bridges.size():
		bridges[index].source_actor.global_position = office_center + Vector2(index % 4 - 2, index / 4 - 2) * 48
	world.transition_phase = &"IDLE"; world.camera_aim_offset = Vector3.ZERO
	world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(true); display.set_palette_enabled(true)
	display._process(0.0)
	world.room_visibility._update_outside_mask()
	paused = true
	for bridge in bridges: bridge._process(0.0)
	var visible_subjects := 0
	for bridge in bridges:
		if world.camera_3d.get_viewport().get_visible_rect().has_point(world.camera_3d.unproject_position(bridge.actor_sprite.global_position)):
			visible_subjects += 1
	print("SNAPSHOT_CAMERA_VISIBLE ", visible_subjects, "/", bridges.size())
	check(visible_subjects == bridges.size(), "All comparison subjects must be on screen")
	# A full sync between request and deferred flush must satisfy that request;
	# a later request still needs its own flush. Compare the first actual draw.
	for ordering in 3:
		var refresh_images: Array[Image] = []
		for legacy_refresh in [true,false,true]:
			for bridge in bridges:
				bridge.set_meta(&"test_legacy_snapshot_sync", false)
				bridge.set_meta(&"test_legacy_pending_refresh", legacy_refresh)
				bridge.set_meta(&"test_snapshot_flush_count",0)
				if ordering==1: bridge._process(0.0)
				bridge.get_weapon_visual_snapshot(bridge.source_actor.global_position+Vector2(20,-5))
				if ordering!=1: bridge._process(0.0)
				if ordering==2: bridge.get_weapon_visual_snapshot(bridge.source_actor.global_position+Vector2(20,-5))
			await RenderingServer.frame_post_draw
			for bridge in bridges:
				check(int(bridge.get_meta(&"test_snapshot_flush_count"))==(1 if legacy_refresh or ordering!=0 else 0),"Pending refresh ordering%d"%ordering)
				bridge.remove_meta(&"test_snapshot_flush_count")
			refresh_images.append(root.get_texture().get_image())
		check(refresh_images[0].get_data()==refresh_images[1].get_data(),"Pending refresh first draw differs")
		check(refresh_images[0].get_data()==refresh_images[2].get_data(),"Pending refresh old repeat differs")
	for bridge in bridges: bridge.remove_meta(&"test_legacy_pending_refresh")
	for legacy in [true, false, true]:
		var samples: Array[float] = []
		for index in 100:
			var started := Time.get_ticks_usec()
			for bridge in bridges:
				bridge.set_meta(&"test_legacy_snapshot_sync", legacy)
				bridge.get_weapon_visual_snapshot(bridge.source_actor.global_position + Vector2(20,-5))
			if index >= 20: samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
		samples.sort()
		print("SNAPSHOT_POSE_CPU ", JSON.stringify({"legacy":legacy,"characters":bridges.size(),"median_ms":samples[40],"p95_ms":samples[76],"synchronous_only":true}))
		for index in 3: await RenderingServer.frame_post_draw
	var pending_only := "--pending-frame" in OS.get_cmdline_user_args()
	if pending_only or "--frame-perf" in OS.get_cmdline_user_args():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps = 0
		var stable_images: Array[Image] = []
		for legacy in [true, false, true]:
			for bridge in bridges:
				bridge.set_meta(&"test_legacy_snapshot_sync", legacy and not pending_only)
				bridge.set_meta(&"test_legacy_pending_refresh", legacy if pending_only else false)
			var started := Time.get_ticks_usec()
			var previous := started
			var frames: Array[float] = []
			while Time.get_ticks_usec() - started < 12000000:
				for bridge in bridges:
					if not pending_only: bridge._process(0.0)
					for request in 2: bridge.get_weapon_visual_snapshot(bridge.source_actor.global_position + Vector2(20,-5))
					if pending_only: bridge._process(0.0)
				await RenderingServer.frame_post_draw
				var now := Time.get_ticks_usec()
				if now - started >= 2000000: frames.append(float(now - previous) / 1000.0)
				previous = now
			frames.sort()
			print("PENDING_REFRESH_FULL_FRAME " if pending_only else "SNAPSHOT_FULL_FRAME ", JSON.stringify({"legacy":legacy,"characters":bridges.size(),"requests_per_character":2,"median_ms":frames[frames.size()/2],"p95_ms":frames[floori(frames.size()*.95)],"includes_deferred_refresh":true,"frozen_gameplay":true}))
			stable_images.append(root.get_texture().get_image())
		check(stable_images[0].get_data() == stable_images[1].get_data(), "Fixed-load full-frame picture differs")
		check(stable_images[0].get_data() == stable_images[2].get_data(), "Fixed-load old repeat picture differs")
		for bridge in bridges: bridge.remove_meta(&"test_legacy_pending_refresh")
	# Unlike the settled-pose comparison below, inspect the first rendered frame
	# after a move/turn and a late snapshot. Deferred capture must not lag a frame.
	var player_source: Node2D = world.player
	var base_position := player_source.global_position
	var pointer_target := base_position + Vector2(160,100)
	player_source.set_meta(&"presentation_pointer_position", func() -> Vector2:
		return world.camera_3d.unproject_position(world.to_global(Vector3(pointer_target.x/32.0, .285, pointer_target.y/32.0))))
	for phase in 8:
		var first_images: Array[Image] = []
		var first_expected: Dictionary = {}
		for legacy in [true, false, true]:
			world.player_depth_bridge.set_meta(&"test_legacy_snapshot_sync", true)
			player_source.global_position = base_position
			player_source.get_node("WeaponRoot").rotation = -0.5
			player_source.equip_weapon("pistol", world.config, {}, 0)
			for index in 3:
				world.player_depth_bridge._process(0.0)
				player_source._update_held_weapon_aim()
				await RenderingServer.frame_post_draw
			player_source.global_position = base_position + Vector2(4,-2) * phase
			world.player_depth_bridge.set_meta(&"test_legacy_snapshot_sync", legacy)
			player_source.equip_weapon(["pistol", "assault_rifle", "shotgun"][phase % 3], world.config, {}, 0)
			player_source.get_node("WeaponRoot").rotation = phase * TAU / 8.0
			world.player_depth_bridge.set_meta(&"test_legacy_snapshot_sync", legacy)
			var result: Dictionary = world.player_depth_bridge.get_weapon_visual_snapshot(player_source.get_projectile_origin())
			if first_images.is_empty(): first_expected = result
			else: check(result.world_origin.is_equal_approx(first_expected.world_origin), "First-frame muzzle differs phase %d" % phase)
			await RenderingServer.frame_post_draw
			first_images.append(root.get_texture().get_image())
		check(first_images[0].get_data() == first_images[1].get_data(), "First rendered frame differs phase %d" % phase)
		check(first_images[0].get_data() == first_images[2].get_data(), "First-frame old repeat unstable phase %d" % phase)
	player_source.global_position = base_position
	for phase in 12:
		for bridge in bridges:
			var source: Node2D = bridge.source_actor
			source.get_node("WeaponRoot").rotation = phase * TAU / 8.0
			source.get_node("CharacterVisual").rotation = 0.0 if phase < 8 else (phase - 7) * 0.3
			if source.is_in_group(&"dream_enemies"): source.dead = phase >= 10
			if phase == 9: source.global_position += Vector2(12,-6)
		for index in 3:
			for bridge in bridges: bridge._process(0.0)
			await RenderingServer.frame_post_draw
		var images: Array[Image] = []
		var expected: Array[Dictionary] = []
		for legacy in [true, false, true]:
			for index in bridges.size():
				var bridge := bridges[index]
				bridge.set_meta(&"test_legacy_snapshot_sync", legacy)
				var point: Vector2 = bridge.source_actor.global_position + Vector2.RIGHT.rotated(phase * TAU / 8.0) * 20
				var result: Dictionary = bridge.get_weapon_visual_snapshot(point)
				if images.is_empty(): expected.append(result)
				else:
					check(result.world_origin.is_equal_approx(expected[index].world_origin), "Muzzle origin differs phase %d" % phase)
					check(is_equal_approx(result.height, expected[index].height), "Reference height differs phase %d" % phase)
			for index in 3: await RenderingServer.frame_post_draw
			images.append(root.get_texture().get_image())
		check(images[0].get_data() == images[1].get_data(), "Camera pixels differ phase %d" % phase)
		check(images[0].get_data() == images[2].get_data(), "Legacy repeat unstable phase %d" % phase)
		if phase in [0, 4, 9, 11]: images[1].save_png("res://.runtime/furniture_face_review/snapshot_pose_%d.png" % phase)
	var player_bridge: Node = world.player_depth_bridge
	player_bridge.set_meta(&"test_legacy_snapshot_sync", false)
	world.player.get_node("CharacterVisual").rotation = 0
	player_bridge.set_meta(&"test_snapshot_flush_count", 0)
	player_bridge.get_weapon_visual_snapshot(world.player.get_projectile_origin())
	player_bridge.get_weapon_visual_snapshot(world.player.get_projectile_origin())
	check(int(player_bridge.get_meta(&"test_snapshot_flush_count")) == 0, "Capture refresh was not deferred")
	for index in 3: await RenderingServer.frame_post_draw
	check(int(player_bridge.get_meta(&"test_snapshot_flush_count")) == 1, "Multiple same-batch snapshots refresh captures more than once")
	for bridge in bridges: bridge.remove_meta(&"test_legacy_snapshot_sync")
	player_bridge.remove_meta(&"test_snapshot_flush_count")
	settings.values = saved
	paused = false; display.queue_free()
	for index in 4: await process_frame
	print("SNAPSHOT_POSE_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
