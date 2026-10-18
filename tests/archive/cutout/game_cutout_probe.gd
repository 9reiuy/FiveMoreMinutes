extends SceneTree
var log_path := "user://game_cutout_probe_log.txt"
func log_line(t: String) -> void:
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f == null: f = FileAccess.open(log_path, FileAccess.WRITE)
	else: f.seek_end()
	f.store_line(t); f.close(); print(t)

func _initialize() -> void:
	call_deferred("run")

func avg(img: Image, cx: int, cy: int, r: int) -> Color:
	var s := Color(0,0,0,0); var n:=0
	for y in range(cy-r,cy+r+1):
		for x in range(cx-r,cx+r+1):
			if x>=0 and y>=0 and x<img.get_width() and y<img.get_height():
				s += img.get_pixel(x,y); n+=1
	return s/float(maxi(n,1))

func near_black_ratio(img: Image, cx: int, cy: int, r: int) -> float:
	var black := 0; var n:=0
	for y in range(cy-r,cy+r+1):
		for x in range(cx-r,cx+r+1):
			if x<0 or y<0 or x>=img.get_width() or y>=img.get_height(): continue
			var c := img.get_pixel(x,y)
			n += 1
			if c.r+c.g+c.b < 0.12: black += 1
	return float(black)/float(maxi(n,1))

func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(30,30))
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("GAME_CUTOUT_PROBE_START")
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 720)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = true
	world.persist_profile = false
	if world.get("enable_game_start_cab_exit") != null:
		world.enable_game_start_cab_exit = false
	root.add_child(world)
	log_line("world_added")
	for i in 20:
		await process_frame
	var ok := true
	if world.has_method("regenerate"):
		ok = world.regenerate(41001)
	log_line("regenerate=%s" % str(ok))
	for i in 90:
		await process_frame
	# Freeze AI/movement if possible
	if world.get("player") != null and is_instance_valid(world.player):
		world.player.set_physics_process(false)
		world.player.set_process(false)
	if world.has_method("set_process"):
		world.set_process(false)
	for i in 10:
		await process_frame
	# Force update cutouts
	if world.has_method("_update_occlusion_cutouts"):
		world._update_occlusion_cutouts()
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png("user://game_cutout_probe_full.png")
	# Also copy into project .runtime for easy access
	var runtime := ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	DirAccess.make_dir_recursive_absolute(runtime)
	img.save_png(runtime.path_join("game_probe_after_invest.png"))
	var cx := img.get_width() / 2
	var cy := img.get_height() / 2
	log_line("center=%s near_black=%s" % [str(avg(img,cx,cy,12)), str(near_black_ratio(img,cx,cy,40))])
	# Read active cutout slots
	for i in 8:
		var v: Variant = RenderingServer.global_shader_parameter_get("occlusion_cutout_%d" % i)
		log_line("slot%d=%s" % [i, str(v)])
	var vp: Variant = RenderingServer.global_shader_parameter_get("occlusion_viewport_size")
	log_line("viewport_size=%s" % str(vp))
	log_line("GAME_CUTOUT_PROBE_DONE")
	quit(0)