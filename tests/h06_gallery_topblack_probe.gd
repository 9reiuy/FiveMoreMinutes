extends "res://tests/h06_hangar_crew_test.gd"
var capture_baseline:=false

func run() -> void:
	create_timer(120,true,false,true).timeout.connect(func():quit(3))
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	preload("res://tests/support/background_gpu.gd").start(self)
	capture_baseline=OS.get_environment("H06_GALLERY_CAPS")=="0"
	set_meta(CHAPTER.RETRY_KEY,{"checkpoint":CHAPTER.Save.ENTRANCE})
	world=load(WORLD).instantiate()
	world.generate_on_ready=false
	world.set_meta(&"h06_gallery_topblack_enabled",not capture_baseline)
	display=load(PREVIEW).instantiate()
	display.preview_mode=false
	display.world=world
	root.add_child(display)
	await frames(1)
	if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2);return
	check(world.regenerate(11011),"actual 1-1 generates")
	world._setup_chapter_session()
	root.get_node("DreamTimeController").slow_time_enabled=false
	Engine.time_scale=1
	world._spotlight_triggered=true
	world.blockout.play_spotlight_reveal(true)
	world.process_mode=Node.PROCESS_MODE_DISABLED
	var bounds:Array=[]
	for node in world.blockout.wall_root.get_children():
		if node is MeshInstance3D and (node.name.begins_with("Wall") or node.name.begins_with("WindowReturn") or node.name.begins_with("ThresholdReturn")):
			bounds.append({"name":node.name,"at":str(node.position),"aabb":str(node.get_aabb())})
	for spec:Array in [["01-entry",Vector2(10.0,6.0)],["02-east-gallery",Vector2(5.5,-1.0)],["03-north-gallery",Vector2(-3.6,-6.4)],["04-monitor-room",Vector2(-3.8,-16.0)],["05-north-exit",Vector2(-5.5,-21.4)]]:
		world._place_feet(spec[1])
		world._sync_height_immediate()
		await frames(16)
		await photograph(spec[0])
	world._set_lower(true)
	world._place_feet(Vector2(16.5,-1.5))
	world.blockout.service_view(true,world._feet())
	world._sync_height_immediate()
	await frames(16)
	await photograph("06-secret")
	FileAccess.open(evidence.path_join("scene.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"wall_bounds":bounds,"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"muted":AudioServer.is_bus_mute(0),"pid":OS.get_process_id()},"\t"))
	display.queue_free()
	await frames(8)
	quit(0 if checks.all(func(row:Dictionary)->bool:return row.pass) else 1)
