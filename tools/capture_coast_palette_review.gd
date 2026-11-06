extends SceneTree
## Real chapter coast Camera readback for colour review; no substitute artwork.
const OUT := "res://.runtime/coast_palette_reference_20261030"
var display: Control
func _initialize() -> void: call_deferred("run")
func frames(n: int = 3) -> void:
	for i in n: await process_frame
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps = 60
	create_timer(90., true, false, true).timeout.connect(func(): quit(2))
	var phase := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	var output := OUT
	if "--lighting" in OS.get_cmdline_user_args(): output = "res://.runtime/coast_spatial_lighting_20261030"
	var city_sample := "--city" in OS.get_cmdline_user_args()
	if city_sample: output = "res://.runtime/coast_city_cliff_20261030"
	DirAccess.make_dir_recursive_absolute(output + "/" + phase)
	display = load("res://scenes/preview/night_coast_city_cliff_display.tscn").instantiate() if city_sample and phase=="after" else load("res://scripts/story/chapter_coast.gd").new()
	root.add_child(display)
	await frames(5)
	var coast: Node3D = display.coast
	for point in [Vector2(-6.2,21),Vector2(0,15),Vector2(-3,6.3)]:
		print("LIGHT_SITE ",point," height=",coast.surface_height(point.x,point.y))
	var arrays: Array = coast.get_node("SandRidge").mesh.surface_get_arrays(0)
	for point in [Vector2(-3,23),Vector2(-3,14),Vector2(-3,6.3)]:
		var index: int = roundi((point.y + 20) * 2) * 261 + roundi((point.x + 65) * 2)
		print("PALETTE_SURFACE_NORMAL ",point," ",arrays[Mesh.ARRAY_NORMAL][index])
	coast.external_step = true
	for i in 60: coast.advance(.1)
	var clear_time := 0.; var covered_time := 0.
	for i in 360:
		if coast.visibility_at(i * .1) > .99: clear_time = i * .1
		if coast.visibility_at(i * .1) < .01: covered_time = i * .1
	var captures: Array = []
	for pose in [["approach",23.,clear_time],["hillside",14.,clear_time],["lookout",6.3,clear_time],["covered",6.3,covered_time]]:
		coast.player_position = Vector3(-3,0,pose[1]); coast.clock = pose[2]
		coast._place_character(); coast.update_camera(0.,true); coast._update_light()
		if city_sample and phase=="after" and pose[0]=="covered": coast.advance(.12)
		await frames(4); await RenderingServer.frame_post_draw
		var image: Image = display.view.get_texture().get_image()
		image.save_png(output + "/" + phase + "/" + pose[0] + ".png")
		captures.append({"pose":pose[0],"time":coast.clock,"moon_visibility":coast.moon_visibility,"image_size":str(image.get_size())})
	print("COAST_PALETTE_CAPTURE ", JSON.stringify({"phase":phase,"gpu":RenderingServer.get_video_adapter_name(),"captures":captures}))
	display.queue_free(); await frames(6)
	quit()
