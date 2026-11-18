extends "res://tests/h06_hangar_crew_test.gd"

func run() -> void:
	create_timer(150,true,false,true).timeout.connect(func():quit(3))
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	preload("res://tests/support/background_gpu.gd").start(self)
	var main:Node=load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await frames(12)
	if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2);return
	main.persistent_day_state=main._create_initial_state()
	main.chapter_one.start_new()
	main._show_dream("basic",false)
	for i in 7200:
		await process_frame
		if not main.transition_running and is_instance_valid(main._supported_dream_world):break
	world=main._supported_dream_world
	check(is_instance_valid(world) and world.scene_file_path==WORLD,"actual Main uses the first-chapter world")
	if not is_instance_valid(world):quit(1);return
	check(world.chapter_stream_ready and world.chapter_staged_regions.size()==3,"Main covered loading prepares the three future visits")
	check(world.last_firearm_render_preparation.get("chapter_streaming",{}).get("ready",false) and world.is_loading_render_ready(),"shared loading transaction includes chapter and formal firearm render receipts")
	check(not paused and world.can_process() and not main.loading_overlay.visible,"Main releases pause control and the existing loading overlay")
	check(world.enemy_count==0 and world.warehouse_squads.is_empty(),"future enemies remain outside the current encounter")
	display=world.get_meta(&"presentation_world_to_hud").get_object()
	await frames(30)
	await photograph("main-first-chapter")
	var receipt:Dictionary=world.chapter_stream_receipt.duplicate(true)
	var released:WeakRef=weakref(world)
	main.queue_free()
	await frames(8)
	check(released.get_ref()==null,"Main exit releases the prepared chapter")
	var failures:Array=checks.filter(func(row:Dictionary)->bool:return not row.pass)
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"warm_receipt":receipt,"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"muted":AudioServer.is_bus_mute(0)},"\t"))
	print("H06_STREAM_MAIN_ENTRY checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
