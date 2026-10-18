extends SceneTree
## Acceptance: player behind REAL furniture; cutout off blocks, on reveals character (not clear-black).
## Does NOT modify production shaders/layers. Placement uses world.to_local <-> gameplay mapping.

var log_path := "user://furn_penetrate_log.txt"
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
			if c.r + c.g + c.b < 0.10:
				black += 1
	return float(black) / float(maxi(n, 1))

func colorfulness(img: Image, cx: int, cy: int, r: int) -> float:
	var s := 0.0
	var n := 0
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var c := img.get_pixel(x, y)
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			s += mx - mn
			n += 1
	return s / float(maxi(n, 1))

func keep_window_away() -> void:
	# Keep WINDOWED so the GPU still presents; only park off-screen.
	# Minimized windows can stop updating root.get_texture() and abort capture.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(-2400, -2400))

func capture() -> Image:
	for i in 8:
		await process_frame
		keep_window_away()
	await RenderingServer.frame_post_draw
	keep_window_away()
	return root.get_texture().get_image()

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

func gameplay_from_world(world: Node3D, world_pos: Vector3) -> Vector2:
	var local: Vector3 = world.to_local(world_pos)
	return Vector2(local.x * world.CELL_PIXELS, local.z * world.CELL_PIXELS)

func actor_world_of(world: Node3D, player: Node2D) -> Vector3:
	if world.has_method("_get_actor_cutout_slot"):
		var cut: Dictionary = world._get_actor_cutout_slot(player)
		if not cut.is_empty():
			return cut.get("world", Vector3.ZERO)
	return world.get_gameplay_world_position(player.global_position, 0.48)

func mesh_has_cutout(mesh: MeshInstance3D) -> bool:
	if mesh.material_override is ShaderMaterial:
		var sm := mesh.material_override as ShaderMaterial
		if sm.shader != null and sm.shader.code.contains("occlusion_cutout_enabled"):
			return true
	if mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
		var sm2 := mesh.get_active_material(0) as ShaderMaterial
		if sm2 != null and sm2.shader != null and sm2.shader.code.contains("occlusion_cutout_enabled"):
			return true
	return false

func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(-2400, -2400))
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("FURN_PENETRATE_START")
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
	for i in 30:
		await process_frame
		keep_window_away()
	world.regenerate(41001)
	for i in 140:
		await process_frame
		if i % 30 == 0:
			keep_window_away()

	if "rooms" in world:
		for room in world.rooms:
			if String(room.get("archetype", "")) == "open_office":
				if world.get("player") != null:
					world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
				if world.has_method("activate_room"):
					world.activate_room(int(room.id))
				log_line("activated_open_office id=%s center=%s" % [str(room.id), str(room.center_cell)])
				break
	for i in 50:
		await process_frame
		keep_window_away()

	var cam: Camera3D = world.camera_3d
	var player: Node2D = world.get("player") as Node2D
	if player == null or cam == null:
		log_line("NO_PLAYER_OR_CAM")
		quit(3)
		return
	player.set_physics_process(false)
	player.set_process(false)

	var best_mesh: MeshInstance3D = null
	var best_score := -1.0
	var best_aabb := AABB()
	var meshes: Array = world.find_children("*", "MeshInstance3D", true, false)
	for node in meshes:
		var mesh := node as MeshInstance3D
		if mesh == null or not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		if not world._mesh_belongs_to_furniture(mesh):
			continue
		if not mesh_has_cutout(mesh):
			continue
		var local_aabb: AABB = mesh.get_aabb()
		if local_aabb.size.y < 0.45:
			continue
		var world_aabb := world_aabb_of(mesh)
		var center: Vector3 = world_aabb.get_center()
		if cam.is_position_behind(center):
			continue
		var sp: Vector2 = cam.unproject_position(center)
		var vr: Rect2 = cam.get_viewport().get_visible_rect().grow(-48)
		if not vr.has_point(sp):
			continue
		# Prefer mesh closer to screen center and tall.
		var center_bias := 1.0 / (1.0 + sp.distance_to(vr.get_center()) * 0.01)
		var score := local_aabb.size.y * 12.0 + local_aabb.size.x * local_aabb.size.z * 0.5 + center_bias * 8.0
		var path_s := String(mesh.get_path()).to_lower()
		if path_s.contains("cabinet") or path_s.contains("shelf") or path_s.contains("locker") or path_s.contains("book") or path_s.contains("tall") or path_s.contains("workstation"):
			score += 18.0
		if path_s.contains("chair") or path_s.contains("seat"):
			score -= 8.0
		if score > best_score:
			best_score = score
			best_mesh = mesh
			best_aabb = world_aabb

	if best_mesh == null:
		# Fallback without cutout shader filter / height floor
		for node in meshes:
			var mesh := node as MeshInstance3D
			if mesh == null or not mesh.is_visible_in_tree() or mesh.mesh == null:
				continue
			if not world._mesh_belongs_to_furniture(mesh):
				continue
			var local_aabb: AABB = mesh.get_aabb()
			if local_aabb.size.length_squared() < 0.05:
				continue
			var world_aabb := world_aabb_of(mesh)
			var center: Vector3 = world_aabb.get_center()
			if cam.is_position_behind(center):
				continue
			var sp: Vector2 = cam.unproject_position(center)
			var vr: Rect2 = cam.get_viewport().get_visible_rect().grow(-48)
			if not vr.has_point(sp):
				continue
			var score := local_aabb.size.y
			if score > best_score:
				best_score = score
				best_mesh = mesh
				best_aabb = world_aabb

	if best_mesh == null:
		log_line("NO_FURNITURE_ON_SCREEN")
		quit(4)
		return

	var furn_center: Vector3 = best_aabb.get_center()
	var cam_local: Vector3 = world.to_local(cam.global_position)
	var furn_local: Vector3 = world.to_local(furn_center)
	var away: Vector3 = furn_local - cam_local
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3(0, 0, 1)
	else:
		away = away.normalized()
	var lateral := Vector3(away.z, 0, -away.x)
	var cell: float = float(world.CELL_PIXELS)
	var half_depth: float = maxf(best_aabb.size.x, best_aabb.size.z) * 0.5

	log_line("furn=%s aabb_size=%s center_global=%s furn_local=%s cam_local=%s cutout_shader=%s layers=%d" % [
		str(best_mesh.get_path()), str(best_aabb.size), str(furn_center), str(furn_local), str(cam_local),
		str(mesh_has_cutout(best_mesh)), best_mesh.layers
	])

	var placed := false
	var offsets: Array = []
	for dist_mul in [0.55, 0.85, 1.15, 1.45, 1.8, 2.2]:
		offsets.append(away * (half_depth + dist_mul))
	for dist_mul in [0.7, 1.1, 1.5]:
		offsets.append(away * (half_depth + dist_mul) + lateral * 0.35)
		offsets.append(away * (half_depth + dist_mul) - lateral * 0.35)

	for off in offsets:
		var p_local: Vector3 = furn_local + off
		p_local.y = 0.0
		player.global_position = Vector2(p_local.x * cell, p_local.z * cell)
		# Let camera catch up toward player
		for i in 12:
			await process_frame
			keep_window_away()
		var player_world: Vector3 = actor_world_of(world, player)
		var head := player_world
		head.y = maxf(head.y, 0.48)
		var occluded := false
		if world.has_method("_actor_is_occluded_by_occluder"):
			occluded = world._actor_is_occluded_by_occluder(head)
		var behind_cam := cam.is_position_behind(head)
		var sp: Vector2 = cam.unproject_position(head) if not behind_cam else Vector2(-1, -1)
		var on_screen := (not behind_cam) and cam.get_viewport().get_visible_rect().grow(-10).has_point(sp)
		var cam_closer_to_furn := cam.global_position.distance_squared_to(furn_center) < cam.global_position.distance_squared_to(player_world)
		log_line("try off=%s player_gp=%s player_world=%s occluded=%s on_screen=%s cam_closer_furn=%s sp=%s" % [
			str(off), str(player.global_position), str(player_world), str(occluded), str(on_screen), str(cam_closer_to_furn), str(sp)
		])
		if occluded and on_screen and cam_closer_to_furn:
			placed = true
			break

	if not placed:
		# Last resort: sit just past furniture local center along away
		var p_local: Vector3 = furn_local + away * (half_depth + 1.0)
		p_local.y = 0.0
		player.global_position = Vector2(p_local.x * cell, p_local.z * cell)
		for i in 16:
			await process_frame
			keep_window_away()
		log_line("WARN_PLACE_FALLBACK used; may not be naturally occluded")

	for i in 20:
		await process_frame
		keep_window_away()

	var player_world2: Vector3 = actor_world_of(world, player)
	var head2 := player_world2
	head2.y = maxf(head2.y, 0.55)
	if cam.is_position_behind(head2):
		log_line("PLAYER_BEHIND_CAMERA world=%s" % str(head2))
		quit(5)
		return
	var sp_player: Vector2 = cam.unproject_position(head2)
	var vp_size: Vector2 = cam.get_viewport().get_visible_rect().size
	var natural_occluded := false
	if world.has_method("_actor_is_occluded_by_occluder"):
		natural_occluded = world._actor_is_occluded_by_occluder(head2)
	log_line("final player_world=%s sp=%s vp=%s natural_occluded=%s placed=%s" % [
		str(head2), str(sp_player), str(vp_size), str(natural_occluded), str(placed)
	])

	var cut_enabled := false
	if best_mesh.material_override is ShaderMaterial:
		var sm := best_mesh.material_override as ShaderMaterial
		if sm.shader != null and sm.shader.code.contains("occlusion_cutout_enabled"):
			cut_enabled = bool(sm.get_shader_parameter("occlusion_cutout_enabled"))
	elif best_mesh.mesh != null and best_mesh.mesh.get_surface_count() > 0:
		var sm2 := best_mesh.get_active_material(0) as ShaderMaterial
		if sm2 != null and sm2.shader != null and sm2.shader.code.contains("occlusion_cutout_enabled"):
			cut_enabled = bool(sm2.get_shader_parameter("occlusion_cutout_enabled"))
	log_line("furn_cutout_enabled=%s layers=%d" % [str(cut_enabled), best_mesh.layers])

	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", vp_size)

	# --- OFF ---
	world.set_process(false)
	for i in range(0, 8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	var img_off: Image = await capture()
	img_off.save_png(runtime.path_join("furn_penetrate_off.png"))

	# --- ON: natural update ---
	world.set_process(true)
	if world.has_method("_update_occlusion_cutouts"):
		world._update_occlusion_cutouts()
	for i in 12:
		await process_frame
		keep_window_away()
	if world.has_method("_update_occlusion_cutouts"):
		world._update_occlusion_cutouts()
	for i in 4:
		await process_frame
	world.set_process(false)

	var any_natural := false
	for i in range(0, 8):
		var v: Variant = RenderingServer.global_shader_parameter_get("occlusion_cutout_%d" % i)
		log_line("natural_slot%d=%s" % [i, str(v)])
		if v is Vector4 and (v as Vector4).w > 0.5:
			any_natural = true

	var forced := false
	if not any_natural:
		forced = true
		var overlap: Variant = null
		if world.has_method("_actor_screen_overlap"):
			overlap = world._actor_screen_overlap(head2, 0.28)
		var aim: Vector2 = sp_player
		if overlap is Vector2:
			aim = overlap
		var radius_px := 70.0
		if world.has_method("_project_occlusion_cutout"):
			var projected: Vector4 = world._project_occlusion_cutout(head2, 0.28, overlap)
			if projected.w > 0.5:
				aim = Vector2(projected.x * vp_size.x, projected.y * vp_size.y)
				radius_px = projected.z
		var slot := Vector4(aim.x / vp_size.x, aim.y / vp_size.y, maxf(radius_px, 48.0), 1.0)
		RenderingServer.global_shader_parameter_set("occlusion_cutout_0", slot)
		for i in range(1, 8):
			RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
		log_line("FORCED_SLOT=%s (natural empty; natural_occluded=%s)" % [str(slot), str(natural_occluded)])
	else:
		log_line("NATURAL_SLOTS_OK")

	var img_on: Image = await capture()
	img_on.save_png(runtime.path_join("furn_penetrate_on.png"))

	var root_size := Vector2(float(img_off.get_width()), float(img_off.get_height()))
	var scale := minf(root_size.x / vp_size.x, root_size.y / vp_size.y)
	var offset := (root_size - vp_size * scale) * 0.5
	var sample_sp := sp_player
	var slot0: Variant = RenderingServer.global_shader_parameter_get("occlusion_cutout_0")
	if slot0 is Vector4 and (slot0 as Vector4).w > 0.5:
		sample_sp = Vector2((slot0 as Vector4).x * vp_size.x, (slot0 as Vector4).y * vp_size.y)
	var px := int(offset.x + sample_sp.x * scale)
	var py := int(offset.y + sample_sp.y * scale)
	log_line("sample_px=%d,%d sample_sp=%s" % [px, py, str(sample_sp)])

	crop_around(img_off, px, py, 48).save_png(runtime.path_join("furn_penetrate_crop_off.png"))
	crop_around(img_on, px, py, 48).save_png(runtime.path_join("furn_penetrate_crop_on.png"))

	var crop_off := crop_around(img_off, px, py, 64)
	var crop_on := crop_around(img_on, px, py, 64)
	var sbs := Image.create(crop_off.get_width() * 2 + 4, crop_off.get_height(), false, Image.FORMAT_RGBA8)
	sbs.fill(Color(0.05, 0.05, 0.08, 1))
	sbs.blit_rect(crop_off, Rect2i(Vector2i.ZERO, crop_off.get_size()), Vector2i(0, 0))
	sbs.blit_rect(crop_on, Rect2i(Vector2i.ZERO, crop_on.get_size()), Vector2i(crop_off.get_width() + 4, 0))
	sbs.save_png(runtime.path_join("furn_penetrate_sbs.png"))

	var off_avg := avg(img_off, px, py, 10)
	var on_avg := avg(img_on, px, py, 10)
	var off_black := black_ratio(img_off, px, py, 18)
	var on_black := black_ratio(img_on, px, py, 18)
	var off_chroma := colorfulness(img_off, px, py, 14)
	var on_chroma := colorfulness(img_on, px, py, 14)
	var luma_delta := luma(on_avg) - luma(off_avg)

	log_line("off_avg=%s black=%.3f chroma=%.4f" % [str(off_avg), off_black, off_chroma])
	log_line("on_avg=%s black=%.3f chroma=%.4f" % [str(on_avg), on_black, on_chroma])
	log_line("luma_delta=%.4f forced=%s placed_natural_occlude=%s" % [luma_delta, str(forced), str(placed)])

	var hole_not_black := on_black < 0.45 and luma(on_avg) > 0.18
	var changed := absf(luma_delta) > 0.04 or absf(on_chroma - off_chroma) > 0.02
	var has_characterish := on_chroma > 0.04 or (hole_not_black and luma(on_avg) > luma(off_avg) + 0.03)
	log_line("ASSERT hole_not_black=%s changed=%s has_characterish=%s" % [
		str(hole_not_black), str(changed), str(has_characterish)
	])
	if hole_not_black and changed and has_characterish:
		log_line("FURN_PENETRATE_PASS")
		quit(0)
	else:
		log_line("FURN_PENETRATE_FAIL")
		quit(2)
