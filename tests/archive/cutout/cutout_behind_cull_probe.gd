extends SceneTree
func _initialize() -> void: call_deferred("run")
func keep(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); DisplayServer.window_set_position(Vector2i(-2400,-2400))
func settle(n=6):
	for i in n: await process_frame; keep()
func run():
	keep(); AudioServer.set_bus_mute(0,true); root.size=Vector2i(1280,720)
	var runtime := ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=true; world.persist_profile=false
	if "enable_game_start_cab_exit" in world: world.enable_game_start_cab_exit=false
	root.add_child(world); await settle(12); world.regenerate(41001); await settle(90)
	for room in world.rooms:
		if String(room.get("archetype",""))=="open_office":
			world.player.global_position=Vector2(room.center_cell)*world.CELL_PIXELS
			world.activate_room(int(room.id)); break
	await settle(25)
	var behind: SubViewport = root.find_child("CutoutBehindViewport", true, false)
	var world_vp: SubViewport = root.find_child("WorldViewport", true, false)
	var bcam: Camera3D = behind.get_camera_3d() if behind else null
	var cam: Camera3D = world.camera_3d
	print("behind_parent=", behind.get_parent().name if behind else null)
	print("main_cull=", cam.cull_mask, " behind_cull=", bcam.cull_mask if bcam else null)
	print("behind_env=", bcam.environment != null if bcam else null)
	# A: match main cull exactly (include furniture)
	bcam.cull_mask = cam.cull_mask
	bcam.environment = null
	bcam.global_transform = cam.global_transform
	for k in [&"projection",&"fov",&"size",&"near",&"far"]: bcam.set(k, cam.get(k))
	await settle(8); await RenderingServer.frame_post_draw
	var bi = behind.get_texture().get_image(); bi.save_png(runtime.path_join("behind_A_samecull.png"))
	var wi = world_vp.get_texture().get_image(); wi.save_png(runtime.path_join("behind_A_main.png"))
	var avg=func(img:Image)->float:
		var s:=0.0; var n:=0
		for y in range(0,img.get_height(),4):
			for x in range(0,img.get_width(),4):
				var c:=img.get_pixel(x,y); s+=c.r+c.g+c.b; n+=1
		return s/float(maxi(n,1))
	print("A behind_luma=", avg.call(bi), " main_luma=", avg.call(wi))
	# B: exclude layer 8 only
	bcam.cull_mask = cam.cull_mask & ~8
	await settle(6); await RenderingServer.frame_post_draw
	bi = behind.get_texture().get_image(); bi.save_png(runtime.path_join("behind_B_nol8.png"))
	print("B behind_luma=", avg.call(bi))
	# C: force ambient-only readable env
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05,0.08,0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6,0.65,0.7)
	env.ambient_light_energy = 0.8
	bcam.environment = env
	await settle(6); await RenderingServer.frame_post_draw
	bi = behind.get_texture().get_image(); bi.save_png(runtime.path_join("behind_C_ambient.png"))
	print("C behind_luma=", avg.call(bi))
	print("CULL_PROBE_DONE")
	quit(0)
