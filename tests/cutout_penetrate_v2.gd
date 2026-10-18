extends SceneTree
## penetrate_v2: tall occluder, cam->furn->actor; compare off / on / hide-furniture.
## PASS only if hole-center on approaches open (hide) colors, not clear-black.

var log_path := "user://penetrate_v2_log.txt"
var runtime := ""

func log_line(t: String) -> void:
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(log_path, FileAccess.WRITE)
	else:
		f.seek_end()
	f.store_line(t)
	f.close()
	print(t)

func _initialize() -> void:
	call_deferred("run")

func keep_window_away() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(-2400, -2400))
	DisplayServer.window_set_size(Vector2i(1280, 720))

func settle(n: int = 10) -> void:
	for _i in n:
		await process_frame
		keep_window_away()

func capture() -> Image:
	await settle(8)
	await RenderingServer.frame_post_draw
	keep_window_away()
	return root.get_texture().get_image()

func avg(img: Image, cx: int, cy: int, r: int) -> Color:
	var s := Color(0, 0, 0, 0)
	var n := 0
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				s += img.get_pixel(x, y)
				n += 1
	return s / float(maxi(n, 1))

func luma(c: Color) -> float:
	return c.r + c.g + c.b

func dist(a: Color, b: Color) -> float:
	var d := a - b
	return absf(d.r) + absf(d.g) + absf(d.b)

func crop_around(img: Image, cx: int, cy: int, half: int) -> Image:
	var x0 := clampi(cx - half, 0, img.get_width() - 1)
	var y0 := clampi(cy - half, 0, img.get_height() - 1)
	var w := mini(half * 2, img.get_width() - x0)
	var h := mini(half * 2, img.get_height() - y0)
	return img.get_region(Rect2i(x0, y0, w, h))

func actor_world_of(world: Node3D, player: Node2D) -> Vector3:
	if world.has_method("_get_actor_cutout_slot"):
		var cut: Dictionary = world._get_actor_cutout_slot(player)
		if not cut.is_empty():
			return cut.get("world", Vector3.ZERO)
	return world.get_gameplay_world_position(player.global_position, 0.95)

func make_tall_occluder(kind: String) -> Node3D:
	var art = load("res://scripts/dream/office_low_pixel_art.gd")
	var visual: Node3D = art.make_visual(kind)
	visual.set_meta(&"occlusion_cutout_occluder", true)
	return visual

func run() -> void:
	keep_window_away()
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("PENETRATE_V2_START")
	log_line("use_depth_prepass=%s" % str(ProjectSettings.get_setting("rendering/gl_compatibility/use_depth_prepass")))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 720)
	runtime = ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	DirAccess.make_dir_recursive_absolute(runtime)

	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = true
	world.persist_profile = false
	if "enable_game_start_cab_exit" in world:
		world.enable_game_start_cab_exit = false
	root.add_child(world)
	await settle(30)
	world.regenerate(41001)
	await settle(120)

	if "rooms" in world and world.rooms.size() > 0:
		var room = world.rooms[0]
		if world.get("player") != null:
			world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
		if world.has_method("activate_room"):
			world.activate_room(int(room.id))
		log_line("activated room0 arch=%s" % String(room.get("archetype", "")))
	await settle(40)

	var cam: Camera3D = world.camera_3d
	var player: Node2D = world.get("player") as Node2D
	if cam == null or player == null:
		log_line("NO_CAM_OR_PLAYER")
		quit(3)
		return
	player.set_physics_process(false)
	player.set_process(false)

	var fixture_root := Node3D.new()
	fixture_root.name = "TallCabinetFixture"
	world.add_child(fixture_root)
	var partition: Node3D = make_tall_occluder("partition")
	var cabinet: Node3D = make_tall_occluder("cabinet")
	fixture_root.add_child(partition)
	fixture_root.add_child(cabinet)
	var cell: float = float(world.CELL_PIXELS)
	await settle(20)

	var cam_pos: Vector3 = cam.global_position
	var forward: Vector3 = -cam.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3(0, 0, -1)
	forward = forward.normalized()

	var player_w: Vector3 = actor_world_of(world, player)
	player_w.y = 0.0
	var to_player: Vector3 = player_w - Vector3(cam_pos.x, 0.0, cam_pos.z)
	to_player.y = 0.0
	if to_player.length_squared() < 0.01:
		to_player = forward
	to_player = to_player.normalized()
	var right: Vector3 = Vector3(to_player.z, 0.0, -to_player.x)

	var dist_cam_player: float = Vector3(cam_pos.x, 0, cam_pos.z).distance_to(player_w)
	var furn_dist: float = maxf(dist_cam_player - 1.05, 5.5)
	var furn_world: Vector3 = Vector3(cam_pos.x, 0, cam_pos.z) + to_player * furn_dist
	player_w = furn_world + to_player * 1.0
	var player_local: Vector3 = world.to_local(player_w)
	player.global_position = Vector2(player_local.x * cell, player_local.z * cell)
	partition.global_position = furn_world
	partition.rotation = Vector3(0, atan2(-to_player.x, -to_player.z), 0)
	cabinet.global_position = furn_world + right * 1.15
	cabinet.rotation = partition.rotation
	await settle(28)

	# Re-nudge after camera follow
	cam_pos = cam.global_position
	player_w = actor_world_of(world, player)
	player_w.y = 0.0
	to_player = player_w - Vector3(cam_pos.x, 0, cam_pos.z)
	to_player.y = 0.0
	to_player = to_player.normalized() if to_player.length_squared() > 0.0001 else forward
	right = Vector3(to_player.z, 0.0, -to_player.x)
	dist_cam_player = Vector3(cam_pos.x, 0, cam_pos.z).distance_to(player_w)
	furn_dist = maxf(dist_cam_player - 1.05, 5.5)
	furn_world = Vector3(cam_pos.x, 0, cam_pos.z) + to_player * furn_dist
	player_w = furn_world + to_player * 1.0
	player_local = world.to_local(player_w)
	player.global_position = Vector2(player_local.x * cell, player_local.z * cell)
	partition.global_position = furn_world
	partition.rotation = Vector3(0, atan2(-to_player.x, -to_player.z), 0)
	cabinet.global_position = furn_world + right * 1.15
	cabinet.rotation = partition.rotation
	await settle(20)
	if world.has_method("_update_camera_and_actor_projection"):
		world._update_camera_and_actor_projection(0.0)
	await settle(6)

	for mesh_n in fixture_root.find_children("*", "MeshInstance3D", true, false):
		var mi2 := mesh_n as MeshInstance3D
		if mi2 != null:
			mi2.layers |= 8
			log_line("fixture_layers=%d" % mi2.layers)
	for node in world.get_tree().get_nodes_in_group("office_dither_lighting"):
		if node.has_method("_register_mesh"):
			for mesh in fixture_root.find_children("*", "MeshInstance3D", true, false):
				node._register_mesh(mesh)
	await settle(12)

	var head: Vector3 = actor_world_of(world, player)
	head.y = 0.95
	var part_mesh: MeshInstance3D = partition.find_child("AuthoredSurfaceMesh", true, false) as MeshInstance3D
	var cab_mesh: MeshInstance3D = cabinet.find_child("AuthoredSurfaceMesh", true, false) as MeshInstance3D
	var cam_xz2 := Vector3(cam.global_position.x, 0.0, cam.global_position.z)
	var part_xz := Vector3(partition.global_position.x, 0.0, partition.global_position.z)
	var head_xz := Vector3(head.x, 0.0, head.z)
	var cam_closer_part := cam_xz2.distance_squared_to(part_xz) < cam_xz2.distance_squared_to(head_xz)
	log_line("xz_dist_part=%.3f xz_dist_head=%.3f cam_closer=%s" % [
		cam_xz2.distance_to(part_xz), cam_xz2.distance_to(head_xz), str(cam_closer_part)
	])
	if not cam_closer_part:
		log_line("FAIL_FURN_NOT_BETWEEN")
		quit(7)
		return
	if cam.is_position_behind(head):
		log_line("HEAD_BEHIND_CAMERA")
		quit(5)
		return

	var sp: Vector2 = cam.unproject_position(head)
	var vp_size: Vector2 = cam.get_viewport().get_visible_rect().size
	for mesh in [part_mesh, cab_mesh]:
		if mesh == null:
			continue
		if mesh.material_override is ShaderMaterial:
			var sm := mesh.material_override as ShaderMaterial
			if sm.shader != null and sm.shader.code.contains("occlusion_cutout_enabled"):
				sm.set_shader_parameter("occlusion_cutout_enabled", true)
				log_line("enabled_cutout_on %s discard=%s depth_prepass=%s" % [
					mesh.name,
					str(sm.shader.code.contains("occlusion_cut < 0.004")),
					str(sm.shader.code.contains("depth_prepass_alpha"))
				])

	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", vp_size)

	# Clear slots before behind sample so behind_tex is not self-holed.
	for i in range(0, 8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	# Composite / behind diagnostics (DreamDisplayBootstrap wraps into SelectivePixelPreview)
	var display: Node = null
	for n in root.find_children("*", "Control", true, false):
		if n.is_in_group(&"dream_display"):
			display = n
			break
	var behind_vp: SubViewport = null
	var overlay: CanvasItem = null
	if display != null:
		behind_vp = display.find_child("CutoutBehindViewport", true, false) as SubViewport
		overlay = display.find_child("OcclusionCutoutComposite", true, false) as CanvasItem
	log_line("display=%s overlay_vis=%s behind=%s" % [
		str(display != null),
		str(overlay.visible) if overlay != null else "null",
		str(behind_vp != null)
	])
	if behind_vp != null:
		await settle(4)
		await RenderingServer.frame_post_draw
		var behind_img: Image = behind_vp.get_texture().get_image()
		if behind_img != null:
			behind_img.save_png(runtime.path_join("penetrate_v2_behind.png"))
			var bavg := avg(behind_img, clampi(int(sp.x), 0, behind_img.get_width()-1), clampi(int(sp.y), 0, behind_img.get_height()-1), 12)
			log_line("BEHIND_LUMA=%.4f avg=%s size=%dx%d" % [luma(bavg), str(bavg), behind_img.get_width(), behind_img.get_height()])
		else:
			log_line("BEHIND_IMG_NULL")
	# OFF
	world.set_process(false)
	for i in range(0, 8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	var img_off: Image = await capture()
	img_off.save_png(runtime.path_join("penetrate_v2_off.png"))

	# ON forced slot
	var radius_px := 80.0
	var aim_sp := sp
	if world.has_method("_project_occlusion_cutout"):
		var projected: Vector4 = world._project_occlusion_cutout(head, 0.32, null)
		if projected.w > 0.5:
			aim_sp = Vector2(projected.x * vp_size.x, projected.y * vp_size.y)
			radius_px = maxf(projected.z, 64.0)
	var best_slot := Vector4(aim_sp.x / vp_size.x, aim_sp.y / vp_size.y, radius_px, 1.0)
	RenderingServer.global_shader_parameter_set("occlusion_cutout_0", best_slot)
	for i in range(1, 8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	log_line("FORCED_SLOT=%s" % str(best_slot))
	var img_on: Image = await capture()
	img_on.save_png(runtime.path_join("penetrate_v2_on.png"))

	# OPEN = hide fixture (reference: what should show through a true hole)
	for i in range(0, 8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	fixture_root.visible = false
	await settle(6)
	var img_open: Image = await capture()
	img_open.save_png(runtime.path_join("penetrate_v2_open.png"))
	fixture_root.visible = true

	var root_size := Vector2(float(img_off.get_width()), float(img_off.get_height()))
	var scale := minf(root_size.x / vp_size.x, root_size.y / vp_size.y)
	var offset := (root_size - vp_size * scale) * 0.5
	var sample_sp := Vector2(best_slot.x * vp_size.x, best_slot.y * vp_size.y)
	var px := int(offset.x + sample_sp.x * scale)
	var py := int(offset.y + sample_sp.y * scale)
	log_line("sample_px=%d,%d img=%dx%d" % [px, py, img_off.get_width(), img_off.get_height()])

	crop_around(img_on, px, py, 90).save_png(runtime.path_join("penetrate_v2_crop_on.png"))
	crop_around(img_off, px, py, 90).save_png(runtime.path_join("penetrate_v2_crop_off.png"))
	crop_around(img_open, px, py, 90).save_png(runtime.path_join("penetrate_v2_crop_open.png"))

	var crop_off := crop_around(img_off, px, py, 100)
	var crop_on := crop_around(img_on, px, py, 100)
	var crop_open := crop_around(img_open, px, py, 100)
	var sbs := Image.create(crop_off.get_width() * 3 + 12, crop_off.get_height(), false, Image.FORMAT_RGBA8)
	sbs.fill(Color(0.04, 0.04, 0.07, 1))
	sbs.blit_rect(crop_off, Rect2i(Vector2i.ZERO, crop_off.get_size()), Vector2i(0, 0))
	sbs.blit_rect(crop_on, Rect2i(Vector2i.ZERO, crop_on.get_size()), Vector2i(crop_off.get_width() + 6, 0))
	sbs.blit_rect(crop_open, Rect2i(Vector2i.ZERO, crop_open.get_size()), Vector2i(crop_off.get_width() * 2 + 12, 0))
	sbs.save_png(runtime.path_join("penetrate_v2_sbs.png"))

	var off_avg := avg(img_off, px, py, 12)
	var on_avg := avg(img_on, px, py, 12)
	var open_avg := avg(img_open, px, py, 12)
	var clear_black := Color(0, 0, 0, 1)
	var on_to_open := dist(on_avg, open_avg)
	var on_to_black := dist(on_avg, clear_black)
	var open_to_black := dist(open_avg, clear_black)
	log_line("off_avg=%s on_avg=%s open_avg=%s" % [str(off_avg), str(on_avg), str(open_avg)])
	log_line("on_to_open=%.4f on_to_black=%.4f open_to_black=%.4f luma_on=%.4f luma_open=%.4f" % [
		on_to_open, on_to_black, open_to_black, luma(on_avg), luma(open_avg)
	])

	# Visual pass: on must be closer to open than to clear black, and not near-black if open isn't.
	var closer_to_open := on_to_open + 0.04 < on_to_black
	var not_clear_black := luma(on_avg) > 0.12 or luma(open_avg) < 0.12
	var approaches_open := on_to_open < 0.55
	var accepted := closer_to_open and not_clear_black and approaches_open and cam_closer_part
	log_line("JUDGE closer_to_open=%s not_clear_black=%s approaches_open=%s => %s" % [
		str(closer_to_open), str(not_clear_black), str(approaches_open), "PASS" if accepted else "FAIL"
	])
	log_line("PENETRATE_V2_DONE")
	quit(0 if accepted else 2)
