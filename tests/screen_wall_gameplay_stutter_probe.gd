extends SceneTree
## First-use effects in the actual tutorial scene, with native GPU drawing.
var out := "res://.runtime/screen_wall_stutter_20261108/gameplay/"
var main: Node
var world: Node3D
var cases: Array = []
var checks := 0
var failures := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): out=arg.trim_prefix("--output-dir=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func frames(count: int) -> void:
	for index in count: await process_frame

func capture(label: String, seconds: float, trigger: Callable=Callable()) -> void:
	var raw: Array=[]
	var began:=Time.get_ticks_usec()
	var previous:=began
	if trigger.is_valid(): trigger.call()
	while Time.get_ticks_usec()-began<int(seconds*1000000.0):
		await process_frame
		var now:=Time.get_ticks_usec()
		var monitor: Node=root.get_node("PerformanceMonitor")
		raw.append({"frame_ms":(now-previous)/1000.0,"draw_span_ms":monitor.last_breakdown.get("draw_span",-1.0),
			"script_ms":monitor.last_breakdown.get("script",-1.0),"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(main.current_screen.world_viewport.get_viewport_rid()),
			"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"time_scale":Engine.time_scale,"position":str(world.player.global_position)})
		previous=now
	var stats:={}
	for metric in ["frame_ms","draw_span_ms","script_ms","gpu_ms"]:
		var values: Array=raw.map(func(row):return row[metric])
		values.sort()
		stats[metric]={"p50":values[values.size()/2],"p95":values[floori(values.size()*.95)],"p99":values[floori(values.size()*.99)],"max":values.back()}
	cases.append({"case":label,"stats":stats,"raw":raw})
	print("GAMEPLAY_CASE ",label," ",stats.frame_ms)

func run() -> void:
	print("DESKTOP_LOAD_PID=",OS.get_process_id()," audio=",AudioServer.get_driver_name())
	if not OS.get_user_data_dir().contains("desktop_probe") or AudioServer.get_driver_name()!="WASAPI" or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true);quit(2);return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-30000,-30000))
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(640,360)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	root.get_node("FrameBudget").apply_window_focus(true)
	main=load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await frames(40)
	main.persistent_day_state=main._create_initial_state()
	main.chapter_one.start_new()
	main._show_tutorial("basic")
	var deadline:=Time.get_ticks_msec()+18000
	while (main.transition_running or main._supported_dream_world==null) and Time.get_ticks_msec()<deadline: await process_frame
	world=main._supported_dream_world
	if world==null: check(false,"tutorial loaded");quit(2);return
	RenderingServer.viewport_set_measure_render_time(main.current_screen.world_viewport.get_viewport_rid(),true)
	check(world.scene_file_path.contains("Tutorial"),"actual tutorial loaded through Main")
	check(Engine.max_fps==60,"gameplay foreground cap remains 60")
	await capture("idle_first_exposure",3.0)
	var training: Node=world.get_node("ChapterTraining")
	training.stage=training.Stage.JUMP_TEST
	training._sync_progression(true)
	world.player.global_position=Vector2(4,13)*32.0
	await frames(10)
	await capture("dash_first",2.0,func():world.player._start_dash(Vector2.RIGHT))
	world.player.global_position=Vector2(4,13)*32.0
	await frames(8)
	await capture("dash_repeat",2.0,func():world.player._start_dash(Vector2.RIGHT))
	training.stage=training.Stage.RANGE_TEST
	training.picked=true
	training._sync_progression(true)
	world.player.global_position=Vector2(4,7.5)*32.0
	world.player.equip_weapon("basic",world.config)
	world.player.set_meta("presentation_pointer_gate",func():return true)
	world.player.set_meta("presentation_pointer_position",func():return world.camera_3d.unproject_position(Vector3(4,.65,2.6)))
	await frames(10)
	await capture("shoot_first",2.0,func():Input.action_press("attack"))
	Input.action_release("attack")
	await frames(25)
	await capture("shoot_repeat",2.0,func():Input.action_press("attack"))
	Input.action_release("attack")
	check(AudioServer.is_bus_mute(0),"private mute retained")
	check(Engine.max_fps==60,"actions do not change frame cap")
	var file:=FileAccess.open(out+"gameplay_load.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"cases":cases,"scope":"Main tutorial first idle/dash/shoot, native offscreen 1280x720 and 640x360 world, VSync, WASAPI private mute, no cache deletion or forced draw; authored training stage advanced only in this private probe"},"\t"))
	file.close()
	Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null,Input.CURSOR_POINTING_HAND)
	main.queue_free()
	await frames(5)
	print("GAMEPLAY_RESULT checks=",checks," failures=",failures," exit=",1 if failures else 0)
	quit(1 if failures else 0)
