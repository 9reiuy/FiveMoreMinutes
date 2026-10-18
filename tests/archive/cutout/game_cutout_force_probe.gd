extends SceneTree
var log_path := "user://game_cutout_force_log.txt"
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

func black_ratio(img: Image, cx: int, cy: int, r: int) -> float:
	var black := 0; var n:=0
	for y in range(cy-r,cy+r+1):
		for x in range(cx-r,cx+r+1):
			if x<0 or y<0 or x>=img.get_width() or y>=img.get_height(): continue
			var c := img.get_pixel(x,y); n+=1
			if c.r+c.g+c.b < 0.10: black += 1
	return float(black)/float(maxi(n,1))

func capture() -> Image:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(40,40))
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("FORCE_START")
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1280,720)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = true
	world.persist_profile = false
	if "enable_game_start_cab_exit" in world: world.enable_game_start_cab_exit = false
	root.add_child(world)
	for i in 15: await process_frame
	world.regenerate(41001)
	for i in 100: await process_frame
	if world.get("player") != null: world.player.set_physics_process(false)
	# Baseline
	var img0: Image = await capture()
	img0.save_png("user://force_baseline.png")
	var vp_size := root.get_visible_rect().size
	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", vp_size)
	# Force a big cutout at screen center
	var forced := Vector4(0.5, 0.5, 90.0, 1.0)
	RenderingServer.global_shader_parameter_set("occlusion_cutout_0", forced)
	for i in range(1,8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	# Also prevent _update from clearing: pause process and mark meta
	world.set_process(false)
	if world.has_method("set_physics_process"): world.set_physics_process(false)
	var img1: Image = await capture()
	img1.save_png("user://force_cutout_on.png")
	var runtime := ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	DirAccess.make_dir_recursive_absolute(runtime)
	img0.save_png(runtime.path_join("force_baseline.png"))
	img1.save_png(runtime.path_join("force_cutout_on.png"))
	var cx := img1.get_width()/2; var cy := img1.get_height()/2
	log_line("baseline_center=%s black=%s" % [str(avg(img0,cx,cy,20)), str(black_ratio(img0,cx,cy,50))])
	log_line("forced_center=%s black=%s" % [str(avg(img1,cx,cy,20)), str(black_ratio(img1,cx,cy,50))])
	log_line("vp_size_set=%s" % str(vp_size))
	# Diff count
	var darker := 0; var n:=0
	for y in range(cy-50,cy+51):
		for x in range(cx-50,cx+51):
			if x<0 or y<0 or x>=img1.get_width() or y>=img1.get_height(): continue
			var a := img0.get_pixel(x,y); var b := img1.get_pixel(x,y)
			n += 1
			if (a.r+a.g+a.b) - (b.r+b.g+b.b) > 0.15: darker += 1
	log_line("darker_pixels=%d/%d" % [darker,n])
	log_line("FORCE_DONE")
	quit(0)