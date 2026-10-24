extends SceneTree
var world: Node
var checks:=0
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(n: int=2) -> void:
	for i in n: await process_frame
func enemy_at(offset: Vector2=Vector2(35,0)) -> Node:
	var enemy: Node=world._spawn_regular_employee(world.current_room_id,world.player.global_position+offset,&"employee",false,"luger")
	enemy.maximum_health=1000; enemy.current_health=1000
	enemy.set_physics_process(false); enemy.set_process(false)
	return enemy
func run() -> void:
	create_timer(100,true,false,true).timeout.connect(func() -> void: quit(2))
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	root.add_child(world); check(world.regenerate(42001),"Formal floor generates")
	world.player.set_physics_process(false); world.player.critical_chance=0; world.player.run_damage_multiplier=1
	await frames()
	var fx: Node=world.floor_root.get_node("EnemyCombatText"); fx.set_process(false)
	var enemy:=enemy_at(); var id:=enemy.get_instance_id()
	var result: Dictionary=world.resolve_player_hit(enemy,10,world.player.global_position)
	check(result.damage==10 and enemy.current_health==990,"Display leaves real damage unchanged")
	check(fx.records.size()==1 and fx.records[id].text=="10","First player hit starts one damage number")
	var small: float=fx.records[id].scale
	fx._process(.4); world.resolve_player_hit(enemy,20,world.player.global_position,&"books")
	check(fx.records.size()==1 and fx.records[id].text=="30" and fx.records[id].age==0,"Same target accumulates and restarts pop/hold")
	check(fx.records[id].scale>small and fx.records[id].scale<=1,"More damage increases size under approved cap")
	var anchor: Vector3=fx.records[id].origin
	enemy.global_position+=Vector2(30,0); world.player.global_position+=Vector2(5,0)
	check(fx.records[id].origin==anchor,"Fixed impact text does not follow moving actors")
	fx._process(.59); check(fx.records.has(id),"Number survives until hold completes")
	fx._process(.25); check(fx.records.has(id),"Number fades after hold rather than disappearing immediately")
	fx._process(.02); check(not fx.records.has(id) and not fx.layer.visible,"Number retires after last-hit hold and fade")
	world.player.critical_chance=1; world.player.critical_damage_multiplier=2
	world.resolve_player_hit(enemy,10,world.player.global_position)
	check(fx.records[id].critical and fx.records[id].total==20,"Critical damage is still counted numerically")
	check(fx.critical_surfaces[id].material.shader==fx.CRITICAL_FILL,"Critical word uses isolated white-to-red halftone fill")
	fx._process(.2); world.player.critical_chance=0; world.resolve_player_hit(enemy,1,world.player.global_position)
	check(fx.records[id].text=="21" and fx.records[id].critical and fx.records[id].crit_age>0,"Ordinary followup preserves but does not endlessly retrigger critical word")
	var other:=enemy_at(Vector2(0,40)); world.resolve_player_hit(other,3,world.player.global_position)
	check(fx.records.size()==2 and fx.records[other.get_instance_id()].text=="3","Different enemies never share a sum")
	var count: int=fx.records.size()
	world.resolve_enemy_projectile_hit(other,2,world.player.global_position)
	check(fx.records.size()==count and fx.records[other.get_instance_id()].total==3,"Enemy friendly fire never emits player damage text")
	world.resolve_player_hit(enemy,0,world.player.global_position)
	# Existing calculate_player_damage clamps zero input to one: verify real loss, not a new rule.
	check(enemy.current_health==948 and fx.records[id].total==22,"Existing minimum-one damage policy remains authoritative")
	var blocked:=enemy_at(Vector2(-35,0)); blocked.room_runtime_active=false
	# Queued/dead targets are rejected by the original world entrypoint.
	blocked.dead=true; world.resolve_player_hit(blocked,20,world.player.global_position)
	check(not fx.records.has(blocked.get_instance_id()),"Dead target cannot show phantom damage")
	world.resolve_player_hit(enemy,2000,world.player.global_position)
	check(enemy.dead and fx.records[id].killed and fx.records[id].text in fx.KILL_WORDS,"Lethal hit replaces cumulative number with a kill phrase")
	check(fx.records[id].scale==1,"Kill phrase never exceeds existing word size")
	count=fx.records.size(); world.resolve_player_hit(enemy,1,world.player.global_position)
	check(fx.records.size()==count,"Repeated hit on corpse creates no extra praise")
	# Real reflected bullet bypasses normal crit math but still publishes its kill.
	var victim:=enemy_at(Vector2(0,-40)); var victim_id:=victim.get_instance_id()
	var bullet: Node=load("res://scenes/entities/basic_projectile.tscn").instantiate()
	world.world_effects_root.add_child(bullet); bullet.source_faction=&"player"; bullet.set_meta(&"reflected_by_parry",true)
	bullet._handle_collision(victim)
	check(victim.dead and fx.records.has(victim_id) and fx.records[victim_id].killed,"Reflected execution emits one praise through original death lifecycle")
	check(fx.damage_scale(1)<fx.damage_scale(50) and fx.damage_scale(1000000)==1,"All totals have bounded monotonic scaling")
	var robot: Node=load("res://scripts/entities/hotel_robot_unit.gd").new()
	world.enemy_root.add_child(robot); robot.global_position=world.player.global_position+Vector2(60,0)
	robot.configure(world,world.player,Rect2(robot.global_position-Vector2(100,100),Vector2(200,200)))
	robot.set_physics_process(false)
	world.resolve_player_hit(robot,7,world.player.global_position)
	check(fx.records[robot.get_instance_id()].total==7 and robot.hp==93,"Robot uses same accepted player damage text")
	var drone: Node=load("res://scripts/entities/exterior_patrol_drone_3d.gd").new()
	drone.world=world; drone.player=world.player; drone.hit_parent=world.enemy_root
	world.floor_root.add_child(drone)
	drone.set_physics_process(false)
	var proxy: Node=drone._proxy
	proxy.global_position=world.player.global_position+Vector2(-60,0)
	world.resolve_player_hit(proxy,6,world.player.global_position)
	check(fx.records[proxy.get_instance_id()].total==6 and drone.hp==94,"Drone proxy reads real 3D health, not a missing 2D health field")
	var isolated:=enemy_at(Vector2(0,60))
	seed(725); randf(); var expected_rng:=randi()
	seed(725); world.resolve_player_hit(isolated,1,world.player.global_position)
	check(randi()==expected_rng,"Nonlethal display consumes no extra gameplay RNG beyond original critical roll")
	fx.clear()
	var saved_snapshot: Dictionary=fx.capture(world,isolated)
	isolated.take_damage(1,world.player.global_position)
	seed(726); expected_rng=randi(); seed(726)
	fx.accept(saved_snapshot,isolated,{})
	check(randi()==expected_rng,"Visual accept uses only local RNG")
	for n in 55:
		fx.accept({"id":100000+n,"health":2.0,"origin":world.get_gameplay_world_position(world.player.global_position,.8)},null,{})
	check(fx.records.size()==fx.MAX_RECORDS,"Crowds and kills have a hard bounded text record budget")
	fx.clear()
	var kick_target:=enemy_at(Vector2(25,0)); var kick_id:=kick_target.get_instance_id()
	world.player.kick_direction=Vector2.RIGHT
	await physics_frame; await physics_frame
	world.player._apply_kick_hits()
	check(fx.records.has(kick_id) and fx.records[kick_id].total==world.player.runtime_config.kick_damage,"Kick observes its existing raw damage without routing through extra critical math")
	for text in fx.KILL_WORDS+["暴击"]:
		for glyph in text: check(fx.COMIC.FONT.get_font().has_char(glyph.unicode_at(0)),"Required combat glyph exists: "+glyph)
	# A target may vanish immediately after the accepted hit; no strong reference retained.
	other.free(); fx._process(.1)
	check(fx.records.size()>0,"Display survives freed enemies without casting them")
	paused=true; fx._process(.01)
	check(fx.records.is_empty() and fx.critical_surfaces.is_empty() and not fx.layer.visible,"Pause clears text and critical canvases")
	paused=false; world.resolve_player_hit(victim,1,world.player.global_position)
	other=enemy_at(); world.resolve_player_hit(other,1,world.player.global_position)
	var old: Node=fx; var old_floor: int=world.floor_index
	world.floor_transition_in_progress=true; world._stash_current_floor_for_rollback(); await frames()
	check(not old._active() and old.records.is_empty(),"Stashed floor cannot leave damage text active")
	world._reset_layout_data(); world._rollback_failed_transition(world.transition_generation_token,old_floor); await frames()
	world.floor_transition_in_progress=false
	check(world.floor_root.get_node("EnemyCombatText")==old,"Rollback restores same floor presenter without duplicate")
	check(world.regenerate(42002),"Second floor generates")
	await frames(); check(not is_instance_valid(old) and world.floor_root.get_node("EnemyCombatText").records.is_empty(),"Old floor text and canvases cannot leak into new floor")
	world.free(); await frames()
	print("ENEMY_COMBAT_TEXT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
