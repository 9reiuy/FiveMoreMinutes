extends SceneTree
var log_path := "user://cutout_tree_log.txt"
func log_line(t: String) -> void:
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f == null: f = FileAccess.open(log_path, FileAccess.WRITE)
	else: f.seek_end()
	f.store_line(t); f.close(); print(t)
func _initialize() -> void: call_deferred("run")
func dump(n: Node, indent: int) -> void:
	var pad := "  ".repeat(indent)
	var extra := ""
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		extra = " vis=%s layers=%s cast=%s" % [str(g.visible), str(g.layers), str(g.cast_shadow)]
	log_line("%s%s (%s)%s" % [pad, n.name, n.get_class(), extra])
	for c in n.get_children():
		dump(c, indent+1)
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(-2400, -2400))
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("TREE_START")
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(960,540)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=true; world.persist_profile=false
	if "enable_game_start_cab_exit" in world: world.enable_game_start_cab_exit=false
	root.add_child(world)
	for i in 12: await process_frame
	world.regenerate(41001)
	for i in 100: await process_frame
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
	log_line("hide_root=%s" % String(hide_root.get_path()))
	dump(hide_root.get_parent(), 0)
	log_line("TREE_DONE")
	quit(0)