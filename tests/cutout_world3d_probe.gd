extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	DisplayServer.window_set_position(Vector2i(-2400, -2400))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 720)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = true
	world.persist_profile = false
	if "enable_game_start_cab_exit" in world: world.enable_game_start_cab_exit = false
	root.add_child(world)
	for i in 30: await process_frame
	world.regenerate(41001)
	for i in 100: await process_frame
	var display: Node = null
	for n in root.find_children("*", "Control", true, false):
		if n.is_in_group(&"dream_display"): display = n; break
	var behind: SubViewport = display.get_node_or_null("CutoutBehindViewport")
	var container = display.get_node_or_null("WorldDisplayContainer")
	var wp: SubViewport = container.get_node_or_null("WorldViewport")
	var overlay: ColorRect = display.get_node_or_null("OcclusionCutoutComposite")
	var wcam: Camera3D = world.camera_3d
	var bcam: Camera3D = behind.get_camera_3d()
	var ww = wcam.get_world_3d() if wcam else null
	var bw = bcam.get_world_3d() if bcam else null
	print("PROP wp.world_3d=", wp.world_3d, " behind.world_3d=", behind.world_3d)
	print("CAM  wcam.world=", ww, " bcam.world=", bw, " same=", ww == bw)
	print("container scale=", container.scale, " size=", container.size, " pos=", container.position)
	print("overlay scale=", overlay.scale, " size=", overlay.size, " pos=", overlay.position)
	# force assign like a fix would, then sample
	if ww != null:
		behind.world_3d = ww
		print("ASSIGNED behind.world_3d from camera")
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	var bi: Image = behind.get_texture().get_image()
	var mi: Image = wp.get_texture().get_image()
	var runtime := ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	DirAccess.make_dir_recursive_absolute(runtime)
	bi.save_png(runtime.path_join("probe2_behind.png"))
	mi.save_png(runtime.path_join("probe2_main.png"))
	# mean center
	var cs := Color(0,0,0); var n:=0
	for y in range(160,200):
		for x in range(300,340):
			cs += bi.get_pixel(x,y); n+=1
	print("behind_center_mean=", cs/float(n), " behind_unique_est_dark_frac=", _dark_frac(bi))
	cs = Color(0,0,0); n=0
	for y in range(160,200):
		for x in range(300,340):
			cs += mi.get_pixel(x,y); n+=1
	print("main_center_mean=", cs/float(n), " main_dark_frac=", _dark_frac(mi))
	print("PROBE2_DONE")
	quit(0)
func _dark_frac(img: Image) -> float:
	var dark:=0; var tot:=0
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			var c:=img.get_pixel(x,y)
			tot+=1
			if c.r+c.g+c.b < 0.12: dark+=1
	return float(dark)/float(maxi(tot,1))
