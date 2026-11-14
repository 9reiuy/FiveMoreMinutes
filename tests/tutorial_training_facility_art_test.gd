extends SceneTree
const BACKGROUND := preload("res://tests/support/background_gpu.gd")
var output := ""
var baseline := false
var lab: Control
var world: Node3D
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var phase := "loading"
var last_usec := 0

func _initialize() -> void: call_deferred("run")

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if last_usec > 0: samples.append({"phase":phase,"ms":(now-last_usec)/1000.0})
	last_usec = now
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(8)
	return false

func frames(count: int) -> void:
	for index in count: await process_frame

func check(ok: bool, title: String) -> void:
	checks.append({"pass":ok,"description":title})
	print("PASS " if ok else "FAIL ",title)

func capture(title: String) -> Image:
	phase = "capture"
	await frames(3)
	await RenderingServer.frame_post_draw
	var picture: Image = world.camera_3d.get_viewport().get_texture().get_image()
	check(picture.save_png(output.path_join(title+".png")) == OK,"Actual Camera: "+title)
	return picture

func pose(at: Vector2) -> void:
	world.player.global_position = at*32.0
	world.player.velocity = Vector2.ZERO
	world.clear_dialogue_focus()
	world._update_camera_and_projection(0.0)
	await frames(8)

func blocked(a: Vector2, b: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(a*32.0,b*32.0,4)
	return not world.player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func compare_floor_wear() -> void:
	var material: ShaderMaterial = world.floor_root.get_child(3).material_override
	var strength := float(material.get_shader_parameter("wear_strength"))
	var worn := await capture("07_worn_gallery")
	material.set_shader_parameter("wear_strength",0.0)
	await frames(4)
	var clean := await capture("08_clean_floor_comparison")
	var changed := 0
	var measured := 0
	for x: float in [10.2,10.6,11.0,11.4,11.8,12.2]:
		for z: float in [10.8,11.2,11.6,12.0,12.4,12.8,13.2,13.6,14.0,14.4,14.8,15.2]:
			if Vector2(x,z).distance_to(Vector2(11,13)) < .65: continue
			var screen: Vector2 = world.camera_3d.unproject_position(Vector3(x,.005,z))
			if not Rect2(Vector2.ZERO,Vector2(worn.get_size())).has_point(screen): continue
			var a := worn.get_pixelv(Vector2i(screen)); var b := clean.get_pixelv(Vector2i(screen))
			if maxf(b.r,maxf(b.g,b.b)) < .03: continue
			measured += 1
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > .006: changed += 1
	material.set_shader_parameter("wear_strength",strength)
	print("WEAR_CAMERA_COMPARE measured=",measured," changed=",changed)
	check(measured >= 20 and changed >= measured*.35,"Fixed-camera floor comparison shows visible surface wear")

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output = argument.trim_prefix("--artifact-dir=")
		if argument == "--case=baseline": baseline = true
	Engine.max_fps = 60
	if not AudioServer.is_bus_mute(0): quit(8); return
	BACKGROUND.start(self)
	lab = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	lab.presentation_scene_path = "res://scenes/testing/TutorialMaintenanceDisplay.tscn"
	root.add_child(lab)
	await frames(16)
	if is_instance_valid(lab.panel): lab.panel.hide()
	if is_instance_valid(lab.hud): lab.hud.hide()
	world = lab.presentation.world
	world.player.set_physics_process(false)
	var lesson: Node = world.get_node("ChapterTraining")
	lesson.set_process(false); lesson.set_physics_process(false)
	print("FACILITY_READY baseline=",baseline," renderer=",RenderingServer.get_current_rendering_method()," size=",world.camera_3d.get_viewport().size)
	check(world.training_zone_states.get(0) and not world.training_zone_states.get(1) and not world.training_zone_states.get(2),"Initial lesson powers only its own room")
	await capture("01_initial")
	for zone in 3:
		world.set_training_zone_enabled(zone,true)
		lesson._gate(["PreparationDoor","EntryToDash","DashToRange"][zone]).set_indicator_power_enabled(true)
		lesson._gate(["PreparationDoor","EntryToDash","DashToRange"][zone]).set_open(true)
	await frames(25)
	for index in 4:
		phase = "camera_move"
		await pose([Vector2(5,21),Vector2(5,13),Vector2(5,5),Vector2(11,13)][index])
		await capture("%02d_%s" % [index+2,["induction","movement","range","gallery"][index]])
		# Drain the image readback/PNG write before timing steady scene frames.
		await frames(3)
		phase = "room_%d_warm" % index
		await frames(120)
	phase = "collision_checks"
	if not baseline:
		check(absf(world.camera_rig.rotation.y+PI*.25)<.0001 and is_equal_approx(world.camera_3d.position.y,13.0),"Tutorial camera turns left 45 degrees without changing its height")
		var art: Node3D = world.get_node("TutorialGeometry/TrainingFacilityArt")
		var black_caps: Array[Node] = art.find_children("ReturnTopBlack*","MeshInstance3D",true,false)
		var sealed_black: bool = art.has_node("WallTopBlack") and black_caps.size() == 3
		for cap: MeshInstance3D in black_caps: sealed_black = sealed_black and cap.material_override == world.authored_cutout.top_black
		if art.has_node("WallTopBlack"): sealed_black = sealed_black and art.get_node("WallTopBlack").material_override == world.authored_cutout.top_black
		check(sealed_black,"Wall tops and ventilation returns use the shared black cap material")
		var shared: Node3D = world.get_node("TutorialGeometry/ChapterLayout/Architecture/SharedWall_1_2")
		check(shared.wall_material_front != world.authored_cutout.top_black and shared.wall_material_back != world.authored_cutout.top_black,"The two sides of shared teaching walls keep their interior material")
		var floor_finish: ShaderMaterial = world.floor_root.get_child(0).material_override
		check(float(floor_finish.get_shader_parameter("wear_strength")) > 1.0 and Vector4(floor_finish.get_shader_parameter("floor_bounds")).z > 0.0,"Ageing is attached to actual floor bounds and uses the visible wear pass")
		check(world.get_node("TutorialGeometry").has_node("TrainingFacilityArt"),"New facility art belongs to the tutorial")
		check(world.floor_cells.has(Vector2i(9,17)) and world.floor_cells.has(Vector2i(9,9)),"Yellow observation walkway has continuous real floor support")
		check(world.get_node("TutorialGeometry/TrainingFacilityArt").find_children("*","Light3D",true,false).is_empty(),"Decorations cannot leave independent room lights on")
		check(world.authored_cutout.blocks_view(world.camera_3d,world.get_gameplay_world_position(Vector2(8.5,17.5)*32.0,1.2)),"Front structural piers participate in shared occlusion cutout")
		check(not blocked(Vector2(9.15,17),Vector2(11.3,17)),"The former gallery divider does not leave an invisible wall")
		check(blocked(Vector2(8.85,16.6),Vector2(8.85,18.4)),"The new full-size pier has matching gameplay collision")
		check(blocked(Vector2(9.15,8.2),Vector2(9.15,10.2)),"The observation desk has matching gameplay collision")
		var gate: Node3D = lesson._gate("EntryToDash")
		gate.set_open(false); await frames(30)
		check(blocked(Vector2(7.8,13),Vector2(9.5,13)),"A closed mesh gate still blocks admission")
		gate.set_open(true); await frames(30)
		check(not blocked(Vector2(7.8,13),Vector2(9.5,13)),"The opened mesh gate releases the real passage")
		await compare_floor_wear()
		var cabinet: Node3D = art.get_node("WeaponCabinet")
		check(cabinet.has_node("OpenMeshDoor") and not world.get_node("TutorialGeometry/ChapterLayout/Range/WeaponTray").visible,"An open weapon cabinet replaces the original ground tray")
		check(blocked(Vector2(2.7,3.3),Vector2(2.7,2.1)),"The weapon cabinet body has matching collision")
		var bridge: Node3D = lesson.pickup.get_meta(&"depth_visual_bridge").get_ref()
		check(bridge.actor_sprite.global_position.y > 1.0 and lesson.pickup.global_position.y < 3.0*32.0,"The actual pickup is displayed above the shelf at the indicated rear wall")
		await pose(lesson.WEAPON_APPROACH/32.0)
		await capture("09_weapon_cabinet")
		lesson.stage=lesson.Stage.RANGE_TEST
		lesson._sync_progression(true)
		var pickup_id: int=lesson.pickup.get_instance_id()
		var bridge_id := bridge.get_instance_id()
		var event := InputEventKey.new(); event.physical_keycode=KEY_E; event.keycode=KEY_E; event.pressed=true
		root.push_input(event,true); await frames(2)
		event=event.duplicate(); event.pressed=false; root.push_input(event,true); await frames(4)
		check(lesson.picked and world.player.selected_weapon_id=="basic","Actual E input takes the single real cabinet weapon")
		check(not is_instance_id_valid(pickup_id) and not is_instance_id_valid(bridge_id),"Taking the cabinet weapon removes its pickup and suspended visual")
		await capture("10_weapon_cabinet_empty")
	# Actual no-source blackout: switch every room, gate and TV off.
	for zone in 3:
		world.set_training_zone_enabled(zone,false)
		world.monitor_feed.stations[zone].set_power_available(false)
	for gate in ["PreparationDoor","EntryToDash","DashToRange","Exit"]: lesson._gate(gate).set_indicator_power_enabled(false)
	await frames(5)
	var dark := await capture("06_all_power_off")
	var lit_pixels := 0
	for y in dark.get_height():
		for x in dark.get_width():
			var pixel := dark.get_pixel(x,y)
			if maxf(pixel.r,maxf(pixel.g,pixel.b)) > .008: lit_pixels += 1
	check(lit_pixels == 0,"No light sources leaves a black room")
	var old: int = world.get_instance_id()
	phase = "rebuild"
	# Presentation mode owns the authored display, without random-world UI.
	lab.presentation.free()
	await frames(2)
	lab.presentation = load("res://scenes/testing/TutorialMaintenanceDisplay.tscn").instantiate()
	lab.add_child(lab.presentation)
	await frames(18)
	world = lab.presentation.world
	check(world.get_instance_id() != old and world.get_node("ChapterTraining").stage == 0,"Test-lab rebuild returns a fresh tutorial")
	check(world.training_zone_states.get(0) and not world.training_zone_states.get(1),"Rebuild restores the initial lighting sequence")
	phase = "reentry_warm"
	await frames(120)
	var statistics := {}
	var groups: Dictionary = {}
	for sample in samples:
		if not groups.has(sample.phase): groups[sample.phase] = []
		groups[sample.phase].append(sample.ms)
	for group: String in groups:
		var values: Array = groups[group]; values.sort()
		statistics[group] = {"frames":values.size(),"p50":values[ceili(values.size()*.50)-1],"p95":values[ceili(values.size()*.95)-1],"p99":values[ceili(values.size()*.99)-1],"max":values.back()}
	FileAccess.open(output.path_join("frame_intervals.json"),FileAccess.WRITE).store_string(JSON.stringify(samples))
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"timing":statistics,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"audio":AudioServer.get_driver_name(),"pid":OS.get_process_id(),"scope":"Staged actual Camera art and lighting, fixed warm-frame intervals and test-lab rebuild; no whole-game performance certification"},"\t"))
	var failed: int = checks.filter(func(item: Dictionary) -> bool: return not item.pass).size()
	lab.free(); await frames(6)
	print("FACILITY_ART checks=",checks.size()," failures=",failed)
	quit(0 if failed == 0 else 1)
