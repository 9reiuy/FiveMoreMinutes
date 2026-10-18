extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DisplayServer.window_set_position(Vector2i(-2400, -2400))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 720)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = true
	world.persist_profile = false
	if "enable_game_start_cab_exit" in world:
		world.enable_game_start_cab_exit = false
	root.add_child(world)
	for i in 25: await process_frame
	world.regenerate(41001)
	for i in 100:
		await process_frame
		if i % 25 == 0: DisplayServer.window_set_position(Vector2i(-2400, -2400))
	var cam: Camera3D = world.camera_3d
	if "rooms" in world:
		for room in world.rooms:
			if String(room.get("archetype", "")) == "open_office":
				if world.get("player") != null:
					world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
				if world.has_method("activate_room"):
					world.activate_room(int(room.id))
				break
	for i in 50: await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("E:/GameProjects/FiveMinuteMore/.runtime/cutout_sample/flicker_fix_office_lit.png")
	# Sample a few on-screen furniture centers for luma
	var samples := 0
	var dark := 0
	var sum_l := 0.0
	for mesh in world.find_children("*", "MeshInstance3D", true, false):
		if samples >= 40:
			break
		if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var is_furn := false
		var cursor: Node = mesh
		while cursor != null:
			if cursor.has_meta(&"occlusion_cutout_occluder") and bool(cursor.get_meta(&"occlusion_cutout_occluder")):
				is_furn = true
				break
			cursor = cursor.get_parent()
		if not is_furn or cam == null:
			continue
		var c3: Vector3 = mesh.global_transform * mesh.get_aabb().get_center()
		if cam.is_position_behind(c3):
			continue
		var sp: Vector2 = cam.unproject_position(c3)
		var vp := cam.get_viewport().get_visible_rect()
		if not vp.has_point(sp):
			continue
		# map to root 1280x720
		var scale := minf(1280.0 / vp.size.x, 720.0 / vp.size.y)
		var offset := (Vector2(1280, 720) - vp.size * scale) * 0.5
		var px := int(offset.x + sp.x * scale)
		var py := int(offset.y + sp.y * scale)
		if px < 2 or py < 2 or px >= img.get_width()-2 or py >= img.get_height()-2:
			continue
		var acc := Color(0,0,0,0)
		for dy in range(-2,3):
			for dx in range(-2,3):
				acc += img.get_pixel(px+dx, py+dy)
		acc /= 25.0
		var l := acc.r+acc.g+acc.b
		sum_l += l
		samples += 1
		if l < 0.18:
			dark += 1
	var avg := sum_l / float(maxi(samples,1))
	print("LIT_SAMPLES n=%d dark_lt018=%d avg_luma=%.3f" % [samples, dark, avg])
	# dark furniture ratio should be low if lights reach layer 1
	var ok := samples >= 8 and float(dark) / float(samples) < 0.35 and avg > 0.25
	print("LIT_RESULT %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)