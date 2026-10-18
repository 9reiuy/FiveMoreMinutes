extends SceneTree
var log_path := "user://cutout_live_shader_log.txt"
func log_line(t: String) -> void:
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f == null: f = FileAccess.open(log_path, FileAccess.WRITE)
	else: f.seek_end()
	f.store_line(t); f.close(); print(t)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	FileAccess.open(log_path, FileAccess.WRITE).close()
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(960,540)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=true; world.persist_profile=false
	if "enable_game_start_cab_exit" in world: world.enable_game_start_cab_exit=false
	root.add_child(world)
	for i in 15: await process_frame
	world.regenerate(41001)
	for i in 100: await process_frame
	world.set_process(false)
	var found_furn := 0
	var found_wall := 0
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null: continue
		var mat := mesh.material_override as ShaderMaterial
		if mat == null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
			mat = mesh.get_active_material(0) as ShaderMaterial
		if mat == null or mat.shader == null: continue
		var code: String = mat.shader.code
		var is_furn := false
		var cursor: Node = mesh
		while cursor != null:
			if cursor.has_meta(&"occlusion_cutout_occluder") and bool(cursor.get_meta(&"occlusion_cutout_occluder")):
				is_furn = true; break
			cursor = cursor.get_parent()
		if is_furn and code.contains("combined_cutout") and found_furn < 2:
			found_furn += 1
			var path := ProjectSettings.globalize_path("user://live_furn_shader_%d.txt" % found_furn)
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(code); f.close()
			log_line("FURN%d path=%s discard_cutout=%s alpha_cutout=%s enabled=%s has_blend=%s has_prepass=%s" % [
				found_furn, str(mesh.get_path()),
				str(code.contains("combined_cutout(SCREEN_UV) < 0.5")),
				str(code.contains("ALPHA = combined_cutout") or code.contains("ALPHA *= combined_cutout")),
				str(mat.get_shader_parameter("occlusion_cutout_enabled")),
				str(code.contains("blend_mix")),
				str(code.contains("depth_prepass_alpha"))
			])
		if code.contains("wainscot_height") and code.contains("combined_cutout") and found_wall < 2:
			found_wall += 1
			var path := ProjectSettings.globalize_path("user://live_wall_shader_%d.txt" % found_wall)
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(code); f.close()
			log_line("WALL%d path=%s discard_cutout=%s alpha_cutout=%s has_blend=%s has_prepass=%s" % [
				found_wall, str(mesh.get_path()),
				str(code.contains("combined_cutout(SCREEN_UV) < 0.5")),
				str(code.contains("ALPHA = combined_cutout")),
				str(code.contains("blend_mix")),
				str(code.contains("depth_prepass_alpha"))
			])
	log_line("found_furn=%d found_wall=%d" % [found_furn, found_wall])
	log_line("DONE")
	quit(0)