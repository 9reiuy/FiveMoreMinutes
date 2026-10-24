extends SceneTree
var checks:=0
var failures:=0
var world: Node
var controller: Node
var defense: Node
var shooter: Node
var origin:=Vector2(12000,12000)
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(count: int) -> void:
	for i in count: await process_frame
func bullet(at: Vector2,heading: Vector2=Vector2.LEFT) -> Node:
	var projectile: Node=load("res://scenes/entities/basic_projectile.tscn").instantiate()
	projectile.global_position=at
	var source: Node=shooter if is_instance_valid(shooter) else null
	projectile.setup(heading,10.0,1000.0,1500.0,&"enemy",source,&"basic")
	world.add_projectile(projectile,source)
	projectile._initial_spawn_verified=true
	projectile.set_physics_process(false)
	return projectile
func ready_swing() -> Node:
	world.player.equip_weapon("lucille",load("res://resources/demo_config.tres"),{})
	var weapon: Node=world.player.lucille_weapon
	weapon.set_process(false)
	weapon.set_physics_process(false)
	weapon.melee_action_active=true
	weapon.swing_elapsed=weapon.windup_seconds+.02
	weapon.swing_direction=Vector2.RIGHT
	weapon.parry_armed=true
	weapon.parry_feedback_sent=false
	return weapon
func run() -> void:
	create_timer(60).timeout.connect(func() -> void: quit(2))
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false
	world.spawn_content=false
	world.persist_profile=false
	world.enable_game_start_cab_exit=false
	root.add_child(world)
	check(world.regenerate(42001),"Formal floor generates with combat and power services")
	await frames(3)
	world.set_process(false)
	world.player.set_physics_process(false)
	defense=world.get_combat_defense()
	controller=world.player._get_dream_time_controller()
	check(controller!=null and controller.mode_enabled,"Single time authority bound to formal player")
	var breaker: Node=world.key_root.get_node_or_null("FloorPowerSwitch")
	check(breaker!=null,"One utility-room power switch is generated")
	if breaker==null: world.free(); quit(1); return
	var fixed_lights: Array=world.ceiling_light_root.find_children("*","Light3D",true,false)
	check(not fixed_lights.is_empty(),"Formal indoor fixed lights exist")
	var flashlight: Node=world.night_lighting.get("flashlight")
	var old_flash: float=flashlight.light_energy if flashlight!=null else 0.0
	breaker.interact()
	var all_off:=true
	for light in fixed_lights: all_off=all_off and light.light_energy==0
	check(not breaker.powered and all_off,"E interaction cuts all indoor light energy")
	check(flashlight==null or flashlight.light_energy==old_flash,"Power switch preserves carried flashlight")
	check(breaker.get_interaction_prompt_state().text=="送电","Off switch offers short restore prompt")
	breaker.interact()
	check(breaker.powered,"Undamaged switch restores supply")
	breaker.take_damage(1)
	breaker.interact()
	check(breaker.broken and not breaker.powered and not breaker.is_interaction_available(world.player),"Bullet damage permanently prevents restore on this floor")
	for x in range(370,385):
		for y in range(370,385): world.floor_cells[Vector2i(x,y)]=true
	world.player.global_position=origin
	world.player.set_meta(&"presentation_pointer_position",func() -> Vector2: return world.camera_3d.unproject_position(world.get_gameplay_world_position(origin+Vector2(200,0),0)))
	shooter=world._spawn_regular_employee(world.current_room_id,origin+Vector2(220,0),&"employee",false,"luger")
	shooter.set_process(false)
	shooter.set_physics_process(false)
	shooter.equip_weapon("assault_rifle")
	shooter.target=world.player
	shooter.can_see_target=true
	shooter.hostile=true
	shooter.has_last_known_target_position=true
	shooter.last_known_target_position=origin
	shooter.state=EmployeeEnemy.State.ATTACK_PLAYER
	shooter.attack_cooldown_left=0
	shooter.reload_left=0
	shooter.pickup_pause_left=0
	var shot_count: int=get_nodes_in_group(&"active_basic_projectiles").size()
	var cues: Array=[]
	root.get_node("SFXManager").sfx_played.connect(func(event: StringName) -> void:
		if event==&"enemy_fire_cue": cues.append(event))
	shooter._begin_ranged_attack_windup()
	check(shooter.ranged_attack_windup_pending and is_equal_approx(shooter.ranged_attack_windup_left,.5),"Formal enemy earns a half-second initial aiming windup")
	check(get_nodes_in_group(&"active_basic_projectiles").size()==shot_count,"Beginning windup never fires early")
	shooter._update_ranged_attack_windup(.39)
	var locked: Vector2=shooter.ranged_attack_target_snapshot
	shooter.last_known_target_position=origin+Vector2(0,80)
	shooter._update_ranged_attack_windup(.03)
	check(shooter.ranged_attack_target_snapshot==locked,"Final 0.12 seconds lock the aim instead of tracking dodge")
	var telegraph: Node=world.floor_root.get_node("EnemyAimTelegraph")
	check(not telegraph.aim_segment(shooter).is_empty(),"Aiming enemy supplies clear HUD line independently of palette")
	shooter._update_ranged_attack_windup(.1)
	check(not shooter.ranged_attack_windup_pending and shooter.ranged_attack_session_active and shooter.ranged_attack_session_weapon_id=="assault_rifle","Automatic firearm preserves session after first windup")
	var interval: float=shooter.attack_cooldown_left
	var next_line: Dictionary=telegraph.aim_segment(shooter)
	check(next_line.is_empty() and shooter.ranged_attack_magazine_primed,"Automatic fire has no repeated windup line inside one magazine")
	shooter.attack_cooldown_left=interval*.2
	var pale: Dictionary=telegraph.line_style(0)
	var dark: Dictionary=telegraph.line_style(.8)
	check(dark.width>pale.width and dark.color.a>pale.color.a and dark.color.g<pale.color.g,"Aiming line progressively thickens, darkens and becomes opaque")
	shooter.attack_cooldown_left=0
	shooter.reaction_left=0
	var serial: int=shooter.ranged_attack_shot_serial
	shooter._update_attack_player(.001)
	var base_interval: float=preload("res://scripts/dream/dream_firearm_rules.gd").parameters(world.config,&"assault_rifle").interval/maxf(float(world.config.weapon_fire_rate_multiplier),.001)
	var jitter: float=shooter._cfg("employee_attack_cadence_jitter_ratio",.12)
	check(shooter.ranged_attack_shot_serial==serial+1 and not shooter.ranged_attack_windup_pending and shooter.attack_cooldown_left>=base_interval*(1-jitter) and shooter.attack_cooldown_left<=base_interval*(1+jitter),"Repeat automatic shot keeps original cadence and jitter without an extra windup")
	check(cues.size()==1,"Automatic magazine announces only the completed initial windup")
	var ding: AudioStreamPlayer=root.get_node("SFXManager").players[&"enemy_fire_cue"]
	check(ding.stream is AudioStreamWAV and ding.stream.get_length()<.1 and ding.bus==&"SFX" and ding.max_polyphony==4,"Short clean bell is bounded and unaffected by slow-time pitch")
	ding.stream.save_to_wav("res://.runtime/enemy_fire_cue.wav")
	shooter._cancel_ranged_attack_windup()
	shooter.attack_cooldown_left=0
	serial=shooter.ranged_attack_shot_serial
	shooter._update_attack_player(.001)
	check(shooter.ranged_attack_shot_serial==serial+1 and not shooter.ranged_attack_windup_pending,"Brief attack-session interruption does not re-prime the same magazine")
	shooter.current_ammo=1
	shooter.attack_cooldown_left=0
	shooter._update_attack_player(.001)
	check(shooter.reload_left>0 and not shooter.ranged_attack_magazine_primed and telegraph.aim_segment(shooter).is_empty(),"Empty magazine clears readiness and hides aim during reload")
	shooter._update_reload(100)
	shooter.attack_cooldown_left=0
	serial=shooter.ranged_attack_shot_serial
	shooter._update_attack_player(.001)
	check(shooter.ranged_attack_windup_pending and shooter.ranged_attack_shot_serial==serial and is_equal_approx(shooter.ranged_attack_windup_left,.5),"Reloaded magazine earns exactly one new windup before firing")
	telegraph._process(1.0/60.0)
	var owned_lines: Array=telegraph.prepared_lines.filter(func(line: Dictionary) -> bool: return line.id==shooter.get_instance_id())
	check(owned_lines.size()==1,"Presenter publishes exactly one line for one enemy")
	var obstacle:=StaticBody2D.new()
	obstacle.collision_layer=8
	var obstacle_shape:=CollisionShape2D.new()
	var obstacle_box:=RectangleShape2D.new()
	obstacle_box.size=Vector2(4,4)
	obstacle_shape.shape=obstacle_box
	obstacle.add_child(obstacle_shape)
	world.collision_root.add_child(obstacle)
	var nominal: Vector2=shooter.projectile_origin.global_position
	obstacle.global_position=(nominal+shooter.global_position)*.5
	await physics_frame
	check(shooter.get_projectile_origin().distance_to(nominal)>.1,"Nearby collider actually clamps gameplay muzzle in regression fixture")
	check(telegraph.aim_segment(shooter).start==shooter.projectile_origin.global_position,"Furniture-clamped gameplay muzzle cannot shift visual red-line origin")
	obstacle.free()
	shooter.current_ammo=1
	var committed: Vector2=shooter.ranged_attack_target_snapshot
	shooter._update_ranged_attack_windup(.6)
	var final_round: Node=get_nodes_in_group(&"active_basic_projectiles")[-1]
	check(Vector2(final_round.direction).dot(shooter.global_position.direction_to(committed))>.9,"Last-round reload cleanup cannot erase the committed shot target")
	shooter._cancel_ranged_attack_windup()
	check(telegraph.aim_segment(shooter).is_empty(),"Cancellation removes enemy aiming line immediately")
	shooter.equip_weapon("shotgun")
	shooter.attack_cooldown_left=0
	var before_pellets: int=cues.size()
	shooter._begin_ranged_attack_windup()
	shooter._update_ranged_attack_windup(.6)
	check(cues.size()==before_pellets+1,"Shotgun plays one cue per shot, never one per pellet")
	shooter.equip_weapon("assault_rifle")
	for shot in get_nodes_in_group(&"active_basic_projectiles"): shot.queue_free()
	await physics_frame
	await frames(2)
	var weapon:=ready_swing()
	var incoming:=bullet(origin+Vector2(60,0))
	var health: float=world.player.current_health
	check(defense.inspect_segment(incoming,origin+Vector2(60,0),origin-Vector2(30,0)),"Fresh frontal melee swing reflects swept bullet")
	check(incoming.source_faction==&"player" and incoming.shooter_instance_id==world.player.get_instance_id(),"Reflection changes faction and ownership")
	check(incoming.damage==10 and incoming.speed==1500,"Reflection preserves bullet damage and speed")
	check(incoming.direction.x>.95 and incoming.global_position.x>origin.x,"Reflected bullet starts at actual interception and follows mouse")
	check(world.player.current_health==health and controller.is_reaction_time_active(),"Successful parry avoids damage and starts reaction time")
	var feedback_before: int=defense.hit_feedback_count
	var second:=bullet(origin+Vector2(55,1))
	check(defense.inspect_segment(second,second.global_position,origin-Vector2(20,0)),"One swing can reflect another pellet")
	check(defense.hit_feedback_count==feedback_before,"Pellets do not stack feedback or refresh separately")
	var executed_target: Node=world._spawn_regular_employee(world.current_room_id,origin+Vector2(240,80),&"employee",false,"luger")
	executed_target.set_physics_process(false)
	executed_target.current_health=1000000
	incoming._handle_collision(executed_target)
	check(executed_target.dead,"Reflected hit executes the enemy actually struck regardless of health")
	defense.register_click()
	check(not weapon.melee_action_active and weapon.cooldown_left==0,"New click after success cancels recovery for chained parry")
	check(defense.claim_click() and not defense.claim_click(),"One click arms only one swing")
	weapon=ready_swing()
	var behind:=bullet(origin-Vector2(40,0),Vector2.RIGHT)
	check(not defense.inspect_segment(behind,behind.global_position,origin+Vector2(30,0)) and behind.source_faction==&"enemy","Rear bullet cannot be parried through player's body")
	weapon.parry_armed=false
	var held:=bullet(origin+Vector2(40,0))
	check(not defense.inspect_segment(held,held.global_position,origin-Vector2(30,0)),"Held-button ordinary swing does not provide continuous parry")
	weapon=ready_swing()
	var wall:=StaticBody2D.new()
	wall.collision_layer=1
	var wall_shape:=CollisionShape2D.new()
	var rectangle:=RectangleShape2D.new()
	rectangle.size=Vector2(8,100)
	wall_shape.shape=rectangle
	wall.add_child(wall_shape)
	world.collision_root.add_child(wall)
	wall.global_position=origin+Vector2(100,0)
	await physics_frame
	var occluded:=bullet(origin+Vector2(150,0))
	check(not defense.inspect_segment(occluded,occluded.global_position,origin+Vector2(50,0)),"Solid wall before parry contact prevents through-wall reflection")
	shooter.attack_cooldown_left=0
	shooter._begin_ranged_attack_windup()
	check(shooter.ranged_attack_windup_pending,"Wall-occlusion probe owns a real pending windup")
	check(telegraph.aim_segment(shooter).is_empty(),"Solid wall hides enemy telegraph rather than revealing position")
	shooter._cancel_ranged_attack_windup()
	wall.free()
	weapon.parry_armed=false
	controller.clear_reaction_time()
	var near:=bullet(origin+Vector2(25,-38))
	check(not defense.inspect_segment(near,near.global_position,origin+Vector2(-25,-38)) and controller.is_reaction_time_active(),"Actual hurt-capsule near pass triggers dodge time")
	var remaining: float=controller.reaction_remaining_real
	defense.inspect_segment(near,origin+Vector2(25,-38),origin+Vector2(-25,-38))
	check(controller.reaction_remaining_real==remaining,"Same bullet cannot repeatedly trigger near miss")
	check(not controller.begin_reaction_time(&"near_miss"),"Near miss cooldown prevents a rapid second trigger")
	controller.reaction_remaining_real=.1
	check(controller.begin_reaction_time(&"parry") and is_equal_approx(controller.reaction_remaining_real,.6),"A successful parry refreshes duration rather than stacking it")
	controller.clear_reaction_time()
	var distant:=bullet(origin+Vector2(25,45))
	defense.inspect_segment(distant,distant.global_position,origin+Vector2(-25,45))
	check(not controller.is_reaction_time_active(),"Distant passing bullet does not trigger slow time")
	controller.begin_reaction_time()
	controller.set_pause_authority(true)
	var pause_left: float=controller.reaction_remaining_real
	controller._update_real_timers(.2)
	check(controller.reaction_remaining_real==pause_left,"Pause does not spend reaction duration")
	controller.set_pause_authority(false)
	controller._process(0.0)
	check(is_equal_approx(world.player.combat_action_delta(.002),.01),"Player actions compensate world slowdown")
	controller.set_lifecycle_enabled(false)
	check(controller.reaction_remaining_real==0 and Engine.time_scale==1,"Lifecycle lock clears reaction scale")
	controller.set_lifecycle_enabled(true)
	var index: int=world.floor_index
	world._stash_current_floor_for_rollback()
	check(not telegraph.visible and not defense.can_process(),"Transition stash hides CanvasLayer lines and stops defense input")
	world._rollback_failed_transition(world.transition_generation_token,index)
	check(breaker.broken and not breaker.powered,"Failed floor transition restores broken breaker state")
	var old_power: WeakRef=weakref(breaker)
	check(world.regenerate(42002),"Next floor generates")
	await frames(2)
	check(old_power.get_ref()==null and world.key_root.get_node("FloorPowerSwitch").powered,"New floor resets breaker without old-floor nodes")
	for layout_seed in [42003,42004,42005,42006]:
		check(world.regenerate(layout_seed),"Additional deterministic floor generates")
		await frames(2)
		check(get_nodes_in_group(&"enemy_threat_huds").size()==1,"Regeneration leaves one HUD, no old-floor duplicate canvas")
		var switches: Array=world.key_root.get_children().filter(func(n: Node) -> bool: return n.is_in_group(&"floor_power_switches"))
		check(switches.size()==1 and switches[0].powered,"Exactly one powered breaker on each random floor")
		if switches.is_empty(): continue
		var test_shot:=bullet(world.player.global_position+Vector2(120,0))
		test_shot._handle_collision(switches[0])
		check(switches[0].broken and not switches[0].powered,"Actual projectile collision permanently cuts supply")
	world.free()
	await frames(3)
	print("COMBAT_DEFENSE_POWER checks=",checks," failures=",failures)
	quit(1 if failures else 0)
