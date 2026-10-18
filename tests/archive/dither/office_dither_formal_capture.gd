extends SceneTree
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920,1080)
	AudioServer.set_bus_mute(0, true)
	var settings := root.get_node("SettingsManager")
	var saved: Dictionary = settings.values.duplicate(true)
	var world := WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.use_authored_office_sample = true
	root.add_child(world)
	for i in 4:
		await process_frame
	world.regenerate(42001)
	for room in world.rooms:
		if String(room.get("archetype", "")) == "open_office":
			world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
			world.activate_room(int(room.id))
			break
	world.player_has_left_elevator_cab = true
	world.player.invulnerability_left = 100000.0
	world.night_lighting.set_flashlight_enabled(false)
	await create_timer(2.0).timeout
	world.process_mode = Node.PROCESS_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute("res://.runtime/dither_formal")
	for pixels in [false, true]:
		for palette in [false, true]:
			settings.values["pixelation_enabled"] = pixels
			settings.values["palette_enabled"] = palette
			settings.setting_changed.emit(&"pixelation_enabled", pixels)
			settings.setting_changed.emit(&"palette_enabled", palette)
			await create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/dither_formal/pixel_%d_palette_%d.png" % [int(pixels),int(palette)])
	settings.values = saved
	print("DITHER_FORMAL_GPU_CAPTURE_PASS ", RenderingServer.get_video_adapter_name())
	world.queue_free()
	await process_frame
	quit()
