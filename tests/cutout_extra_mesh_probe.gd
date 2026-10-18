extends SceneTree
var log_path := "user://cutout_extra_mesh_log.txt"
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
		if mesh == null or not String(mesh.get_path()).contains("LowPixelOfficeVisual_chair"): continue
		if mesh.name != "BaseMesh": continue
		var center: Vector3 = mesh.global_transform * mesh.get_aabb().get_center()
		if cam.is_position_behind(center): continue
		var sp: Vector2 = cam.unproject_position(center)
		if cam.get_viewport().get_visible_rect().grow(-30).has_point(sp):
			furn = mesh; break
	var bridge: Node = furn.get_parent().get_parent() # LowPixel -> bridge node
	log_line("bridge=%s" % str(bridge.get_path()))
	for c in bridge.get_children():
		log_line("child=%s class=%s" % [c.name, c.get_class()])
		if c is MeshInstance3D:
			var m := c as MeshInstance3D
			log_line("  mesh aabb=%s cast=%s mat=%s albedo=%s" % [
				str(m.get_aabb()), str(m.cast_shadow),
				str(m.material_override),
				str((m.material_override as BaseMaterial3D).albedo_color if m.material_override is BaseMaterial3D else "shader_or_null")
			])
			if m.material_override is ShaderMaterial:
				var sm := m.material_override as ShaderMaterial
				log_line("  shader_path=%s cutout=%s" % [sm.shader.resource_path if sm.shader else "", str(sm.get_shader_parameter("occlusion_cutout_enabled"))])
	# Find SolidShadowCasters
	for c in bridge.find_children("*", "MeshInstance3D", true, false):
		var m := c as MeshInstance3D
		if m.name == "SolidShadowCaster" or m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			log_line("shadow_caster=%s cast=%s layers=%s gi=%s" % [str(m.get_path()), str(m.cast_shadow), str(m.layers), str(m.gi_mode)])
	# Plate + cutout tests
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
	var root_size := Vector2(1280,720)
	var scale := minf(root_size.x / vp_size.x, root_size.y / vp_size.y)
	var offset := (root_size - vp_size * scale) * 0.5
	var px := int(offset.x + sp.x * scale)
	var py := int(offset.y + sp.y * scale)
	# A: baseline cutout
	var img: Image = await capture()
	log_line("A_all=%s" % str(avg(img,px,py,15)))
	# B: hide extra @MeshInstance siblings of visual
	for c in bridge.get_children():
		if c is MeshInstance3D and c != furn.get_parent():
			c.visible = false
			log_line("hid_extra=%s" % c.name)
	img = await capture()
	log_line("B_no_extra_mesh=%s green=%s" % [str(avg(img,px,py,15)), str(avg(img,px,py,15).g > 0.4)])
	# C: also hide SolidShadowCasters
	for c in bridge.find_children("SolidShadowCaster", "MeshInstance3D", true, false):
		c.visible = false
		log_line("hid_shadow=%s" % str(c.get_path()))
	img = await capture()
	log_line("C_no_shadow_casters=%s green=%s" % [str(avg(img,px,py,15)), str(avg(img,px,py,15).g > 0.4)])
	# D: hide ALL under bridge except plate
	for c in bridge.get_children():
		if c != plate and c != furn.get_parent():
			c.visible = false
	# keep visual but force - actually hide visual meshes' shadow only already done
	img = await capture()
	log_line("D=%s" % str(avg(img,px,py,15)))
	# E: hide entire chair visual, keep plate
	furn.get_parent().visible = false
	img = await capture()
	log_line("E_no_chair=%s green=%s" % [str(avg(img,px,py,15)), str(avg(img,px,py,15).g > 0.4)])
	log_line("DONE")
	quit(0)