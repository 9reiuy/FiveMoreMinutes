extends "res://tests/woo_volume_shadow_test.gd"
## Exercise the user-facing entry without overriding its art/visibility defaults.
## Reuse the independent triangle oracle and native door/blood/breach fixtures.
const MERGE_OUT := "res://.runtime/hellkind_purple_sample_20261103/combined_art_visibility"

func write_picture(name: String) -> void:
	var image: Image = lab.world.get_viewport().get_texture().get_image()
	check(image.save_png(MERGE_OUT.path_join(name + ".png")) == OK, "Camera capture " + name)

func palette_pixels(image: Image, target: Color) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if absf(color.r-target.r) <= 1.1/255.0 and absf(color.g-target.g) <= 1.1/255.0 and absf(color.b-target.b) <= 1.1/255.0: count += 1
	return count

func run() -> void:
	DirAccess.make_dir_recursive_absolute(MERGE_OUT)
	create_timer(300.0).timeout.connect(func(): print("COMBINED_TIMEOUT"); quit(2))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-20000, -20000))
	check(DisplayServer.get_name() != "headless", "Actual GPU renderer")
	lab = load("res://scenes/preview/hellkind_purple_sample.tscn").instantiate()
	lab.automation = true
	root.add_child(lab)
	while not lab.sample_ready or lab.busy or lab._loading_layer.visible: await process_frame
	await frames(6)
	evidence["entry_configuration"] = lab.configuration()
	check(lab.style_index == 4 and lab.environment_halftone.enabled, "Shared entry starts with latest art half-tone")
	check(lab.checks.palette.button_pressed and lab.environment_halftone.palette_enabled, "Latest room palette enabled by default")
	check(lab.checks.pixels.button_pressed and lab.world.get_viewport().size == Vector2i(640,360), "Shared entry renders the complete camera at 640 by 360")
	check(lab.use_volume_visibility and lab.visibility_field.get_script() == FIELD and lab.vision_enabled, "Shared entry uses full three-dimensional wall shadows")
	check(not lab._lamps_enabled and lab._sample_city_bounce != null, "Original exterior sun and city bounce are retained")
	check(not lab.configuration().actor_composite, "Original character path has no added display overlay")
	check(lab.measure_player_body_pixels() >= 30.0 and lab.measure_player_body_pixels() <= 34.0, "Complete original player is approximately 32 logical pixels")
	check(root.get_texture().get_image().save_png(MERGE_OUT.path_join("entry.png")) == OK, "Actual entry screenshot including controls")
	lab.sample_ui.hide()
	lab.world.player.process_mode = Node.PROCESS_MODE_DISABLED
	var dark_count := 0
	var light_count := 0
	var oracle_samples := 0
	var mismatches: Array[Dictionary] = []
	var room_colors: Array[Dictionary] = []
	for station_index in 4:
		lab.teleport(station_index)
		await frames(8)
		collect_native_geometry()
		var field: Node = lab.visibility_field
		var atlas: Image = field.texture.get_image()
		var origin: Vector3 = field.light_position
		for radius in [2.0, 4.0, 7.0, 10.0]:
			for angle_index in 16:
				var direction := Vector2.from_angle(TAU*float(angle_index)/16.0 + .037)
				for height in [.05, .95, 2.0]:
					var target := origin + Vector3(direction.x*radius, height-origin.y, direction.y*radius)
					var expected := cpu_visible(origin, target, native_triangles)
					var actual := gpu_visible(field, target, atlas)
					oracle_samples += 1
					if expected != actual: mismatches.append({"room":station_index,"target":target,"cpu":expected,"gpu":actual})
		var picture: Image = lab.world.get_viewport().get_texture().get_image()
		var dark := palette_pixels(picture, Color("191d2e"))
		var light := palette_pixels(picture, Color("ffe1e8"))
		dark_count += dark
		light_count += light
		room_colors.append({"room":station_index,"dark":dark,"light":light})
		write_picture("room_%d_on" % station_index)
		lab.set_vision_enabled(false)
		await frames(5)
		write_picture("room_%d_off" % station_index)
		lab.set_vision_enabled(true)
		await frames(5)
	check(mismatches.is_empty(), "Merged art: four-room GPU visibility agrees with independent source triangles")
	evidence["geometry_oracle"] = {"samples":oracle_samples,"mismatches":mismatches}
	evidence["palette_pixels"] = room_colors
	check(dark_count > 100 and light_count > 100, "Actual Camera contains the approved dark blue-grey and pale pink inks")
	check(lab.visibility_surfaces.unsupported_names.is_empty(), "All existing art material paths support the depth shadow")
	for style in [1,3,4]:
		lab.apply_style(style)
		await frames(6)
		check(lab.world.get_viewport().size == Vector2i(640,360) and lab.checks.palette.button_pressed, "Art preset %d retains the explicit palette and resolution controls" % (style+1))
		check(lab.use_volume_visibility and lab.vision_enabled, "Art preset %d retains three-dimensional visibility" % (style+1))
		write_picture("style_%d" % (style+1))
	lab.set_sample_palette(false)
	await frames(6)
	var monochrome: Image = lab.world.get_viewport().get_texture().get_image()
	check(not lab.environment_halftone.palette_enabled and palette_pixels(monochrome, Color.WHITE)>100, "Palette toggle restores monochrome art")
	write_picture("palette_off")
	lab.set_sample_palette(true)
	lab.set_sample_pixels(false)
	await frames(6)
	check(lab.world.get_viewport().size == Vector2i(1280,720) and lab.environment_halftone.palette_enabled, "Native-resolution comparison keeps current palette and visibility")
	write_picture("native_resolution")
	lab.set_sample_pixels(true)
	lab.toggle_lamps()
	await frames(6)
	check(lab._lamps_enabled and lab.vision_enabled, "Indoor-light comparison retains optical visibility")
	write_picture("indoor_lamps")
	lab.toggle_lamps()
	lab.set_scene_halftone(false)
	await frames(5)
	check(not lab.environment_halftone.enabled and lab.vision_enabled, "Half-tone comparison retains optical visibility")
	lab.set_scene_halftone(true)
	await frames(6)
	await dynamic_test()
	var old_field: WeakRef = weakref(lab.visibility_field)
	await lab.rebuild()
	while not lab.sample_ready or lab.busy or lab._loading_layer.visible: await process_frame
	await frames(6)
	check(old_field.get_ref() == null and lab.visibility_field.field_ready, "Rebuild retires the old visibility world")
	check(lab.style_index == 4 and lab.environment_halftone.palette_enabled and lab.world.get_viewport().size == Vector2i(640,360), "Rebuild preserves merged art, palette and camera resolution")
	write_picture("rebuilt")
	var audio: Node = root.get_node("SFXManager")
	if audio.music_tween != null and audio.music_tween.is_valid(): audio.music_tween.kill()
	audio.music_player.stop()
	audio.music_player.stream = null
	await lab.retire_drawing()
	lab.queue_free()
	await frames(6)
	var file := FileAccess.open(MERGE_OUT.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"Unified sample entry and real-Camera functional integration; not a whole-game performance certification"}, "\t"))
	file.close()
	print("COMBINED_RESULT ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
