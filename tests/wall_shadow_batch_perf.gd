extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var settings := root.get_node("SettingsManager")
	var saved: Dictionary = settings.values.duplicate(true)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false; world.persist_profile = false; world.enable_game_start_cab_exit = false
	var display: Control = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world; display.preview_mode = false
	root.add_child(display)
	check(world.regenerate(41001), "Generate formal random floor")
	for index in 30: await process_frame
	world.player.invulnerability_left = 999
	world.player.global_position = world.enemy_root.get_child(0).global_position + Vector2(96,0)
	world.transition_phase = &"IDLE"
	world.camera_aim_offset = Vector3.ZERO
	world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(true); display.set_palette_enabled(true)
	display._process(0.0)
	world.room_visibility._update_outside_mask()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps = 0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < 10000000: await RenderingServer.frame_post_draw
	paused = true
	# A TIME-based dropped-weapon shine changes despite SceneTree pause. Freeze
	# that unrelated diagnostic material equally for all three shadow groups.
	var shine_materials: Dictionary = {}
	for node in world.find_children("*", "CanvasItem", true, false):
		var material: ShaderMaterial = node.material as ShaderMaterial
		if material != null and material.shader != null and "uniform bool shine_enabled" in material.shader.code:
			if not shine_materials.has(material): shine_materials[material] = material.get_shader_parameter("shine_enabled")
			material.set_shader_parameter("shine_enabled", false)
	world.player.invulnerability_left = 0
	world.player_depth_bridge._process(0.0)
	for index in 4: await RenderingServer.frame_post_draw
	var batch: Node3D = load("res://tests/wall_shadow_batch_candidate.gd").new()
	batch.build(world.wall_root)
	check(batch.originals.size() > 20 and batch.batches.size() < batch.originals.size(), "No meaningful wall batching")
	print("WALL_SHADOW_BATCH_COUNT originals=", batch.originals.size(), " batches=", batch.batches.size())
	var images: Array[Image] = []
	for enabled in [false,true,false]:
		batch.set_batched(enabled)
		start = Time.get_ticks_usec()
		while Time.get_ticks_usec() - start < 2000000: await RenderingServer.frame_post_draw
		var samples: Array[float] = []; var draws: Array[float] = []
		start = Time.get_ticks_usec(); var previous := start
		while Time.get_ticks_usec() - start < 15000000:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			samples.append(float(now - previous) / 1000.0); previous = now
			draws.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		samples.sort(); draws.sort()
		print("WALL_SHADOW_FRAME_PERF ", JSON.stringify({"batched":enabled,"median_ms":samples[samples.size()/2],"p95_ms":samples[floori(samples.size()*.95)],"draw_calls_median":draws[draws.size()/2],"frozen_gameplay":true,"gpu":RenderingServer.get_video_adapter_name()}))
		images.append(root.get_texture().get_image())
		images.back().save_png("res://.runtime/furniture_face_review/wall_shadow_batch_%d.png" % (images.size()-1))
	var legacy_data := images[2].get_data()
	var legacy_diff := 0
	var min_pos := Vector2i(99999,99999); var max_pos := Vector2i.ZERO
	var before := images[0].get_data(); var after := images[1].get_data(); var different := 0
	for index in range(0, before.size(), 4):
		if before[index] != after[index] or before[index+1] != after[index+1] or before[index+2] != after[index+2]: different += 1
		if before[index] != legacy_data[index] or before[index+1] != legacy_data[index+1] or before[index+2] != legacy_data[index+2]:
			legacy_diff += 1
			var point := Vector2i((index / 4) % images[0].get_width(), (index / 4) / images[0].get_width())
			min_pos = min_pos.min(point); max_pos = max_pos.max(point)
	print("WALL_SHADOW_LEGACY_DIFF ", legacy_diff, " bounds=", min_pos, "..", max_pos)
	check(legacy_diff == 0, "Legacy shadow image unstable")
	print("WALL_SHADOW_PIXEL_DIFFERENCES ", different)
	check(different == 0, "Batched wall shadows change formal Camera image")
	settings.values = saved
	for material in shine_materials: material.set_shader_parameter("shine_enabled", shine_materials[material])
	paused = false; display.queue_free()
	for index in 4: await process_frame
	print("WALL_SHADOW_BATCH_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
