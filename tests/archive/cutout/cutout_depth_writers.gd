extends SceneTree
var log_path := "user://cutout_depth_writers_log.txt"
func log_line(t: String) -> void:
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f == null: f = FileAccess.open(log_path, FileAccess.WRITE)
	else: f.seek_end()
	f.store_line(t); f.close(); print(t)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("WRITERS_START")
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
	log_line("furn=%s" % String(furn.get_path()))
	log_line("hide_root=%s meta=%s" % [String(hide_root.get_path()), str(hide_root.get_meta(&"occlusion_cutout_occluder"))])
	log_line("bridge=%s" % String(bridge.get_path()))
	log_line("--- bridge children ---")
	for c in bridge.get_children():
		log_line("child %s type=%s vis=%s" % [c.name, c.get_class(), str(c.visible if c is Node3D else "?")])
		if c is MeshInstance3D:
			var m := c as MeshInstance3D
			var mat := m.material_override
			var info := "no_override"
			if mat is ShaderMaterial:
				var sm := mat as ShaderMaterial
				var code := sm.shader.code if sm.shader else ""
				info = "shader mode=%s cutout_en=%s has_ALPHA=%s" % [
					code.substr(code.find("render_mode"), 60).replace("\n"," "),
					str(sm.get_shader_parameter("occlusion_cutout_enabled") if code.contains("occlusion_cutout_enabled") else "n/a"),
					str(code.contains("ALPHA"))
				]
			elif mat is StandardMaterial3D:
				var stm := mat as StandardMaterial3D
				info = "std albedo=%s transparent=%s no_depth=%s" % [str(stm.albedo_color), str(stm.transparency), str(stm.no_depth_test)]
			log_line("  mesh layers=%s cast_shadow=%s gi=%s %s" % [str(m.layers), str(m.cast_shadow), str(m.gi_mode), info])
			if m.mesh:
				for si in m.mesh.get_surface_count():
					var smat := m.get_active_material(si)
					log_line("  surface[%d] active=%s" % [si, smat.get_class() if smat else "null"])
	log_line("--- all meshes under bridge ---")
	for node in bridge.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		var mat := m.material_override as ShaderMaterial
		var mode := "?"
		var cut := "?"
		if mat and mat.shader:
			mode = mat.shader.code.substr(mat.shader.code.find("render_mode"), 70).replace("\n"," ")
			cut = str(mat.get_shader_parameter("occlusion_cutout_enabled")) if mat.shader.code.contains("occlusion_cutout_enabled") else "n/a"
		log_line("MESH %s vis=%s mode=%s cutout=%s" % [String(m.get_path()), str(m.visible), mode, cut])
	log_line("WRITERS_DONE")
	quit(0)