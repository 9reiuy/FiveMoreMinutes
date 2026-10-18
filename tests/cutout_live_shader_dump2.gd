extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(960,540)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=true; world.persist_profile=false
	if "enable_game_start_cab_exit" in world: world.enable_game_start_cab_exit=false
	root.add_child(world)
	for i in 12: await process_frame
	world.regenerate(41001)
	for i in 90: await process_frame
	var out := ProjectSettings.globalize_path("res://.runtime/cutout_sample/live_shader_dump.txt")
	var f := FileAccess.open(out, FileAccess.WRITE)
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.material_override == null: continue
		var mat := mesh.material_override as ShaderMaterial
		if mat == null or mat.shader == null: continue
		if not bool(mat.get_shader_parameter("occlusion_cutout_enabled")): continue
		f.store_line("PATH=" + String(mesh.get_path()))
		f.store_line("SHADER_RID=" + str(mat.shader.get_rid()))
		f.store_line("--- CODE START ---")
		f.store_string(mat.shader.code)
		f.store_line("\n--- CODE END ---")
		# also dump if original path
		f.store_line("resource_path=" + mat.shader.resource_path)
		break
	f.close()
	print("DUMPED")
	quit(0)