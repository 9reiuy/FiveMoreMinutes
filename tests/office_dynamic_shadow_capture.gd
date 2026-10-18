extends SceneTree

const WORLD := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
var world: Node
var baseline := false
var quick := false
var no_sun := false
var roof_visible := false
var output_prefix := "shadow_after"
var palette_material: ShaderMaterial
var origin := Vector2.ZERO

func _initialize() -> void:
	baseline = "--baseline" in OS.get_cmdline_user_args()
	quick = "--quick" in OS.get_cmdline_user_args()
	no_sun = "--no-sun" in OS.get_cmdline_user_args()
	roof_visible = "--roof-visible" in OS.get_cmdline_user_args()
	output_prefix = "shadow_before" if baseline else "shadow_after"
	call_deferred("_run")

func _run() -> void:
	var master_bus := AudioServer.get_bus_index(&"Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, true)
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# This test action feeds the existing player input path, not a damage shortcut.
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	for property in world.get_property_list():
		if property.name == "dynamic_shadows_enabled":
			world.set("dynamic_shadows_enabled", not baseline)
	root.add_child(world)
	var layer := CanvasLayer.new()
	layer.layer = 1000
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palette_material = ShaderMaterial.new()
	palette_material.shader = preload("res://shaders/palette_quantize.gdshader")
	palette_material.set_shader_parameter("palette_enabled", false)
	overlay.material = palette_material
	layer.add_child(overlay)
	root.add_child(layer)
	var results: Dictionary = {"mode": output_prefix, "gpu": RenderingServer.get_video_adapter_name(), "resolution": "1920x1080", "samples": []}
	for combat in [false, true]:
		if not world.regenerate(42001):
			quit(2)
			return
		if no_sun and world.shadow_manager != null and is_instance_valid(world.shadow_manager.sun):
			world.shadow_manager.sun.light_energy = 0.0
		if roof_visible and world.shadow_manager != null and is_instance_valid(world.shadow_manager.roof):
			world.shadow_manager.roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		world.player.invulnerability_left = 10000.0
		world.player_has_left_elevator_cab = true
		for room in world.rooms:
			if String(room.get("archetype", "")) in ["open_office", "office"]:
				origin = Vector2(room.center_cell) * world.CELL_PIXELS
				world.player.global_position = origin
				world.activate_room(int(room.id))
				break
		world.player.set_attacking_enabled(combat)
		world.night_lighting.set_flashlight_enabled(false)
		root.warp_mouse(Vector2(1360, 440))
		var warm_until := Time.get_ticks_msec() + (1000 if quick else 10000)
		while Time.get_ticks_msec() < warm_until:
			await process_frame
		if not combat:
			await _capture("office_off")
			palette_material.set_shader_parameter("palette_enabled", true)
			await _capture("office_palette1")
			palette_material.set_shader_parameter("palette_enabled", false)
			world.night_lighting.set_flashlight_enabled(true)
			await _capture("office_flashlight")
			world.night_lighting.set_flashlight_enabled(false)
		var frames: Array[float] = []
		var draw_calls: Array[float] = []
		var start := Time.get_ticks_usec()
		var previous := start
		var duration := 4000000 if quick else 60000000
		var phase := -1
		if combat:
			Input.action_press("attack")
		while Time.get_ticks_usec() - start < duration:
			var elapsed := float(Time.get_ticks_usec() - start) / 1000000.0
			var next_phase := int(elapsed / 0.7) % 4
			if phase != next_phase:
				_release_movement()
				Input.action_press(["move_right", "move_down", "move_left", "move_up"][next_phase])
				phase = next_phase
			if combat and world.player.is_weapon_empty_for_attack():
				Input.action_press("reload_weapon")
			else:
				Input.action_release("reload_weapon")
			await process_frame
			var now := Time.get_ticks_usec()
			frames.append(float(now - previous) / 1000.0)
			previous = now
			draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_release_movement()
		Input.action_release("attack")
		Input.action_release("reload_weapon")
		frames.sort()
		draw_calls.sort()
		var sample := {"scenario": "combat" if combat else "movement", "duration_seconds": float(Time.get_ticks_usec() - start) / 1000000.0,
			"frames": frames.size(), "median_ms": frames[frames.size() / 2], "p95_ms": frames[mini(frames.size() - 1, int(frames.size() * .95))],
			"p95_draw_calls": draw_calls[mini(draw_calls.size() - 1, int(draw_calls.size() * .95))]}
		if world.get("shadow_manager") != null:
			sample["shadow_stats"] = world.shadow_manager.get_debug_stats()
		results.samples.append(sample)
		print("SHADOW_BENCH ", sample)
	var file := FileAccess.open("res://.runtime/" + output_prefix + "_metrics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	world.queue_free()
	await process_frame
	quit()

func _release_movement() -> void:
	for action in ["move_right", "move_down", "move_left", "move_up"]:
		Input.action_release(action)

func _capture(label: String) -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png("res://.runtime/" + output_prefix + "_" + label + ".png")
