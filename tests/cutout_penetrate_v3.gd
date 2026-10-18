extends SceneTree
## penetrate_v3: diagnose depth seal then verify hole shows open colors.
## Samples TORSO on partition face (not head peek). Modes: off / on / alpha0 / open.

var log_path := "user://penetrate_v3_log.txt"
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

func keep_away() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(-2400, -2400))
	DisplayServer.window_set_size(Vector2i(1280, 720))

func settle(n: int = 8) -> void:
	for _i in n:
		await process_frame
		keep_away()

var world_viewport: SubViewport

func capture() -> Image:
	await settle(6)
	await RenderingServer.frame_post_draw
	keep_away()
	if is_instance_valid(world_viewport):
		return world_viewport.get_texture().get_image()
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

func dump_mesh(mesh: MeshInstance3D, tag: String) -> void:
	if mesh == null:
		log_line("%s NULL" % tag)
		return
	log_line("%s name=%s layers=%d cast_shadow=%d overlay=%s" % [
		tag, mesh.name, mesh.layers, mesh.cast_shadow, str(mesh.material_overlay != null)
	])
	var mat := mesh.material_override as ShaderMaterial
	if mat == null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
		mat = mesh.get_active_material(0) as ShaderMaterial
	if mat == null or mat.shader == null:
		log_line("%s no ShaderMaterial" % tag)
		return
	var code: String = mat.shader.code
	var rm := ""
	var i := code.find("render_mode")
	if i >= 0:
		rm = code.substr(i, mini(120, code.length() - i)).replace("\n", " ")
	log_line("%s render=%s" % [tag, rm])
	log_line("%s has_never=%s has_prepass=%s has_discard_cut=%s cut_param=%s" % [
		tag,
		str(code.contains("depth_draw_never")),
		str(code.contains("depth_prepass_alpha")),
		str(code.contains("occlusion_cut < 0.35") or code.contains("occlusion_cut < 0.004")),
		str(mat.get_shader_parameter("occlusion_cutout_enabled"))
	])

func force_alpha0_shader(mesh: MeshInstance3D) -> void:
	## Force whole furniture invisible via discard (probe A/B: must match open).
	if mesh == null or not (mesh.material_override is ShaderMaterial):
		return
	var sm := mesh.material_override as ShaderMaterial
	var code: String = sm.shader.code
	code = code.replace(
		"float occlusion_cut = occlusion_cutout_enabled ? combined_cutout(SCREEN_UV) : 1.0;",
		"float occlusion_cut = 0.0; // PROBE_ALPHA0"
	)
	if not code.contains("PROBE_ALPHA0"):
		code = code.replace(
			"float occlusion_cut = (cutout_behind_pass || !occlusion_cutout_enabled) ? 1.0 : combined_cutout(SCREEN_UV);",
			"float occlusion_cut = 0.0; // PROBE_ALPHA0"
		)
	if not code.contains("PROBE_ALPHA0"):
		# Last resort: prepend discard at start of fragment
		var fi := code.find("void fragment()")
		if fi >= 0:
			var brace := code.find("{", fi)
			if brace >= 0:
				code = code.insert(brace + 1, "\n\tdiscard; // PROBE_ALPHA0\n")
	var sh := Shader.new()
	sh.code = code
	sm.shader = sh
	sm.set_shader_parameter("occlusion_cutout_enabled", true)

func run() -> void:
	keep_away()
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("PENETRATE_V3_START")
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
	await settle(8)
	# DreamDisplayBootstrap wraps into SelectivePixelPreview — capture the 3D SubViewport directly.
	for n in root.find_children("*", "SubViewport", true, false):
		if String(n.name) == "WorldViewport":
			world_viewport = n as SubViewport
			break
	log_line("world_viewport=%s size=%s" % [str(world_viewport != null), str(world_viewport.size) if world_viewport else "null"])
	await settle(16)
	world.regenerate(41001)
	await settle(100)

	if "rooms" in world and world.rooms.size() > 0:
		var room = world.rooms[0]
		if world.get("player") != null:
			world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
		if world.has_method("activate_room"):
			world.activate_room(int(room.id))
		log_line("room0=%s" % String(room.get("archetype", "")))
	await settle(30)

	var cam: Camera3D = world.camera_3d
	var player: Node2D = world.get("player") as Node2D
	if cam == null or player == null:
		log_line("NO_CAM_PLAYER")
		quit(3)
		return
	player.set_physics_process(false)
	player.set_process(false)

	var art = load("res://scripts/dream/office_low_pixel_art.gd")
	var fixture := Node3D.new()
	fixture.name = "V3Fixture"
	world.add_child(fixture)
	var partition: Node3D = art.make_visual("partition")
	partition.set_meta(&"occlusion_cutout_occluder", true)
	fixture.add_child(partition)
	var cell: float = float(world.CELL_PIXELS)
	await settle(12)

	var cam_pos: Vector3 = cam.global_position
	var player_w: Vector3 = actor_world_of(world, player)
	player_w.y = 0.0
	var to_player: Vector3 = player_w - Vector3(cam_pos.x, 0.0, cam_pos.z)
	to_player.y = 0.0
	if to_player.length_squared() < 0.01:
		to_player = Vector3(0, 0, -1)
	to_player = to_player.normalized()
	var dist_cp: float = Vector3(cam_pos.x, 0, cam_pos.z).distance_to(player_w)
	var furn_dist: float = maxf(dist_cp - 1.05, 5.5)
	var furn_world: Vector3 = Vector3(cam_pos.x, 0, cam_pos.z) + to_player * furn_dist
	player_w = furn_world + to_player * 1.0
	var player_local: Vector3 = world.to_local(player_w)
	player.global_position = Vector2(player_local.x * cell, player_local.z * cell)
	partition.global_position = furn_world
	partition.rotation = Vector3(0, atan2(-to_player.x, -to_player.z), 0)
	await settle(20)

	# Re-nudge
	cam_pos = cam.global_position
	player_w = actor_world_of(world, player)
	player_w.y = 0.0
	to_player = player_w - Vector3(cam_pos.x, 0, cam_pos.z)
	to_player.y = 0.0
	to_player = to_player.normalized() if to_player.length_squared() > 0.0001 else Vector3(0, 0, -1)
	dist_cp = Vector3(cam_pos.x, 0, cam_pos.z).distance_to(player_w)
	furn_dist = maxf(dist_cp - 1.05, 5.5)
	furn_world = Vector3(cam_pos.x, 0, cam_pos.z) + to_player * furn_dist
	player_w = furn_world + to_player * 1.0
	player_local = world.to_local(player_w)
	player.global_position = Vector2(player_local.x * cell, player_local.z * cell)
	partition.global_position = furn_world
	partition.rotation = Vector3(0, atan2(-to_player.x, -to_player.z), 0)
	await settle(16)
	if world.has_method("_update_camera_and_actor_projection"):
		world._update_camera_and_actor_projection(0.0)
	await settle(6)

	var part_mesh: MeshInstance3D = partition.find_child("AuthoredSurfaceMesh", true, false) as MeshInstance3D
	for mesh_n in fixture.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_n as MeshInstance3D
		if mi:
			mi.layers |= 8
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node in world.get_tree().get_nodes_in_group("office_dither_lighting"):
		if node.has_method("_register_mesh") and part_mesh:
			node._register_mesh(part_mesh)
	await settle(10)

	# List ALL meshes under fixture + any material_overlay
	for mesh_n in fixture.find_children("*", "MeshInstance3D", true, false):
		dump_mesh(mesh_n as MeshInstance3D, "FIXTURE_MESH")

	# Ensure cutout on live material AFTER dither
	if part_mesh and part_mesh.material_override is ShaderMaterial:
		var sm := part_mesh.material_override as ShaderMaterial
		if sm.shader and sm.shader.code.contains("occlusion_cutout_enabled"):
			sm.set_shader_parameter("occlusion_cutout_enabled", true)
	dump_mesh(part_mesh, "LIVE")

	var head: Vector3 = actor_world_of(world, player)
	head.y = 0.95
	var torso: Vector3 = actor_world_of(world, player)
	torso.y = 0.55
	# Sample on partition face center toward camera (where hole must reveal torso)
	var part_face: Vector3 = partition.global_position + Vector3(0, 0.9, 0)
	var cam_xz := Vector3(cam.global_position.x, 0, cam.global_position.z)
	var part_xz := Vector3(partition.global_position.x, 0, partition.global_position.z)
	var head_xz := Vector3(head.x, 0, head.z)
	var cam_closer := cam_xz.distance_squared_to(part_xz) < cam_xz.distance_squared_to(head_xz)
	log_line("cam_closer=%s xz_part=%.3f xz_head=%.3f" % [str(cam_closer), cam_xz.distance_to(part_xz), cam_xz.distance_to(head_xz)])
	if not cam_closer:
		log_line("FAIL_GEOM")
		quit(7)
		return

	var vp_size: Vector2 = cam.get_viewport().get_visible_rect().size
	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", vp_size)

	# Screen sample: unproject torso, but clamp toward partition face so we hit furniture pixels
	var sp_torso: Vector2 = cam.unproject_position(torso)
	var sp_face: Vector2 = cam.unproject_position(part_face)
	# Blend: prefer face for furniture coverage, slightly toward torso
	var sp: Vector2 = sp_face.lerp(sp_torso, 0.35)
	log_line("sp_face=%s sp_torso=%s sp_sample=%s vp=%s" % [str(sp_face), str(sp_torso), str(sp), str(vp_size)])

	world.set_process(false)
	for node in world.get_tree().get_nodes_in_group("office_dither_lighting"):
		node.set_process(false)
	for i in range(0, 8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)

	# --- OFF ---
	var img_off: Image = await capture()
	img_off.save_png(runtime.path_join("penetrate_v3_off.png"))

	# --- ON forced cutout ---
	var radius_px := 90.0
	var best := Vector4(sp.x / vp_size.x, sp.y / vp_size.y, radius_px, 1.0)
	RenderingServer.global_shader_parameter_set("occlusion_cutout_0", best)
	for i in range(1, 8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	log_line("FORCED_SLOT=%s" % str(best))
	var img_on: Image = await capture()
	img_on.save_png(runtime.path_join("penetrate_v3_on.png"))

	# --- B: ALPHA0 whole furniture (should match open if transparent path works) ---
	for i in range(0, 8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	force_alpha0_shader(part_mesh)
	dump_mesh(part_mesh, "ALPHA0")
	var img_a0: Image = await capture()
	img_a0.save_png(runtime.path_join("penetrate_v3_alpha0.png"))

	# --- OPEN hide fixture ---
	fixture.visible = false
	await settle(4)
	var img_open: Image = await capture()
	img_open.save_png(runtime.path_join("penetrate_v3_open.png"))
	fixture.visible = true

	var px := int(sp.x)
	var py := int(sp.y)
	# If capture came from root (letterboxed), map; WorldViewport is 1:1 with cam UV.
	if img_off.get_width() != int(vp_size.x) or img_off.get_height() != int(vp_size.y):
		var root_size := Vector2(float(img_off.get_width()), float(img_off.get_height()))
		var scale := minf(root_size.x / vp_size.x, root_size.y / vp_size.y)
		var offset := (root_size - vp_size * scale) * 0.5
		px = int(offset.x + sp.x * scale)
		py = int(offset.y + sp.y * scale)
	log_line("sample_px=%d,%d img=%dx%d vp=%s" % [px, py, img_off.get_width(), img_off.get_height(), str(vp_size)])

	crop_around(img_on, px, py, 100).save_png(runtime.path_join("penetrate_v3_crop_on.png"))
	crop_around(img_off, px, py, 100).save_png(runtime.path_join("penetrate_v3_crop_off.png"))
	crop_around(img_open, px, py, 100).save_png(runtime.path_join("penetrate_v3_crop_open.png"))
	crop_around(img_a0, px, py, 100).save_png(runtime.path_join("penetrate_v3_crop_alpha0.png"))

	var c_off := crop_around(img_off, px, py, 100)
	var c_on := crop_around(img_on, px, py, 100)
	var c_open := crop_around(img_open, px, py, 100)
	var sbs := Image.create(c_off.get_width() * 3 + 12, c_off.get_height(), false, Image.FORMAT_RGBA8)
	sbs.fill(Color(0.05, 0.05, 0.08, 1))
	sbs.blit_rect(c_off, Rect2i(Vector2i.ZERO, c_off.get_size()), Vector2i(0, 0))
	sbs.blit_rect(c_on, Rect2i(Vector2i.ZERO, c_on.get_size()), Vector2i(c_off.get_width() + 6, 0))
	sbs.blit_rect(c_open, Rect2i(Vector2i.ZERO, c_open.get_size()), Vector2i(c_off.get_width() * 2 + 12, 0))
	sbs.save_png(runtime.path_join("penetrate_v3_sbs.png"))

	var off_a := avg(img_off, px, py, 14)
	var on_a := avg(img_on, px, py, 14)
	var a0_a := avg(img_a0, px, py, 14)
	var open_a := avg(img_open, px, py, 14)
	var black := Color(0, 0, 0, 1)
	log_line("OFF=%s ON=%s ALPHA0=%s OPEN=%s" % [str(off_a), str(on_a), str(a0_a), str(open_a)])
	log_line("on_to_open=%.4f on_to_black=%.4f a0_to_open=%.4f a0_to_black=%.4f open_to_black=%.4f" % [
		dist(on_a, open_a), dist(on_a, black), dist(a0_a, open_a), dist(a0_a, black), dist(open_a, black)
	])
	log_line("luma off=%.3f on=%.3f a0=%.3f open=%.3f" % [luma(off_a), luma(on_a), luma(a0_a), luma(open_a)])

	# Probe verdicts
	var a0_ok := dist(a0_a, open_a) + 0.05 < dist(a0_a, black) and dist(a0_a, open_a) < 0.55
	var on_ok := dist(on_a, open_a) + 0.05 < dist(on_a, black) and dist(on_a, open_a) < 0.55 and luma(on_a) > 0.15
	# OFF should differ from OPEN (furniture covering) — otherwise geom bad
	var off_hides := dist(off_a, open_a) > 0.12
	log_line("PROBE_A_open_ref luma=%.3f" % luma(open_a))
	log_line("PROBE_B_alpha0_ok=%s (whole mesh ALPHA0 ~ open)" % str(a0_ok))
	log_line("PROBE_ON_ok=%s off_hides=%s" % [str(on_ok), str(off_hides)])

	var accepted := on_ok and off_hides and cam_closer
	log_line("JUDGE => %s" % ("PASS" if accepted else "FAIL"))
	log_line("PENETRATE_V3_DONE")
	quit(0 if accepted else 2)