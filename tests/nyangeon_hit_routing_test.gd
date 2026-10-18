extends SceneTree
const FEEDBACK=preload("res://scripts/entities/combat_feedback_effect.gd")
var checks:=0
var failures:=0
func _initialize()->void: call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func feedback(world:Node)->Array:
	return world.world_effects_root.get_children().filter(func(node:Node)->bool: return node.get_script()==FEEDBACK)
func run()->void:
	AudioServer.set_bus_mute(0,true)
	var world:=preload("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	root.add_child(world); check(world.regenerate(42001),"Formal fixture generated")
	world.player.set_physics_process(false)
	var enemy:=preload("res://scenes/entities/employee_enemy.tscn").instantiate()
	world.enemy_root.add_child(enemy); enemy.global_position=world.player.global_position+Vector2(40,0)
	enemy.set_meta(&"dream_room_id",world.current_room_id); enemy.set_process(false); enemy.set_physics_process(false)
	enemy.current_health=100
	enemy.take_damage(1,enemy.global_position-Vector2(8,0),0,&"player_projectile_basic")
	var effects:=feedback(world)
	check(effects.size()==1 and effects[0].nyangeon_style and not effects[0].is_kill,"One accepted nonlethal firearm hit has one sample burst")
	enemy.take_damage(1,enemy.global_position-Vector2(8,0),0,&"player_projectile_basic")
	check(feedback(world).size()==1,"Same-frame pellets respect the existing feedback interval")
	enemy.take_damage(999,enemy.global_position-Vector2(8,0),0,&"player_projectile_basic")
	effects=feedback(world)
	check(enemy.dead and effects.size()==2 and effects.back().nyangeon_style and effects.back().is_kill,"Lethal early return produces exactly one stronger burst")
	var other:=preload("res://scenes/entities/employee_enemy.tscn").instantiate()
	world.enemy_root.add_child(other); other.global_position=world.player.global_position+Vector2(-40,0)
	other.set_meta(&"dream_room_id",world.current_room_id); other.set_process(false); other.set_physics_process(false)
	other.take_damage(1,other.global_position+Vector2(8,0),0,&"kick")
	check(not feedback(world).back().nyangeon_style,"Melee retains the approved original feedback even in a sample world")
	var smoke: Node=world.floor_root.get_node("FootstepSmoke")
	var reference: WeakRef=weakref(smoke)
	check(world.regenerate(42002),"Real regeneration succeeds with the sample installed")
	for i in 4: await process_frame
	check(reference.get_ref()==null,"Real floor regeneration releases the smoke manager and native sprites")
	world.free()
	print("NYANGEON_HIT_ROUTING checks=",checks," failures=",failures)
	quit(1 if failures else 0)
