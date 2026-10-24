extends "res://tests/phone_tab_delivery.gd"
var city:Node
func shot(label:String)->void:
	# Count completed frames after shader/material edits. A newly compiled
	# shader can consume the entire wall-clock wait in just one stale frame.
	for index in 6:
		await process_frame
		if is_instance_valid(city):city._sync_render_snapshot()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label+".png")
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):quit(2);return
	output="res://.runtime/city_visibility_20261020/camera"
	preload("res://tests/support/background_gpu.gd").start(self)
	process_frame.connect(func()->void:
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1920,1080);Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);await ready_main()
	main.persistent_day_state=main._create_initial_state();main.persistent_day_state.tutorial_completed=true
	seed(120);main._show_dream("basic");await ready_main();world=main._supported_dream_world
	var deadline:=Time.get_ticks_msec()+45000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline:await wait(.05)
	world.player.dash_invulnerability_left=3600
	city=world.office_art_root.get_child(0).city
	# Submit production camera snapshots explicitly while the comparison freezes
	# world processing; ordinary gameplay owns this through its pre-draw hook.
	process_frame.connect(func()->void:
		if is_instance_valid(city) and is_instance_valid(world):
			world.room_visibility._update_outside_mask()
			city._sync_render_snapshot())
	var original_process_mode:Node.ProcessMode=world.process_mode
	world.process_mode=Node.PROCESS_MODE_DISABLED
	# Reproduce the rejected OUTWARD dissolve on exactly the same paused frame.
	var inverse:Image=city.topology.image.duplicate()
	for y in inverse.get_height():
		for x in inverse.get_width():
			var color:=inverse.get_pixel(x,y);color.r=1.0-color.r;inverse.set_pixel(x,y,color)
	var bad_texture:=ImageTexture.create_from_image(city.interior_cut_depth_image({"image":inverse}))
	var bad_shader:Shader=city.CITY_SHADER.duplicate()
	bad_shader.code=bad_shader.code.replace("soft_occlusion_enabled && !own_facade && texture(city_void, mask_uv).r < 0.5","soft_occlusion_enabled && !own_facade").replace("float interior_depth = max(0.0, texture(city_clearance, mask_uv).r - 0.5);","float interior_depth = texture(city_clearance, mask_uv).r;").replace("retention = 1.0 - smoothstep(0.0, 1.5, interior_depth);","retention = smoothstep(0.65, 2.4, interior_depth);").replace("if (soft_occlusion_enabled && !own_facade)","if (texture(city_void, mask_uv).r < 0.5) { discard; }\n\t\t\tif (soft_occlusion_enabled && !own_facade)")
	# The first rejected version also dissolved the current building skirt.
	bad_shader.code=bad_shader.code.replace(" && !own_facade", "")
	for material in city.render_materials:
		material.shader=bad_shader;material.set_shader_parameter("city_clearance",bad_texture)
	await shot("before")
	var baseline:Image=root.get_texture().get_image()
	for material in city.render_materials:
		material.shader=city.CITY_SHADER;material.set_shader_parameter("city_clearance",city.topology.clearance_texture)
	await shot("after")
	var corrected:Image=root.get_texture().get_image()
	check(baseline.get_data()!=corrected.get_data(),"Actual GPU restores solid external buildings from the rejected outward dissolve")
	await shot("stable")
	check(corrected.get_data()==root.get_texture().get_image().get_data(),"Frozen camera dissolve stays stable instead of sparkling")
	check(city.render_materials.size()==3,"City keeps the same three batched materials")
	check(city.render_materials[2].get_shader_parameter("own_facade")==true,"Current building side facade retains its separate rule")
	world.process_mode=original_process_mode
	var origin:Vector2=world.player.global_position
	begin("walk")
	Input.action_press("move_up");await wait(.7);Input.action_release("move_up")
	Input.action_press("move_left");await wait(.7);Input.action_release("move_left")
	Input.action_press("move_down");await wait(.7);Input.action_release("move_down")
	await wait(.3);finish()
	check(origin.distance_to(world.player.global_position)>2,"Walk clip moves the actual player and gameplay camera")
	phone=main.game_phone
	begin("phone_zoom");await tap(KEY_TAB);await settled();await shot("zoom")
	check(paused and phone.active,"Phone zoom pauses gameplay while city snapshot still updates")
	await tap(KEY_TAB);await settled();finish()
	check(not paused and not phone.is_open(),"Closing phone restores gameplay with city visible")
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"Actual Camera verification remains minimized")
	var report:={"checks":checks,"failures":failures,"clips":clips,"seed":world.active_seed,"gpu":RenderingServer.get_video_adapter_name(),"scope":"Actual Main Camera; same frozen rejected outward dissolve / corrected inward transition, normal-speed walk and phone zoom; not combat performance"}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CITY_VISIBILITY_GPU checks=",checks," failures=",failures.size())
	main.free();quit(0 if failures.is_empty() else 1)
