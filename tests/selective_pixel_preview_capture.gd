extends SceneTree
const PREVIEW = preload("res://scenes/dream/preview/SelectivePixelPreview.tscn")
var preview: Control
var shot_count := 0
var attack_probe_printed := false
func _initialize() -> void:
	call_deferred("_run")
func frames(count: int) -> void:
	for _i in count:
		await process_frame
func capture(label: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	var suffix := "_1280x800" if "nonwide" in OS.get_cmdline_user_args() else ""
	root.get_texture().get_image().save_png("res://.runtime/unified_pixel_" + label + suffix + ".png")
func _run() -> void:
	root.size = Vector2i(1280, 800) if "nonwide" in OS.get_cmdline_user_args() else Vector2i(1920, 1080)
	if not InputMap.has_action("attack"): InputMap.add_action("attack")
	preview = PREVIEW.instantiate()
	root.add_child(preview)
	await frames(35)
	var world: Node3D = preview.world
	world.player.auto_weapon.weapon_fired.connect(func(_recoil): shot_count += 1)
	world.player.invulnerability_left = 999.0
	for enemy in world.enemy_root.get_children():
		enemy.set_physics_process(false)
	world.player.equip_weapon("basic", world.config, {})
	await frames(45)
	world.set_process(false)
	world.player.set_physics_process(false)
	preview.set_palette_enabled(false)
	await capture("640_office")
	preview.world_viewport.get_texture().get_image().save_png("res://.runtime/unified_pixel_world_640.png")
	preview.set_selective_enabled(false)
	await capture("native_office")
	preview.set_palette_enabled(true)
	await capture("native_palette1")
	preview.set_selective_enabled(true)
	await capture("640_palette1")
	preview.set_palette_enabled(false)
	preview.set_preview_pixel_size(Vector2i(960, 540))
	await capture("960_office")
	preview.set_preview_pixel_size(Vector2i(640, 360))
	world.set_process(true)
	world.player.set_physics_process(true)
	if "clip" in OS.get_cmdline_user_args():
		await record_clip()
	if "benchmark" in OS.get_cmdline_user_args():
		await benchmark()
	print("TASK018_CAPTURE shots=", shot_count, " ", preview.get_stats())
	preview.queue_free()
	await frames(5)
	quit()
func benchmark() -> void:
	var results: Array = []
	for selected in [false, true]:
		# Use a fresh gameplay scene for each mode. Reusing regenerate() after a
		# firefight retains some sprite capture viewports and skews the second run.
		preview.queue_free()
		await frames(8)
		preview = PREVIEW.instantiate()
		preview.initial_selective_enabled = selected
		root.add_child(preview)
		await frames(45)
		preview.world.player.auto_weapon.weapon_fired.connect(func(_recoil): shot_count += 1)
		preview.world.player.invulnerability_left = 999.0
		preview.world.player.equip_weapon("basic", preview.world.config, {})
		for enemy in preview.world.enemy_root.get_children(): enemy.set_physics_process(false)
		_release_actions()
		var shots_before := shot_count
		var start := Time.get_ticks_usec()
		while Time.get_ticks_usec() - start < 10000000:
			await process_frame
		var samples: Array[float] = []
		var calls: Array[float] = []
		start = Time.get_ticks_usec()
		var previous := start
		while Time.get_ticks_usec() - start < 60000000:
			_drive(float(Time.get_ticks_usec() - start) / 1000000.0)
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append(float(now - previous) / 1000.0)
			calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			previous = now
		samples.sort()
		_release_actions()
		var sum := 0.0
		for value in calls: sum += value
		results.append({"pixelation": selected, "median_ms": samples[samples.size() / 2], "p95_ms": samples[int(samples.size() * 0.95)], "mean_draw_calls": sum / calls.size(), "samples": samples.size(), "shots": shot_count - shots_before, "stats": preview.get_stats()})
	var file := FileAccess.open("res://.runtime/unified_pixel_performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))

func _drive(time: float, clip_mode := false) -> void:
	var angle := floorf(time / 0.75) * TAU / 8.0
	var mouse := InputEventMouseMotion.new()
	var logical_pointer: Vector2 = preview.world_to_hud(Vector2(preview.world_viewport.size) * 0.5 + Vector2.RIGHT.rotated(angle) * float(preview.world_viewport.size.y) * 0.3)
	# Input.parse_input_event receives physical window pixels. Godot then
	# converts them through the root canvas transform before _input sees them.
	mouse.position = preview.get_viewport().get_final_transform() * logical_pointer
	Input.parse_input_event(mouse)
	for action in [&"move_right", &"move_down", &"move_left", &"move_up"]:
		Input.action_release(action)
	var movement: Array[StringName] = [&"move_right", &"move_down", &"move_left", &"move_up"]
	if not clip_mode or fmod(time, 1.5) < 0.2:
		Input.action_press(movement[int(time / 1.5) % 4])
	if (clip_mode and time >= 1.0) or int(time) % 12 >= 6:
		Input.action_press("attack")
		if not attack_probe_printed:
			attack_probe_printed = true
			var player = preview.world.player
			print("ATTACK_PROBE ", {"pointer": mouse.position, "inside": preview._pointer_inside(), "trigger": player.should_trigger_weapon_attack(), "active": player.auto_weapon.active, "dead": player.dead, "enabled": player.attacking_enabled, "selected": player.selected_weapon_id, "cooldown": player.auto_weapon.cooldown_left, "processing": player.auto_weapon.is_processing(), "paused": paused})
	else:
		Input.action_release("attack")
	if int(time * 10.0) % 60 == 0:
		Input.action_press("reload_weapon")
	else:
		Input.action_release("reload_weapon")
	if clip_mode and time >= 2.0 and time < 2.5:
		Input.action_press("dash")
	else:
		Input.action_release("dash")

func _release_actions() -> void:
	for action in [&"move_right", &"move_down", &"move_left", &"move_up", &"attack", &"reload_weapon", &"dash"]:
		Input.action_release(action)

func record_clip() -> void:
	DirAccess.make_dir_recursive_absolute("res://.runtime/unified_pixel_clip")
	var start := Time.get_ticks_msec()
	for index in 96:
		_drive(float(index) / 10.0, true)
		await frames(2)
		while Time.get_ticks_msec() - start < index * 100:
			_drive(float(index) / 10.0, true)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/unified_pixel_clip/frame_%03d.png" % index)
	_release_actions()
