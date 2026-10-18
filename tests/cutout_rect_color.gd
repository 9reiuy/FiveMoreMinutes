extends SceneTree
var log_path := "user://cutout_rect_color_log.txt"
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
	DisplayServer.window_set_position(Vector2i(-2400, -2400))
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("RECT_START")
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1280,720)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=true; world.persist_profile=false
	if "enable_game_start_cab_exit" in world: world.enable_game_start_cab_exit=false
	root.add_child(world)
	for i in 25: await process_frame
	world.regenerate(41001)
	for i in 120: await process_frame
	var display: Node = null
	for n in root.find_children("*", "Control", true, false):
		if n.is_in_group(&"dream_display"): display = n; break
	var palette = display.find_child("WorldPalette", true, false)
	if palette: palette.visible = false; log_line("hid_palette")
	var comp: ColorRect = display.find_child("OcclusionCutoutComposite", true, false) as ColorRect
	comp.material = null
	comp.color = Color(1.0, 0.0, 1.0, 1.0)
	log_line("comp_color_set_magenta")
	var img: Image = await capture()
	var runtime := ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	img.save_png(runtime.path_join("rect_magenta.png"))
	var a := avg(img, 640, 360, 20)
	log_line("center=%s" % str(a))
	log_line("RECT_DONE")
	quit(0)