extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	DisplayServer.window_set_position(Vector2i(-2400, -2400))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(640, 360)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=true; world.persist_profile=false
	if "enable_game_start_cab_exit" in world: world.enable_game_start_cab_exit=false
	root.add_child(world)
	for i in 20: await process_frame
	world.regenerate(41001)
	for i in 80: await process_frame
	var wcam: Camera3D = world.camera_3d
	var furn: MeshInstance3D = null
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or not String(mesh.get_path()).contains("LowPixelOfficeVisual_chair/BaseMesh"): continue
		var center: Vector3 = mesh.global_transform * mesh.get_aabb().get_center()
		if wcam.is_position_behind(center): continue
		if wcam.get_viewport().get_visible_rect().grow(-30).has_point(wcam.unproject_position(center)):
			furn = mesh; break
	var hide_root: Node = furn
	while hide_root.get_parent() != null and not hide_root.has_meta(&"occlusion_cutout_occluder"):
		hide_root = hide_root.get_parent()
	print("hide_root=", hide_root.name, " meta=", hide_root.get_meta(&"occlusion_cutout_occluder"))
	for node in hide_root.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		print("MESH ", m.name, " layers=", m.layers, " has8=", (m.layers&8)!=0, " shadow=", m.cast_shadow, " visible=", m.visible, " path=", m.get_path())
	# also count office occluders missing layer8
	var missing:=0; var total:=0
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		var cur: Node = m
		var is_occ:=false
		while cur:
			if cur.has_meta(&"occlusion_cutout_occluder") and bool(cur.get_meta(&"occlusion_cutout_occluder")):
				is_occ=true; break
			cur = cur.get_parent()
		if not is_occ: continue
		if m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		total+=1
		if (m.layers & 8)==0:
			missing+=1
			if missing <= 12:
				print("MISSING8 ", m.name, " layers=", m.layers, " path=", str(m.get_path()))
	print("occluder_visible_meshes=", total, " missing_layer8=", missing)
	print("MESH_PROBE_DONE")
	quit(0)
