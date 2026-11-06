extends SceneTree
## Production Main routes; controlled scene positions for art review.
var main: Node
var world: Node
var out := "res://.runtime/art_revision_20261102/after"
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func frames(count := 8) -> void:
	for i in count: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)
func settle() -> void:
	while main.transition_running: await process_frame
	await frames(45)
	world = main._supported_dream_world
func snap(label: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + label + ".png")
func reception_at(point: Vector2, label: String) -> void:
	world.player.global_position = point * 32.
	world.camera_aim_offset = Vector3.ZERO
	world._update_camera_and_projection(0.)
	await snap(label)
func run() -> void:
	if "--before" in OS.get_cmdline_user_args(): out = "res://.runtime/art_revision_20261102/before"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=")
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size = Vector2i(1280,720); Engine.max_fps = 60; AudioServer.set_bus_mute(0,true)
	create_timer(300.,true,false,true).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await settle()
	main.persistent_day_state = main._create_initial_state(); main.chapter_one.start_new()
	main.chapter_one.state.seed = 42001
	main.chapter_one.state.stage = "RECEPTION"; main.chapter_one.resume(); await settle()
	world.player.set_physics_process(false)
	await reception_at(world.PLAYER_SPAWN/32.,"reception_entry")
	await reception_at(Vector2(8.,4.5),"reception_hall")
	await reception_at(world.RECEPTION_DESK_POS_2D/32.+Vector2(0,1.6),"reception_tarot")
	await reception_at(Vector2(world.ELEVATOR_POS_3D.x,3.5),"reception_elevator")
	main.chapter_one.state.stage = "TUTORIAL"; main.chapter_one.resume(); await settle()
	var training: Node = world.get_node("ChapterTraining")
	training.set_process(false); training.set_physics_process(false); world.player.set_physics_process(false)
	training.panel.dismiss()
	training.hint.hide()
	for zone in 3:
		training.stage = [1,2,3][zone]; training._sync_progression(true)
		world.player.global_position = Vector2(11.,[21.,13.,5.][zone])*32.
		world.camera_aim_offset = Vector3.ZERO; world._update_camera_and_projection(0.)
		await snap("tutorial_zone%d" % zone)
	main.chapter_one.show_room(false); await settle(); world.mode="EVENING"
	await snap("bedroom")
	main.chapter_one.state.stage = "ASCENT"; main.chapter_one.state.floor=2
	main.chapter_one.resume(); await settle()
	while world.floor_transition_in_progress: await process_frame
	await frames(40)
	world.player.invulnerability_left = 999.
	var adapter: Node = world.get_node("ChapterOneRun")
	world.player.global_position = adapter.terminal_position + Vector2(0,70)
	world.player.set_physics_process(false); world._update_camera_and_actor_projection(0.)
	await snap("rest_workbench")
	main.chapter_one.state.stage="COAST"; main.chapter_one.resume(); await settle()
	var coast: Node3D = main.current_screen.coast
	coast.external_step=true; coast.player_position=Vector3(-3,0,6.3); coast._place_character(); coast.update_camera(0.,true)
	var times: Dictionary={}
	for i in 1800:
		var t:=i*.02; var visibility: float=coast.visibility_at(t)
		if visibility>.99 and not times.has("clear"): times["clear"]=t
		if visibility<.001 and not times.has("clouded"): times["clouded"]=t
	for state in times:
		coast.clock=times[state]; coast._update_light(); await snap("coast_"+state)
	check(times.size()==2,"production coast retains clear and clouded moon states")
	FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Production Main scene Camera review; scene positioning is controlled, not a full chapter playthrough or performance test."},"\t"))
	main.queue_free(); await frames(10)
	print("ART_REVIEW checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
