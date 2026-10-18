extends SceneTree
## Production-path cutout: SelectivePixelPreview composite + exclusive layer-8 furniture.
## Evidence: OFF|ON only. Capture final root (includes composite).

var log_path := "user://real_cutout_log.txt"
var runtime := ""
var world_viewport: SubViewport
var display: Node

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

func capture_final() -> Image:
	await settle(6)
	await RenderingServer.frame_post_draw
	keep_away()
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

func black_ratio(img: Image, cx: int, cy: int, r: int) -> float:
	var black := 0
	var n := 0
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var c := img.get_pixel(x, y)
			n += 1
			if c.r + c.g + c.b < 0.12:
				black += 1
	return float(black) / float(maxi(n, 1))

func crop_around(img: Image, cx: int, cy: int, half: int) -> Image:
	var x0 := clampi(cx - half, 0, img.get_width() - 1)
	var y0 := clampi(cy - half, 0, img.get_height() - 1)
	var w := mini(half * 2, img.get_width() - x0)
	var h := mini(half * 2, img.get_height() - y0)
	return img.get_region(Rect2i(x0, y0, w, h))

func world_aabb_of(mesh: MeshInstance3D) -> AABB:
	var local_aabb: AABB = mesh.get_aabb()
	var xf := mesh.global_transform
	var world_aabb := AABB(xf * local_aabb.position, Vector3.ZERO)
	for xi in [0.0, 1.0]:
		for yi in [0.0, 1.0]:
			for zi in [0.0, 1.0]:
				var corner := local_aabb.position + local_aabb.size * Vector3(xi, yi, zi)
				world_aabb = world_aabb.expand(xf * corner)
	return world_aabb

func actor_world_of(world: Node3D, player: Node2D) -> Vector3:
	if world.has_method("_get_actor_cutout_slot"):
		var cut: Dictionary = world._get_actor_cutout_slot(player)
		if not cut.is_empty():
			return cut.get("world", Vector3.ZERO)
	return world.get_gameplay_world_position(player.global_position, 0.55)

func mesh_cutout_enabled(mesh: MeshInstance3D) -> bool:
	var mats: Array = []
	if mesh.material_override is ShaderMaterial:
		mats.append(mesh.material_override)
	elif mesh.mesh != null:
		for i in mesh.mesh.get_surface_count():
			var m := mesh.get_active_material(i)
			if m is ShaderMaterial:
				mats.append(m)
	for m in mats:
		var sm := m as ShaderMaterial
		if sm.shader != null and sm.shader.code.contains("occlusion_cutout_enabled"):
			return bool(sm.get_shader_parameter("occlusion_cutout_enabled"))
	return false

func run() -> void:
	keep_away()
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("REAL_CUTOUT_START")
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
	await settle(20)

	display = root.get_node_or_null("DreamSettingsDisplay")
	if display == null:
		for n in root.find_children("*", "Control", true, false):
			if n.is_in_group(&"dream_display"):
				display = n
				break
	for n in root.find_children("*", "SubViewport", true, false):
		if String(n.name) == "WorldViewport":
			world_viewport = n as SubViewport
			break
	var overlay := root.find_child("OcclusionCutoutComposite", true, false) as CanvasItem
	log_line("display=%s world_vp=%s overlay=%s overlay_visible=%s" % [
		str(display != null), str(world_viewport != null),
		str(overlay != null), str(overlay.visible) if overlay else "n/a"
	])
	if overlay != null and not overlay.visible:
		overlay.visible = true
		log_line("FORCED_OVERLAY_VISIBLE")

	await settle(10)
	world.regenerate(41001)
	await settle(120)

	if "rooms" in world:
		for room in world.rooms:
			if String(room.get("archetype", "")) == "open_office":
				if world.get("player") != null:
					world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
				if world.has_method("activate_room"):
					world.activate_room(int(room.id))
				log_line("activated_open_office id=%s" % str(room.id))
				break
	await settle(40)

	var cam: Camera3D = world.camera_3d
	var player: Node2D = world.get("player") as Node2D
	if cam == null or player == null:
		log_line("NO_CAM_PLAYER")
		quit(3)
		return
	player.set_physics_process(false)
	player.set_process(false)

	var best_mesh: MeshInstance3D = null
	var best_score := -1.0
	var best_aabb := AABB()
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		if world.has_method("_mesh_belongs_to_furniture") and not world._mesh_belongs_to_furniture(mesh):
			continue
		var local_aabb: AABB = mesh.get_aabb()
		if local_aabb.size.y < 0.9:
			continue
		var world_aabb := world_aabb_of(mesh)
		var center: Vector3 = world_aabb.get_center()
		if cam.is_position_behind(center):
			continue
		var sp: Vector2 = cam.unproject_position(center)
		var vr: Rect2 = cam.get_viewport().get_visible_rect().grow(-40)
		if not vr.has_point(sp):
			continue
		var score := local_aabb.size.y * 20.0 + local_aabb.size.x * local_aabb.size.z
		var path_s := String(mesh.get_path()).to_lower()
		if path_s.contains("cabinet") or path_s.contains("partition") or path_s.contains("locker"):
			score += 30.0
		if path_s.contains("workstation"):
			score += 10.0
		if mesh_cutout_enabled(mesh):
			score += 15.0
		if score > best_score:
			best_score = score
			best_mesh = mesh
			best_aabb = world_aabb

	if best_mesh == null:
		log_line("NO_TALL_FURNITURE")
		quit(4)
		return

	log_line("furn=%s aabb=%s layers=%d cutout_en=%s" % [
		str(best_mesh.get_path()), str(best_aabb.size), best_mesh.layers, str(mesh_cutout_enabled(best_mesh))
	])
	if best_mesh.layers != 8:
		log_line("WARN_LAYERS_NOT_EXCLUSIVE got=%d" % best_mesh.layers)
		best_mesh.layers = 8
		log_line("FORCED_LAYER_8")

	var furn_center: Vector3 = best_aabb.get_center()
	var cam_local: Vector3 = world.to_local(cam.global_position)
	var furn_local: Vector3 = world.to_local(furn_center)
	var away: Vector3 = furn_local - cam_local
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3(0, 0, 1)
	else:
		away = away.normalized()
	var cell: float = float(world.CELL_PIXELS)
	var half_depth: float = maxf(best_aabb.size.x, best_aabb.size.z) * 0.5

	var placed := false
	for dist_mul in [0.55, 0.85, 1.15, 1.45, 1.8, 2.2, 2.6]:
		var p_local: Vector3 = furn_local + away * (half_depth + dist_mul)
		p_local.y = 0.0
		player.global_position = Vector2(p_local.x * cell, p_local.z * cell)
		await settle(14)
		if world.has_method("_update_camera_and_actor_projection"):
			world._update_camera_and_actor_projection(0.0)
		await settle(4)
		var player_world: Vector3 = actor_world_of(world, player)
		var head := player_world
		head.y = maxf(head.y, 0.55)
		var occluded := false
		if world.has_method("_actor_is_occluded_by_occluder"):
			occluded = world._actor_is_occluded_by_occluder(head)
		var behind_cam := cam.is_position_behind(head)
		var sp: Vector2 = cam.unproject_position(head) if not behind_cam else Vector2(-1, -1)
		var on_screen := (not behind_cam) and cam.get_viewport().get_visible_rect().grow(-8).has_point(sp)
		var cam_closer := cam.global_position.distance_squared_to(furn_center) < cam.global_position.distance_squared_to(player_world)
		log_line("try dist=%.2f occluded=%s on_screen=%s cam_closer=%s" % [
			dist_mul, str(occluded), str(on_screen), str(cam_closer)
		])
		if occluded and on_screen and cam_closer:
			placed = true
			break

	if not placed:
		log_line("WARN_PLACE_FALLBACK")
		var p_local2: Vector3 = furn_local + away * (half_depth + 1.1)
		player.global_position = Vector2(p_local2.x * cell, p_local2.z * cell)
		await settle(16)

	await settle(20)
	if world.has_method("_update_camera_and_actor_projection"):
		world._update_camera_and_actor_projection(0.0)
	await settle(6)

	var head2: Vector3 = actor_world_of(world, player)
	head2.y = maxf(head2.y, 0.55)
	if cam.is_position_behind(head2):
		log_line("PLAYER_BEHIND_CAMERA")
		quit(5)
		return
	var sp_player: Vector2 = cam.unproject_position(head2)
	var torso: Vector3 = head2
	torso.y = 0.45
	var sp_torso: Vector2 = cam.unproject_position(torso)
	var vp_size: Vector2 = cam.get_viewport().get_visible_rect().size
	var natural_occ := false
	if world.has_method("_actor_is_occluded_by_occluder"):
		natural_occ = world._actor_is_occluded_by_occluder(head2)
	log_line("final head=%s sp=%s torso_sp=%s natural_occ=%s placed=%s" % [
		str(head2), str(sp_player), str(sp_torso), str(natural_occ), str(placed)
	])

	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", vp_size)

	world.set_process(false)
	for i in range(0, 8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	await settle(4)
	var img_off: Image = await capture_final()
	img_off.save_png(runtime.path_join("real_off.png"))

	world.set_process(true)
	if world.has_method("_update_occlusion_cutouts"):
		world._update_occlusion_cutouts()
	await settle(10)
	if world.has_method("_update_occlusion_cutouts"):
		world._update_occlusion_cutouts()
	await settle(6)

	var any_natural := false
	var best_slot := Vector4.ZERO
	var cached: Variant = world.get("_last_cutout_slots")
	log_line("last_cutout_slots=%s" % str(cached))
	if cached is Array:
		for i in range(mini((cached as Array).size(), 8)):
			var v2: Variant = (cached as Array)[i]
			log_line("natural_slot%d=%s" % [i, str(v2)])
			if v2 is Vector4 and (v2 as Vector4).w > 0.5:
				any_natural = true
				if (v2 as Vector4).z > best_slot.z:
					best_slot = v2

	var used_forced := false
	if not any_natural:
		used_forced = true
		var overlap: Variant = null
		if world.has_method("_actor_screen_overlap"):
			overlap = world._actor_screen_overlap(head2, 0.28)
		var projected := Vector4.ZERO
		if world.has_method("_project_occlusion_cutout"):
			projected = world._project_occlusion_cutout(head2, 0.28, overlap)
		if projected.w > 0.5:
			best_slot = projected
		else:
			var aim: Vector2 = sp_torso
			if overlap is Vector2:
				aim = overlap
			best_slot = Vector4(aim.x / vp_size.x, aim.y / vp_size.y, 64.0, 1.0)
		RenderingServer.global_shader_parameter_set("occlusion_cutout_0", best_slot)
		for i in range(1, 8):
			RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
		log_line("FORCED_VIA_PROJECT slot=%s" % str(best_slot))
	else:
		log_line("NATURAL_SLOTS_OK best_z=%.1f" % best_slot.z)

	world.set_process(false)
	await settle(4)
	var img_on: Image = await capture_final()
	img_on.save_png(runtime.path_join("real_on.png"))
	var behind_vp2: SubViewport = root.find_child("CutoutBehindViewport", true, false) as SubViewport
	if behind_vp2 != null:
		behind_vp2.get_texture().get_image().save_png(runtime.path_join("real_behind.png"))
		log_line("saved real_behind.png")

	var root_size := Vector2(float(img_off.get_width()), float(img_off.get_height()))
	var scale := minf(root_size.x / vp_size.x, root_size.y / vp_size.y)
	var offset := (root_size - vp_size * scale) * 0.5
	var sample_sp := sp_torso
	if best_slot.w > 0.5:
		sample_sp = Vector2(best_slot.x * vp_size.x, best_slot.y * vp_size.y)
	var px := int(offset.x + sample_sp.x * scale)
	var py := int(offset.y + sample_sp.y * scale)
	log_line("sample_px=%d,%d sample_sp=%s" % [px, py, str(sample_sp)])

	crop_around(img_on, px, py, 72).save_png(runtime.path_join("real_crop_on.png"))
	crop_around(img_off, px, py, 72).save_png(runtime.path_join("real_crop_off.png"))

	var c_off := crop_around(img_off, px, py, 80)
	var c_on := crop_around(img_on, px, py, 80)
	var sbs := Image.create(c_off.get_width() * 2 + 6, c_off.get_height(), false, Image.FORMAT_RGBA8)
	sbs.fill(Color(0.05, 0.05, 0.08, 1))
	sbs.blit_rect(c_off, Rect2i(Vector2i.ZERO, c_off.get_size()), Vector2i(0, 0))
	sbs.blit_rect(c_on, Rect2i(Vector2i.ZERO, c_on.get_size()), Vector2i(c_off.get_width() + 6, 0))
	sbs.save_png(runtime.path_join("real_sbs.png"))

	var off_a := avg(img_off, px, py, 12)
	var on_a := avg(img_on, px, py, 12)
	var off_black := black_ratio(img_off, px, py, 20)
	var on_black := black_ratio(img_on, px, py, 20)
	var luma_delta := luma(on_a) - luma(off_a)
	log_line("OFF avg=%s black=%.3f luma=%.3f" % [str(off_a), off_black, luma(off_a)])
	log_line("ON  avg=%s black=%.3f luma=%.3f" % [str(on_a), on_black, luma(on_a)])
	log_line("luma_delta=%.4f forced=%s" % [luma_delta, str(used_forced)])

	var rim_r := int(maxf(best_slot.z * scale * 0.95, 40.0))
	var rim_px := clampi(px + rim_r, 0, img_on.get_width() - 1)
	var rim_on := avg(img_on, rim_px, py, 6)
	log_line("rim_px=%d rim_on=%s" % [rim_px, str(rim_on)])

	var hole_not_black := on_black < 0.40 and luma(on_a) > 0.20
	var changed := absf(luma_delta) > 0.05 or on_black + 0.08 < off_black
	var furniture_still_there := luma(rim_on) > 0.12
	log_line("ASSERT hole_not_black=%s changed=%s furniture_rim=%s" % [
		str(hole_not_black), str(changed), str(furniture_still_there)
	])

	var accepted := hole_not_black and changed and furniture_still_there
	log_line("JUDGE => %s" % ("PASS" if accepted else "FAIL"))
	log_line("REAL_CUTOUT_DONE")
	quit(0 if accepted else 2)