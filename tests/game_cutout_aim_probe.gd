extends SceneTree
var log_path := "user://game_cutout_aim_log.txt"
func log_line(t: String) -> void:
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f == null: f = FileAccess.open(log_path, FileAccess.WRITE)
	else: f.seek_end()
	f.store_line(t); f.close(); print(t)
func _initialize() -> void: call_deferred("run")
func avg(img: Image, cx: int, cy: int, r: int) -> Color:
	var s := Color(0,0,0,0); var n:=0
	for y in range(cy-r,cy+r+1):
		for x in range(cx-r,cx+r+1):
			if x>=0 and y>=0 and x<img.get_width() and y<img.get_height():
				s += img.get_pixel(x,y); n+=1
	return s/float(maxi(n,1))
func black_ratio(img: Image, cx: int, cy: int, r: int) -> float:
	var black:=0; var n:=0
	for y in range(cy-r,cy+r+1):
		for x in range(cx-r,cx+r+1):
			if x<0 or y<0 or x>=img.get_width() or y>=img.get_height(): continue
			var c:=img.get_pixel(x,y); n+=1
			if c.r+c.g+c.b < 0.10: black+=1
	return float(black)/float(maxi(n,1))
func capture() -> Image:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(40,40))
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("AIM_START")
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1280,720)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=true; world.persist_profile=false
	if "enable_game_start_cab_exit" in world: world.enable_game_start_cab_exit=false
	root.add_child(world)
	for i in 15: await process_frame
	world.regenerate(41001)
	for i in 110: await process_frame
	if world.get("player")!=null: world.player.set_physics_process(false)
	world.set_process(false)
	var cam: Camera3D = world.camera_3d
	# Find a furniture mesh on screen
	var target_screen := Vector2(-1,-1)
	var target_name := ""
	var meshes: Array = world.find_children("*", "MeshInstance3D", true, false)
	for node in meshes:
		var mesh := node as MeshInstance3D
		if mesh == null or not mesh.is_visible_in_tree() or mesh.mesh == null: continue
		var is_furn := false
		var cursor: Node = mesh
		while cursor != null:
			if cursor.has_meta(&"occlusion_cutout_occluder") and bool(cursor.get_meta(&"occlusion_cutout_occluder")):
				is_furn = true; break
			cursor = cursor.get_parent()
		if not is_furn: continue
		var center: Vector3 = mesh.global_transform * mesh.get_aabb().get_center()
		if cam.is_position_behind(center): continue
		var sp: Vector2 = cam.unproject_position(center)
		var vr: Rect2 = cam.get_viewport().get_visible_rect()
		if vr.grow(-20).has_point(sp):
			target_screen = sp
			target_name = str(mesh.get_path())
			break
	log_line("target=%s screen=%s" % [target_name, str(target_screen)])
	if target_screen.x < 0.0:
		# fallback: any wall mesh
		for node in meshes:
			var mesh := node as MeshInstance3D
			if mesh == null or not mesh.is_visible_in_tree(): continue
			if not String(mesh.name).contains("Wall") and not String(mesh.get_parent().name if mesh.get_parent() else "").contains("Wall"):
				continue
			var center: Vector3 = mesh.global_position
			if cam.is_position_behind(center): continue
			var sp: Vector2 = cam.unproject_position(center)
			var vr: Rect2 = cam.get_viewport().get_visible_rect()
			if vr.grow(-20).has_point(sp):
				target_screen = sp; target_name = str(mesh.get_path()); break
		log_line("fallback_wall=%s screen=%s" % [target_name, str(target_screen)])
	var vp_size: Vector2 = cam.get_viewport().get_visible_rect().size
	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", vp_size)
	var img0: Image = await capture()
	# Map camera viewport point into root image pixels (letterbox aware)
	var root_size := Vector2(img0.get_width(), img0.get_height())
	var scale := minf(root_size.x / vp_size.x, root_size.y / vp_size.y)
	var offset := (root_size - vp_size * scale) * 0.5
	var px := int(offset.x + target_screen.x * scale)
	var py := int(offset.y + target_screen.y * scale)
	log_line("sample_px=%s,%s vp=%s scale=%s" % [str(px), str(py), str(vp_size), str(scale)])
	img0.save_png("user://aim_baseline.png")
	var before := avg(img0, px, py, 12)
	var before_black := black_ratio(img0, px, py, 35)
	# Force cutout aimed at furniture
	var slot := Vector4(target_screen.x / vp_size.x, target_screen.y / vp_size.y, 80.0, 1.0)
	RenderingServer.global_shader_parameter_set("occlusion_cutout_0", slot)
	for i in range(1,8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	var img1: Image = await capture()
	img1.save_png("user://aim_cutout_on.png")
	var runtime := ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	DirAccess.make_dir_recursive_absolute(runtime)
	img0.save_png(runtime.path_join("aim_baseline.png"))
	img1.save_png(runtime.path_join("aim_cutout_on.png"))
	var after := avg(img1, px, py, 12)
	var after_black := black_ratio(img1, px, py, 35)
	log_line("slot=%s" % str(slot))
	log_line("before=%s black=%s" % [str(before), str(before_black)])
	log_line("after=%s black=%s" % [str(after), str(after_black)])
	var darker:=0; var n:=0
	for y in range(py-40,py+41):
		for x in range(px-40,px+41):
			if x<0 or y<0 or x>=img1.get_width() or y>=img1.get_height(): continue
			var a:=img0.get_pixel(x,y); var b:=img1.get_pixel(x,y); n+=1
			if (a.r+a.g+a.b)-(b.r+b.g+b.b) > 0.12: darker += 1
	log_line("darker=%d/%d" % [darker,n])
	# Check a material has cutout uniform
	var checked := 0
	for node in meshes:
		var mesh := node as MeshInstance3D
		if mesh == null: continue
		var mat := mesh.material_override as ShaderMaterial
		if mat == null or mat.shader == null: continue
		if mat.shader.code.contains("combined_cutout") or mat.shader.code.contains("occlusion_cutout_enabled"):
			checked += 1
			if checked <= 3:
				log_line("mat_path=%s has_cutout_code=1 enabled_param=%s render_modes_snip=%s" % [
					str(mesh.get_path()),
					str(mat.get_shader_parameter("occlusion_cutout_enabled")),
					mat.shader.code.substr(0, mini(180, mat.shader.code.length())).replace("\n"," ")
				])
	log_line("materials_with_cutout_code=%d" % checked)
	log_line("AIM_DONE")
	quit(0)