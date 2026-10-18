extends SceneTree
var log_path := "user://cutout_clear_dest_log.txt"
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
	log_line("CLEAR_DEST_START")
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
	# Find WorldViewport and set clear/environment to bright orange
	var wp: SubViewport = null
	for n in world.get_tree().root.find_children("*", "SubViewport", true, false):
		if String(n.name).contains("WorldViewport") or (n.get_child_count()>0 and n.get_child(0)==world):
			wp = n as SubViewport
	# climb to find SubViewport parent of world
	var p: Node = world.get_parent()
	while p != null:
		if p is SubViewport:
			wp = p as SubViewport
			break
		p = p.get_parent()
	log_line("worldviewport=%s" % str(wp))
	if wp != null:
		wp.transparent_bg = false
		RenderingServer.viewport_set_clear_color(wp.get_viewport_rid(), Color(1.0, 0.4, 0.0, 1.0))
	# also project clear
	ProjectSettings.set_setting("rendering/environment/defaults/default_clear_color", Color(1.0, 0.4, 0.0, 1.0))
	var env_nodes = world.find_children("*", "WorldEnvironment", true, false)
	for e in env_nodes:
		var we := e as WorldEnvironment
		if we.environment:
			we.environment.background_mode = Environment.BG_COLOR
			we.environment.background_color = Color(1.0, 0.4, 0.0, 1.0)
			log_line("set_env_orange")
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
	var hide_root: Node = furn
	while hide_root.get_parent() != null and not hide_root.has_meta(&"occlusion_cutout_occluder"):
		hide_root = hide_root.get_parent()
	var bridge: Node = hide_root.get_parent()
	for c in bridge.get_children():
		if c is MeshInstance3D: c.visible = false
	for c in bridge.find_children("SolidShadowCaster", "MeshInstance3D", true, false):
		c.visible = false
	# Force ALPHA=0 on chair visuals
	for node in hide_root.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m == null or m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: 
			if m: m.visible = false
			continue
		if not (m.material_override is ShaderMaterial): continue
		var sm := m.material_override as ShaderMaterial
		if sm.shader == null or not sm.shader.code.contains("occlusion_cutout_enabled"): continue
		var code: String = sm.shader.code
		var re := RegEx.new(); re.compile("ALPHA = [^;]+;")
		code = re.sub(code, "ALPHA = 0.0;", true)
		code = code.replace("if (occlusion_cutout_enabled)", "if (true)")
		code = code.replace("render_mode blend_mix, depth_draw_never, diffuse_lambert;", "render_mode unshaded, blend_mix, depth_draw_never;")
		var sh2 := Shader.new(); sh2.code = code; sm.shader = sh2
	var furn_center: Vector3 = furn.global_transform * furn.get_aabb().get_center()
	var sp: Vector2 = cam.unproject_position(furn_center)
	var vp_size: Vector2 = cam.get_viewport().get_visible_rect().size
	var root_size := Vector2(1280,720)
	var scale := minf(root_size.x / vp_size.x, root_size.y / vp_size.y)
	var offset := (root_size - vp_size * scale) * 0.5
	var px := int(offset.x + sp.x * scale)
	var py := int(offset.y + sp.y * scale)
	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", vp_size)
	RenderingServer.global_shader_parameter_set("occlusion_cutout_0", Vector4(sp.x/vp_size.x, sp.y/vp_size.y, 160.0, 1.0))
	var img: Image = await capture()
	hide_root.visible = false
	var img2: Image = await capture()
	var runtime := ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	img.save_png(runtime.path_join("clear_dest_alpha0.png"))
	img2.save_png(runtime.path_join("clear_dest_hidden.png"))
	var a := avg(img,px,py,12); var b := avg(img2,px,py,12)
	log_line("alpha0=%s hidden=%s" % [str(a), str(b)])
	var orange_ish: bool = a.r > 0.5 and a.g > 0.15 and a.g < 0.6 and a.b < 0.25
	log_line("holes_are_clear_color=%s" % str(orange_ish or (a.r>0.7 and a.g<0.5)))
	log_line("CLEAR_DEST_DONE")
	quit(0)