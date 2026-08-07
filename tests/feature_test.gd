extends SceneTree
const CONFIG:=preload("res://resources/demo_config.tres")
const BEDROOM:=preload("res://scenes/bedroom/bedroom.tscn")
const DREAM:=preload("res://scenes/dream/dream_world.tscn")
const MELATONIN:=preload("res://scenes/ui/melatonin_interaction.tscn")
const STAPLE:=preload("res://scenes/entities/staple_projectile.tscn")
var failures:Array[String]=[]
func _initialize()->void:
	# Standalone SceneTree tests do not load project input actions early enough for
	# instantiated gameplay scenes, so register the action names used by the Demo.
	for action in ["move_left", "move_right", "move_up", "move_down", "interact", "confirm", "restart_demo", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	call_deferred("_run")
func _run()->void:
	_test_attendance_and_economy()
	await _test_purchase_and_melatonin()
	await _test_bedroom_forced_sleep()
	await _test_damage_and_death_delay()
	await _test_enemy_archetypes()
	if failures.is_empty(): print("FEATURE TEST PASSED: attendance -> economy -> purchase -> melatonin -> forced sleep -> invulnerability -> death delay -> special enemies"); quit(0)
	else:
		for f in failures: push_error(f)
		quit(1)
func _test_attendance_and_economy()->void:
	_assert(RunSettlement.attendance_for_minutes(449)=="正常上班","07:29 must be on time")
	_assert(RunSettlement.attendance_for_minutes(450)=="轻微迟到","07:30 boundary failed")
	_assert(RunSettlement.attendance_for_minutes(480)=="严重迟到","08:00 boundary failed")
	_assert(RunSettlement.attendance_for_minutes(540)=="旷工","09:00 boundary failed")
	var meta={"balance":1325,"ram":0,"unemployed":false}; var summary={"wake_minutes":485.0,"total_experience":1268,"level":5}
	var result:=RunSettlement.settle(summary,meta,CONFIG)
	_assert(result.run_ram==4 and meta.ram==4,"RAM must equal final level minus one")
	_assert(result.wage==150 and meta.balance==1475,"Severe-late wage settlement failed")
	RunSettlement.settle(result,meta,CONFIG); _assert(meta.balance==1475 and meta.ram==4,"Settlement was applied twice")
	_assert(RunSettlement.format_time(1505)=="01:05","Time did not wrap past 24:00")
func _test_purchase_and_melatonin()->void:
	var bedroom=BEDROOM.instantiate(); bedroom.persistent_state={"balance":1325,"ram":0,"melatonin_inventory":0,"melatonin_bottle_present":false,"melatonin_ever_purchased":false}
	root.add_child(bedroom); await process_frame
	bedroom.phone._purchase_melatonin(); _assert(bedroom.persistent_state.balance==1225 and bedroom.persistent_state.melatonin_inventory==1,"QuickLink purchase failed")
	_assert(bedroom.persistent_state.melatonin_bottle_present,"First purchase did not create bottle state")
	var interaction=MELATONIN.instantiate(); var c:DemoConfig=CONFIG.duplicate(true); c.melatonin_shake_segment_min_distance=4; c.melatonin_required_shakes=2; c.melatonin_required_reversals=2; c.melatonin_required_shake_distance=20; interaction.config=c; root.add_child(interaction); interaction.open(bedroom.persistent_state)
	for x in [8.0,-8.0,8.0]: var e:=InputEventMouseMotion.new(); e.relative=Vector2(x,0); interaction._gui_input(e)
	_assert(bedroom.persistent_state.melatonin_inventory==1,"Moving without holding deducted inventory")
	var press:=InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=interaction.BOTTLE_HOME; interaction._gui_input(press)
	for x in [8.0,-8.0,8.0]: var e:=InputEventMouseMotion.new(); e.relative=Vector2(x,0); interaction._gui_input(e)
	await create_timer(0.9).timeout; _assert(bedroom.persistent_state.melatonin_inventory==1,"Inventory was deducted before the consume animation completed")
	await create_timer(0.9).timeout; _assert(bedroom.persistent_state.melatonin_inventory==0,"Completed consume animation did not deduct exactly one tablet")
	interaction.queue_free(); bedroom.queue_free(); await process_frame
func _test_bedroom_forced_sleep()->void:
	var bedroom=BEDROOM.instantiate(); var c:DemoConfig=CONFIG.duplicate(true); c.bedroom_start_minutes=1439.0; c.bedroom_force_sleep_minutes=1440.0; c.bedroom_real_seconds_per_game_minute=0.01; bedroom.config=c; bedroom.persistent_state={"balance":1325,"melatonin_inventory":0,"melatonin_bottle_present":false,"food_eaten_today":false,"stress_value":100}
	var state={"slept":false}; bedroom.sleep_requested.connect(func(_used:int,_hungry:bool):state.slept=true); root.add_child(bedroom); await create_timer(0.08).timeout
	_assert(state.slept,"00:00 did not force sleep"); bedroom.queue_free(); await process_frame
func _test_damage_and_death_delay()->void:
	var dream=DREAM.instantiate(); var c:DemoConfig=CONFIG.duplicate(true); c.death_wake_delay_min_minutes=45; c.death_wake_delay_max_minutes=45; c.base_enemy_damage=0; dream.config=c; dream.get_node("DreamClock").config=c; dream.get_node("EnemySpawner").config=c; dream.get_node("UILayer/WakeOverlay").config=c; root.add_child(dream); await process_frame; dream.spawner.running=false
	var hp:float=dream.player.current_health; dream.player.receive_damage(10); dream.player.receive_damage(10); _assert(dream.player.current_health==hp-10,"Hurt invulnerability did not block repeated damage")
	dream.clock.current_minutes=440; var summary:Dictionary=dream._build_summary("梦中倒下"); _assert(summary.wake_minutes==485 and summary.wake_time=="08:05","Death wake delay did not use configured integer minutes")
	dream.queue_free(); await process_frame
func _test_enemy_archetypes()->void:
	var dream=DREAM.instantiate(); var c:DemoConfig=CONFIG.duplicate(true); c.base_enemy_health=999; c.base_enemy_damage=0; c.correction_charge_seconds=0.05; c.stapler_fire_interval=0.05
	dream.config=c; dream.get_node("DreamClock").config=c; dream.get_node("EnemySpawner").config=c; dream.get_node("UILayer/WakeOverlay").config=c; root.add_child(dream); await process_frame; dream.spawner.running=false
	dream._on_spawn_requested(dream.player.position+Vector2(180,0),1.0,0.0,"basic")
	dream._on_spawn_requested(dream.player.position+Vector2(40,0),1.0,0.0,"correction")
	dream._on_spawn_requested(dream.player.position+Vector2(180,40),1.0,0.0,"stapler")
	await create_timer(0.03).timeout
	var correction=dream.enemy_container.get_node_or_null("CorrectionTapeEnemy"); var stapler=dream.enemy_container.get_node_or_null("StaplerEnemy")
	_assert(correction!=null and correction.state==correction.State.CHARGING,"Correction tape did not enter its locked charge state")
	await create_timer(0.08).timeout; _assert(stapler!=null and dream.projectile_container.get_child_count()>0,"Stapler did not fire on its configured interval")
	var staple=STAPLE.instantiate(); staple.setup(Vector2.RIGHT,0,100,10,2,null); root.add_child(staple); await create_timer(0.15).timeout; _assert(not is_instance_valid(staple),"Staple did not despawn at maximum range")
	dream.queue_free(); await process_frame
func _assert(condition:bool,message:String)->void:
	if not condition: failures.append(message)
