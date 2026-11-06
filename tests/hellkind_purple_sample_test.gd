extends SceneTree
## Real Camera acceptance for the standalone purple sample. No production writes.
## Run natively with isolated APPDATA. Optional: -- --sample-perf for 3 x 5s A/B/A.
## --interaction-check reruns only initialization, UI and shader restoration checks.
const OUT := "res://.runtime/hellkind_purple_sample_20261103/native640_full_validation"
const SCENE := "res://scenes/preview/hellkind_purple_sample.tscn"
const ORANGE := Color(0.8509804, 0.4196078, 0.0941176, 1.0)
var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []
var orange_counts: Dictionary = {}
var performance_runs: Array[Dictionary] = []
var material_evidence: Dictionary = {}
var lab
var _world_viewport_id := 0
var _done := false
var interaction_only := OS.get_cmdline_user_args().has("--interaction-check")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PURPLE_CHECK ", label, " ", ok)
	if not ok:
		failures.append(label)
		push_error(label)

func frames(count: int) -> void:
	for i in count:
		await process_frame

func draw() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func capture(name: String) -> Image:
	var picture: Image = await draw()
	var path := OUT.path_join(name + ".png")
	check(picture.save_png(path) == OK, "Camera capture " + name)
	captures.append(path)
	return picture

func orange_pixels(picture: Image) -> int:
	var count := 0
	for y in picture.get_height():
		for x in picture.get_width():
			var c := picture.get_pixel(x, y)
			if absf(c.r - ORANGE.r) < 0.035 and absf(c.g - ORANGE.g) < 0.035 and absf(c.b - ORANGE.b) < 0.035:
				count += 1
	return count

func pixel_difference(a: Image, b: Image) -> int:
	if a.get_size() != b.get_size():
		return -1
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.03:
				count += 1
	return count

func hide_sample_ui() -> void:
	lab.panel.hide()
	lab.hud.hide()
	lab.sample_ui.hide()
	var monitor := root.get_node_or_null("PerformanceMonitor")
	if monitor is CanvasLayer:
		monitor.hide()

func key_press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func check_live_materials(label: String) -> void:
	var reflection = lab.world.get_node_or_null("FloorReflections")
	check(reflection != null and not reflection.floor_materials.is_empty(), label + " retains floor reflection materials")
	if reflection == null:
		return
	var clean_registered := 0
	var weather_registered := 0
	var weather_installed := 0
	var active := 0
	var living_surfaces := 0
	for material in reflection.floor_materials:
		if lab.clean_floor_materials.has(material):
			clean_registered += 1
		if lab.weather_materials.has(material):
			weather_registered += 1
		if material.shader.code.contains("hk_sample_weathering"):
			weather_installed += 1
	for record in reflection.surfaces:
		var mesh = record.node.get_ref()
		if not is_instance_valid(mesh):
			continue
		living_surfaces += 1
		if mesh.get_active_material(int(record.index)) == record.material:
			active += 1
	check(clean_registered == reflection.floor_materials.size(), label + " keeps original floor Material identities in clean-floor registry")
	check(weather_registered == 0 and weather_installed == 0, label + " excludes every authored floor from added weathering")
	check(living_surfaces > 0 and active == living_surfaces, label + " reflection records remain the actual mesh materials")
	var pairs_valid := true
	for pair in lab._weather_pairs:
		# The visibility pass can wrap the installed weather shader in place.
		var current: Shader = pair.material.shader
		var wrapper: Dictionary = lab.visibility_surfaces._records.get(pair.material, {})
		var matches_wrapper: bool = wrapper.get("original") == pair.installed_shader and wrapper.get("installed") == current
		if current != pair.installed_shader and not matches_wrapper:
			pairs_valid = false
	check(pairs_valid and not lab._weather_pairs.is_empty(), label + " retains installed private shaders on owner materials")
	material_evidence[label] = {"floor_materials": reflection.floor_materials.size(), "clean_registered": clean_registered, "weather_registered": weather_registered, "weather_installed": weather_installed, "active_surfaces": active, "living_surfaces": living_surfaces}

func check_actor_resolution(label: String) -> void:
	# Existing character atlas/depth viewports are part of the formal renderer.
	# Only the rejected additional color/mask/composite route must be absent.
	var extra_actor_targets := root.find_children("Actor*640", "SubViewport", true, false)
	var composites := root.find_children("PurpleActorComposite", "CanvasLayer", true, false)
	var mask_proxies := root.find_children("UnlitActorMaskCarriers", "", true, false)
	check(extra_actor_targets.is_empty() and composites.is_empty() and mask_proxies.is_empty(), label + " has no added actor color/mask targets or composite")
	check(lab.world.get_viewport() == lab.display.world_viewport and lab.display.world_viewport.get_instance_id() == _world_viewport_id, label + " renders through the same existing world viewport")
	var expected_fov: float = lab.camera_zoom_fov if lab.style_index >= 3 else lab.original_camera_fov
	check(is_equal_approx(lab.world.authoritative_camera_fov, expected_fov) and absf(lab.world.camera_3d.fov - expected_fov) < 0.01, label + " applies the selected FOV to the actual main Camera")
	var expected_size := Vector2i(320, 180) if lab.style_index == 2 else Vector2i(640, 360)
	if lab.style_index == 4: expected_size = Vector2i(DisplayServer.window_get_size())
	check(lab.display.world_viewport.size == expected_size, label + " uses the selected native resolution for the entire world")
	if lab.style_index == 3:
		check(lab.camera_zoom_fov > 0.0 and absf(lab.camera_zoom_fov - lab.original_camera_fov) < 3.0, label + " keeps calibrated FOV within 3 degrees of the original view")

func reflection_views() -> Dictionary:
	var result: Dictionary = {}
	var reflection = lab.world.get_node_or_null("FloorReflections")
	if reflection != null:
		for material in reflection.floor_materials:
			result[material.get_instance_id()] = material.get_shader_parameter("sample_reflection_view")
	return result

func restore_expectations() -> Array:
	# Weather restores the live pre-weather shader first. The floor-reflection
	# owner then legitimately restores its own earlier shader on actor records.
	var result: Array = []
	var reflection = lab.world.get_node_or_null("FloorReflections")
	for pair in lab._weather_pairs:
		var final_shader: Shader = pair.original_shader
		if reflection != null:
			for record in reflection.actor_shaders:
				if record.material.get_ref() == pair.material:
					final_shader = record.shader
					break
		result.append({"material": pair.material, "final_shader": final_shader, "installed_shader": pair.installed_shader})
	return result

func check_restored_pairs(pairs: Array, label: String) -> void:
	var restored := true
	for pair in pairs:
		if pair.material.shader != pair.final_shader or pair.material.shader == pair.installed_shader:
			restored = false
		if pair.material.shader != null and pair.material.shader.code.contains("hk_sample_weathering"):
			restored = false
	check(not pairs.is_empty() and restored, label)

func check_sample_controls() -> void:
	# Input.parse_input_event accepts window pixels. Control transforms describe
	# the logical canvas, so include the viewport's final stretch transform.
	lab.sample_ui.show()
	for item in [[KEY_1, 0], [KEY_2, 1], [KEY_3, 2], [KEY_4, 3], [KEY_5, 4], [KEY_2, 1]]:
		await key_press(item[0])
		check(lab.style_index == item[1], "Keyboard %d switches to style %d" % [int(item[0]) - KEY_0, int(item[1])])
		check_actor_resolution("Keyboard style %d" % item[1])
		if lab.environment_halftone != null:
			check(lab.environment_halftone.enabled == (item[1] == 4), "Camera halftone follows the fifth style")
			if item[1] == 4:
				await key_press(KEY_F11)
				check(not lab.environment_halftone.enabled and lab.world.player_depth_bridge.actor_sprite.material_override == lab.character_inks.actor_inks, "F11 disables only the environment effect")
				await key_press(KEY_F11)
				check(lab.environment_halftone.enabled, "F11 restores the environment effect")
	await key_press(KEY_F1)
	check(not lab.sample_ui.visible, "F1 hides sample controls")
	await key_press(KEY_F1)
	check(lab.sample_ui.visible, "F1 restores sample controls")
	await frames(4)
	var button: Button = lab.style_buttons[3]
	var ui_point: Vector2 = button.get_viewport().get_final_transform() * button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = ui_point
	motion.global_position = ui_point
	Input.parse_input_event(motion)
	await frames(2)
	var click := InputEventMouseButton.new()
	click.position = ui_point
	click.global_position = ui_point
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	var shots_before_ui: int = lab.shot_count
	Input.parse_input_event(click)
	for i in 18:
		await physics_frame
	click = InputEventMouseButton.new()
	click.position = ui_point
	click.global_position = ui_point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	Input.parse_input_event(click)
	await frames(4)
	check(lab.style_index == 3, "Mouse click on fourth button switches to the calibrated native-640 mode")
	check(lab.shot_count == shots_before_ui, "Clicking or holding top controls never fires the weapon")
	await key_press(KEY_4)
	await frames(4)
	check_actor_resolution("Controls capture")
	await capture("08_controls")
	hide_sample_ui()

func interaction_check() -> void:
	await check_sample_controls()
	var old_id: int = lab.world.get_instance_id()
	var old_pairs := restore_expectations()
	await lab.rebuild()
	while not lab.sample_ready or lab.busy:
		await process_frame
	check(not is_instance_id_valid(old_id), "Rebuild frees previous world")
	_world_viewport_id = lab.display.world_viewport.get_instance_id()
	check_restored_pairs(old_pairs, "Rebuild respects weather and reflection owners' shader restoration")
	old_pairs.clear()
	check_live_materials("Interaction-only rebuilt room")
	check_actor_resolution("Interaction-only rebuilt room")
	var final_id: int = lab.world.get_instance_id()
	var exit_pairs := restore_expectations()
	lab.free()
	await frames(3)
	check(not is_instance_id_valid(final_id), "Sample exit frees the world")
	check_restored_pairs(exit_pairs, "Exit respects owner restoration and leaves no installed weather shader")
	exit_pairs.clear()
	report_and_quit(0 if failures.is_empty() else 1)

func report_and_quit(code: int) -> void:
	if _done:
		return
	_done = true
	# The original world releases its owned BGM using a 120 ms fade. Let that
	# finish before terminating the engine, including uncapped auxiliary views.
	await create_timer(0.25, true, false, true).timeout
	for action in ["move_left", "move_right", "move_up", "move_down", "attack"]:
		if InputMap.has_action(action):
			Input.action_release(action)
	var result := {
		"checks": checks, "failures": failures, "native_camera": DisplayServer.get_name() != "headless",
		"gpu": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info(),
		"captures": captures, "orange_counts": orange_counts, "performance_runs": performance_runs, "material_evidence": material_evidence,
		"interaction_only": interaction_only,
		"scope": "Standalone production-art native-640 lab. Default style 4 renders the entire world at 640x360 with the main Camera calibrated toward a 32px body target, near the original 35-degree view. Style 3 is the historical 320x180 comparison. No added actor composite. Actual body pixel height is measured by the separate targeted probe. Authored floors excluded from added wear. Same-pose comparisons, real motion/fire, blood, lamps, UI and lifecycle. Movement image readbacks are not performance samples. Optional A/B/A is a short controlled lab sample, not whole-game 60 FPS acceptance."
	}
	if interaction_only:
		result.scope = "Targeted follow-up only: initialized production-art lab, actual keyboard/mouse controls, top-panel firing gate, and owner-correct shader restoration on rebuild/exit. No repeat of previously passed walking, blood, lighting or performance coverage."
	var file := FileAccess.open(OUT.path_join("interaction_report.json" if interaction_only else "report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	print("PURPLE_RESULT ", checks, " checks; ", failures.size(), " failures")
	quit(code)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(OUT.path_join("walk"))
	create_timer(360, true, false, true).timeout.connect(func():
		check(false, "Sample validation timeout")
		report_and_quit(2))
	var native := DisplayServer.get_name() != "headless"
	check(native, "Actual GPU renderer required for Camera acceptance")
	if not native:
		report_and_quit(1)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(-30000, -30000))
	AudioServer.set_bus_mute(0, true)
	var scene = load(SCENE)
	check(scene != null, "Standalone sample scene loads")
	if scene == null:
		report_and_quit(1)
		return
	lab = scene.instantiate()
	lab.output_root = OUT.path_join("performance")
	root.add_child(lab)
	while not lab.sample_ready or lab.busy:
		await process_frame
	await frames(90)
	_world_viewport_id = lab.display.world_viewport.get_instance_id()
	hide_sample_ui()
	check(not lab.world.persist_profile, "Campaign progress persistence disabled")
	check(not lab.world.lab_whitebox, "Actual production art in lab")
	check(lab.world.furniture_root.get_child_count() > 0, "Existing furniture retained")
	check(lab.world.enemy_root.get_child_count() > 0, "Enemy actors retained")
	check(lab.weather_binding_count > 0 and lab.weather_materials.size() > 0, "Local environment weathering materials installed")
	check(lab.display.world_viewport != root, "World renderer separate from root UI")
	check(not lab.display.world_viewport.is_ancestor_of(lab.sample_ui), "Sample controls outside world effects")
	check(lab.world.player.get_script().resource_path == "res://scripts/testing/lab_player.gd", "Original lab player authority retained")
	check_live_materials("Initial room")
	check(lab.style_index == 4 and not lab.display.selective_enabled and not lab.display.palette_enabled, "Default two-ink comparison disables pixel mode and palette")
	check(not lab._lamps_enabled and not lab.retro_material.get_shader_parameter("enabled"), "Default comparison has no indoor lighting or purple post")
	check(lab.world.player_depth_bridge.actor_sprite.material_override == lab.character_inks.actor_inks, "Default comparison styles the original player depth carrier")
	check_actor_resolution("Initial room")
	lab.toggle_lamps() # Preserve the older comparison fixtures below.
	if interaction_only:
		await interaction_check()
		return

	# The world is frozen only for direct same-pose images, never for movement tests.
	lab.apply_style(0)
	await frames(4)
	var old_process: int = lab.world.process_mode
	lab.world.process_mode = Node.PROCESS_MODE_DISABLED
	var start_camera: Transform3D = lab.world.camera_3d.global_transform
	var start_player: Vector2 = lab.world.player.global_position
	var baseline: Image
	var purple: Image
	for style in [0, 1, 2, 3]:
		lab.apply_style(style)
		await frames(4)
		check(lab.style_index == style, "Style %d selected" % style)
		var expected := Vector2i(320, 180) if style == 2 else Vector2i(640, 360)
		check(lab.display.world_viewport.size == expected, "Style %d true world resolution" % style)
		check_actor_resolution("Same-pose style %d" % style)
		check(lab.world.player.global_position == start_player, "Style %d keeps authoritative player position" % style)
		if style < 3:
			check(lab.world.camera_3d.global_transform == start_camera, "Style %d keeps the original Camera transform" % style)
		else:
			check(lab.world.camera_3d.global_transform.origin.is_finite() and lab.world.camera_3d.projection == Camera3D.PROJECTION_PERSPECTIVE and absf(lab.world.camera_3d.fov - lab.original_camera_fov) < 3.0, "Native-640 style keeps a valid perspective Camera with only small FOV calibration")
		var picture: Image = await capture(["00_current", "01_purple", "02_purple_lowres", "09_native640"][style])
		if style == 0:
			baseline = picture
		elif style == 1:
			purple = picture
	check(pixel_difference(baseline, purple) > 1000, "Purple style changes real Camera output")
	lab.apply_style(0)
	await frames(4)
	var restored: Image = await draw()
	check(pixel_difference(baseline, restored) < 64, "Baseline style returns to same-pose original image")
	lab.world.process_mode = old_process
	lab.apply_style(3)
	hide_sample_ui()
	await frames(6)
	var reflection_before_walk := reflection_views()

	# Actual action input, not teleport-based visual motion.
	var before_walk: Vector2 = lab.world.player.global_position
	Input.action_press("move_right")
	for i in 12:
		await physics_frame
	Input.action_release("move_right")
	check(lab.world.player.global_position.distance_to(before_walk) > 2.0, "WASD moves the authoritative player")
	var walk_start: Vector2 = lab.world.player.global_position
	var walk_max_distance := 0.0
	var directions := ["move_right", "move_down", "move_left", "move_up"]
	for i in 48:
		var action: String = directions[int(i / 12)]
		if i % 12 == 0:
			if i > 0:
				Input.action_release(directions[int(i / 12) - 1])
			Input.action_press(action)
		for tick in 3:
			await physics_frame
		walk_max_distance = maxf(walk_max_distance, lab.world.player.global_position.distance_to(walk_start))
		var frame_image: Image = await draw()
		frame_image.save_png(OUT.path_join("walk/%03d.png" % i))
	for action in directions:
		Input.action_release(action)
	check(walk_max_distance > 8.0, "48-frame Camera sequence contains real player movement")
	await frames(12)
	var reflection_after_walk := reflection_views()
	var updated_views := 0
	for material_id in reflection_before_walk:
		if reflection_after_walk.has(material_id) and reflection_before_walk[material_id] != reflection_after_walk[material_id]:
			updated_views += 1
	check(updated_views > 0, "Actual movement updates reflection view matrices on the unchanged floor materials")
	material_evidence["moving_reflection_views_updated"] = updated_views
	check_live_materials("After actual walk")
	check_actor_resolution("After actual walk")

	# F2 must work with existing material owners; do not run a repair scan here.
	var start_station: int = lab.station.selected
	for i in lab.station.item_count:
		var previous_station: int = lab.station.selected
		await key_press(KEY_F2)
		await frames(20)
		check(lab.station.selected == (previous_station + 1) % lab.station.item_count, "F2 switches room %d" % i)
		check_live_materials("F2 room %d" % lab.station.selected)
		check_actor_resolution("F2 room %d" % lab.station.selected)
	check(lab.station.selected == start_station, "F2 cycles back to starting room")

	lab.teleport(1)
	await frames(10)
	lab.world.player.set_meta(&"aim_direction_override", Vector2.RIGHT)
	var shots_before: int = lab.shot_count
	lab.world.player.set_meta(&"force_weapon_attack", true)
	for i in 36:
		await physics_frame
	lab.world.player.remove_meta(&"force_weapon_attack")
	check(lab.shot_count > shots_before, "Real equipped weapon fires")
	await capture("03_after_firing")
	var orange_before := orange_pixels(await draw())
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		lab.world.player.set_meta(&"aim_direction_override", direction)
		lab.trigger("blood")
	for i in 90:
		await physics_frame
	for style in [1, 2, 3]:
		lab.apply_style(style)
		await frames(5)
		var blood_picture: Image = await capture({1: "04_blood_purple", 2: "05_blood_lowres", 3: "10_blood_native640"}[style])
		var count := orange_pixels(blood_picture)
		orange_counts[str(style)] = count
		check(count > 16, "Style %d preserves visible orange blood (#D96B18)" % style)
	orange_counts["before_spawn"] = orange_before
	check(int(orange_counts["3"]) > orange_before + 8, "Actual blood adds orange pixels beyond the pre-spawn image in calibrated native-640 mode")
	lab.world.player.remove_meta(&"aim_direction_override")
	lab.apply_style(3)
	await frames(5)

	# Leave the world processing: managers may refresh lights every frame.
	check(lab.world.process_mode != Node.PROCESS_MODE_DISABLED, "Lamp acceptance runs with the real world processing")
	await frames(15)
	var light_on: Image = await draw()
	await key_press(KEY_F5)
	await frames(20)
	var light_off: Image = await capture("06_lamps_off")
	check(pixel_difference(light_on, light_off) > 100, "F5 changes the actual Camera while world light managers keep running")
	await key_press(KEY_F5)
	await frames(20)
	var light_restored: Image = await draw()
	check(pixel_difference(light_on, light_restored) < pixel_difference(light_on, light_off), "F5 restores the running world's rendered lighting")
	await frames(6)
	var old_id: int = lab.world.get_instance_id()
	var old_weather_pairs := restore_expectations()
	await lab.rebuild()
	while not lab.sample_ready or lab.busy:
		await process_frame
	check(not is_instance_id_valid(old_id), "Rebuild frees previous world")
	_world_viewport_id = lab.display.world_viewport.get_instance_id()
	check_restored_pairs(old_weather_pairs, "Rebuild restores each previous owner material's original shader")
	old_weather_pairs.clear()
	check(lab.weather_binding_count > 0, "Rebuild reinstalls local sample materials")
	check(not lab.world.persist_profile, "Rebuilt sample remains isolated from campaign progress")
	hide_sample_ui()
	lab.apply_style(3)
	await frames(30)
	await capture("07_rebuilt_purple")
	check_live_materials("Rebuilt room")
	check_actor_resolution("Rebuilt room")

	# Exercise the actual controls rather than calling the style methods here.
	await check_sample_controls()

	if OS.get_cmdline_user_args().has("--sample-perf"):
		await sample_performance()
	var last_world_id: int = lab.world.get_instance_id()
	var exit_weather_pairs := restore_expectations()
	lab.free()
	await frames(3)
	check(not is_instance_id_valid(last_world_id), "Sample exit frees the world")
	check_restored_pairs(exit_weather_pairs, "Sample exit restores original shaders on all retained owner material references")
	exit_weather_pairs.clear()
	report_and_quit(0 if failures.is_empty() else 1)

func sample_performance() -> void:
	for style in [2, 3, 2]:
		lab.checks.uncapped.button_pressed = true
		await lab.rebuild()
		while not lab.sample_ready or lab.busy:
			await process_frame
		lab.apply_style(style)
		lab.duration.value = 5
		lab.scenario.select(3)
		hide_sample_ui()
		await lab.toggle_recording()
		lab.recorder.metadata["sample_style"] = style
		lab.recorder.metadata["comparison_scope"] = "A/B/A: historical 320x180 / entire-world native 640x360 with small main-Camera calibration / historical 320x180. Same lab seed/population/settings and 5s real firing plus smoke workload. Resolution and small FOV differences change rendering workload. Separate rebuilds; no deterministic physics or whole-game FPS claim."
		while lab.recorder.active:
			await process_frame
		var report_path: String = lab.last_export.path_join("report.json")
		var result = JSON.parse_string(FileAccess.get_file_as_string(report_path))
		check(result is Dictionary and int(result.get("all_sampled", {}).get("frames", 0)) > 20, "Style %d benchmark produces raw frames and summary" % style)
		check(lab.shot_count > 0 and lab.event_history.has("smoke"), "Style %d benchmark actually fires and triggers smoke" % style)
		if result is Dictionary:
			performance_runs.append({"style": style, "path": lab.last_export, "shots": lab.shot_count, "all_sampled": result.get("all_sampled", {})})
