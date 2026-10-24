extends SceneTree
const RULES=preload("res://scripts/dream/dream_firearm_rules.gd")
const NAV=preload("res://scripts/dream/units/robot_navigation.gd")
var checks:=0
var failures:=0
var world: Node
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(n: int) -> void:
	for i in n: await process_frame
func shots() -> Array: return get_nodes_in_group(&"dream_projectiles")
func bullet(shooter: Node2D, point: Vector2) -> Node:
	var item: Node=load("res://scenes/entities/basic_projectile.tscn").instantiate()
	item.global_position=point; item.setup(Vector2.LEFT,1.0,1000.0,1500.0,&"enemy",shooter,&"basic")
	world.add_projectile(item,shooter); item.set_physics_process(false)
	return item
func run() -> void:
	create_timer(150,true,false,true).timeout.connect(func() -> void: quit(2))
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.enable_game_start_cab_exit=false; world.spawn_content=true
	root.add_child(world)
	var old_units: Array=[]
	for test_seed in [41001,42001,90210]:
		check(world.regenerate(test_seed),"Full formal floor generates %d" % test_seed)
		await frames(2)
		for old in old_units: check(not is_instance_valid(old),"Previous floor unit is freed")
		old_units.clear()
		var count: int=world._count_hotel_robots()
		check(count<=1,"At most one robot per floor")
		check(count==1,"Test seed has a valid indoor robot spawn")
		check(world._exterior_drone_root.get_child_count()<=2,"At most two drones per floor")
		for child in world.enemy_root.get_children():
			if child.get_meta(&"content_kind","")==&"hotel_robot":
				old_units.append(child); check(child.hp==100.0,"Robot starts at 100 HP")
				check(child.get_meta(&"dream_room_id")!=world.spawn_room_id,"Robot never spawns in safe reception")
		for drone in world._exterior_drone_root.get_children():
			old_units.append(drone); check(drone.hp==100.0,"Drone starts at 100 HP")
			check(not drone.patrol_points.is_empty(),"Drone patrols existing exterior windows")
			for point: Vector3 in drone.patrol_points:
				var local: Vector3=world.to_local(point)
				check(not world.floor_cells.has(Vector2i(Vector2(local.x,local.z).round())),"Every drone waypoint stays outside floor")
		var ids: Array=[]
		for old in old_units: ids.append(old.get_instance_id())
		world._spawn_special_units()
		check(world._count_hotel_robots()==count,"Room refresh does not respawn robot")
		for old in old_units: check(is_instance_valid(old) and ids.has(old.get_instance_id()),"Room refresh keeps same units")
	# Failure rollback must preserve the same 2D and 3D objects.
	var saved:=old_units.duplicate()
	var old_floor: int=world.floor_index
	world.floor_transition_in_progress=true
	world._stash_current_floor_for_rollback()
	await frames(2)
	for old in saved: check(is_instance_valid(old) and not old.can_process(),"Stash suspends units without destroying proxies")
	world._reset_layout_data()
	world._rollback_failed_transition(world.transition_generation_token,old_floor)
	await frames(2)
	for old in saved: check(is_instance_valid(old),"Failed generation restores exact old unit")
	for old in saved:
		if old.has_method("health_bar"):
			check(is_instance_valid(old._proxy) and is_instance_valid(old._muzzle_2d),"Drone proxy and muzzle survive rollback reparenting")
	var staged_old:=saved.duplicate()
	check(await world._regenerate_staged(90211,old_floor+1,world.transition_generation_token),"Staged floor transition generates with special units")
	await frames(2)
	for old in staged_old: check(not is_instance_valid(old),"Successful staged transition destroys previous floor units")
	check(world._count_hotel_robots()<=1 and world._exterior_drone_root.get_child_count()<=2,"Staged transition preserves per-floor population limits")
	world.floor_transition_in_progress=false
	# Test combat and navigation in an isolated patch of the real 2D physics world.
	for child in world.enemy_root.get_children(): child.set_physics_process(false)
	world.player.set_physics_process(false)
	var origin:=Vector2(12000,12000)
	for y in range(370,388):
		for x in range(370,388): world.floor_cells[Vector2i(x,y)]=true
	world.player.global_position=origin+Vector2(220,0)
	var unit: Node=load("res://scripts/entities/hotel_robot_unit.gd").new()
	world.enemy_root.add_child(unit); unit.global_position=origin
	unit.configure(world,world.player,Rect2(origin-Vector2(32,128),Vector2(320,288)))
	unit.set_physics_process(false)
	check(unit.hp==100.0,"Configured robot health contract")
	var obstacle:=StaticBody2D.new(); obstacle.collision_layer=8; obstacle.collision_mask=0
	var shape:=CollisionShape2D.new(); shape.shape=RectangleShape2D.new(); shape.shape.size=Vector2(32,128); obstacle.add_child(shape)
	world.gameplay_world.add_child(obstacle); obstacle.global_position=origin+Vector2(96,0)
	await physics_frame; await physics_frame
	var route:=NAV.path(unit,world.player.global_position)
	check(route.size()>4,"Robot finds multi-step furniture detour")
	var bends:=false
	for point: Vector2 in route: if absf(point.y-origin.y)>48.0: bends=true
	check(bends,"Route travels around, not through, blocking furniture")
	var start: Vector2=unit.global_position
	for i in 150:
		unit._route_time-=1.0/60.0
		unit._move_toward(world.player.global_position,180.0)
		await physics_frame
	check(unit.global_position.x>obstacle.global_position.x+32.0,"Real physics movement passes obstacle")
	check(start.distance_to(unit.global_position)>100.0,"Robot does not remain stuck")
	unit.deploy=1.0
	var before:=shots().size()
	unit._fire(Vector2.RIGHT); unit._fire(Vector2.RIGHT)
	var emitted:=shots().slice(before)
	check(emitted.size()==2 and unit.shot_serial==2,"Both side shots share total rifle cadence")
	for item in emitted:
		item.set_physics_process(false)
		check(item.source_weapon_id==&"assault_rifle" and item.damage==RULES.parameters(world.config,&"assault_rifle").damage,"Robot uses formal rifle damage")
		check(item.speed==RULES.parameters(world.config,&"assault_rifle").speed,"Robot uses formal rifle flight speed")
		check(item.direction.dot(item.global_position.direction_to(world.player.global_position))>.999,"Each side barrel converges on player rather than shooting parallel")
	check(emitted[0].global_position!=emitted[1].global_position,"Left/right guns have different origins")
	var enemy: Node=world._spawn_regular_employee(world.current_room_id,origin+Vector2(160,96),&"employee",false,"luger")
	enemy.set_physics_process(false); enemy.current_health=1e12
	var item:=bullet(enemy,origin+Vector2(10,10))
	var expected: Vector2=item.global_position.direction_to(enemy.global_position)
	item.reflect_from_player(world.player,item.global_position)
	check(item.direction.is_equal_approx(expected),"Parry returns toward original shooter, not mouse")
	check(item.speed==1500.0 and item.source_faction==&"player","Reflection keeps speed and becomes player-safe")
	item._handle_collision(enemy)
	check(enemy.dead,"Reflection executes enemy with trillion HP")
	var missing:=Node2D.new(); world.gameplay_world.add_child(missing)
	item=bullet(missing,origin); missing.free(); item.reflect_from_player(world.player,origin)
	check(item.direction.is_equal_approx(Vector2.RIGHT),"Freed shooter falls back to reverse incoming direction")
	item._handle_collision(unit)
	check(unit.dead,"Reflected shot executes indoor robot")
	var blocked_target: Node=world._spawn_regular_employee(world.current_room_id,origin+Vector2(160,96),&"employee",false,"luger")
	blocked_target.set_physics_process(false); blocked_target.current_health=10000.0
	var wall:=StaticBody2D.new(); wall.collision_layer=1; wall.collision_mask=0
	var wall_shape:=CollisionShape2D.new(); wall_shape.shape=RectangleShape2D.new(); wall_shape.shape.size=Vector2(16,64); wall.add_child(wall_shape)
	world.gameplay_world.add_child(wall); wall.global_position=origin+Vector2(80,96)
	await physics_frame; await physics_frame
	item=bullet(blocked_target,origin+Vector2(0,96)); item.reflect_from_player(world.player,item.global_position)
	var reflected_heading: Vector2=item.direction
	blocked_target.global_position+=Vector2(0,50)
	check(item.direction==reflected_heading,"Return shot does not become a homing missile")
	item._physics_process(.12)
	check(item.consumed and not blocked_target.dead,"Solid wall stops returned bullet before it executes enemy")
	# Same-frame enemy snapshot contains a freed object: actual melee call must skip it.
	world.player.equip_weapon("lucille",world.config,{})
	var stale:=Node2D.new(); world.enemy_root.add_child(stale)
	world._cached_dream_enemies=[stale]; world._cached_dream_enemies_frame=Engine.get_process_frames(); stale.free()
	world.player.lucille_weapon._resolve_swing_hits(world.player,world.player.global_position,Vector2.RIGHT)
	check(true,"Melee tolerates released cached enemy")
	world.free(); await frames(2)
	print("SPECIAL_FORMAL_PARRY checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
