extends SceneTree
## Independent native-Camera evidence for the sample's whole-world 640x360 mode.
## Run with isolated APPDATA; this test never installs an actor/composite viewport.
const OUT := "res://.runtime/hellkind_purple_sample_20261103/native640_validation"
const SCENE := "res://scenes/preview/hellkind_purple_sample.tscn"
const TARGET_HEIGHT := 32.0
var lab
var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []
var measurements: Dictionary = {}
var _done := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("ZOOM_CHECK ", label, " ", ok)
	if not ok:
		failures.append(label)
		push_error(label)

func frames(count: int) -> void:
	for i in count:
		await process_frame

func draw_root() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func draw_world() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return lab.display.world_viewport.get_texture().get_image()

func capture(name: String) -> void:
	var picture: Image = await draw_root()
	var path := OUT.path_join(name + ".png")
	check(picture.save_png(path) == OK, "Actual main-Camera screenshot " + name)
	captures.append(path)

func hide_test_ui() -> void:
	lab.panel.hide()
	lab.hud.hide()
	lab.sample_ui.hide()
	var monitor := root.get_node_or_null("PerformanceMonitor")
	if monitor is CanvasLayer:
		monitor.hide()

func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func opaque_bounds(picture: Image) -> Rect2i:
	var lo := picture.get_size()
	var hi := Vector2i(-1, -1)
	for y in picture.get_height():
		for x in picture.get_width():
			if picture.get_pixel(x, y).a <= 0.05:
				continue
			lo.x = mini(lo.x, x)
			lo.y = mini(lo.y, y)
			hi.x = maxi(hi.x, x)
			hi.y = maxi(hi.y, y)
	return Rect2i(lo, hi - lo + Vector2i.ONE) if hi.x >= 0 else Rect2i()

## Independent of the controller's calibration helper: project opaque texture
## pixel EDGES through the actual Sprite3D transform and actual main Camera.
## WeaponRoot has its own capture and is absent from this body texture.
func projected_body() -> Dictionary:
	var bridge = lab.world.player_depth_bridge
	var sprite: Sprite3D = bridge.actor_sprite
	var camera: Camera3D = lab.world.camera_3d
	var picture: Image = bridge.render_viewport.get_texture().get_image()
	var opaque := opaque_bounds(picture)
	if not opaque.has_area():
		return {"height": 0.0, "width": 0.0, "rect": Rect2(), "source_rect": opaque}
	var half_size := Vector2(picture.get_size()) * 0.5
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for x in [opaque.position.x, opaque.end.x]:
		for y in [opaque.position.y, opaque.end.y]:
			var local := Vector3(float(x) - half_size.x, half_size.y - float(y), 0.0) * sprite.pixel_size
			var screen := camera.unproject_position(sprite.to_global(local))
			low.x = minf(low.x, screen.x)
			low.y = minf(low.y, screen.y)
			high.x = maxf(high.x, screen.x)
			high.y = maxf(high.y, screen.y)
	return {"height": high.y - low.y, "width": high.x - low.x,
		"rect": Rect2(low, high - low), "source_rect": opaque,
		"capture_size": picture.get_size(), "world_size": lab.display.world_viewport.size,
		"fov": camera.fov, "sprite_pixel_size": sprite.pixel_size}

func check_original_actor_path(label: String) -> void:
	var forbidden: Array[String] = []
	for node in lab.find_children("*", "", true, false):
		var script: Script = node.get_script()
		var helper := script != null and script.resource_path.ends_with("hellkind_actor_resolution.gd")
		if helper or node.name in [&"ActorColor640", &"ActorWhite640", &"ActorBlack640", &"PurpleActorComposite", &"UnlitActorMaskCarriers"]:
			forbidden.append(str(node.get_path()))
	check(forbidden.is_empty(), label + " has no actor auxiliary render/composite nodes")
	var bridge = lab.world.player_depth_bridge
	check(bridge.character_projection, label + " keeps the original character depth bridge")
	check(bridge.actor_sprite.billboard == BaseMaterial3D.BILLBOARD_DISABLED and bridge.actor_sprite.centered and bridge.actor_sprite.offset == Vector2.ZERO, label + " body projection matches the authored Sprite3D plane")
	check(bridge.render_root.find_child("WeaponRoot", true, false) == null and is_instance_valid(bridge.weapon_capture_root), label + " body measurement excludes held weapon")
	check(not bridge.actor_sprite.no_depth_test, label + " original body still receives world occlusion")

func diff_bounds(a: Image, b: Image, roi: Rect2) -> Dictionary:
	var from := Vector2i(roi.position.floor()).max(Vector2i.ZERO)
	var to := Vector2i(roi.end.ceil()).min(a.get_size())
	var lo := a.get_size()
	var hi := Vector2i(-1, -1)
	var count := 0
	for y in range(from.y, to.y):
		for x in range(from.x, to.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) <= 0.015:
				continue
			count += 1
			lo.x = mini(lo.x, x)
			lo.y = mini(lo.y, y)
			hi.x = maxi(hi.x, x)
			hi.y = maxi(hi.y, y)
	var bounds := Rect2i(lo, hi - lo + Vector2i.ONE) if count > 0 else Rect2i()
	return {"pixels": count, "height": bounds.size.y, "width": bounds.size.x, "rect": bounds}

## Hide/show only the ORIGINAL body to measure actual native raster pixels.
## World processing is already frozen by the caller; its shadows are unchanged.
## A paused reflection target cannot introduce reflected-body differences.
func raster_body(label: String, projection: Dictionary) -> Dictionary:
	var sprite: Sprite3D = lab.world.player_depth_bridge.actor_sprite
	var original_visible := sprite.visible
	var reflection = lab.world.get_node_or_null("FloorReflections")
	var reflection_mode := -1
	if is_instance_valid(reflection) and is_instance_valid(reflection.viewport):
		reflection_mode = reflection.viewport.render_target_update_mode
		reflection.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sprite.visible = true
	await frames(3)
	var shown: Image = await draw_world()
	sprite.visible = false
	await frames(3)
	var hidden: Image = await draw_world()
	sprite.visible = original_visible
	if reflection_mode >= 0 and is_instance_valid(reflection) and is_instance_valid(reflection.viewport):
		reflection.viewport.render_target_update_mode = reflection_mode
	var expected_size := Vector2i(320, 180) if lab.style_index == 2 else Vector2i(640, 360)
	check(shown.get_size() == expected_size and hidden.get_size() == shown.get_size(), label + " difference images use the selected native world resolution")
	check(shown.save_png(OUT.path_join(label + "_body_on_world.png")) == OK, label + " saves native body-on image")
	check(hidden.save_png(OUT.path_join(label + "_body_off_world.png")) == OK, label + " saves native body-off image")
	var result := diff_bounds(shown, hidden, (projection.rect as Rect2).grow(3.0))
	await frames(3)
	return result

func check_live_fov(label: String) -> void:
	check(lab.display.world_viewport.size == Vector2i(640, 360), label + " renders the whole world at native 640x360")
	check(absf(lab.world.camera_3d.fov - float(lab.camera_zoom_fov)) < 0.02, label + " main Camera retains calibrated FOV")
	check(absf(lab.world.authoritative_camera_fov - float(lab.camera_zoom_fov)) < 0.02, label + " authoritative FOV agrees with main Camera")
	check(absf(float(lab.camera_zoom_fov) - 35.0) < 3.0, label + " calibrated FOV stays within 3 degrees of the original view")

func report_and_quit(code: int) -> void:
	if _done:
		return
	_done = true
	# Allow the original world's owned BGM fade to finish before engine exit.
	await create_timer(0.25, true, false, true).timeout
	for action in ["move_right", "move_down", "move_left", "move_up"]:
		Input.action_release(action)
	var result := {"checks": checks, "failures": failures, "captures": captures, "measurements": measurements,
		"native_camera": DisplayServer.get_name() != "headless", "gpu": RenderingServer.get_video_adapter_name(),
		"scope": "Independent whole-world native-640 sample. Original body alpha projected through actual main Camera, with 30-34px projected body and 28-36 native raster rows as acceptance bands. Main-world hide/show differences compare historical 320x180 with default 640x360; Camera stays near original 35-degree view. Real input walk, F2, rebuild and release. Frozen pose/reflection pause only for image comparison. No auxiliary actor renderer, no performance or whole-game acceptance claim."}
	var file := FileAccess.open(OUT.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	print("ZOOM_RESULT ", checks, " checks; ", failures.size(), " failures")
	quit(code)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT.path_join("walk"))
	create_timer(240.0, true, false, true).timeout.connect(func():
		if not _done:
			check(false, "Native-640 Camera validation timeout")
			report_and_quit(2))
	check(DisplayServer.get_name() != "headless", "Native renderer required")
	if DisplayServer.get_name() == "headless":
		report_and_quit(1)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(-30000, -30000))
	AudioServer.set_bus_mute(0, true)
	lab = load(SCENE).instantiate()
	root.add_child(lab)
	while not lab.sample_ready or lab.busy:
		await process_frame
	lab.apply_style(3)
	lab.toggle_lamps()
	await frames(60)
	check(lab.style_index == 3, "Fourth style selects whole-world native 640x360")
	check(not lab.world.persist_profile, "Sample never persists campaign progress")
	check_original_actor_path("Initial sample")
	hide_test_ui()
	var original_process: int = lab.world.process_mode
	lab.world.process_mode = Node.PROCESS_MODE_DISABLED
	var player_position: Vector2 = lab.world.player.global_position
	var body_pixel_size: float = lab.world.player_depth_bridge.actor_sprite.pixel_size
	var capture_size: Vector2i = lab.world.player_depth_bridge.render_viewport.size
	for style in [2, 3]:
		lab.apply_style(style)
		lab.world._update_camera_and_actor_projection(0.0)
		lab.world.player_depth_bridge._process(0.0)
		await frames(5)
		await RenderingServer.frame_post_draw
		var projection := projected_body()
		var name := "00_lowres" if style == 2 else "01_native640"
		measurements[name] = projection
		measurements[name + "_raster"] = await raster_body(name, projection)
		check(projection.height > 0.0, name + " has nonempty original body alpha")
		check(lab.world.player.global_position == player_position and lab.world.player_depth_bridge.actor_sprite.pixel_size == body_pixel_size and lab.world.player_depth_bridge.render_viewport.size == capture_size, name + " preserves player art size, original actor capture and physics position")
		if style == 2:
			check(absf(lab.world.camera_3d.fov - 35.0) < 0.02 and lab.display.world_viewport.size == Vector2i(320, 180), "Historical low-resolution reference uses original 35 degree Camera at 320x180")
		else:
			check(projection.height >= 30.0 and projection.height <= 34.0, "Independent body alpha projection reaches 30-34 native pixels")
			var source_body_height: int = projection.source_rect.size.y
			var body_texel_scale := float(projection.height) / maxf(float(source_body_height), 1.0)
			measurements["native_body_to_source_texel_height_ratio"] = body_texel_scale
			check(source_body_height > 0 and absf(body_texel_scale - 1.0) <= 0.05, "Native body projection preserves approximately one rendered pixel per authored body texel")
			var raster: Dictionary = measurements[name + "_raster"]
			check(raster.height >= 28 and raster.height <= 36 and raster.pixels > 64, "Original body occupies about 32 ACTUAL native raster rows")
			check_live_fov("Frozen native-640 view")
		await capture(name)
	var projected_ratio := float(measurements["01_native640"].height) / maxf(float(measurements["00_lowres"].height), 0.001)
	var raster_ratio := float(measurements["01_native640_raster"].height) / maxf(float(measurements["00_lowres_raster"].height), 1.0)
	measurements["native640_to_lowres_projected_height_ratio"] = projected_ratio
	measurements["native640_to_lowres_raster_height_ratio"] = raster_ratio
	check(projected_ratio >= 1.7 and projected_ratio <= 2.3, "Native projected body height roughly doubles from resolution plus small FOV calibration")
	check(raster_ratio >= 1.6 and raster_ratio <= 2.4, "Actual raster body height roughly doubles independently of display scaling")
	lab.world.process_mode = original_process
	await frames(6)

	var walk_start: Vector2 = lab.world.player.global_position
	var maximum_distance := 0.0
	var directions := ["move_right", "move_down", "move_left", "move_up"]
	for i in 48:
		if i % 12 == 0:
			if i > 0:
				Input.action_release(directions[int(i / 12) - 1])
			Input.action_press(directions[int(i / 12)])
		for tick in 3:
			await physics_frame
		maximum_distance = maxf(maximum_distance, lab.world.player.global_position.distance_to(walk_start))
		var picture: Image = await draw_root()
		check(picture.save_png(OUT.path_join("walk/%03d.png" % i)) == OK, "Live Camera walk frame %02d" % i)
	for action in directions:
		Input.action_release(action)
	check(maximum_distance > 8.0, "48-frame sequence includes actual player movement")
	measurements["walk_max_gameplay_distance"] = maximum_distance
	check_live_fov("After live movement")
	await capture("02_after_walk")
	for room in 4:
		var previous_station: int = lab.station.selected
		await press_key(KEY_F2)
		await frames(8)
		check(lab.station.selected != previous_station, "F2 changes room %d" % room)
		check_live_fov("F2 room %d" % room)
		check_original_actor_path("F2 room %d" % room)
		await capture("room_%d" % room)
	var old_world_id: int = lab.world.get_instance_id()
	await lab.rebuild()
	while not lab.sample_ready or lab.busy:
		await process_frame
	await frames(30)
	hide_test_ui()
	check(not is_instance_id_valid(old_world_id), "Rebuild releases previous world")
	check_live_fov("Rebuilt sample")
	check_original_actor_path("Rebuilt sample")
	await RenderingServer.frame_post_draw
	measurements["rebuilt_body"] = projected_body()
	check(float(measurements.rebuilt_body.height) >= 30.0 and float(measurements.rebuilt_body.height) <= 34.0, "Rebuild recalibrates the original body to 30-34 native pixels")
	await capture("03_rebuilt_native640")
	lab.sample_ui.show()
	await capture("04_controls")
	var last_world_id: int = lab.world.get_instance_id()
	lab.free()
	await frames(3)
	check(not is_instance_id_valid(last_world_id), "Exit releases the sample world")
	report_and_quit(0 if failures.is_empty() else 1)
