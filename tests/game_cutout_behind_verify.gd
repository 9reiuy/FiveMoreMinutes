extends SceneTree
var log_path := "user://game_cutout_behind_verify_log.txt"
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
	DisplayServer.window_set_position(Vector2i(40,40))
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("BEHIND4_START")
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
	# Put a giant green plate directly in front of camera first as sanity check
	var sanity := MeshInstance3D.new()
	var sq := QuadMesh.new(); sq.size=Vector2(1,1); sanity.mesh=sq
	var sm := StandardMaterial3D.new(); sm.albedo_color=Color(0,1,0); sm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; sm.cull_mode=BaseMaterial3D.CULL_DISABLED
	sanity.material_override=sm
	world.add_child(sanity)
	sanity.global_position = cam.global_position + (-cam.global_transform.basis.z) * 2.0
	sanity.global_basis = Basis.looking_at(-cam.global_transform.basis.z, Vector3.UP)
	var img_s: Image = await capture()
	var sc := avg(img_s, img_s.get_width()/2, img_s.get_height()/2, 20)
	log_line("sanity_center=%s" % str(sc))
	sanity.queue_free(); await process_frame
	# Find cabinet (taller) rather than chair
	var furn: MeshInstance3D = null
	var best_h := -1.0
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or not mesh.is_visible_in_tree(): continue
		var cursor: Node = mesh; var ok:=false; var root_vis: Node = null
		while cursor != null:
			if cursor.has_meta(&"occlusion_cutout_occluder") and bool(cursor.get_meta(&"occlusion_cutout_occluder")):
				ok=true; root_vis=cursor; break
			cursor = cursor.get_parent()
		if not ok: continue
		var center: Vector3 = mesh.global_transform * mesh.get_aabb().get_center()
		if cam.is_position_behind(center): continue
		var sp: Vector2 = cam.unproject_position(center)
		if not cam.get_viewport().get_visible_rect().grow(-30).has_point(sp): continue
		var h: float = mesh.get_aabb().size.y * mesh.global_transform.basis.get_scale().y
		if h > best_h:
			best_h = h; furn = mesh
	log_line("picked=%s h=%s" % [str(furn.get_path()) if furn else "null", str(best_h)])
	if furn == null: quit(1); return
	# Hide entire visual root
	var hide_root: Node = furn
	while hide_root.get_parent() != null and not (hide_root.has_meta(&"occlusion_cutout_occluder")):
		hide_root = hide_root.get_parent()
	var furn_center: Vector3 = furn.global_transform * furn.get_aabb().get_center()
	var flat := Vector3(cam.global_position.x - furn_center.x, 0, cam.global_position.z - furn_center.z).normalized()
	var plate := MeshInstance3D.new()
	var pq := QuadMesh.new(); pq.size=Vector2(2.5,2.5); plate.mesh=pq
	var pm := StandardMaterial3D.new(); pm.albedo_color=Color(0.05,1,0.1); pm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; pm.cull_mode=BaseMaterial3D.CULL_DISABLED
	plate.material_override=pm
	# Parent under same building layout as furniture
	furn.get_parent().add_child(plate)
	plate.global_position = Vector3(furn_center.x, maxf(furn_center.y, 0.6), furn_center.z) - flat * 1.0
	plate.global_basis = Basis.looking_at((cam.global_position - plate.global_position).normalized(), Vector3.UP)
	log_line("plate=%s hide_root=%s" % [str(plate.global_position), str(hide_root.get_path())])
	hide_root.visible = false
	# Also hide sibling bridge sprite if any
	var bridge := hide_root.get_parent()
	if bridge != null:
		for ch in bridge.get_children():
			if ch is Sprite3D: ch.visible = false
	var img_plate: Image = await capture()
	var sp: Vector2 = cam.unproject_position(furn_center)
	var vp_size: Vector2 = cam.get_viewport().get_visible_rect().size
	var root_size := Vector2(img_plate.get_width(), img_plate.get_height())
	var scale := minf(root_size.x / vp_size.x, root_size.y / vp_size.y)
	var offset := (root_size - vp_size * scale) * 0.5
	var px := int(offset.x + sp.x * scale)
	var py := int(offset.y + sp.y * scale)
	var plate_only := avg(img_plate, px, py, 15)
	log_line("plate_only=%s" % str(plate_only))
	hide_root.visible = true
	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", vp_size)
	var img0: Image = await capture()
	var before := avg(img0, px, py, 15)
	RenderingServer.global_shader_parameter_set("occlusion_cutout_0", Vector4(sp.x/vp_size.x, sp.y/vp_size.y, 100.0, 1.0))
	for i in range(1,8): RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	var img1: Image = await capture()
	var after := avg(img1, px, py, 15)
	var runtime := ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	DirAccess.make_dir_recursive_absolute(runtime)
	img_s.save_png(runtime.path_join("behind_verify_sanity.png"))
	img_plate.save_png(runtime.path_join("behind_verify_plate_only.png"))
	img0.save_png(runtime.path_join("behind_verify_off.png"))
	img1.save_png(runtime.path_join("behind_verify_on.png"))
	log_line("before=%s after=%s" % [str(before), str(after)])
	log_line("shows_green=%s plate_green=%s" % [str(after.g > 0.4 and after.g > after.r + 0.15), str(plate_only.g > 0.4)])
	log_line("BEHIND4_DONE")
	quit(0 if (after.g > 0.4 and after.g > after.r + 0.15) else 2)