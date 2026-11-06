extends SceneTree

const OUT := "res://.runtime/screen_wall_review_20261106"
var checks := 0
var failures := 0
var review: Node3D
var activated_actions: Array[StringName] = []


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ",description)


func frames(count: int) -> void:
	for i in count:
		await process_frame


func screenshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + "/" + label + ".png") == OK, "capture " + label)


func move_pointer(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	Input.parse_input_event(event)


func mouse_click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = root.get_final_transform() * point
		event.global_position = event.position
		Input.parse_input_event(event)
		await frames(2)


func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)


func find_visible_point(display: Node3D) -> Vector2:
	for uv in [Vector2(0,0),Vector2(-0.2,0.0),Vector2(0.2,0.0),Vector2(0,0.2),Vector2(0,-0.2)]:
		var world: Vector3 = display.chassis.to_global(Vector3(uv.x * display.glass_size.x, uv.y * display.glass_size.y,0.04))
		var point: Vector2 = review.camera.unproject_position(world)
		if review.pick_display(point) == display:
			return point
	return Vector2(-999,-999)


func run() -> void:
	print("SCREEN_WALL_TEST PID=",OS.get_process_id()," audio=",AudioServer.get_driver_name())
	if AudioServer.get_driver_name() != "Dummy" or not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")):
		AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"),true)
		push_error("Private muted settings required before test entry")
		quit(2)
		return
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps = 60
	root.size = Vector2i(1280,800) if "--roundtrip-review" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	root.content_scale_size = Vector2i(640,360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	review = load("res://scenes/preview/screen_wall_review.tscn").instantiate()
	review.preview_only = false
	review.menu_requested.connect(func(id: StringName): activated_actions.append(id))
	root.add_child(review)
	await frames(65)
	check(review.displays.size() == 12, "twelve separate curved screen meshes")
	check(review.model.get_node("ServerBanks").get_child_count() == 6, "six CC0 server racks")
	check(review.model.get_node("CableHarnesses").get_child_count() >= 35, "modeled hanging, rear and floor cable bundles")
	check(review.displays[0].effect != review.displays[3].effect, "screen effects have independent material state")
	check(review.displays[0].effect.get_shader_parameter("mosaic_image") == review.displays[3].effect.get_shader_parameter("mosaic_image"), "all screens share one image source")
	check(review.get_node("ScreenRoomLighting").environment.ambient_light_energy == 0.0, "global ambient light is disabled")
	check(review.find_children("*", "DirectionalLight3D", true, false).is_empty(), "no overhead or directional lights")
	var screen_lights := review.find_children("*", "OmniLight3D", true, false)
	check(screen_lights.size() == 12, "only the twelve screen spill lights illuminate the model")
	var visible_points: Array[Vector2] = []
	for display in review.displays:
		var point := find_visible_point(display)
		visible_points.append(point)
		check(point.x > 0.0, "visible raycast area " + String(display.chassis.name))
	await screenshot("idle")
	if "--eye-review" in OS.get_cmdline_user_args():
		await verify_eye_follow()
		await finish()
		return
	if "--roundtrip-review" in OS.get_cmdline_user_args():
		check(review.model.scene_file_path == review.MODEL_PATH, "preview loads the editable saved scene")
		check(root.size == Vector2i(1280,800), "native 16:10 window used for letterbox check")
		check(root.get_texture().get_image().get_size() == Vector2i(1280,720), "16:9 game image preserved in a taller window")
		var selected: Node3D = review.displays[5]
		review.preview_only = true
		move_pointer(visible_points[5])
		await frames(35)
		await mouse_click(visible_points[5])
		check(review.settings_overlay != null and review.settings_overlay.visible, "settings screen opens from the saved 3D model")
		var muted := AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master"))
		if not muted:
			AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"),true)
			check(false, "settings reload preserves private mute")
			await finish()
			return
		check(muted, "settings reload preserves private mute")
		await screenshot("settings_panel")
		await key(KEY_ESCAPE)
		check(not review.settings_overlay.visible, "Escape returns to the screen wall")
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		check(doc.append_from_file("res://art/preview/screen_wall/screen_wall_model.glb",state) == OK, "exported GLB can be read back")
		var imported := doc.generate_scene(state)
		check(imported.find_children("TV_*", "Node3D", true, false).size() == 12, "GLB preserves all twelve separate television groups")
		imported.free()
		state = null
		doc = null
		await frames(4)
		await finish()
		return
	if "--capture-only" in OS.get_cmdline_user_args():
		move_pointer(visible_points[0])
		await frames(4)
		await screenshot("static")
		await frames(32)
		await screenshot("new_game")
		await finish()
		return
	for index in [0,3,5,7]:
		var display: Node3D = review.displays[index]
		move_pointer(visible_points[index])
		await frames(3)
		check(display.phase == "static" and display.noise_amount > 0.5, "proximity starts local static " + String(display.action_id))
		var action_count := activated_actions.size()
		await mouse_click(visible_points[index])
		check(activated_actions.size() == action_count, "static transition blocks accidental activation")
		if index == 0:
			await screenshot("static")
		await frames(34)
		check(display.phase == "option" and display.option_mix > 0.95, "static resolves to readable option " + String(display.action_id))
		await screenshot(String(display.action_id))
		await mouse_click(visible_points[index])
		check(activated_actions.size() == action_count + 1 and activated_actions.back() == display.action_id, "visible 3D surface activates " + String(display.action_id))
		var local_hover_count := 0
		for other in review.displays:
			if other.hovering:
				local_hover_count += 1
		check(local_hover_count == 1, "one hovered monitor, other mosaics stay idle")
	move_pointer(Vector2(1,355))
	await frames(35)
	check(review.hovered == null and review.displays[7].phase == "idle", "leaving restores the mosaic")
	check(review.pick_display(Vector2(15,180)) == null, "off-wall click does not activate any screen")
	# A front-most solid obstruction must win over every screen behind it.
	var blocked: Node3D = review.displays[0]
	var obstruction := StaticBody3D.new()
	obstruction.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2,2,0.1)
	shape.shape = box
	obstruction.add_child(shape)
	review.add_child(obstruction)
	obstruction.global_position = blocked.chassis.global_position + Vector3(0,0,3)
	await physics_frame
	await physics_frame
	check(review.pick_display(visible_points[0]) == null, "solid foreground objects prevent clicking through to a screen")
	obstruction.queue_free()
	await physics_frame
	for i in 4:
		await key(KEY_RIGHT)
		await frames(33)
		var count := activated_actions.size()
		await key(KEY_ENTER)
		check(activated_actions.size() == count + 1, "keyboard focus and activation " + str(i + 1))
	# Near-but-outside detection reveals the option without expanding the click area.
	var polygon: PackedVector2Array = blocked.visible_polygon(review.camera)
	var boundary := (polygon[0] + polygon[1]) * 0.5
	var outside := boundary + Vector2(0,4)
	check(review.nearby_display(outside) != null, "approaching a bezel can reveal a nearby screen")
	# Capture the actual hover animation at a known time cadence.
	await key(KEY_ESCAPE)
	move_pointer(Vector2(1,355))
	await frames(35)
	var timestamps: Array[int] = []
	for i in 72:
		if i == 12:
			move_pointer(visible_points[0])
		if i == 36:
			move_pointer(visible_points[3])
		if i == 60:
			move_pointer(Vector2(1,355))
		await frames(3)
		await RenderingServer.frame_post_draw
		timestamps.append(Time.get_ticks_msec())
		root.get_texture().get_image().save_png(OUT + "/motion_%02d.png" % i)
	var timings := FileAccess.open(OUT + "/motion_timing.json", FileAccess.WRITE)
	timings.store_string(JSON.stringify(timestamps))
	timings.close()
	review._export_model()
	await frames(3)
	check(FileAccess.file_exists("res://art/preview/screen_wall/screen_wall_model.glb"), "editable GLB kitbash exported")
	check(FileAccess.file_exists("res://art/preview/screen_wall/screen_wall_model.tscn"), "editable Godot model scene exported")
	await finish()


func finish() -> void:
	print("SCREEN_WALL_TEST checks=",checks," failures=",failures," exit=",0 if failures==0 else 1)
	if is_instance_valid(review):
		review.queue_free()
	await frames(4)
	quit(0 if failures == 0 else 1)


func eye_red_centroid() -> Vector2:
	await RenderingServer.frame_post_draw
	var rendered := root.get_texture().get_image()
	var total := Vector2.ZERO
	var count := 0
	# This is the original, stationary alpha mask's screen-space footprint.
	var a: Vector2 = review.source_to_viewport(Vector2(625,207)) * 2.0
	var b: Vector2 = review.source_to_viewport(Vector2(673,227)) * 2.0
	for y in range(floori(a.y),ceili(b.y)):
		for x in range(floori(a.x),ceili(b.x)):
			var color := rendered.get_pixel(x,y)
			if color.r > 0.15 and color.r > color.g * 1.3 and color.r > color.b * 1.15:
				total += Vector2(x,y)
				count += 1
	check(count > 20, "original red iris is visible in rendered pixels")
	return total / maxf(1.0,count)


func verify_eye_follow() -> void:
	var eye_screen: Node3D = review.displays[6]
	check(eye_screen.glass_size.x >= 2.0 and eye_screen.glass_size.y >= 2.0, "eye monitor is enlarged independently")
	var eye_rect := Rect2(Vector2(615,197),Vector2(76,38))
	var outline_visible := true
	for corner in [eye_rect.position,eye_rect.position+Vector2(eye_rect.size.x,0),eye_rect.end,eye_rect.position+Vector2(0,eye_rect.size.y)]:
		outline_visible = outline_visible and review.pick_display(review.source_to_viewport(corner)) == eye_screen
	check(outline_visible, "complete eye outline fits inside one visible monitor")
	var mask: Image = load("res://art/Home Screen/Home_Screen_chr_eye_mask.png").get_image()
	var all_visible := true
	var used := mask.get_used_rect()
	for y in range(used.position.y,used.end.y):
		for x in range(used.position.x,used.end.x):
			if mask.get_pixel(x,y).a > 0.1:
				var point: Vector2 = review.source_to_viewport(Vector2(x+0.5,y+0.5))
				all_visible = all_visible and review.pick_display(point) == eye_screen
	check(all_visible, "every nontransparent eye-mask pixel reaches the eye monitor")
	var center: Vector2 = review.source_to_viewport(review.EYE_CENTER)
	var up_distance := minf(180.0,center.y-8.0)
	move_pointer(center + Vector2(-250,0))
	await frames(28)
	check(review.eye_offset.x < -3.8 and absf(review.eye_offset.y) < 0.1, "iris follows the pointer to the left")
	var left_centroid := await eye_red_centroid()
	await screenshot("eye_left")
	move_pointer(center + Vector2(250,0))
	await frames(28)
	check(review.eye_offset.x > 5.8 and absf(review.eye_offset.y) < 0.1, "iris follows the pointer to the right")
	var right_centroid := await eye_red_centroid()
	await screenshot("eye_right")
	check(right_centroid.x - left_centroid.x > 10.0, "GPU-rendered iris moves visibly in the same direction as the pointer")
	move_pointer(center + Vector2(0,-up_distance))
	await frames(28)
	check(review.eye_offset.y < -(up_distance/200.0)*4.0*0.94, "iris follows the pointer upward")
	move_pointer(center + Vector2(0,150))
	await frames(28)
	check(review.eye_offset.y > 2.8, "iris follows the pointer downward")
	check(review.eye_offset.x >= -4.0 and review.eye_offset.x <= 6.0 and absf(review.eye_offset.y) <= 4.0, "iris remains inside the original movement limits")
	await create_timer(3.8).timeout
	check(review.eye_offset.length() < 0.2, "idle iris smoothly returns to its original position")
	await screenshot("eye_idle")
	var timestamps: Array[int] = []
	for i in 64:
		if i == 4:
			move_pointer(center+Vector2(-250,0))
		if i == 20:
			move_pointer(center+Vector2(250,0))
		if i == 36:
			move_pointer(center+Vector2(0,-up_distance))
		if i == 50:
			move_pointer(find_visible_point(review.displays[0]))
		await frames(2)
		await RenderingServer.frame_post_draw
		timestamps.append(Time.get_ticks_msec())
		root.get_texture().get_image().save_png(OUT+"/eye_motion_%02d.png"%i)
	var timing := FileAccess.open(OUT+"/eye_motion_timing.json",FileAccess.WRITE)
	timing.store_string(JSON.stringify(timestamps))
	timing.close()
	review._export_model()
	await frames(3)
