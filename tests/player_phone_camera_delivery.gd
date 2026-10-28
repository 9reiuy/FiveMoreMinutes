extends "res://tests/phone_tab_delivery.gd"
var recording := ""
var records: Dictionary = {}
var next_record := 0
var letter_changes := 0
func _process(_delta: float) -> bool:
	if recording.is_empty() or Time.get_ticks_msec()<next_record:return false
	next_record=Time.get_ticks_msec()+40
	var list: Array=records[recording]
	var file: String="%s_%03d.png"%[recording,list.size()]
	root.get_texture().get_image().save_png(output+"/"+file)
	var effect: Variant=phone.character_presentation
	list.append({"file":file,"milliseconds":Time.get_ticks_msec(),"frame":effect.frame_index if effect!=null else -1,"glow":effect.glow_alpha if effect!=null else 0.0})
	return false
func record_context(label: String) -> void:
	var player: Node=world.player
	var original_position: Vector2=player.global_position
	var original_weapon: String=player.selected_weapon_id
	records[label]=[];recording=label
	await tap(KEY_TAB)
	check(phone.active and paused,"Actual Tab opens paused phone in "+label)
	await wait(2.4)
	var effect: Variant=phone.character_presentation
	check(effect!=null and effect.frame_index in [4,5],"Authored penultimate character pair loops in "+label)
	check(not player.body_pivot.visible and not player.weapon_root.visible,"Normal limbs/hair/weapon do not overlap full phone frame in "+label)
	var alphas: Dictionary={};var used: Dictionary={}
	for item in records[label]:alphas[item.glow]=true;used[item.frame]=true
	check(alphas.size()>5 and used.has(4) and used.has(5),"Phone video light changes while world is paused in "+label)
	check(player.global_position==original_position and player.selected_weapon_id==original_weapon,"Phone preserves position and inventory in "+label)
	await tap(KEY_D)
	check(phone.screen.get_page_id()==&"home" and player.global_position==original_position,"Phone WASD navigation does not move posed actor in "+label)
	await shot(label+"_open")
	recording=""
	# Paused production Camera: isolate only head-mask emission, hold UI/camera pose.
	phone.set_process(false)
	var material: ShaderMaterial=effect.emission_material
	var strength: float=material.get_shader_parameter("phone_glow_strength")
	material.set_shader_parameter("phone_glow_strength",0.0)
	await wait(.12);await RenderingServer.frame_post_draw
	var dark: Image=root.get_texture().get_image()
	dark.save_png(output+"/"+label+"_glow_off.png")
	material.set_shader_parameter("phone_glow_strength",strength)
	await wait(.12);await RenderingServer.frame_post_draw
	var bright: Image=root.get_texture().get_image()
	bright.save_png(output+"/"+label+"_glow_on.png")
	var foot: Vector2=player.get_presentation_hud_position(world.camera_3d.unproject_position(world.get_gameplay_world_position(player.global_position,0)))
	var physical: Vector2=Vector2(root.size)/root.get_visible_rect().size
	var box:=Rect2i(Vector2i((foot+Vector2(-22,-42))*physical),Vector2i(Vector2(44,48)*physical)).intersection(Rect2i(Vector2i.ZERO,root.size))
	var changed:=0
	for y in range(box.position.y,box.end.y):
		for x in range(box.position.x,box.end.x):
			if dark.get_pixel(x,y)!=bright.get_pixel(x,y):changed+=1
	check(changed>4,"GPU head region receives actual localized blue mask light in "+label)
	phone.set_process(true)
	recording=label
	await tap(KEY_TAB);await wait(.65)
	recording=""
	check(not phone.is_open() and not paused and phone.character_presentation==null,"Close releases pause and temporary presentation in "+label)
	check(player.body_pivot.visible and player.weapon_root.visible and not player.visual.has_node("PhonePose"),"Original actor and gun restore after close in "+label)
	check(not world.player_depth_bridge.lit_material.get_shader_parameter("phone_glow_enabled"),"Phone emission is disabled after close in "+label)
func run() -> void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):quit(2);return
	output="res://.runtime/phone_actor_20261027/camera"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	preload("res://tests/support/background_gpu.gd").start(self)
	create_timer(240,true,false,true).timeout.connect(func():quit(2))
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1280,720);Engine.max_fps=60
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);await ready_main()
	phone=main.game_phone
	main.persistent_day_state=main._create_initial_state();main.persistent_day_state.tutorial_completed=true
	main._show_reception("basic");await ready_main();world=main._supported_dream_world
	world.player.global_position=Vector2(12.5,10.5)*32
	world.player.set_meta(&"aim_direction_override",Vector2.RIGHT)
	await wait(.3)
	await record_context("lobby")
	main._show_dream("basic");await ready_main();world=main._supported_dream_world
	while world.floor_transition_in_progress:await wait(.05)
	for enemy in world.enemy_root.get_children():enemy.set_physics_process(false)
	world.player.set_meta(&"aim_direction_override",Vector2.RIGHT)
	await record_context("floor")
	await tap(KEY_TAB);await wait(.15)
	main._show_reception("basic");await ready_main()
	check(phone.character_presentation==null and not paused,"Scene transition aborts an opening phone without stale pose or global pause")
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"Actual Camera captured minimized without focus")
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records,"gpu":RenderingServer.get_video_adapter_name(),"scope":"Actual Main, Tab open/loop/close in lobby and formal floor; normal-time recording; isolated GPU head-mask comparison"},"\t"));file.close()
	print("PLAYER_PHONE_CAMERA checks=",checks," failures=",failures.size())
	main.free();quit(0 if failures.is_empty() else 1)
