extends SceneTree
var log_path := "user://cutout_bridge_struct_log.txt"
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
func dump_tree(n: Node, depth: int) -> void:
	if depth > 4: return
	var extra := ""
	if n is MeshInstance3D:
		var m := n as MeshInstance3D
		var mat := m.material_override as ShaderMaterial
		extra = " MESH vis=%s cast=%s" % [str(m.visible), str(m.cast_shadow)]
		if mat != null:
			extra += " cutout_en=%s" % str(mat.get_shader_parameter("occlusion_cutout_enabled"))
	if n is Sprite3D:
		var s := n as Sprite3D
		extra = " SPRITE3D vis=%s mat=%s" % [str(s.visible), str(s.material_override != null)]
		if s.material_override is ShaderMaterial:
			var mat := s.material_override as ShaderMaterial
			extra += " cutout_en=%s" % str(mat.get_shader_parameter("occlusion_cutout_enabled"))
	log_line("%s%s%s" % ["  ".repeat(depth), n.name, extra])
	for c in n.get_children():
		dump_tree(c, depth+1)
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	FileAccess.open(log_path, FileAccess.WRITE).close()
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1280,720)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=true; world.persist_profile=false
	if "enable_game_start_cab_exit" in world: world.enable_game_start_cab_exit=false
	root.add_child(world)
	for i in 15: await process_frame
	world.regenerate(41001)
	for i in 100: await process_frame
	world.set_process(false)
	var cam: Camera3D = world.camera_3d
	var furn: MeshInstance3D = null
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or not String(mesh.get_path()).contains("LowPixelOfficeVisual"): continue
		var center: Vector3 = mesh.global_transform * mesh.get_aabb().get_center()
		if cam.is_position_behind(center): continue
		var sp: Vector2 = cam.unproject_position(center)
		if cam.get_viewport().get_visible_rect().grow(-30).has_point(sp):
			furn = mesh; break
	var bridge: Node = furn
	while bridge != null and not bridge.get_parent().name.begins_with("ActorDepth") and bridge.get_parent() != null:
		if String(bridge.name).begins_with("@Node3D") or bridge.get("actor_sprite") != null:
			break
		bridge = bridge.get_parent()
	# climb to ActorDepthBridge instance
	var n: Node = furn
	while n != null:
		if n.get("actor_sprite") != null or n.has_method("configure"):
			bridge = n; break
		n = n.get_parent()
	log_line("furn=%s" % str(furn.get_path()))
	log_line("bridge=%s" % str(bridge.get_path() if bridge else "null"))
	if bridge: dump_tree(bridge, 0)
	# Place plate and test: cutout with sprites hidden vs meshes only
	var furn_center: Vector3 = furn.global_transform * furn.get_aabb().get_center()
	var flat := Vector3(cam.global_position.x - furn_center.x, 0, cam.global_position.z - furn_center.z).normalized()
	var plate := MeshInstance3D.new()
	var pq := QuadMesh.new(); pq.size=Vector2(2.5,2.5); plate.mesh=pq
	var pm := StandardMaterial3D.new(); pm.albedo_color=Color(0.05,1,0.1); pm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; pm.cull_mode=BaseMaterial3D.CULL_DISABLED
	plate.material_override=pm
	furn.get_parent().add_child(plate)
	plate.global_position = Vector3(furn_center.x, 0.7, furn_center.z) - flat * 1.0
	plate.global_basis = Basis.looking_at((cam.global_position - plate.global_position).normalized(), Vector3.UP)
	var sp: Vector2 = cam.unproject_position(furn_center)
	var vp_size: Vector2 = cam.get_viewport().get_visible_rect().size
	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", vp_size)
	RenderingServer.global_shader_parameter_set("occlusion_cutout_0", Vector4(sp.x/vp_size.x, sp.y/vp_size.y, 100.0, 1.0))
	for i in range(1,8): RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	# Hide all Sprite3D under bridge
	if bridge:
		for c in bridge.find_children("*", "Sprite3D", true, false):
			(c as Sprite3D).visible = false
			log_line("hid_sprite=%s" % str(c.get_path()))
	var img: Image = await capture()
	var root_size := Vector2(img.get_width(), img.get_height())
	var scale := minf(root_size.x / vp_size.x, root_size.y / vp_size.y)
	var offset := (root_size - vp_size * scale) * 0.5
	var px := int(offset.x + sp.x * scale)
	var py := int(offset.y + sp.y * scale)
	var after := avg(img, px, py, 15)
	img.save_png(ProjectSettings.globalize_path("res://.runtime/cutout_sample/behind_no_sprite.png"))
	log_line("after_hide_sprites=%s green=%s" % [str(after), str(after.g > 0.4)])
	log_line("DONE")
	quit(0)