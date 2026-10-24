extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false;world.persist_profile=false;world.spawn_content=false
	root.add_child(world);check(world.regenerate(42001),"Formal floor loads")
	world.player.set_physics_process(false)
	var smoke: Node=world.floor_root.get_node("FireExtinguisherSystem")
	smoke.set_physics_process(false)
	var player: Node=world.player
	var origin:=Vector2(12000,12000)
	player.global_position=origin+Vector2(110,0)
	var employee=load("res://scenes/entities/employee_enemy.tscn").instantiate()
	world.enemy_root.add_child(employee)
	employee.configure(player,100,10,Rect2(origin-Vector2(200,200),Vector2(500,500)),0,12)
	employee.set_physics_process(false);employee.set_process(false);employee.global_position=origin
	employee.equip_weapon("assault_rifle");employee.hostile=true
	employee._cached_dream_world=world
	var remembered:=origin+Vector2(80,0)
	employee._remember_target_position(remembered,0)
	var smoke_cell: Vector2i=world._cell_for_gameplay_position(player.global_position)
	smoke.cells[smoke_cell]=1.0
	for visual in [false,true]:
		employee.uses_visual_perception=visual
		employee.can_see_target=true;employee.ranged_attack_windup_pending=true
		employee.unarmed_attack_active=true;employee.perception_update_left=1.0
		employee._update_target_perception_clock(.016)
		check(not employee.can_see_target and not employee.ranged_attack_windup_pending,"Smoke interrupts direct and visual perception immediately")
		check(not employee.unarmed_attack_active,"Smoke interrupts a pending melee counterattack")
		check(employee.last_known_target_position==remembered,"Smoke does not refresh the player's live position")
		employee._remember_player_damage_awareness()
		check(employee.last_known_target_position==remembered,"Taking damage does not reveal concealed player transform")
	var before:=get_nodes_in_group(&"dream_projectiles").size()
	employee.can_see_target=true;employee._fire_held_weapon()
	check(get_nodes_in_group(&"dream_projectiles").size()==before,"A stale employee firing callback cannot shoot a hidden player")
	employee.configure_boss(true);employee.can_see_target=true
	employee._update_direct_target_awareness()
	check(not employee.can_see_target,"Boss direct awareness also respects smoke")
	smoke.cells.clear()
	employee._update_direct_target_awareness()
	check(employee.can_see_target,"Leaving smoke permits normal direct reacquisition")
	# A cloud between two clear endpoints must block vision too.
	smoke.cells[world._cell_for_gameplay_position(origin+Vector2(50,0))]=1.0
	check(not smoke.contains(origin) and not smoke.contains(player.global_position) and smoke.blocks_sight(origin,player.global_position),"Intermediate smoke blocks a ray with both endpoints outside")
	var employee_bridge: Node3D=world._spawn_depth_bridge(employee,[NodePath("CharacterVisual")])
	smoke.apply_coverage()
	check(employee.get_meta(&"smoke_hidden_from_player",false) and not employee_bridge.visible,"Real employee billboard is hidden from player behind intervening smoke")
	smoke.cells.clear();smoke.apply_coverage()
	check(employee_bridge.visible and not employee.get_meta(&"smoke_hidden_from_player",false),"Real employee billboard returns after the smoke corridor clears")
	smoke.cells[world._cell_for_gameplay_position(origin+Vector2(50,0))]=1.0
	var robot=load("res://scripts/entities/hotel_robot_unit.gd").new()
	world.enemy_root.add_child(robot);robot.global_position=origin
	robot.configure(world,player,Rect2(origin-Vector2(100,100),Vector2(400,400)))
	robot.set_physics_process(false);robot.alert=true;robot.deploy=1
	robot._aiming=true;robot._aim_elapsed=.4;robot._last_seen_position=origin
	robot._physics_process(.016)
	check(not robot._aiming and robot._aim_elapsed==0 and not robot._can_see_player(),"Delivery robot loses aim through smoke")
	before=get_nodes_in_group(&"dream_projectiles").size();robot._fire(Vector2.RIGHT)
	check(get_nodes_in_group(&"dream_projectiles").size()==before,"Delivery robot fire entrypoint cannot bypass gas")
	world._spawn_exterior_drones()
	check(world._exterior_drone_root.get_child_count()>0,"Actual exterior drone is available")
	if world._exterior_drone_root.get_child_count()>0:
		var drone: Node=world._exterior_drone_root.get_child(0)
		drone.set_physics_process(false)
		var local: Vector3=world.to_local(drone.global_position)
		player.global_position=Vector2(local.x,local.z)*32+drone.inward_normal*90
		smoke.cells.clear();smoke.cells[world._cell_for_gameplay_position(player.global_position)]=1.0
		drone._spot_elapsed=.3;drone._magazine_primed=true
		var aim: Vector2=drone._aim_target
		drone._update_detection(.2)
		check(drone._spot_elapsed<0 and drone.get_ranged_telegraph_state().is_empty(),"Drone cancels spotlight lock and red telegraph")
		check(drone._aim_target==aim,"Hidden player movement does not update drone aim")
		before=get_nodes_in_group(&"dream_projectiles").size();drone._fire()
		check(get_nodes_in_group(&"dream_projectiles").size()==before,"Drone automatic followup cannot shoot into hidden lock")
	# No projectile deletion is used to implement concealment.
	var bullet=load("res://scenes/entities/basic_projectile.tscn").instantiate()
	world.gameplay_world.add_child(bullet);bullet.set_physics_process(false)
	smoke.blocks_sight(origin,player.global_position)
	check(is_instance_valid(bullet) and not bullet.is_queued_for_deletion(),"Already-fired projectiles survive concealment")
	world.free();await process_frame
	print("SMOKE_VISIBILITY checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
