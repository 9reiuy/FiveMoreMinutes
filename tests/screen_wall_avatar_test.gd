extends SceneTree
## Actual-Camera admission for the posed user avatar, with no extra lights.
const OUT := "res://.runtime/screen_wall_avatar_20261107/"
var checks := 0
var failures := 0
var menu: Control
var wall: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func frames(count: int) -> void:
	for index in count: await process_frame

func shot(label: String) -> Image:
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	check(picture.save_png(OUT + label + ".png") == OK, "Camera " + label)
	return picture

func run() -> void:
	print("AVATAR_LAB_PID=", OS.get_process_id(), " audio=", AudioServer.get_driver_name())
	if AudioServer.get_driver_name() != "Dummy" or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0, true)
		quit(2)
		return
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var lab: Control = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	lab.presentation_scene_path = "res://scenes/preview/screen_wall_avatar_candidate.tscn"
	root.add_child(lab)
	menu = lab.presentation
	wall = menu.wall_view
	wall.preview_frame_limit = 60
	wall.unfocused_frame_limit = 60
	wall._apply_preview_frame_limit(false)
	await frames(65)
	check(wall.avatar != null, "supplied avatar is present in the independent lab")
	check(wall.find_children("*", "OmniLight3D", true, false).size() == 12, "the original twelve screen lights are the only light sources")
	check(wall.avatar.find_children("*", "Light3D", true, false).is_empty(), "avatar contributes no light nodes")
	check(wall.avatar.find_children("*", "Skeleton3D", true, false).is_empty(), "runtime uses the baked pose without skeleton work")
	check(ResourceLoader.get_dependencies("res://art/preview/screen_wall/avatar/ung35_folded_pose.scn").is_empty(), "runtime model is self-contained and does not depend on the temporary VRM copy")
	check(wall.get_node("ScreenRoomLighting").environment.ambient_light_energy == 0.0, "ambient fill remains zero")
	var geometry: Node3D = wall.avatar.geometry
	var material_ok := true
	var face_ok := false
	var eyes_ok := false
	var hair_bounds := Rect2()
	var hair_count := 0
	for item in geometry.find_children("*", "MeshInstance3D", true, false):
		for surface in item.mesh.get_surface_count():
			var shaded: StandardMaterial3D = item.get_active_material(surface)
			var original: StandardMaterial3D = item.mesh.surface_get_material(surface)
			material_ok = material_ok and shaded.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and not shaded.emission_enabled and not shaded.rim_enabled and not shaded.backlight_enabled
			if original.resource_name.contains("Skin_Face"):
				face_ok = shaded.albedo_texture == original.albedo_texture and original.albedo_texture != null and item.layers == wall.avatar.FACE_LAYER
			if original.resource_name.begins_with("Eye"):
				eyes_ok = shaded.albedo_texture == original.albedo_texture and original.albedo_texture != null
			if String(item.name) == "HairMain":
				var points: PackedVector3Array = item.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for point in points:
					var projected: Vector2 = wall.camera.unproject_position(item.to_global(point))
					if hair_count == 0: hair_bounds = Rect2(projected, Vector2.ZERO)
					else: hair_bounds = hair_bounds.expand(projected)
					hair_count += 1
	check(material_ok, "every avatar surface uses actual scene lighting without emission, rim, or backlight")
	check(face_ok and eyes_ok, "original face and eye textures survive the material conversion")
	var eye_polygon: PackedVector2Array = wall.displays[6].visible_polygon(wall.camera)
	var projected_y: Array = Array(eye_polygon).map(func(point: Vector2): return point.y)
	var eye_bottom: float = projected_y.max()
	var eye_top: float = projected_y.min()
	check(hair_bounds.position.y < eye_bottom and hair_bounds.position.y > eye_bottom - (eye_bottom - eye_top) * 0.25, "larger head slightly overlaps only the eye television's lower region")
	var eye_mask: Image = load("res://art/Home Screen/Home_Screen_chr_eye_mask.png").get_image()
	var used := eye_mask.get_used_rect()
	var visible_eye := true
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if eye_mask.get_pixel(x,y).a > 0.1:
				visible_eye = visible_eye and wall.pick_display(wall.source_to_viewport(Vector2(x + 0.5,y + 0.5))) == wall.displays[6]
	check(visible_eye, "the character leaves every iris-mask pixel unobstructed")
	var face_point: Vector2 = wall.camera.unproject_position(geometry.to_global(Vector3(0,1.235,-0.20)))
	check(wall.pick_display(face_point) == null, "character geometry blocks clicking through its face into rear screens")
	for index in [0,6,5,8]:
		var display: Node3D = wall.displays[index]
		var center: Vector2 = wall.camera.unproject_position(display.chassis.to_global(Vector3(0,0,0.04)))
		check(wall.pick_display(center) == display, "visible interaction center remains reachable: " + String(display.action_id))
	await shot("avatar_menu")
	# Isolate geometry while leaving the actual light nodes in place.
	for display in wall.displays: display.set_process(false)
	wall.set_process(false)
	var hidden: Array[Node3D] = []
	for item in wall.model.find_children("*", "GeometryInstance3D", true, false):
		if item.visible:
			item.hide()
			hidden.append(item)
	menu.footer_link.hide()
	await frames(4)
	var lit := await shot("avatar_only_lit")
	var side_energies: Array[float] = []
	for index in [3,4]:
		side_energies.append(wall.displays[index].spill_light.light_energy)
		wall.displays[index].spill_light.light_energy = 0.0
	await frames(4)
	var sides_off := await shot("avatar_side_screens_off")
	var arm_response := 0
	var arm_max_change := 0.0
	for y in range(413,480):
		for x in range(565,750):
			var difference := lit.get_pixel(x,y) - sides_off.get_pixel(x,y)
			var change := maxf(difference.r,maxf(difference.g,difference.b))
			if change > 0.012: arm_response += 1
			arm_max_change = maxf(arm_max_change,change)
	check(arm_response > 100, "upper hand and sleeve respond to real side-screen light changes")
	for index in 2: wall.displays[[3,4][index]].spill_light.light_energy = side_energies[index]
	var energies: Array[float] = []
	for display in wall.displays:
		energies.append(display.spill_light.light_energy)
		display.spill_light.light_energy = 0.0
	await frames(4)
	var unlit := await shot("avatar_only_screens_off")
	var lit_pixels := 0
	var dark_max := 0.0
	for y in range(250, 680):
		for x in range(500, 950):
			var on := lit.get_pixel(x,y)
			var off := unlit.get_pixel(x,y)
			if maxf(on.r,maxf(on.g,on.b)) > 0.06: lit_pixels += 1
			dark_max = maxf(dark_max,maxf(off.r,maxf(off.g,off.b)))
	check(lit_pixels > 100, "existing screens produce a visible colored contour")
	check(dark_max < 0.02, "with screen lights off the avatar emits no remaining light")
	for index in wall.displays.size():
		wall.displays[index].spill_light.light_energy = energies[index]
		wall.displays[index].set_process(true)
	for item in hidden: item.show()
	wall.set_process(true)
	menu.footer_link.show()
	await frames(4)
	await shot("avatar_final")
	var file := FileAccess.open(OUT + "avatar_lab_result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"hair_rect":[hair_bounds.position.x,hair_bounds.position.y,hair_bounds.size.x,hair_bounds.size.y],"lit_pixels":lit_pixels,"lights_off_max":dark_max,"upper_arm_response_pixels":arm_response,"upper_arm_max_change":arm_max_change,"scope":"independent actual-Camera avatar, eye visibility and existing-light-only gate"},"\t"))
	file.close()
	lab.queue_free()
	await frames(5)
	print("AVATAR_LAB_RESULT checks=", checks, " failures=", failures," exit=",1 if failures else 0)
	quit(1 if failures else 0)
