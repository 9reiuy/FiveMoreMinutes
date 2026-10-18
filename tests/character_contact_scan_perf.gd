extends SceneTree
## Formal-camera old/new equivalence and full bridge cost, not gameplay speed.
var checks := 0
var failures := 0
var bridges: Array[Node] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func sync_all(legacy: bool) -> void:
	for bridge in bridges:
		bridge.set_meta(&"test_legacy_contact_scan", legacy)
		bridge._process(0.0)
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var settings := root.get_node("SettingsManager")
	var saved: Dictionary = settings.values.duplicate(true)
	var world: Node3D = load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	world.generate_on_ready = false
	world.enable_game_start_cab_exit = false
	var display: Control = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world
	display.preview_mode = false
	root.add_child(display)
	check(world.regenerate(120), "Generate sample")
	for index in 30: await process_frame
	display.set_selective_enabled(true)
	display.set_palette_enabled(true)
	for bridge in world.actor_depth_bridges_root.get_children():
		if bridge.get("character_projection") == true: bridges.append(bridge)
	if world.player_depth_bridge != null: bridges.append(world.player_depth_bridge)
	check(bridges.size() > 5, "Must exercise player and multiple enemies")
	# Startup can leave the review character outside the selected room. Place
	# all passive comparison subjects in the actual office, not in black void.
	var office_center := Vector2.ZERO
	var found_office := false
	for room in world.rooms:
		if String(room.get("sample_key", "")) == "office":
			office_center = Vector2(room.grid_rect.get_center()) * 32.0
			found_office = true
			break
	check(found_office, "Missing authored office")
	for index in bridges.size():
		bridges[index].source_actor.global_position = office_center + Vector2(index % 4 - 2, index / 4 - 2) * 48.0
	world.camera_aim_offset = Vector3.ZERO
	world.transition_phase = &"IDLE"
	world._update_camera_and_actor_projection(0.0)
	display._process(0.0)
	sync_all(false)
	var visible_subjects := 0
	for bridge in bridges:
		if world.camera_3d.get_viewport().get_visible_rect().has_point(world.camera_3d.unproject_position(bridge.actor_sprite.global_position)):
			visible_subjects += 1
	print("CONTACT_CAMERA_VISIBLE ", visible_subjects, "/", bridges.size(), " player=", world.player.global_position, " rig=", world.camera_rig.position, " camera=", world.camera_3d.global_position, " viewport=", world.camera_3d.get_viewport().get_visible_rect())
	check(visible_subjects >= 6, "Comparison needs multiple actually visible characters")
	paused = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for legacy in [true, false, true]:
		var samples: Array[float] = []
		for index in 120:
			var started := Time.get_ticks_usec()
			sync_all(legacy)
			if index >= 20: samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
		samples.sort()
		print("CHARACTER_CONTACT_SYNC ", JSON.stringify({"legacy":legacy,"characters":bridges.size(),"median_ms":samples[50],"p95_ms":samples[95],"samples":100}))
	for phase in 5:
		for bridge in bridges:
			var source: Node2D = bridge.source_actor
			var body: Node2D = source.get_node("CharacterVisual")
			body.rotation = [0.0, 0.6, PI * 0.5, 0.0, -0.4][phase]
			if source.is_in_group(&"dream_enemies"): source.dead = phase >= 2
			if phase == 4:
				source.global_position += Vector2(16, -8)
				var weapon: Node2D = source.get_node("WeaponRoot")
				weapon.rotation += 0.7
		# Pose changes update the formal weapon reference height and shadow atlas
		# in stages; settle those before either algorithm's image is sampled.
		for index in 3:
			sync_all(true)
			await RenderingServer.frame_post_draw
		var images: Array[Image] = []
		var expected: Array[Transform3D] = []
		for legacy in [true, false, true]:
			for bridge in bridges: bridge.set_meta(&"test_contact_scan_count", 0)
			sync_all(legacy)
			for index in bridges.size():
				var bridge := bridges[index]
				if images.is_empty(): expected.append(bridge.actor_sprite.global_transform)
				else: check(expected[index].is_equal_approx(bridge.actor_sprite.global_transform), "Character contact transform differs phase %d" % phase)
				if not legacy:
					var source: Node2D = bridge.source_actor
					var scans := int(bridge.get_meta(&"test_contact_scan_count"))
					if phase == 0: check(scans == 0, "Upright contact still scans opaque bounds")
					if phase == 2: check(scans > 0, "Corpse/rotated contact lost live scan")
				bridge.remove_meta(&"test_contact_scan_count")
			for index in 2: await RenderingServer.frame_post_draw
			if not DisplayServer.get_name() == "headless":
				images.append(root.get_texture().get_image())
			else: images.append(Image.new())
		if DisplayServer.get_name() != "headless":
			check(images[0].get_data() == images[1].get_data(), "Full Camera image changed phase %d" % phase)
			check(images[0].get_data() == images[2].get_data(), "Legacy image unstable phase %d" % phase)
			images[1].save_png("res://.runtime/furniture_face_review/contact_scan_%d.png" % phase)
	for bridge in bridges: bridge.remove_meta(&"test_legacy_contact_scan")
	settings.values = saved
	paused = false
	display.queue_free()
	for index in 4: await process_frame
	print("CHARACTER_CONTACT_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
