extends SceneTree
const OUT="res://.runtime/emotion_interaction_20261023"
var checks:=0
var failures:=0
var main: Node
var room: Node
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(n: int=8) -> void:
	for i in n: await process_frame
func settle() -> void:
	var deadline:=Time.get_ticks_msec()+90000
	while main.transition_running and Time.get_ticks_msec()<deadline: await process_frame
	await frames(12)
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+label+".png")
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func() -> void: quit(2))
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"): quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); root.size=Vector2i(1280,720); Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var settings:=root.get_node("SettingsManager")
	settings.set_setting(&"pixelation_enabled",true); settings.set_palette_enabled(true)
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await settle()
	main.persistent_day_state=main._create_initial_state(); main._show_reception("basic"); await settle()
	room=main._supported_dream_world
	check(room is Dream3DReceptionRoom,"Actual Main enters formal reception")
	room.player.set_physics_process(false)
	room.player.global_position=room.RECEPTION_DESK_POS_2D+Vector2(0,45)
	await frames(20)
	check(room.interaction_prompt.text=="交流" and room.npc_hint_bubble.visible,"Actual camera has nearby talk and emotion widgets")
	await shot("talk_palette")
	room.set_process(false)
	room.npc_hint_bubble.set_process(false)
	for mood in room.npc_hint_bubble.EMOTIONS:
		room.waitress_npc.hint_emotion=str(mood); room._update_interaction_prompt()
		room.npc_hint_bubble.reveal=1; room.npc_hint_bubble._process(0); room.npc_hint_bubble.set_process(false)
		await frames(2); await shot("emotion_"+str(mood))
		check(room.npc_hint_bubble.emotion==mood,"Formal camera shows authored mood: "+str(mood))
	# Deterministic frame-by-frame animation in the real game camera, not an FPS benchmark.
	var prompt: Node=room.interaction_prompt
	prompt.dismiss(true); prompt.present("交流",room.npc_hint_bubble.prompt_anchor(prompt.size),-99); prompt.set_process(false)
	for i in 25:
		if i==15: prompt.dismiss()
		prompt._process(.02)
		await frames(1); await shot("motion_%02d" % i)
	check(not prompt.visible,"Captured close animation completes")
	for word in ["拾取","替换","进入"]:
		prompt.present(word,room.npc_hint_bubble.prompt_anchor(prompt.size),word.hash()); prompt._process(.2); prompt.set_process(false)
		await frames(2); await shot("action_"+word)
		check(prompt.text==word and prompt.scale==Vector2.ONE,"Short action keeps original glyph size: "+word)
	settings.set_setting(&"pixelation_enabled",false); settings.set_palette_enabled(false)
	room.set_process(true); room.waitress_npc.hint_emotion="nervous"; await frames(12)
	await shot("talk_native")
	check(room.interaction_prompt.FRAME_COLOR==Color("396FE2"),"HUD blue is not modified by world palette")
	var input:=InputEventAction.new(); input.action="pickup_weapon"; input.pressed=true; Input.parse_input_event(input)
	await frames(2)
	input=InputEventAction.new(); input.action="pickup_weapon"; input.pressed=false; Input.parse_input_event(input)
	await frames(18); await shot("dialogue_body_unchanged")
	check(room.dialogue_controller.is_active(),"Existing real E input still starts conversation")
	check(not room.interaction_prompt.visible and not room.npc_hint_bubble.visible,"Dialogue hides both proximity widgets")
	check(room.dialogue_bubble.get_script().resource_path.ends_with("growing_dialogue_bubble.gd"),"Dialogue body implementation is unchanged")
	main.free(); await frames(3)
	print("EMOTION_CAMERA checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
