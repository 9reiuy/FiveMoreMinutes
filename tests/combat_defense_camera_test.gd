extends SceneTree
var main: Node
var world: Node
var failures:=0
var checks:=0
var output: String
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(count: int) -> void:
	for i in count: await process_frame
func ready_main() -> void:
	var deadline:=Time.get_ticks_msec()+90000
	while main.transition_running and Time.get_ticks_msec()<deadline: await process_frame
	await frames(20)
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func click(down: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=root.get_visible_rect().size*.5+Vector2(120,0)
	event.pressed=down
	Input.parse_input_event(event)
func run() -> void:
	create_timer(160,true,false,true).timeout.connect(func() -> void: quit(2))
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"): quit(2); return
	AudioServer.set_bus_mute(0,true)
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size=Vector2i(1280,720)
	Engine.max_fps=60
	var pixel:=not "--native" in OS.get_cmdline_user_args()
	output="res://.runtime/combat_defense_20261022/"+("pixel_palette" if pixel else "native_original")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.get_node("SettingsManager").set_palette_enabled(pixel)
	root.get_node("SettingsManager").set_setting(&"pixelation_enabled",pixel)
	main=load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await ready_main()
	main.persistent_day_state=main._create_initial_state()
	main.persistent_day_state.tutorial_completed=true
	seed(120)
	main._show_dream("lucille")
	await ready_main()
	world=main._supported_dream_world
	var deadline:=Time.get_ticks_msec()+90000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
	for enemy in world.enemy_root.get_children(): enemy.set_physics_process(false); enemy.set_process(false)
	var found:=false
	for room in world.rooms:
		if String(room.get("archetype",""))!="open_office": continue
		for cell in room.get("usable_cells",[]):
			var point:=Vector2(cell)*32.0
			if world._content_position_is_clear(point,85):
				world.player.global_position=point
				world.activate_room(int(room.id))
				found=true
				break
		if found: break
	check(found,"Formal generated office contains testable combat area")
	for actor in world.enemy_root.get_children(): actor.process_mode=Node.PROCESS_MODE_DISABLED
	var player: Node=world.player
	player.current_health=100000
	player.maximum_health=100000
	player.invulnerability_left=0
	player.equip_weapon("lucille",world.config,{})
	var origin: Vector2=player.global_position
	var aim:=Vector2.RIGHT
	player.set_meta(&"presentation_pointer_position",func() -> Vector2: return world.camera_3d.unproject_position(world.get_gameplay_world_position(origin+aim*300,0)))
	var enemy: Node=world._spawn_regular_employee(world.current_room_id,origin+aim*160,&"employee",false,"assault_rifle")
	enemy.set_physics_process(false); enemy.set_process(false)
	enemy.process_mode=Node.PROCESS_MODE_DISABLED
	enemy.target=player
	enemy.can_see_target=true
	enemy.hostile=true
	enemy.has_last_known_target_position=true
	enemy.last_known_target_position=origin
	enemy.state=EmployeeEnemy.State.ATTACK_PLAYER
	await frames(30)
	enemy.attack_cooldown_left=0
	enemy.reload_left=0
	enemy.pickup_pause_left=0
	enemy._update_weapon_aim()
	enemy._begin_ranged_attack_windup()
	check(enemy.ranged_attack_windup_pending,"Formal enemy starts visible windup before firing")
	check(not world.floor_root.get_node("EnemyAimTelegraph").aim_segment(enemy).is_empty(),"Visible enemy contributes a red threat line")
	await frames(2)
	await shot("01_aim_start")
	enemy._update_ranged_attack_windup(.39)
	await frames(2)
	await shot("02_aim_locked")
	enemy._update_ranged_attack_windup(.12)
	enemy.process_mode=Node.PROCESS_MODE_INHERIT
	enemy.set_process(true)
	enemy.set_physics_process(true)
	var live_presenter: Node=world.floor_root.get_node("EnemyAimTelegraph")
	var live_serial: int=enemy.ranged_attack_shot_serial
	var live_samples:=0
	var duplicate_samples:=0
	var repeated_aim_samples:=0
	for frame in 60:
		await process_frame
		var per_enemy: Array=live_presenter.prepared_lines.filter(func(line: Dictionary) -> bool: return line.id==enemy.get_instance_id())
		if per_enemy.size()==1: live_samples+=1
		if per_enemy.size()>1: duplicate_samples+=1
		if enemy.ranged_attack_magazine_primed and per_enemy.size()>0: repeated_aim_samples+=1
		if frame%2==0: await shot("aim_%03d" % (frame/2))
	check(enemy.ranged_attack_shot_serial>live_serial and repeated_aim_samples==0,"Live automatic enemy repeats shots without repeating windup inside magazine")
	check(duplicate_samples==0,"Live camera never draws two lines for the same enemy")
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.process_mode=Node.PROCESS_MODE_DISABLED
	enemy._cancel_ranged_attack_windup()
	for projectile in get_nodes_in_group(&"active_basic_projectiles"): projectile.queue_free()
	await frames(2)
	var defense: Node=world.get_combat_defense()
	var weapon: Node=player.lucille_weapon
	enemy.global_position=origin+Vector2(55,25)
	await frames(4)
	await shot("outline_near_white")
	enemy.global_position=origin+Vector2(-100,0)
	await frames(4)
	await shot("outline_far_gray")
	click(true)
	var sent:=false
	var parried:=false
	var input_armed:=false
	var chain_clicked:=false
	var chain_sent:=false
	for frame in 65:
		await process_frame
		input_armed=input_armed or (weapon.melee_action_active and weapon.parry_armed)
		if not sent and weapon.melee_action_active and weapon.swing_elapsed>=weapon.windup_seconds:
			var bullet: Node=load("res://scenes/entities/basic_projectile.tscn").instantiate()
			bullet.position=origin+aim*100
			bullet.setup(-aim,10,1000,1500,&"enemy",enemy,&"basic")
			world.add_projectile(bullet,enemy)
			bullet._initial_spawn_verified=true
			sent=true
		parried=parried or defense.hit_feedback_count>0
		if frame==8: click(false)
		if frame>=10 and parried and not chain_clicked:
			click(true)
			chain_clicked=true
		if chain_clicked and not chain_sent and weapon.melee_action_active and weapon.parry_armed and not weapon.parry_feedback_sent and weapon.swing_elapsed>=weapon.windup_seconds:
			var followup: Node=load("res://scenes/entities/basic_projectile.tscn").instantiate()
			followup.position=origin+aim*100
			followup.setup(-aim,10,1000,1500,&"enemy",enemy,&"basic")
			world.add_projectile(followup,enemy)
			followup._initial_spawn_verified=true
			chain_sent=true
		if frame==18: click(false)
		if frame<48 and frame%2==0: await shot("action_%03d" % (frame/2))
	check(input_armed,"Real left press arms a melee parry")
	check(parried,"Real swept enemy bullet is parried by live swing")
	check(defense.hit_feedback_count>=2,"Fresh real click chains another successful parry during bullet time")
	check(not world.player.dead,"Live reflection leaves player alive")
	var breaker: Node=world.key_root.get_node_or_null("FloorPowerSwitch")
	check(breaker!=null,"Formal entry includes utility breaker")
	if breaker!=null:
		player.global_position=breaker.global_position+Vector2(breaker.get_meta(&"wall_inward"))*20
		await frames(30)
		await shot("03_power_on")
		var event:=InputEventKey.new()
		event.physical_keycode=KEY_E; event.keycode=KEY_E; event.pressed=true
		Input.parse_input_event(event)
		await frames(3)
		event=event.duplicate(); event.pressed=false; Input.parse_input_event(event)
		check(not breaker.powered,"Real E input toggles floor supply")
		await shot("04_power_off")
	print("COMBAT_CAMERA checks=",checks," failures=",failures," pixel=",pixel," gpu=",RenderingServer.get_video_adapter_name())
	main.free()
	await frames(5)
	quit(1 if failures else 0)
