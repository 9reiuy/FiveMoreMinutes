extends SceneTree
# Read-only probe: dump behind/main viewport textures + slot/layer facts.
# Does NOT modify office/composite production path beyond forcing test slots.

var log_path := "user://cutout_fail_probe_log.txt"

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

func avg(img: Image, cx: int, cy: int, r: int) -> Color:
	var s := Color(0, 0, 0, 0)
	var n := 0
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				s += img.get_pixel(x, y)
				n += 1
	return s / float(maxi(n, 1))

func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	DisplayServer.window_set_position(Vector2i(-2400, -2400))
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("FAIL_PROBE_START")
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 720)

	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = true
	world.persist_profile = false
	if "enable_game_start_cab_exit" in world:
		world.enable_game_start_cab_exit = false
	root.add_child(world)
	for i in 30:
		await process_frame
	world.regenerate(41001)
	for i in 140:
		await process_frame

	var display: Node = null
	for n in root.find_children("*", "Control", true, false):
		if n.is_in_group(&"dream_display"):
			display = n
			break
	var behind: SubViewport = null
	var wp: SubViewport = null
	var overlay: ColorRect = null
	var container: Control = null
	if display:
		behind = display.get_node_or_null("CutoutBehindViewport") as SubViewport
		container = display.get_node_or_null("WorldDisplayContainer") as Control
		if container:
			wp = container.get_node_or_null("WorldViewport") as SubViewport
		overlay = display.get_node_or_null("OcclusionCutoutComposite") as ColorRect
	log_line("display=%s behind=%s wp=%s overlay=%s container=%s" % [str(display), str(behind), str(wp), str(overlay), str(container)])
	if behind == null or wp == null:
		log_line("MISSING_VIEWPORTS")
		quit(3)
		return

	log_line("wp_size=%s behind_size=%s wp_world=%s behind_world=%s same_world=%s" % [
		str(wp.size), str(behind.size), str(wp.world_3d), str(behind.world_3d),
		str(wp.world_3d == behind.world_3d and wp.world_3d != null)
	])
	log_line("behind_update=%s transparent_bg=%s own_world=%s" % [
		str(behind.render_target_update_mode), str(behind.transparent_bg), str(behind.own_world_3d)
	])
	var bcam: Camera3D = behind.get_camera_3d()
	var wcam: Camera3D = world.get("camera_3d") as Camera3D
	if wcam == null:
		wcam = wp.get_camera_3d()
	log_line("bcam=%s wcam=%s bcam_cull=%s wcam_cull=%s" % [
		str(bcam), str(wcam),
		str(bcam.cull_mask if bcam else -1), str(wcam.cull_mask if wcam else -1)
	])
	if bcam and wcam:
		log_line("xform_match=%s bpos=%s wpos=%s" % [
			str(bcam.global_transform.is_equal_approx(wcam.global_transform)),
			str(bcam.global_position), str(wcam.global_position)
		])
	if overlay:
		log_line("overlay_pos=%s size=%s scale=%s z=%s visible=%s" % [
			str(overlay.position), str(overlay.size), str(overlay.scale), str(overlay.z_index), str(overlay.visible)
		])
		var mat := overlay.material as ShaderMaterial
		if mat:
			var bt = mat.get_shader_parameter(&"behind_tex")
			var mt = mat.get_shader_parameter(&"main_tex")
			log_line("mat_behind_tex=%s mat_main_tex=%s shader=%s" % [str(bt), str(mt), str(mat.shader != null)])

	# Find chair + ensure layer bit; place player behind it on screen.
	var furn: MeshInstance3D = null
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or not String(mesh.get_path()).contains("LowPixelOfficeVisual_chair/BaseMesh"):
			continue
		var center: Vector3 = mesh.global_transform * mesh.get_aabb().get_center()
		if wcam.is_position_behind(center):
			continue
		var sp0: Vector2 = wcam.unproject_position(center)
		if wcam.get_viewport().get_visible_rect().grow(-30).has_point(sp0):
			furn = mesh
			break
	if furn == null:
		log_line("NO_FURN")
		quit(3)
		return
	log_line("furn_layers=%d has8=%s path=%s" % [furn.layers, str((furn.layers & 8) != 0), str(furn.get_path())])

	var hide_root: Node = furn
	while hide_root.get_parent() != null and not hide_root.has_meta(&"occlusion_cutout_occluder"):
		hide_root = hide_root.get_parent()
	var layer8_count := 0
	var mesh_count := 0
	for node in hide_root.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m == null:
			continue
		mesh_count += 1
		if (m.layers & 8) != 0:
			layer8_count += 1
	log_line("occluder_meshes=%d with_layer8=%d meta=%s" % [mesh_count, layer8_count, str(hide_root.has_meta(&"occlusion_cutout_occluder"))])

	# Character visual layers
	var char_layer_bits: Array = []
	for node in world.find_children("*", "Sprite3D", true, false):
		var s := node as Sprite3D
		if s and s.name == &"DepthVisual":
			char_layer_bits.append("%s layers=%d" % [str(s.get_path()).get_file(), s.layers])
	log_line("depth_visuals=%s" % str(char_layer_bits))

	# Hide blockers under bridge for clean read (same as prior verify)
	var bridge: Node = hide_root.get_parent()
	for c in bridge.get_children():
		if c is MeshInstance3D:
			c.visible = false
	for c in bridge.find_children("SolidShadowCaster", "MeshInstance3D", true, false):
		c.visible = false

	if world.get("player") != null:
		world.player.set_physics_process(false)
		# Put player near chair footprint in 2D so actor is occluded by chair.
		var chair_2d := Vector2(furn.global_position.x, furn.global_position.z) * 32.0 # may be wrong scale
		# Prefer using existing world helpers if any
		if world.has_method("get_gameplay_world_position"):
			pass
		# Use unproject inverse: place player at screen point of chair
		var furn_center: Vector3 = furn.global_transform * furn.get_aabb().get_center()
		# Approximate: keep player wherever preview put them; log occlusion
		log_line("player_pos2d=%s" % str(world.player.global_position))

	var furn_center2: Vector3 = furn.global_transform * furn.get_aabb().get_center()
	var sp: Vector2 = wcam.unproject_position(furn_center2)
	var vp_size: Vector2 = wcam.get_viewport().get_visible_rect().size
	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", vp_size)
	for i in range(0, 8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)

	# Sync a few frames
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw

	var runtime := ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	DirAccess.make_dir_recursive_absolute(runtime)

	# Direct viewport dumps (the key evidence)
	var behind_img: Image = behind.get_texture().get_image()
	var main_img: Image = wp.get_texture().get_image()
	behind_img.save_png(runtime.path_join("probe_behind_tex.png"))
	main_img.save_png(runtime.path_join("probe_main_tex.png"))

	var sx := int(clamp(sp.x, 0, vp_size.x - 1))
	var sy := int(clamp(sp.y, 0, vp_size.y - 1))
	# Images may be flipped vertically vs unproject Y
	var sy_flip := int(clamp(vp_size.y - 1 - sp.y, 0, vp_size.y - 1))
	log_line("sp=%s vp_size=%s sample=(%d,%d) flip_y=%d" % [str(sp), str(vp_size), sx, sy, sy_flip])
	log_line("behind@sp=%s behind@flip=%s main@sp=%s main@flip=%s" % [
		str(avg(behind_img, sx, sy, 6)), str(avg(behind_img, sx, sy_flip, 6)),
		str(avg(main_img, sx, sy, 6)), str(avg(main_img, sx, sy_flip, 6))
	])

	# Diff behind vs main at chair
	var diff_count := 0
	var black_behind := 0
	var r := 40
	for y in range(maxi(0, sy - r), mini(behind_img.get_height(), sy + r)):
		for x in range(maxi(0, sx - r), mini(behind_img.get_width(), sx + r)):
			var b := behind_img.get_pixel(x, y)
			var m := main_img.get_pixel(x, y)
			if abs(b.r - m.r) + abs(b.g - m.g) + abs(b.b - m.b) > 0.08:
				diff_count += 1
			if b.r + b.g + b.b < 0.08:
				black_behind += 1
	log_line("local_diff_px=%d black_behind_px=%d window=%d" % [diff_count, black_behind, (2 * r + 1) * (2 * r + 1)])

	# Force large cutout at furniture and capture final root
	RenderingServer.global_shader_parameter_set("occlusion_cutout_0", Vector4(sp.x / vp_size.x, sp.y / vp_size.y, 120.0, 1.0))
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var root_on: Image = root.get_texture().get_image()
	root_on.save_png(runtime.path_join("probe_root_on.png"))

	# Hide furniture entirely — expect character/floor
	hide_root.visible = false
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var behind_open: Image = behind.get_texture().get_image()
	var main_open: Image = wp.get_texture().get_image()
	behind_open.save_png(runtime.path_join("probe_behind_open.png"))
	main_open.save_png(runtime.path_join("probe_main_open.png"))
	var root_open: Image = root.get_texture().get_image()
	root_open.save_png(runtime.path_join("probe_root_open.png"))

	log_line("behind_open@sp=%s main_open@sp=%s" % [str(avg(behind_open, sx, sy, 6)), str(avg(main_open, sx, sy, 6))])
	log_line("FAIL_PROBE_DONE")
	quit(0)
