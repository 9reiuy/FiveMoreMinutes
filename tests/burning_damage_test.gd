extends SceneTree
const BURN=preload("res://scripts/dream/burning_effects.gd")
class Victim extends Node2D:
	var maximum_health:=100.0
	var current_health:=100.0
	var boss_variant:=false
	var dead:=false
	func take_damage(amount: float,_origin=Vector2.ZERO,_force=0.0,_source=&"") -> void:
		current_health-=amount
		dead=current_health<=0.0
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false;world.persist_profile=false;world.spawn_content=false
	root.add_child(world)
	check(world.regenerate(42001),"Formal floor loads")
	world.player.set_physics_process(false)
	var controller:=BURN.install(world)
	controller.set_physics_process(false);controller.effects.set_process(false)
	controller.spread_left=10000.0
	var victim:=Victim.new();world.gameplay_world.add_child(victim)
	victim.global_position=Vector2(20000,20000)
	check(controller.ignite(victim),"Ordinary actor ignites")
	controller.advance(.5)
	controller.ignite(victim)
	controller.advance(.5)
	check(is_equal_approx(victim.current_health,90),"Repeated contact refreshes, not stacks: 10 percent max per second")
	victim.maximum_health=200;victim.current_health=200
	controller.advance(1.0)
	check(is_equal_approx(victim.current_health,180),"Tick follows maximum health, not remaining health")
	victim.boss_variant=true
	controller.advance(1.0)
	check(victim.current_health==180 and not controller.burning.has(victim.get_instance_id()),"Boss conversion removes burn without damage")
	check(not controller.ignite(victim),"Current boss identity is immune")
	victim.boss_variant=false;victim.set_meta(&"is_boss",true)
	check(not controller.ignite(victim),"Future boss metadata is immune")
	victim.set_meta(&"is_boss",false)
	victim.current_health=200
	controller.ignite(victim)
	for i in 6:controller.advance(1.0)
	check(victim.current_health==100 and controller.burning.is_empty(),"No source: five ticks then extinguish")
	var furniture=load("res://scenes/dream/props/office_chair_01.tscn").instantiate()
	world.gameplay_world.add_child(furniture);furniture.global_position=Vector2(20000,20000)
	var maximum: float=furniture.max_hp
	check(controller.ignite(furniture),"Real furniture ignites")
	var chair_profile: Dictionary=controller.burn_profile(furniture)
	preload("res://scripts/dream/office_furniture_catalog.gd").configure(furniture,"table")
	var table_profile: Dictionary=controller.burn_profile(furniture)
	check(float(table_profile.radius)>float(chair_profile.radius) and table_profile.extent.x>chair_profile.extent.x,"Larger furniture has wider and larger fire than a chair")
	preload("res://scripts/dream/office_furniture_catalog.gd").configure(furniture,"chair")
	controller.advance(1.0)
	check(is_equal_approx(furniture.hp,maximum*.9),"Furniture uses actual scaled max durability")
	var target:=Victim.new();world.gameplay_world.add_child(target)
	target.add_to_group(&"dream_enemies");target.global_position=furniture.global_position+Vector2(10,0)
	await physics_frame
	controller.spread()
	check(controller.burning.has(target.get_instance_id()),"Burning furniture ignites a nearby enemy")
	furniture.hp=maximum*.05
	controller.apply_tick(furniture)
	check(furniture.destroyed,"Burning furniture uses existing destruction path")
	var saved: float=target.current_health
	world.floor_transition_in_progress=true
	controller.advance(2.0)
	check(target.current_health==saved,"Floor transition suspends damage")
	world.floor_transition_in_progress=false
	target.queue_free();await process_frame
	controller.advance(.1)
	check(not controller.burning.has(target.get_instance_id()) if is_instance_valid(target) else true,"Freed targets safely retire")
	for id in controller.burning.keys():controller.remove_burn(id)
	var player=world.player
	player.global_position=Vector2(21000,21000)
	player.current_health=player.maximum_health
	player.invulnerability_left=0.0;player.dash_invulnerability_left=0.0
	player.dissociation_ready=false;player.has_shield=false
	check(controller.ignite(player),"Real player can be ignited")
	controller.advance(1.0)
	check(is_equal_approx(player.current_health,player.maximum_health*.9),"Player uses normal damage entrypoint at ten percent max HP")
	for id in controller.burning.keys():controller.remove_burn(id)
	var robot=load("res://scripts/entities/hotel_robot_unit.gd").new()
	world.enemy_root.add_child(robot)
	robot.global_position=Vector2(22000,22000)
	robot.configure(world,player,Rect2(Vector2(21900,21900),Vector2(200,200)))
	robot.set_physics_process(false)
	robot.take_damage(75.0)
	check(robot.hp==25.0 and controller.burning.has(robot.get_instance_id()),"Actual low-health robot automatically ignites")
	for i in 3:controller.advance(1.0)
	check(robot.dead,"Burning kills robot through its existing death path")
	check(controller.burning.is_empty(),"Dead robot does not keep a fire source alive")
	var contact:=Victim.new();world.gameplay_world.add_child(contact)
	contact.global_position=Vector2(23000,23000);contact.add_to_group(&"dream_enemies")
	var at: Vector3=world.get_gameplay_world_position(contact.global_position,.45)
	controller.muzzle(at,Vector3.FORWARD)
	controller.spread()
	check(not controller.burning.has(contact.get_instance_id()),"Muzzle flame is visual only and cannot ignite")
	controller.explosion(at)
	controller.spread()
	check(controller.burning.has(contact.get_instance_id()),"Explosion fire can ignite a contact target")
	for id in controller.burning.keys():controller.remove_burn(id)
	var employee=load("res://scenes/entities/employee_enemy.tscn").instantiate()
	world.enemy_root.add_child(employee)
	employee.configure(player,100,10,Rect2(Vector2(23500,23500),Vector2(400,400)),0,12)
	employee.global_position=Vector2(23700,23700)
	employee.set_physics_process(false);employee.set_process(false)
	employee.equip_weapon("assault_rifle")
	var drops: Array=[]
	employee.weapon_drop_requested.connect(func(id,at,impulse,skin):drops.append([id,at,impulse,skin]))
	check(controller.ignite(employee),"Actual human enemy ignites")
	check(employee.burning_panic and employee.held_weapon_id.is_empty() and drops.size()==1,"Ignition enters panic and drops the real carried weapon once")
	controller.ignite(employee)
	check(drops.size()==1,"Repeated flame contact does not duplicate dropped weapons")
	employee.equip_weapon("pistol")
	check(employee.held_weapon_id.is_empty(),"Burning enemy cannot pick up or equip another weapon")
	var pickup=load("res://scenes/dream/world_weapon_pickup.tscn").instantiate()
	world.world_weapon_root.add_child(pickup)
	employee.commit_reserved_world_weapon(pickup)
	check(not pickup.is_queued_for_deletion() and employee.held_weapon_id.is_empty(),"A late pickup commit cannot consume a weapon during burning panic")
	pickup.queue_free()
	employee.ranged_attack_windup_pending=true
	employee._update_burning_panic(.016)
	var old_destination: Vector2=employee.burning_panic_destination
	employee.burning_panic_turn_left=0
	employee._update_burning_panic(.016)
	check(old_destination!=employee.burning_panic_destination and employee.arena_bounds.has_point(employee.burning_panic_destination),"Panic changes escape direction inside room bounds")
	check(not employee.ranged_attack_windup_pending and employee.get_ranged_telegraph_state().is_empty(),"Panic cancels enemy aim and attack windup")
	controller.remove_burn(employee.get_instance_id())
	check(not employee.burning_panic,"Extinguishing restores ordinary AI")
	employee.configure_boss(true)
	check(not controller.ignite(employee) and not employee.burning_panic,"Boss does not enter burning panic")
	check(not robot.has_method("set_burning_panic"),"Robot burning does not use human weapon-drop panic")
	world.free();await process_frame
	print("BURNING_DAMAGE checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
