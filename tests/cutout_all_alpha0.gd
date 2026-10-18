extends SceneTree
var log_path := "user://cutout_all_alpha0_log.txt"
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
	DisplayServer.window_set_position(Vector2i(-2400, -2400))
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("ALLA0_START")
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1280,720)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=true; world.persist_profile=false
	if "enable_game_start_cab_exit" in world: world.enable_game_start_cab_exit=false
	root.add_child(world)
	for i in 15: await process_frame
	world.regenerate(41001)
	for i in 110: await process_frame
	world.set_process(false)
	var cam: Camera3D = world.camera_3d
	var furn: MeshInstance3D = null
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or not String(mesh.get_path()).contains("LowPixelOfficeVisual_chair/BaseMesh"): continue
		var center: Vector3 = mesh.global_transform * mesh.get_aabb().get_center()
		if cam.is_position_behind(center): continue
		var sp0: Vector2 = cam.unproject_position(center)
		if cam.get_viewport().get_visible_rect().grow(-30).has_point(sp0):
			furn = mesh; break
	if furn == null:
		log_line("NO_FURN"); log_line("ALLA0_DONE"); quit(3); return
	var hide_root: Node = furn
	while hide_root.get_parent() != null and not hide_root.has_meta(&"occlusion_cutout_occluder"):
		hide_root = hide_root.get_parent()
	var bridge: Node = hide_root.get_parent()
	for c in bridge.get_children():
		if c is MeshInstance3D: c.visible = false
	var invis := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, blend_mix, depth_draw_never;\nvoid fragment(){ALBEDO=vec3(1.0,0.0,1.0); ALPHA=0.0;}\n"
	invis.shader = sh
	var n := 0
	for node in hide_root.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		log_line("mesh %s vis=%s cast=%s" % [m.name, str(m.visible), str(m.cast_shadow)])
		m.material_override = invis
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n += 1
	log_line("forced_invis_count=%d" % n)
	var furn_center: Vector3 = furn.global_transform * furn.get_aabb().get_center()
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
	DirAccess.make_dir_recursive_absolute(runtime)
	img_a.save_png(runtime.path_join("all_alpha0.png"))
	img_b.save_png(runtime.path_join("all_hidden.png"))
	var a := avg(img_a,px,py,12); var b := avg(img_b,px,py,12)
	log_line("alla0=%s hidden=%s" % [str(a), str(b)])
	log_line("PASS=%s" % str((a.r+a.g+a.b)>0.3))
	log_line("ALLA0_DONE")
	quit(0)