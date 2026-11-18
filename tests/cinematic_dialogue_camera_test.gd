extends SceneTree

const PREVIEW := preload("res://scripts/testing/cinematic_dialogue_preview.gd")
const STATS := preload("res://scripts/testing/lab_recorder.gd")
const RECEPTIONIST_DIALOGUE_PATH := "res://scenes/ui/dialogue/receptionist_dialogue.tscn"
var output := "res://.runtime/cinematic_dialogue_20261117/camera"
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var preview: PREVIEW
var baseline: Image
var external_controller: Node
var receptionist_load_ms := 0.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="): output = arg.trim_prefix("--artifact-dir=")
	run.call_deferred()


func check(ok: bool, description: String) -> void:
	checks.append({"pass": ok, "description": description})
	print("PASS " if ok else "FAIL ", description)


func frames(count: int = 4) -> void:
	for _i in count: await process_frame


func snapshot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	check(img.save_png(output.path_join(name + ".png")) == OK, "Saved actual Camera " + name)
	return img


func sample(name: String, count: int = 120, activate: Callable = Callable()) -> void:
	if OS.get_cmdline_user_args().has("--visual-only"):
		if activate.is_valid():
			activate.call()
			await frames(2)
		return
	var rows: Array[float] = []
	var stamp := Time.get_ticks_usec()
	var raw: Array[Array] = []
	if activate.is_valid(): activate.call()
	for _i in count:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - stamp) / 1000.0
		stamp = now
		rows.append(ms)
		raw.append([Engine.get_process_frames(), ms])
	var csv := FileAccess.open(output.path_join(name + ".csv"), FileAccess.WRITE)
	csv.store_csv_line(["engine_frame", "wall_ms"])
	for row in raw: csv.store_csv_line([str(row[0]), str(row[1])])
	csv.close()
	samples.append({"name": name, "stats": STATS.stats(rows), "ui_visible": preview.dialogue.visible, "enemies": preview.world.enemy_root.get_child_count(), "furniture": preview.world.furniture_root.get_child_count()})
	print("SAMPLE ", name, " ", JSON.stringify(samples.back().stats))


func start_external_line(side: String, text: String, expression: StringName) -> void:
	preview.dialogue.default_speaker_side = side
	external_controller.start_dialogue(preview.dialogue, text, [], Vector2.ZERO, {
		"expression": expression, "typewriter_speed": 0.0, "compact_dialogue": true, "countdown_extra": 3600.0
	})
	external_controller._process(0.0)


func show_line(side: String, text: String = "先在这里停一下。\n等我确认前面的通道。", expression: StringName = &"normal") -> void:
	hide_line()
	preview.dialogue.two_person_dialogue = true
	if is_instance_valid(external_controller):
		start_external_line(side, text, expression)
		await create_timer(0.25).timeout
	else:
		await preview.dialogue.open_data({"lines": [{"speaker": side, "speaker_side": side, "text": text, "blip": false}]})
		preview.dialogue._complete_typewriter()
	await frames(8)
	check(preview.dialogue.portrait.is_visible_in_tree() and is_equal_approx(preview.dialogue.portrait.modulate.a, 1.0) and is_equal_approx(preview.dialogue.dialogue_panel.modulate.a, 1.0), "Portraits and text finish their entrance at full visible alpha")


func check_receptionist_state(expression: String) -> void:
	var right := preview.dialogue.right_art.texture as AtlasTexture
	var left := preview.dialogue.character_art.texture as AtlasTexture
	check(right != null and right.atlas.resource_path.get_file() == "receptionist_%s.png" % expression
		and right.atlas.get_size() == Vector2(555, 1796) and left != null and left.atlas == preview.dialogue.PORTRAIT_IDLE,
		"Receptionist uses the authored %s state while the player keeps their own portrait" % expression)


func hide_line() -> void:
	if is_instance_valid(external_controller): external_controller.dismiss_if_active()
	preview.dialogue.close_without_signal()


func mean_alpha(image: Image, area: Rect2i) -> float:
	var total := 0.0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x): total += image.get_pixel(x, y).a
	return total / float(area.size.x * area.size.y)


func check_veil_profile() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rect := ColorRect.new()
	rect.size = Vector2(viewport.size)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/ui/cinematic_dialogue_veil.gdshader")
	rect.material = material
	viewport.add_child(rect)
	await frames(8)
	await RenderingServer.frame_post_draw
	var img := viewport.get_texture().get_image()
	img.save_png(output.path_join("curved_veil_alpha.png"))
	var top_center := mean_alpha(img, Rect2i(620, 116, 40, 24))
	var top_side := mean_alpha(img, Rect2i(40, 116, 40, 24))
	var bottom_center := mean_alpha(img, Rect2i(620, 535, 40, 24))
	var bottom_side := mean_alpha(img, Rect2i(40, 535, 40, 24))
	check(top_center > top_side + 0.25, "Upper matte curves downward into the center of the visible world")
	check(bottom_center > bottom_side + 0.25, "Lower matte curves upward into the center of the visible world")
	var text_min_alpha := 1.0
	for y in range(604, 672):
		for x in range(228, 1072): text_min_alpha = minf(text_min_alpha, img.get_pixel(x, y).a)
	check(text_min_alpha > 0.995, "Both dialogue rows remain wholly inside the opaque black matte across the full text width")
	check(mean_alpha(img, Rect2i(620, 568, 40, 8)) < 0.98, "Contracted matte reveals more of the scene above the dialogue instead of adding excess black padding")
	var sizes: Array[int] = []
	for logical_y in [57, 69, 75]:
		var row := floori(float(logical_y) / 6.0)
		var cx := 324 if row % 2 else 321
		var width := 0
		for x in range(cx * 2 - 6, cx * 2 + 6):
			if img.get_pixel(x, logical_y * 2).a > 0.5: width += 1
		sizes.append(width)
	check(sizes[0] > sizes[1] and sizes[1] > sizes[2] and sizes[2] > 0, "Rendered halftone disks shrink from the matte toward the outer edge: " + str(sizes))
	material.set_shader_parameter(&"presentation_progress", 0.0)
	material.set_shader_parameter(&"bottom_lift", 40.0)
	await frames(4)
	await RenderingServer.frame_post_draw
	var withdrawn := viewport.get_texture().get_image()
	var offscreen := true
	for x in [40, 640, 1240]:
		for y in [4, 60, 660, 715]: offscreen = offscreen and withdrawn.get_pixel(x, y).a < 0.01
	check(offscreen, "Retracted upper and lower matte, including choice layout, are actually outside the viewport")
	viewport.queue_free()
	await frames(3)


func check_choice_dot_profile() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(336, 46)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var row := ColorRect.new()
	row.size = Vector2(viewport.size)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/ui/dialogue_choice_halftone.gdshader")
	material.set_shader_parameter(&"selected", 1.0)
	row.material = material
	viewport.add_child(row)
	await frames(6)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.save_png(output.path_join("choice_halftone_mask.png"))
	var diameters: Array[int] = []
	for column in [2, 6, 8]:
		var center := roundi(2.0 * (115.0 + (float(column) + 0.5) * 5.2))
		var diameter := 0
		for x in range(center - 5, center + 5):
			if image.get_pixel(x, 26).a > 0.35:
				diameter += 1
		diameters.append(diameter)
	check(diameters[0] > diameters[1] and diameters[1] > diameters[2] and diameters[2] > 0,
		"Measured choice dots shrink toward the right tail: " + str(diameters))
	var left_edge := image.get_pixel(40, 2)
	var middle_edge := image.get_pixel(180, 2)
	check(left_edge.g * left_edge.a > 0.65 and middle_edge.g * middle_edge.a < 0.22,
		"The white rim is bright near the left corner and has already faded by mid-row")
	var upper_gap := image.get_pixel(271, 7).a
	var lower_gap := image.get_pixel(271, 28).a
	check(upper_gap > 0.06 and upper_gap < 0.35 and upper_gap > lower_gap + 0.04,
		"The top gradient covers gaps between halftone disks and eases off lower in the row")
	viewport.queue_free()
	await frames(3)


func open_choice_sample(side_layout: bool) -> void:
	var old := preview.dialogue
	var container := old.get_parent()
	old.free()
	preview.dialogue = load("res://scenes/ui/dialogue/cinematic_dialogue.tscn").instantiate()
	preview.dialogue.use_side_choices = side_layout
	preview.dialogue.right_portrait = load("res://art/characters/receptionist/portraits/receptionist_normal.png")
	preview.dialogue.right_source_region = Rect2(0.0, 0.0, 555.0, 885.0)
	container.add_child(preview.dialogue)
	await preview.dialogue.open_data({"lines": [{
		"speaker_side": "right", "two_person_dialogue": true,
		"text": "前面的通道已经打开了。\n准备好以后，我们就过去。", "typewriter_speed": 10.0, "blip": false,
		"choices": [{"text": "现在出发"}, {"text": "先看看四周"}, {"text": "再等一下"}],
	}]})


func record_choice_reveal(label: String) -> void:
	var view := preview.dialogue
	check(not view.buttons.visible, "Choices remain concealed until the dialogue is ready")
	var stamp := Time.get_ticks_usec()
	var samples_ms: Array[float] = []
	var records: Array[Array] = []
	view._complete_typewriter()
	var start := view.buttons.position
	check(DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_VISIBLE,
		"The native pointer becomes visible as the choices begin to slide in")
	var previous_x := start.x
	var moving_left := true
	for _i in 30:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := float(now - stamp) / 1000.0
		stamp = now
		samples_ms.append(ms)
		moving_left = moving_left and view.buttons.position.x <= previous_x + 0.001 and view.buttons.position.y == start.y
		previous_x = view.buttons.position.x
		records.append([Engine.get_process_frames(), ms, previous_x, view.buttons.position.y, view.side_choice_list.interactive])
	check(start.x >= 640.0 and moving_left and previous_x < 500.0 and view.side_choice_list.interactive,
		"Choice rows slide from beyond the right edge and settle at constant height")
	FileAccess.open(output.path_join(label + ".json"), FileAccess.WRITE).store_string(JSON.stringify(records, "\t"))
	var result := STATS.stats(samples_ms)
	samples.append({"name": label, "stats": result, "ui_visible": true})
	print("SAMPLE ", label, " ", JSON.stringify(result))


func press_choice(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)


func open_interrupt_sample() -> void:
	var view := preview.dialogue
	await view.open_data({"lines": [{
		"speaker_side": "right", "two_person_dialogue": true,
		"text": "前面的通道已经打开了。\n准备好以后，我们一起过去。",
		"typewriter_speed": 5.0, "blip": false,
	}]})
	view._process(87.5)
	await frames(3)


func check_typing_interrupt(mode: int) -> void:
	var view := preview.dialogue
	var stop := view.side_choice_list.interrupt_button
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	await open_interrupt_sample()
	check(stop.is_visible_in_tree() and DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_VISIBLE,
		"The red interrupt choice is clickable while the line is still typing")
	await sample("interrupt_%d_before" % mode, 45)
	var pressed := {"fragments": 0}
	await sample("interrupt_%d_first_click" % mode, 45, func():
		press_choice(stop)
		if is_instance_valid(view._interrupt_fragments):
			pressed.fragments = view._interrupt_fragments.get_child_count()
	)
	if OS.get_cmdline_user_args().has("--visual-only"):
		await create_timer(0.55).timeout
	check(int(pressed.fragments) == 16 and not view.visible and not is_instance_valid(view._interrupt_fragments),
		"Mouse click scatters only the visible letters, then releases the dialogue and debris")
	check(DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_HIDDEN,
		"Interrupt restores the pointer mode")
	await open_interrupt_sample()
	await snapshot("interrupt_%d_button" % mode)
	var origin := view.prompt_label.get_global_transform() * view.prompt_label.get_character_bounds(0).position
	press_choice(stop)
	await create_timer(0.12).timeout
	var scatter := view._interrupt_fragments
	check(is_instance_valid(scatter) and (scatter.get_child(0) as Label).global_position.y < origin.y,
		"The first glyph lifts away from the bottom text before it falls")
	await snapshot("interrupt_%d_scatter" % mode)
	await create_timer(0.48).timeout
	check(not view.visible and not is_instance_valid(scatter), "A repeated interrupt leaves no stale UI")


func check_side_choices(lab: Control) -> void:
	await check_choice_dot_profile()
	for mode in [1, 2]:
		await preview.rebuild(mode)
		await frames(55)
		var world_id := preview.world.get_instance_id()
		check(preview.ready_world and preview.world.rooms.size() == 4 and preview.world.enemy_root.get_child_count() == 8,
			"Choice comparison uses the populated four-room lab")
		for pass_name in ["A_before", "B_halftone", "A_after"]:
			var side_layout: bool = pass_name == "B_halftone"
			if side_layout:
				Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			await open_choice_sample(side_layout)
			if side_layout:
				await record_choice_reveal("choice_mode_%d_first_reveal" % mode)
				await snapshot("choice_mode_%d" % mode)
			else:
				preview.dialogue._complete_typewriter()
				await frames(8)
			await sample("choice_mode_%d_%s" % [mode, pass_name])
			preview.dialogue.close_without_signal()
			if side_layout:
				check(DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_HIDDEN,
					"Closing the choices restores the scene's previous pointer mode")
			check(not preview.dialogue.buttons.is_visible_in_tree() and is_instance_id_valid(world_id),
				"Closing a choice leaves the same test world active")
		await open_choice_sample(true)
		preview.dialogue.close_without_signal()
		await check_typing_interrupt(mode)
	await open_choice_sample(true)
	await record_choice_reveal("choice_repeated_reveal")
	var smoke: Node = preview.world.floor_root.get_node_or_null("FireExtinguisherSystem")
	if smoke != null:
		smoke.discharge(preview.world.player.global_position + Vector2(36, -24))
		check(not smoke.sources.is_empty(), "Production smoke remains active beneath the side choices")
		await sample("choice_production_smoke", 150)
		await snapshot("choice_production_smoke")
	var choice_id := preview.dialogue.get_instance_id()
	lab.queue_free()
	await frames(12)
	check(not is_instance_id_valid(choice_id), "Leaving the lab releases the choice view and its row art")
	check(DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_HIDDEN,
		"Exiting the active choice view restores the pointer mode without a close click")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	if not AudioServer.is_bus_mute(0) or AudioServer.get_driver_name() != "Dummy":
		AudioServer.set_bus_mute(0, true)
		check(false, "Private pre-entry mute and Dummy driver required")
		finish(); return
	if DisplayServer.get_name() == "headless":
		check(false, "Real Forward+ renderer required"); finish(); return
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	Engine.max_fps = 60
	create_timer(180.0, true, false, true).timeout.connect(func(): push_error("Dialogue camera validation timed out"); quit(2))
	await check_veil_profile()
	var lab: Control = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	lab.presentation_scene_path = "res://scenes/testing/CinematicDialoguePreview.tscn"
	root.add_child(lab)
	preview = lab.presentation
	preview.auto_start = false
	var receptionist_candidate := OS.get_cmdline_user_args().has("--receptionist-portraits")
	if receptionist_candidate:
		var started := Time.get_ticks_usec()
		var receptionist_scene := load(RECEPTIONIST_DIALOGUE_PATH) as PackedScene
		receptionist_load_ms = (Time.get_ticks_usec() - started) / 1000.0
		check(receptionist_scene != null, "Independent lab loads the receptionist dialogue and its imported textures")
		if receptionist_scene == null: finish(); return
		var original := preview.dialogue
		preview.dialogue = receptionist_scene.instantiate()
		original.get_parent().add_child(preview.dialogue)
		original.free()
	if receptionist_candidate or OS.get_cmdline_user_args().has("--external-view"):
		preview.dialogue.externally_driven = true
		external_controller = preload("res://scripts/ui/dialogue/dream_dialogue_controller.gd").new()
		root.add_child(external_controller)
	var deadline := Time.get_ticks_msec() + 100000
	while not preview.ready_world and Time.get_ticks_msec() < deadline: await process_frame
	check(preview.ready_world and is_instance_valid(preview.world.camera_3d), "GameTestLab presentation loads the real storage warehouse and gameplay Camera")
	if not preview.ready_world: finish(); return
	check(RenderingServer.get_current_rendering_method() == "forward_plus", "Preview retains the project's Forward+ renderer")
	check(get_root().get_node("SettingsManager").is_music_suppressed(), "Independent UI test suppresses background music")
	if OS.get_cmdline_user_args().has("--side-choices"):
		await check_side_choices(lab)
		finish()
		return
	await frames(60)
	baseline = await snapshot("warehouse_baseline")
	await sample("warehouse_A_before")
	if receptionist_candidate and not OS.get_cmdline_user_args().has("--visual-only"):
		await sample("warehouse_first_dialogue_open", 60, func(): start_external_line("left", "先在这里停一下。\n等我确认前面的通道。", &"normal"))
	else:
		await show_line("left")
	if receptionist_candidate: check_receptionist_state("normal")
	var img := await snapshot("warehouse_left_speaking")
	var text_pixels := 0
	for y in range(603, 670):
		for x in range(225, 1000):
			var color := img.get_pixel(x, y)
			if minf(color.r, minf(color.g, color.b)) > 0.75: text_pixels += 1
	check(text_pixels > 100, "First dialogue entrance actually renders its white text in the Camera image")
	var original_luma := 0.0
	var dim_luma := 0.0
	for y in range(220, 470, 4):
		for x in range(370, 910, 4):
			var a := baseline.get_pixel(x, y)
			var b := img.get_pixel(x, y)
			original_luma += a.r + a.g + a.b
			dim_luma += b.r + b.g + b.b
	check(original_luma > 1.0 and dim_luma < original_luma * 0.8, "Actual Camera confirms overall background darkening in the unobstructed central area")
	check(preview.dialogue.right_art.get_global_rect().position.y > preview.dialogue.character_art.get_global_rect().position.y, "Actual runtime uses the lower right-listener placement")
	await sample("warehouse_B_dialogue")
	await show_line("right", "好，我在这里等你。", &"talking" if receptionist_candidate else &"normal")
	await snapshot("warehouse_right_speaking")
	check(preview.dialogue.character_art.modulate.r < preview.dialogue.right_art.modulate.r, "Right speaker lights up while left listener dims")
	if receptionist_candidate:
		check_receptionist_state("talking")
		await sample("warehouse_receptionist_expression_change", 60, func(): start_external_line("right", "我、我没在数！", &"nervous"))
		check_receptionist_state("nervous")
		await snapshot("warehouse_receptionist_nervous")
	hide_line()
	await frames(12)
	await sample("warehouse_A_after")
	await snapshot("warehouse_closed")
	if OS.get_cmdline_user_args().has("--warehouse-only"):
		lab.queue_free()
		await frames(12)
		finish(); return
	for mode in [1, 2]:
		var old_world := preview.world.get_instance_id()
		await preview.rebuild(mode)
		await frames(60)
		check(not is_instance_id_valid(old_world) and preview.ready_world, "World reset disposes the previous scene in mode " + str(mode))
		check(preview.world.rooms.size() == 4 and preview.world.enemy_root.get_child_count() == 8 and preview.world.furniture_root.get_child_count() > 0, "Whitebox / production-art test keeps the same four-room layout, eight enemies and furniture")
		await sample("mode_%d_A_before" % mode)
		await show_line("left")
		await snapshot("mode_%d_left_speaking" % mode)
		await sample("mode_%d_B_dialogue" % mode)
		hide_line()
		await frames(12)
		await sample("mode_%d_A_after" % mode)
	await show_line("right" if receptionist_candidate else "left", "先在这里停一下。\n等我确认前面的通道。", &"normal")
	var smoke: Node = preview.world.floor_root.get_node_or_null("FireExtinguisherSystem")
	if smoke != null:
		smoke.discharge(preview.world.player.global_position + Vector2(36, -24))
		check(not smoke.sources.is_empty(), "Production smoke remains available beneath the dialogue overlay")
		await sample("production_art_smoke_dialogue", 150)
		await snapshot("production_art_smoke_dialogue")
	else:
		check(false, "Production smoke system exists for combined presentation")
	var old_dialogue := preview.dialogue.get_instance_id()
	var old_world := preview.world.get_instance_id()
	lab.queue_free()
	await frames(12)
	check(not is_instance_id_valid(old_dialogue) and not is_instance_id_valid(old_world), "Leaving the independent lab releases both dialogue and world")
	check(not get_root().get_node("SettingsManager").is_music_suppressed(), "Leaving the UI lab releases its temporary music suppression")
	finish()


func finish() -> void:
	var failures := checks.filter(func(row: Dictionary): return not row.pass).size()
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"pid": OS.get_process_id(), "renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(), "audio": AudioServer.get_driver_name(), "window": str(DisplayServer.window_get_size()), "logical_ui": "640x360", "native_world": true, "receptionist_scene_load_ms": receptionist_load_ms, "checks": checks, "samples": samples, "failures": failures, "scope": "Independent actual Camera preview, muted Dummy audio, minimized forced rendering, 60 fps cap; bounded A/B/A wall-clock samples, not whole-game performance certification."}, "\t"))
	print("CINEMATIC_CAMERA checks=", checks.size(), " failures=", failures)
	quit(1 if failures else 0)
