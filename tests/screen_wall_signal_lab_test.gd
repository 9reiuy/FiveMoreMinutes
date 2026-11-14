extends SceneTree
const OUT := "res://.runtime/screen_wall_signal_20261108/"
var lab: Control
var wall: Node3D
var checks := 0
var failures := 0
var actions: Array[StringName] = []
var events: Array = []
var reports: Array = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func frames(count: int) -> void:
	for index in count: await process_frame

func create_wall(variant: String) -> void:
	lab = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	lab.presentation_scene_path = OUT + variant + "/lab.tscn"
	root.add_child(lab)
	wall = lab.presentation.get_node("Wall")
	wall.menu_requested.connect(func(action: StringName): actions.append(action))
	wall.preview_only = false
	root.get_node("FrameBudget").apply_window_focus(true)
	await frames(5)

func destroy_wall() -> void:
	var weak_wall: WeakRef = weakref(wall)
	lab.queue_free()
	await frames(4)
	check(weak_wall.get_ref() == null, "television world released")

func shot(label: String) -> Image:
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	check(picture.save_png(OUT + label + ".png") == OK, "actual Camera " + label)
	return picture

func force_style(display: Node3D, style: int) -> void:
	display.set_hovered(false)
	for attempt in 40:
		display._reset_broadcast(false)
		display._begin_broadcast()
		if display.signal_style == style: break
	display._process(0.30)
	display.set_process(false)

func native_pointer(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	Input.parse_input_event(event)

func visible_point(display: Node3D) -> Vector2:
	for uv in [Vector2.ZERO, Vector2(-0.2, 0), Vector2(0.2, 0), Vector2(0, -0.2)]:
		var point: Vector2 = wall.camera.unproject_position(display.chassis.to_global(Vector3(uv.x*display.glass_size.x, uv.y*display.glass_size.y, 0.04)))
		if wall.pick_display(point) == display: return point
	return Vector2(-999, -999)

func functional_visual() -> void:
	await create_wall("candidate")
	check(wall.displays.size() == 12, "all production televisions loaded")
	var waits: Array = []
	var option_count := 0
	for index in wall.displays.size():
		var display: Node3D = wall.displays[index]
		waits.append(snappedf(display.signal_wait, 0.001))
		check(display.base_tint.s >= 0.799 and display.base_tint.v >= 0.939, "vivid screen tint " + str(index))
		if not display.action_id.is_empty(): option_count += 1
		display.broadcast_started.connect(func(style: int): events.append({"screen":index,"style":style,"ms":Time.get_ticks_msec()}))
	check(option_count == 4, "four option screens and eight decorative screens")
	var shared_tint: Color = wall.displays[3].base_tint
	check(wall.displays.all(func(display):return display.base_tint.is_equal_approx(shared_tint)), "all screens share the middle-right monitor blue")
	check(waits.duplicate().reduce(func(unique: Array, value):
		if not unique.has(value): unique.append(value)
		return unique, []).size() >= 10, "independent randomized first intervals")
	await shot("vivid_idle")
	# Observe real timed broadcasts before arranging diagnostic Camera states.
	await create_timer(5.2).timeout
	check(events.size() >= 8 and actions.is_empty(), "random broadcasts run without activating menu actions")
	var image: Node3D = wall.displays[6]
	for display in wall.displays:
		var style: int = display.BroadcastStyle.OPTION if not display.action_id.is_empty() else (display.BroadcastStyle.COLOR_BARS if int(display.navigation_order)%2 == 0 else display.BroadcastStyle.SNOW)
		force_style(display, style)
		check(display.signal_style == style, "correct option or fault signal for " + str(display.navigation_order))
		if not display.action_id.is_empty():
			check(not display.is_ready_to_activate() and is_equal_approx(display.effect.get_shader_parameter("option_mix"), 1.0), "ambient text is visible but not auto-selected")
	wall.set_process(false)
	await shot("signal_showcase")
	# The whole option glass must be independent of the original portrait.
	var before := await shot("option_portrait_reference")
	var original: Texture2D = image.effect.get_shader_parameter("mosaic_image")
	var original_eye: Texture2D = image.effect.get_shader_parameter("eye_image")
	var solid := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	solid.fill(Color.MAGENTA)
	image.effect.set_shader_parameter("mosaic_image", ImageTexture.create_from_image(solid))
	image.effect.set_shader_parameter("eye_image", ImageTexture.create_from_image(solid))
	await frames(2)
	var after := await shot("option_portrait_replaced")
	var unchanged := 0
	for uv in [Vector2(-.32,.25),Vector2(.28,.25),Vector2(-.32,-.23),Vector2(.28,-.23)]:
		var point: Vector2 = wall.camera.unproject_position(image.chassis.to_global(Vector3(uv.x*image.glass_size.x,uv.y*image.glass_size.y,.026)))
		var pixel := Vector2i(point)
		if before.get_pixelv(pixel).is_equal_approx(after.get_pixelv(pixel)): unchanged += 1
	check(unchanged == 4, "revealed option contains no residual portrait pixels")
	image.effect.set_shader_parameter("mosaic_image", original)
	image.effect.set_shader_parameter("eye_image", original_eye)
	# Native pointer input wins over timed flicker and retains its dwell time.
	wall.set_process(true)
	for display in wall.displays: display.set_process(true)
	var point := visible_point(image)
	check(point.x >= 0, "eye television has a visible native hit area")
	native_pointer(point)
	await frames(34)
	check(wall.hovered == image and not image.signal_active and image.is_ready_to_activate(), "hover cancels ambient flicker and retains normal interaction")
	check(image.effect.get_shader_parameter("option_mix") > 0.99, "hovered option stays legible")
	# End a broadcast by its own timer, then check randomized rescheduling.
	wall._set_hovered(null)
	force_style(image, image.BroadcastStyle.OPTION)
	image._process(image.signal_hold + 0.4)
	check(not image.signal_active and image.signal_wait >= 2.4 and image.signal_wait <= 7.8, "broadcast returns to portrait with a new random interval")
	image.set_process(true)
	for display in wall.displays: display._begin_broadcast()
	await wall.play_shutdown()
	check(wall.displays.all(func(display):return display.powered_off and not display.signal_active), "shutdown cancels all random signals and closes every tube")
	await destroy_wall()
	await create_wall("candidate")
	check(wall.displays.all(func(display):return not display.powered_off and not display.signal_active), "reload starts with a clean signal lifecycle")
	await destroy_wall()

func performance_case(variant: String, label: String) -> void:
	await create_wall(variant)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	await create_timer(1.0).timeout
	root.get_node("FrameBudget").apply_window_focus(true)
	await frames(6)
	var raw: Array = []
	var began := Time.get_ticks_usec()
	var previous := began
	var hovered_index := -1
	wall.keyboard_focus = 0
	while Time.get_ticks_usec()-began < 4000000:
		var next_hover := int((Time.get_ticks_usec()-began)/700000)%4
		if next_hover != hovered_index:
			wall._set_hovered(wall.displays[[0,6,5,8][next_hover]])
			hovered_index = next_hover
		await process_frame
		var now := Time.get_ticks_usec()
		var active_signals := 0
		if variant == "candidate":
			for display in wall.displays:
				if display.signal_active: active_signals += 1
		raw.append({"frame_ms":(now-previous)/1000.0,"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"active_signals":active_signals,"fps_limit":Engine.max_fps})
		previous = now
	var stats := {}
	for metric in ["frame_ms", "gpu_ms", "draw_calls"]:
		var values: Array = raw.map(func(row):return row[metric])
		values.sort()
		stats[metric] = {"p50":values[values.size()/2],"p95":values[floori(values.size()*.95)],"p99":values[floori(values.size()*.99)],"max":values.back()}
	reports.append({"case":label,"stats":stats,"raw":raw})
	check(raw.all(func(row):return row.fps_limit==60), "matched 60 FPS limit throughout " + label)
	if variant == "candidate": check(raw.any(func(row):return row.active_signals >= 2), "performance sample includes overlapping broadcasts and hover")
	print("SIGNAL_PERF ",label," ",stats)
	await destroy_wall()

func run() -> void:
	print("SIGNAL_LAB_PID=",OS.get_process_id()," audio=",AudioServer.get_driver_name())
	var perf := "--signal-perf" in OS.get_cmdline_user_args()
	var driver := "WASAPI" if perf else "Dummy"
	if not OS.get_user_data_dir().contains("signal_private") or AudioServer.get_driver_name()!=driver or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true);quit(2);return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-30000,-30000))
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(640,360)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	check(RenderingServer.get_current_rendering_driver_name()=="opengl3_angle", "accepted Direct3D11 presentation retained")
	if perf:
		# Native offscreen focus events must not switch one member of the A/B/A
		# set to 30 FPS. Keep this diagnostic process at the declared 60 FPS.
		var budget: Node = root.get_node("FrameBudget")
		root.focus_entered.disconnect(budget.apply_window_focus.bind(true))
		root.focus_exited.disconnect(budget.apply_window_focus.bind(false))
		await performance_case("baseline","A")
		await performance_case("candidate","B")
		await performance_case("baseline","A2")
	else:
		await functional_visual()
	check(AudioServer.is_bus_mute(0), "private mute retained")
	var file := FileAccess.open(OUT+("performance.json" if perf else "lab_result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"audio":driver,"driver":RenderingServer.get_current_rendering_driver_name(),"events":events,"reports":reports,"scope":"production-art GameTestLab, native offscreen ANGLE/D3D11, 1280x720, 60 FPS, VSync disabled, private prelaunch mute. A/B/A is 1s warmup and 4s measured per case with no captures or forced drawing; bounded menu scope only."},"\t"));file.close()
	Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null,Input.CURSOR_POINTING_HAND)
	print("SIGNAL_LAB_RESULT checks=",checks," failures=",failures," exit=",1 if failures else 0)
	quit(1 if failures else 0)
