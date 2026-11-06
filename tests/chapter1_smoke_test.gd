extends SceneTree
var main: Node
var checks:=0
var failures:=0
const OUT="res://.runtime/chapter1_20261029"
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
	print("PASS " if value else "FAIL ",label)
func _initialize() -> void: call_deferred("run")
func frames(n: int=4) -> void:
	for i in n: await process_frame
func settle() -> void:
	while main.transition_running: await process_frame
	await frames()
func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+name+".png")
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	create_timer(240,true,false,true).timeout.connect(func(): quit(2))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await settle()
	main.persistent_day_state=main._create_initial_state(); main.chapter_one.start_new()
	main._show_bedroom(false); await settle()
	check(main.chapter_one.enabled(),"new story profile enabled")
	var bedroom: Node=main._supported_dream_world
	main.game_phone.open_phone(); await frames(60)
	check(main.game_phone._backend==bedroom.phone,"new bedroom retains phone backend after CanvasLayer adoption")
	check(main.game_phone._clock_data().time=="21:00","evening phone clock uses bedroom time")
	check(not main.game_phone.screen.apps_model.can_purchase() and main.game_phone.screen.apps_model.purchase_hint()=="本章暂不开放购物","chapter shopping is explicitly read-only")
	await snap("bedroom_phone")
	main.game_phone.close_phone(false); await frames(20)
	bedroom.computer_overlay.open(); await frames(15)
	check(is_instance_valid(bedroom.computer_overlay.archive_app),"anonymous archive exists from first evening")
	bedroom.computer_overlay._open_app("archive"); await frames()
	check(not bedroom.panel.status.visible and not bedroom.phone.visible,"computer hides overlapping status and phone entry")
	await snap("archive")
	check(not bedroom.computer_overlay.archive_app.verify(),"first chapter cannot reveal complete truth")
	bedroom.computer_overlay.close(); await frames(25)
	main._start_story_dream(1,false); await settle()
	var tutorial: Node=main._supported_dream_world
	check(is_instance_valid(tutorial.get_node_or_null("ChapterTraining")),"actual Main enters tutorial")
	await frames(30); await snap("tutorial")
	check(not tutorial.get_node("ChapterTraining").can_exit(),"cannot walk past uncompleted training")
	main.chapter_one.state.stage="ASCENT"; main.chapter_one.state.floor=2; main.chapter_one.state.build="damage"; main.chapter_one.state.tarot_id="fool"
	main.chapter_one.resume(); await settle()
	var rest: Node=main._supported_dream_world
	await frames(30)
	var adapter: Node=rest.get_node("ChapterOneRun")
	check(is_instance_valid(adapter.terminal_collision) and adapter.terminal_position!=Vector2.ZERO,"rest workstation placed on actual floor")
	check(rest.enemy_root.get_child_count()==0,"safe rest has no special-unit hostiles")
	rest.player.global_position=adapter.terminal_position+Vector2(0,60); await frames(25); await snap("workbench")
	var camera_prop: Node3D=adapter.cameras.get_child(0)
	rest.player.global_position=Vector2(camera_prop.position.x+.5,camera_prop.position.z+2.5)*32.; await frames(25); await snap("surveillance")
	# Scene-specific presentation smoke; transition logic is tested separately.
	main.chapter_one.state.stage="BED"; main.chapter_one.show_room(false); await settle()
	await frames(12); await snap("return_room")
	check(is_instance_valid(main._supported_dream_world.actor),"return bedroom has a walkable actor")
	main.chapter_one.state.stage="WAKE"; main.chapter_one.show_room(true); await settle()
	await frames(12); await snap("wake_room")
	check(main._supported_dream_world.body.visible,"sleeping self remains visible in wake room")
	main.chapter_one.state.stage="COAST"; main.chapter_one.show_coast(); await settle()
	await frames(12); await snap("coast")
	check(main.current_screen.coast.story_mode,"formal coast hides experimental input")
	check(main.current_screen.coast.atmosphere.signal_nodes.filter(func(node): return node.visible).size()==3,"first fragment uses three spatial dots")
	print("CHAPTER1_SMOKE checks=",checks," failures=",failures)
	main.queue_free(); await frames(3); quit(failures)
