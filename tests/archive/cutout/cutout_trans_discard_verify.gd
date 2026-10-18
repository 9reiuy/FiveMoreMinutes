extends SceneTree
var log_path := "user://cutout_trans_discard_log.txt"
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
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(-2400, -2400))
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("TRANS_DISCARD_START")
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
	if world.get("player")!=null: world.player.set_physics_process(false)
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
		log_line("NO_FURN"); log_line("TRANS_DISCARD_DONE"); quit(3); return
	var mat := furn.material_override as ShaderMaterial
	log_line("live_has_discard=%s live_mode=%s" % [
		str(mat.shader.code.contains("if (_cut < 0.5)")),
		mat.shader.code.substr(mat.shader.code.find("render_mode"), 70).replace("\n"," ")
	])
	var hide_root: Node = furn
	while hide_root.get_parent() != null and not hide_root.has_meta(&"occlusion_cutout_occluder"):
		hide_root = hide_root.get_parent()
	var bridge: Node = hide_root.get_parent()
	for c in bridge.get_children():
		if c is MeshInstance3D: c.visible = false
	for c in bridge.find_children("SolidShadowCaster", "MeshInstance3D", true, false):
		c.visible = false
	for node in hide_root.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m and m.material_override is ShaderMaterial:
			var sm := m.material_override as ShaderMaterial
			if sm.shader and sm.shader.code.contains("occlusion_cutout_enabled"):
				sm.set_shader_parameter("occlusion_cutout_enabled", true)
	var furn_center: Vector3 = furn.global_transform * furn.get_aabb().get_center()
	var sp: Vector2 = cam.unproject_position(furn_center)
	var vp_size: Vector2 = cam.get_viewport().get_visible_rect().size
	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", vp_size)
	var root_size := Vector2(1280,720)
	var scale := minf(root_size.x / vp_size.x, root_size.y / vp_size.y)
	var offset := (root_size - vp_size * scale) * 0.5
	var px := int(offset.x + sp.x * scale)
	var py := int(offset.y + sp.y * scale)
	for i in range(0,8): RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	var img_off: Image = await capture()
	RenderingServer.global_shader_parameter_set("occlusion_cutout_0", Vector4(sp.x/vp_size.x, sp.y/vp_size.y, 160.0, 1.0))
	var img_on: Image = await capture()
	hide_root.visible = false
	var img_open: Image = await capture()
	var runtime := ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	DirAccess.make_dir_recursive_absolute(runtime)
	img_off.save_png(runtime.path_join("trans_discard_off.png"))
	img_on.save_png(runtime.path_join("trans_discard_on.png"))
	img_open.save_png(runtime.path_join("trans_discard_open.png"))
	var off_c := avg(img_off,px,py,12)
	var on_c := avg(img_on,px,py,12)
	var open_c := avg(img_open,px,py,12)
	log_line("off=%s on=%s open=%s" % [str(off_c), str(on_c), str(open_c)])
	var on_sum: float = on_c.r+on_c.g+on_c.b
	var matches: bool = abs(on_c.r-open_c.r)+abs(on_c.g-open_c.g)+abs(on_c.b-open_c.b) < 0.4
	var ok: bool = on_sum > 0.25 and (matches or on_sum > 0.4)
	log_line("PASS=%s matches_open=%s" % [str(ok), str(matches)])
	log_line("TRANS_DISCARD_DONE")
	quit(0 if ok else 2)