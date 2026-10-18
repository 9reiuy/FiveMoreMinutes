extends SceneTree
var log_path := "user://cutout_force_alpha0_log.txt"
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
func capture() -> Image:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("FORCE0_START")
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1280,720)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=true; world.persist_profile=false
	if "enable_game_start_cab_exit" in world: world.enable_game_start_cab_exit=false
	root.add_child(world)
	for i in 12: await process_frame
	world.regenerate(41001)
	for i in 100: await process_frame
	world.set_process(false)
	var cam: Camera3D = world.camera_3d
	var furn: MeshInstance3D = null
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or not String(mesh.get_path()).contains("LowPixelOfficeVisual"): continue
		var cursor: Node = mesh; var ok:=false
		while cursor != null:
			if cursor.has_meta(&"occlusion_cutout_occluder") and bool(cursor.get_meta(&"occlusion_cutout_occluder")):
				ok=true; break
			cursor = cursor.get_parent()
		if not ok: continue
		var center: Vector3 = mesh.global_transform * mesh.get_aabb().get_center()
		if cam.is_position_behind(center): continue
		var sp0: Vector2 = cam.unproject_position(center)
		if cam.get_viewport().get_visible_rect().grow(-30).has_point(sp0):
			furn = mesh; break
	var hide_root: Node = furn
	while hide_root.get_parent() != null and not hide_root.has_meta(&"occlusion_cutout_occluder"):
		hide_root = hide_root.get_parent()
	var bridge := hide_root.get_parent()
	for c in bridge.get_children():
		if c is MeshInstance3D: c.visible = false
	for c in bridge.find_children("SolidShadowCaster", "MeshInstance3D", true, false):
		c.visible = false
	# Rewrite live shaders: ALPHA=0 always, no screen texture
	for node in hide_root.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m == null or m.material_override == null: continue
		var mat := m.material_override as ShaderMaterial
		if mat == null or mat.shader == null: continue
		if not mat.shader.code.contains("occlusion_cutout_enabled"): continue
		var code: String = mat.shader.code
		# strip screen texture path; force ALPHA=0
		code = code.replace("uniform sampler2D occlusion_screen : hint_screen_texture, filter_nearest;", "")
		var sh := Shader.new()
		# inject at end of fragment before closing: force
		var marker := "void fragment()"
		# Replace fragment body ending ALPHA block with force ALPHA=0
		var re := RegEx.new()
		re.compile("if \\(occlusion_cutout_enabled\\)[\\s\\S]*?else \\{[\\s\\S]*?ALPHA = 1\\.0;[\\s\\S]*?\\}")
		code = re.sub(code, "ALPHA = 0.0;", false)
		if not code.contains("ALPHA = 0.0"):
			code = code.replace("ALPHA = 1.0;", "ALPHA = 0.0;")
		sh.code = code
		mat.shader = sh
		log_line("patched %s hasA0=%s mode=%s" % [m.name, str(sh.code.contains("ALPHA = 0.0")), sh.code.substr(sh.code.find("render_mode"), 70).replace("\n"," ")])
	var furn_center: Vector3 = furn.global_transform * furn.get_aabb().get_center()
	var flat := Vector3(cam.global_position.x - furn_center.x, 0, cam.global_position.z - furn_center.z).normalized()
	var plate := MeshInstance3D.new()
	var pq := QuadMesh.new(); pq.size=Vector2(2.5,2.5); plate.mesh=pq
	var pm := StandardMaterial3D.new(); pm.albedo_color=Color(0.05,1.0,0.1); pm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; pm.cull_mode=BaseMaterial3D.CULL_DISABLED
	plate.material_override=pm
	furn.get_parent().add_child(plate)
	plate.global_position = Vector3(furn_center.x, 0.7, furn_center.z) - flat * 1.0
	plate.global_basis = Basis.looking_at((cam.global_position - plate.global_position).normalized(), Vector3.UP)
	var sp: Vector2 = cam.unproject_position(furn_center)
	var vp_size: Vector2 = cam.get_viewport().get_visible_rect().size
	var root_size := Vector2(1280,720)
	var scale := minf(root_size.x / vp_size.x, root_size.y / vp_size.y)
	var offset := (root_size - vp_size * scale) * 0.5
	var px := int(offset.x + sp.x * scale)
	var py := int(offset.y + sp.y * scale)
	var img_a: Image = await capture()
	hide_root.visible = false
	var img_b: Image = await capture()
	var runtime := ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	img_a.save_png(runtime.path_join("force0_chair_alpha0.png"))
	img_b.save_png(runtime.path_join("force0_no_chair.png"))
	var a := avg(img_a,px,py,15); var b := avg(img_b,px,py,15)
	log_line("alpha0_chair=%s no_chair=%s" % [str(a), str(b)])
	log_line("plate_shows_with_alpha0=%s" % str(a.g > 0.35))
	log_line("FORCE0_DONE")
	quit(0)