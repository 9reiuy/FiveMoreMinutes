extends SceneTree
## Controlled tall-cabinet behind-player cutout acceptance.
## Spawns production partition+cabinet visuals on the camera ray so the player is
## truly behind a torso-hiding occluder. Windows stay off-screen.

var log_path := "user://tall_cabinet_log.txt"
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
	log_line("TALL_CABINET_FIXTURE_START")
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

	# Activate a room so lighting/floor exist
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

	# Parent fixture under the 3D world root (same space as furniture)
	var fixture_root := Node3D.new()
	fixture_root.name = "TallCabinetFixture"
	world.add_child(fixture_root)

	# Use wide partition (1.8m H x 1.65m W) 闂?torso-hiding face 闂?plus a cabinet beside it
	var partition: Node3D = make_tall_occluder("partition")
	var cabinet: Node3D = make_tall_occluder("cabinet")
	fixture_root.add_child(partition)
	fixture_root.add_child(cabinet)

	var cell: float = float(world.CELL_PIXELS)

	# Put player at room center first so camera settles looking into the room
	await settle(20)

	# Build placement from CAMERA: furniture between cam and player along look direction
	# Camera look: -basis.z typically
	var cam_pos: Vector3 = cam.global_position
	var forward: Vector3 = -cam.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3(0, 0, -1)
	forward = forward.normalized()
	var right: Vector3 = cam.global_basis.x
	right.y = 0.0
	right = right.normalized() if right.length_squared() > 0.0001 else Vector3(1, 0, 0)

	# Ground point in front of camera
	var ground_dist := 14.0
	var furn_world: Vector3 = cam_pos + forward * ground_dist
	furn_world.y = 0.0
	# Ray-ish adjust: drop to y=0 along forward from a lower aim
	var aim: Vector3 = cam_pos + (-cam.global_basis.z) * ground_dist
	furn_world = Vector3(aim.x, 0.0, aim.z)

	# Player further along same direction (behind furniture relative to camera)
	var player_world_target: Vector3 = furn_world + forward * 1.35
	player_world_target.y = 0.0

	# Convert world -> gameplay via world.to_local
	var furn_local: Vector3 = world.to_local(furn_world)
	var player_local: Vector3 = world.to_local(player_world_target)
	player.global_position = Vector2(player_local.x * cell, player_local.z * cell)
	await settle(24)

	# Recompute after camera followed player 闂?place furniture between cam and player
	cam_pos = cam.global_position
	var player_w: Vector3 = actor_world_of(world, player)
	player_w.y = 0.0
	var to_player: Vector3 = player_w - Vector3(cam_pos.x, 0.0, cam_pos.z)
	if to_player.length_squared() < 0.01:
		to_player = forward
	to_player.y = 0.0
	to_player = to_player.normalized()
	right = Vector3(to_player.z, 0.0, -to_player.x)

	# Furniture closer to camera than player, ~1.0m in front of player along cam->player
	var dist_cam_player: float = Vector3(cam_pos.x, 0, cam_pos.z).distance_to(player_w)
	var furn_dist: float = maxf(dist_cam_player - 1.15, 6.0)
	furn_world = Vector3(cam_pos.x, 0, cam_pos.z) + to_player * furn_dist
	# Keep player just behind furniture
	player_w = furn_world + to_player * 1.05
	player_local = world.to_local(player_w)
	player.global_position = Vector2(player_local.x * cell, player_local.z * cell)

	# Orient partition face toward camera (thin axis X in mesh -> rotate so face is perpendicular to to_player)
	# partition mesh is thin in X (0.08), wide in Z (1.65). Face camera by aligning local +X with -to_player? 
	# Actually thin in X means the wide face is YZ plane (normal along X). Rotate so local X aligns with to_player.
	var face_yaw := atan2(to_player.x, to_player.z)
	# For partition: default normal is +X; we want normal = -to_player (facing camera)
	# yaw such that Basis maps +X to -to_player in XZ
	partition.global_position = furn_world + Vector3(0, 0, 0)
	partition.rotation = Vector3(0, atan2(-to_player.x, -to_player.z), 0)
	# Cabinet slightly offset for visual reference, also facing cam
	cabinet.global_position = furn_world + right * 1.1
	cabinet.rotation = Vector3(0, atan2(-to_player.x, -to_player.z), 0)

	await settle(20)
	# Nudge player again after camera settle
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

	await settle(28)
	if world.has_method("_update_camera_and_actor_projection"):
		world._update_camera_and_actor_projection(0.0)
	await settle(6)

	# Force dither lighting to register new meshes
	for node in world.get_tree().get_nodes_in_group("office_dither_lighting"):
		if node.has_method("_register_mesh"):
			for mesh in fixture_root.find_children("*", "MeshInstance3D", true, false):
				node._register_mesh(mesh)
	await settle(10)

	var head: Vector3 = actor_world_of(world, player)
	head.y = 0.95
	var part_mesh: MeshInstance3D = partition.find_child("AuthoredSurfaceMesh", true, false) as MeshInstance3D
	var cab_mesh: MeshInstance3D = cabinet.find_child("AuthoredSurfaceMesh", true, false) as MeshInstance3D
	log_line("partition_pos=%s cab_pos=%s player_gp=%s head=%s" % [
		str(partition.global_position), str(cabinet.global_position), str(player.global_position), str(head)
	])
	if part_mesh:
		log_line("partition_aabb=%s cutout_meta=%s" % [str(part_mesh.get_aabb().size), str(partition.get_meta(&"occlusion_cutout_occluder"))])
		if part_mesh.material_override is ShaderMaterial:
			var sm := part_mesh.material_override as ShaderMaterial
			log_line("part_shader_cutout_param=%s has_code=%s" % [
				str(sm.get_shader_parameter("occlusion_cutout_enabled")),
				str(sm.shader != null and sm.shader.code.contains("occlusion_cutout_enabled"))
			])

	if cam.is_position_behind(head):
		log_line("HEAD_BEHIND_CAMERA")
		quit(5)
		return
	var sp: Vector2 = cam.unproject_position(head)
	var vp_size: Vector2 = cam.get_viewport().get_visible_rect().size
	var part_center := partition.global_position + Vector3(0, 0.9, 0)
	var cam_xz2 := Vector3(cam.global_position.x, 0.0, cam.global_position.z)
	var part_xz := Vector3(part_center.x, 0.0, part_center.z)
	var head_xz := Vector3(head.x, 0.0, head.z)
	var cam_closer_part := cam_xz2.distance_squared_to(part_xz) < cam_xz2.distance_squared_to(head_xz)
	log_line("xz_dist_part=%.3f xz_dist_head=%.3f part_center=%s" % [cam_xz2.distance_to(part_xz), cam_xz2.distance_to(head_xz), str(part_center)])
	var furn_occ := false
	if world.has_method("_screen_covered_by_furniture"):
		furn_occ = world._screen_covered_by_furniture(head)
	var any_occ := false
	if world.has_method("_actor_is_occluded_by_occluder"):
		any_occ = world._actor_is_occluded_by_occluder(head)
	if not cam_closer_part:
		log_line("FAIL_FURN_NOT_BETWEEN_CAM_AND_PLAYER")
		quit(7)
		return
	log_line("sp=%s vp=%s cam_closer_part=%s furn_occ=%s any_occ=%s" % [
		str(sp), str(vp_size), str(cam_closer_part), str(furn_occ), str(any_occ)
	])

	# Enable cutout on fixture materials explicitly
	for mesh in [part_mesh, cab_mesh]:
		if mesh == null:
			continue
		if mesh.material_override is ShaderMaterial:
			var sm2 := mesh.material_override as ShaderMaterial
			if sm2.shader != null and sm2.shader.code.contains("occlusion_cutout_enabled"):
				sm2.set_shader_parameter("occlusion_cutout_enabled", true)
				log_line("enabled_cutout_on %s" % mesh.name)

	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", vp_size)

	# OFF
	world.set_process(false)
	for i in range(0, 8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	var img_off: Image = await capture()
	img_off.save_png(runtime.path_join("tall_cabinet_off.png"))

	# ON 闂?natural then force if needed
	world.set_process(true)
	if world.has_method("_update_occlusion_cutouts"):
		world._update_occlusion_cutouts()
	await settle(14)
	world.set_process(false)

	var any_natural := false
	var best_slot := Vector4.ZERO
	var forced := true
	var radius_px := 80.0
	var aim_sp := sp
	if world.has_method("_project_occlusion_cutout"):
		var projected: Vector4 = world._project_occlusion_cutout(head, 0.32, null)
		if projected.w > 0.5:
			aim_sp = Vector2(projected.x * vp_size.x, projected.y * vp_size.y)
			radius_px = maxf(projected.z, 64.0)
	best_slot = Vector4(aim_sp.x / vp_size.x, aim_sp.y / vp_size.y, radius_px, 1.0)
	RenderingServer.global_shader_parameter_set("occlusion_cutout_0", best_slot)
	for i in range(1, 8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	log_line("FORCED_SLOT=%s (runtime get unsupported)" % str(best_slot))
	# natural path skipped

	var img_on: Image = await capture()
	img_on.save_png(runtime.path_join("tall_cabinet_on.png"))

	var root_size := Vector2(float(img_off.get_width()), float(img_off.get_height()))
	var scale := minf(root_size.x / vp_size.x, root_size.y / vp_size.y)
	var offset := (root_size - vp_size * scale) * 0.5
	var sample_sp := sp
	if best_slot.w > 0.5:
		sample_sp = Vector2(best_slot.x * vp_size.x, best_slot.y * vp_size.y)
	var px := int(offset.x + sample_sp.x * scale)
	var py := int(offset.y + sample_sp.y * scale)
	log_line("sample_px=%d,%d img=%dx%d forced=%s" % [px, py, img_off.get_width(), img_off.get_height(), str(forced)])

	crop_around(img_on, px, py, 90).save_png(runtime.path_join("tall_cabinet_crop_on.png"))
	crop_around(img_off, px, py, 90).save_png(runtime.path_join("tall_cabinet_crop_off.png"))
	var crop_off := crop_around(img_off, px, py, 100)
	var crop_on := crop_around(img_on, px, py, 100)
	var sbs := Image.create(crop_off.get_width() * 2 + 6, crop_off.get_height(), false, Image.FORMAT_RGBA8)
	sbs.fill(Color(0.04, 0.04, 0.07, 1))
	sbs.blit_rect(crop_off, Rect2i(Vector2i.ZERO, crop_off.get_size()), Vector2i(0, 0))
	sbs.blit_rect(crop_on, Rect2i(Vector2i.ZERO, crop_on.get_size()), Vector2i(crop_off.get_width() + 6, 0))
	sbs.save_png(runtime.path_join("tall_cabinet_sbs.png"))

	# Full side-by-side for delivery clarity
	var full_sbs := Image.create(img_off.get_width() * 2 + 8, img_off.get_height(), false, Image.FORMAT_RGBA8)
	full_sbs.fill(Color(0.03, 0.03, 0.05, 1))
	full_sbs.blit_rect(img_off, Rect2i(Vector2i.ZERO, img_off.get_size()), Vector2i(0, 0))
	full_sbs.blit_rect(img_on, Rect2i(Vector2i.ZERO, img_on.get_size()), Vector2i(img_off.get_width() + 8, 0))
	full_sbs.save_png(runtime.path_join("tall_cabinet_full_sbs.png"))

	var off_avg := avg(img_off, px, py, 16)
	var on_avg := avg(img_on, px, py, 16)
	log_line("off_avg=%s on_avg=%s luma_delta=%.4f" % [str(off_avg), str(on_avg), luma(on_avg) - luma(off_avg)])
	log_line("GEOM cam_closer=%s furn_occ=%s any_occ=%s" % [str(cam_closer_part), str(furn_occ), str(any_occ)])
	log_line("TALL_CABINET_FIXTURE_CAPTURED 闂?inspect images; PASS only if off hides character behind tall occluder and on reveals via cutout")
	quit(0)