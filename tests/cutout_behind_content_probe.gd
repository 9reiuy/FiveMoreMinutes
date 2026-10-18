extends SceneTree
var log_path := "user://behind_probe_log.txt"
func log_line(t: String) -> void:
	var f := FileAccess.open(log_path, FileAccess.WRITE_READ) if FileAccess.file_exists(log_path) else FileAccess.open(log_path, FileAccess.WRITE)
	if f == null: f = FileAccess.open(log_path, FileAccess.WRITE)
	else: f.seek_end()
	f.store_line(t); f.close(); print(t)
func _initialize() -> void: call_deferred("run")
func keep() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(-2400,-2400))
func settle(n:=6) -> void:
	for i in n: await process_frame; keep()
func run() -> void:
	keep(); FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("BEHIND_PROBE_START")
	AudioServer.set_bus_mute(0,true); root.size=Vector2i(1280,720)
	var runtime := ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	DirAccess.make_dir_recursive_absolute(runtime)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=true; world.persist_profile=false
	if "enable_game_start_cab_exit" in world: world.enable_game_start_cab_exit=false
	root.add_child(world)
	await settle(16)
	world.regenerate(41001)
	await settle(100)
	for room in world.rooms:
		if String(room.get("archetype",""))=="open_office":
			world.player.global_position=Vector2(room.center_cell)*world.CELL_PIXELS
			world.activate_room(int(room.id)); break
	await settle(30)
	var display := root.get_node_or_null("DreamSettingsDisplay")
	var behind_vp: SubViewport = null
	var world_vp: SubViewport = null
	var overlay: ColorRect = null
	for n in root.find_children("*","SubViewport",true,false):
		if n.name=="CutoutBehindViewport": behind_vp=n
		if n.name=="WorldViewport": world_vp=n
	overlay = root.find_child("OcclusionCutoutComposite",true,false) as ColorRect
	log_line("behind=%s world_vp=%s overlay_vis=%s" % [str(behind_vp!=null), str(world_vp!=null), str(overlay.visible if overlay else null)])
	if behind_vp:
		log_line("behind size=%s update=%s world3d=%s" % [str(behind_vp.size), str(behind_vp.render_target_update_mode), str(behind_vp.world_3d!=null)])
		var bcam := behind_vp.get_camera_3d()
		log_line("behind_cam=%s current=%s cull=%s" % [str(bcam!=null), str(bcam.current if bcam else null), str(bcam.cull_mask if bcam else null)])
	# place player behind workstation
	var cam: Camera3D = world.camera_3d
	var player: Node2D = world.player
	player.set_physics_process(false)
	var best: MeshInstance3D=null; var best_aabb:=AABB(); var best_y:=0.0
	for node in world.find_children("*","MeshInstance3D",true,false):
		var mesh:=node as MeshInstance3D
		if mesh==null or not String(mesh.get_path()).contains("LowPixelOfficeVisual"): continue
		var aabb:AABB=mesh.get_aabb()
		if aabb.size.y<best_y: continue
		var xf:=mesh.global_transform
		var wa:=AABB(xf*aabb.position,Vector3.ZERO)
		for xi in [0.0,1.0]:
			for yi in [0.0,1.0]:
				for zi in [0.0,1.0]:
					wa=wa.expand(xf*(aabb.position+aabb.size*Vector3(xi,yi,zi)))
		var c:=wa.get_center()
		if cam.is_position_behind(c): continue
		if not cam.get_viewport().get_visible_rect().grow(-40).has_point(cam.unproject_position(c)): continue
		best=mesh; best_aabb=wa; best_y=aabb.size.y
	best.layers=8
	var furn_c:=best_aabb.get_center()
	var away:=world.to_local(furn_c)-world.to_local(cam.global_position); away.y=0; away=away.normalized()
	var fl:=world.to_local(furn_c)+away*(maxf(best_aabb.size.x,best_aabb.size.z)*0.5+1.0)
	player.global_position=Vector2(fl.x*world.CELL_PIXELS, fl.z*world.CELL_PIXELS)
	await settle(20)
	if world.has_method("_update_camera_and_actor_projection"): world._update_camera_and_actor_projection(0.0)
	await settle(8)
	world._update_occlusion_cutouts()
	await settle(4)
	var slots: Array = world.get_meta(&"test_cutout_slots", []) if world.has_meta(&"test_cutout_slots") else []
	log_line("meta_slots=%s last=%s" % [str(slots), str(world.get("_last_cutout_slots"))])
	# Force a solid mid-size slot on torso
	var head: Vector3 = world._get_actor_cutout_slot(player).get("world", Vector3.ZERO)
	head.y=0.5
	var sp:=cam.unproject_position(head)
	var vp:=cam.get_viewport().get_visible_rect().size
	var slot:=Vector4(sp.x/vp.x, sp.y/vp.y, 48.0, 1.0)
	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", vp)
	RenderingServer.global_shader_parameter_set("occlusion_cutout_0", slot)
	for i in range(1,8): RenderingServer.global_shader_parameter_set("occlusion_cutout_%d"%i, Vector4.ZERO)
	log_line("forced_slot=%s layers_furn=%d" % [str(slot), best.layers])
	await settle(8)
	await RenderingServer.frame_post_draw
	if behind_vp:
		var bi: Image = behind_vp.get_texture().get_image()
		bi.save_png(runtime.path_join("probe_behind.png"))
		var wi: Image = world_vp.get_texture().get_image()
		wi.save_png(runtime.path_join("probe_main.png"))
		var fi: Image = root.get_texture().get_image()
		fi.save_png(runtime.path_join("probe_final.png"))
		# sample hole center in behind vs main (640 space)
		var px:=int(sp.x); var py:=int(sp.y)
		var sb:=Color(0,0,0); var sm:=Color(0,0,0); var n:=0
		for y in range(py-10,py+11):
			for x in range(px-10,px+11):
				if x<0 or y<0 or x>=bi.get_width() or y>=bi.get_height(): continue
				sb+=bi.get_pixel(x,y); sm+=wi.get_pixel(x,y); n+=1
		sb/=float(maxi(n,1)); sm/=float(maxi(n,1))
		log_line("behind_avg=%s main_avg=%s n=%d" % [str(sb), str(sm), n])
		# count non-dark pixels in behind sample
		var lit:=0
		for y in range(py-10,py+11):
			for x in range(px-10,px+11):
				if x<0 or y<0 or x>=bi.get_width() or y>=bi.get_height(): continue
				var c:=bi.get_pixel(x,y)
				if c.r+c.g+c.b>0.25: lit+=1
		log_line("behind_lit_px=%d/%d" % [lit, n])
	log_line("BEHIND_PROBE_DONE")
	quit(0)
