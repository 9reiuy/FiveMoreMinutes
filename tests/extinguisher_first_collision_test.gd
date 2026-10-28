extends SceneTree
const FIXTURE=preload("res://tests/fire_extinguisher_test.gd")
const SYSTEM=preload("res://scripts/dream/fire_extinguisher_system.gd")
class Target extends Area2D:
	var dead:=false
	var health:=1000.0
	func take_damage(amount:float,_at:Vector2,_force:float,_kind:StringName)->void:health-=amount
var checks:=0
var failures:Array[String]=[]
func expect(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func make_wall(parent:Node,point:Vector2)->void:
	var wall:=StaticBody2D.new();wall.collision_layer=1;wall.position=point
	var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(4,800);collision.shape=shape
	wall.add_child(collision);parent.add_child(wall)
func run()->void:
	var world:=FIXTURE.World.new();root.add_child(world)
	for y in 12:
		for x in 15:
			world.floor_cells[Vector2i(x,y)]="room"
			world.room_cells[Vector2i(x,y)]=0 if x<4 else 1
	for y in 12:
		world.wall_edges["V:4:%d"%y]={"axis":"V","x":4,"y":y}
	make_wall(world.key_root,Vector2(112,64));make_wall(world.key_root,Vector2(-16,64))
	var smoke:Node=SYSTEM.install(world);smoke.set_physics_process(false)
	for mounted in world.key_root.get_children():
		if mounted.has_method("advance_flight"):mounted.set_physics_process(false)
	var victim:=Target.new();victim.collision_layer=16;victim.collision_mask=0;victim.position=Vector2(80,64)
	var hit:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=7;hit.shape=circle;victim.add_child(hit);victim.add_to_group(&"dream_enemies");world.key_root.add_child(victim)
	var tank:Node=FIXTURE.TANK.new();tank.world=world;tank.controller=smoke;tank.position=Vector2(64,64)
	world.key_root.add_child(tank);tank.set_physics_process(false)
	await physics_frame;await physics_frame
	tank.take_damage(20,Vector2.RIGHT)
	tank.advance_flight(1.0/60.0);smoke.advance(1.0/60.0)
	expect(victim.health==990.0,"cylinder deals unchanged ten damage while crossing enemy")
	expect(not tank.emission_stopped and tank.bounces==0,"enemy hit alone does not stop gas emission")
	expect(smoke.sources[0].trail.size()>0,"first straight flight leaves suppressant trail")
	var guard:=0
	while tank.bounces==0 and guard<30:
		tank.advance_flight(1.0/60.0);smoke.advance(1.0/60.0);guard+=1
	expect(tank.bounces==1 and tank.emission_stopped,"first physical bounce closes emission")
	expect(tank.flying and tank.velocity.x<0,"first bounce still reverses flight")
	var trail:Array=smoke.sources[0].trail.duplicate(true)
	var revision:int=smoke.emission_revision
	var rng_state:int=smoke.rng.state
	for tick in 100:
		tank.advance_flight(1.0/60.0);smoke.advance(1.0/60.0)
	expect(smoke.sources[0].trail==trail,"later bounces do not append any path cells")
	expect(smoke.emission_revision==revision and smoke.rng.state==rng_state,"no new path or nozzle particles after first bounce")
	expect(tank.bounces==7 and not tank.flying,"existing maximum of seven bounces retained")
	expect(smoke.contains(Vector2(64,64)),"original release remains after cylinder stops")
	expect(smoke.cells.size()<=smoke.smallest_room_cells,"original total coverage cap retained")
	var enlarged:=false
	for cloud in smoke.clouds:
		if float(cloud.get("path_scale",1))>1:enlarged=true
	expect(enlarged,"path cloud cards are wider and taller")
	expect(smoke.clouds.size()+smoke.fringe_clouds.size()+smoke.puffs.size()<=smoke.MAX_PUFFS,"particle budget not increased")
	for cell in smoke.cells:expect(int(cell.x)<4,"widening never crosses intact wall")
	smoke.advance(12.0)
	expect(smoke.sources.is_empty() and smoke.cells.is_empty(),"origin and straight trail still expire at twelve-second release lifetime")
	world.free();await process_frame
	# Isolate path-radius widening from the area cap; both retain the same cap.
	var worlds:Array=[];var controllers:Array=[]
	for index in 2:
		var open_world:=FIXTURE.World.new();root.add_child(open_world);worlds.append(open_world)
		for y in 20:
			for x in 30:
				open_world.floor_cells[Vector2i(x,y)]="room"
				open_world.room_cells[Vector2i(x,y)]=0
		var gas:Node=SYSTEM.install(open_world);controllers.append(gas);gas.set_physics_process(false)
		gas.coverage_radius=4
		gas.trail_width_scale=1.0 if index==0 else 1.25
		gas.discharge(Vector2(8,8)*32)
		gas.emit_trail(Vector2(8,8)*32,Vector2(14,8)*32,1)
		gas.sources[0].age=2.0;gas.rebuild_field()
	expect(not controllers[0].contains(Vector2(14,13)*32) and controllers[1].contains(Vector2(14,13)*32),"path widening changes authoritative smoke coverage, not just card size")
	expect(controllers[1].blocks_sight(Vector2(14,13)*32,Vector2(14,14)*32),"new path edge blocks gameplay sight")
	expect(controllers[0].smallest_room_cells==controllers[1].smallest_room_cells and controllers[1].cells.size()<=controllers[1].smallest_room_cells,"wider path retains identical total area allowance")
	for open_world in worlds:open_world.free()
	await process_frame
	print("FIRST_COLLISION_SMOKE checks=%d failures=%s"%[checks,failures])
	quit(0 if failures.is_empty() else 1)
