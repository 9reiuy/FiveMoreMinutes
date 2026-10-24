extends SceneTree
const SYSTEM=preload("res://scripts/dream/fire_extinguisher_system.gd")
const TANK=preload("res://scripts/dream/fire_extinguisher.gd")
class Door extends Node3D:
	var is_destroyed:=false
	var open_angle:=0.0
class Victim extends Node2D:
	var maximum_health:=100.0
	var current_health:=100.0
	var dead:=false
	func take_damage(amount: float,_origin=Vector2.ZERO,_force=0.0,_kind=&"") -> void:current_health-=amount
class World extends Node3D:
	var floor_root:=Node3D.new()
	var door_root:=Node3D.new()
	var key_root:=Node2D.new()
	var actor_depth_bridges_root:=Node3D.new()
	var floor_transition_in_progress:=false
	var floor_cells: Dictionary={}
	var wall_edges: Dictionary={}
	var door_edges: Dictionary={}
	var door_opening_edges: Dictionary={}
	var glass_wall_edges: Dictionary={}
	var window_wall_edges: Dictionary={}
	var room_cells: Dictionary={}
	var pit_cells: Dictionary={}
	var rooms: Array=[{},{}]
	var active_seed:=331
	var wall_thickness:=.25
	var player: Node2D
	func is_smoke_sight_blocked(from: Vector2,to: Vector2) -> bool:
		var smoke:=floor_root.get_node_or_null("FireExtinguisherSystem")
		return smoke!=null and smoke.blocks_sight(from,to)
	func disperse_smoke_segment(from: Vector2,to: Vector2) -> void:
		var smoke:=floor_root.get_node_or_null("FireExtinguisherSystem")
		if smoke!=null:smoke.disperse_segment(from,to)
	func _ready() -> void:
		for node in [floor_root,door_root,key_root,actor_depth_bridges_root]:add_child(node)
	func get_gameplay_world_position(at: Vector2,height: float) -> Vector3:return to_global(Vector3(at.x/32,height,at.y/32))
	func _cell_for_gameplay_position(at: Vector2) -> Vector2i:return Vector2i((at/32).round())
	func _edge_key(edge: Dictionary) -> String:return "%s:%d:%d" % [edge.axis,edge.x,edge.y]
	func _edge_from_cell_direction(cell: Vector2i,d: Vector2i) -> Dictionary:
		return {"axis":"H","x":cell.x,"y":cell.y+(1 if d.y>0 else 0)} if d.y!=0 else {"axis":"V","x":cell.x+(1 if d.x>0 else 0),"y":cell.y}
	func _edge_side_cells(edge: Dictionary) -> Array:
		var cell:=Vector2i(edge.x,edge.y)
		return [cell-Vector2i.LEFT*-1,cell] if edge.axis=="V" else [cell-Vector2i.DOWN,cell]
	func _edge_gameplay_position(edge: Dictionary) -> Vector2:return (Vector2(edge.x,edge.y)-Vector2(.5,0) if edge.axis=="V" else Vector2(edge.x,edge.y)-Vector2(0,.5))*32
	func _content_position_is_clear(_at: Vector2,_r: float) -> bool:return true
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var world:=World.new();root.add_child(world)
	for y in 3:
		for x in 5:
			world.floor_cells[Vector2i(x,y)]="room"
			world.room_cells[Vector2i(x,y)]=0 if x<2 else 1
	for y in [0,2]:world.wall_edges["V:2:%d" % y]={"axis":"V","x":2,"y":y}
	world.glass_wall_edges["H:0:1"]={"axis":"H","x":0,"y":1}
	world.wall_edges["H:0:1"]=world.glass_wall_edges["H:0:1"]
	var edge:={"axis":"V","x":2,"y":1,"door_id":1}
	world.door_edges["V:2:1"]=edge;world.door_opening_edges["V:2:1"]=edge
	var door:=Door.new();door.set_meta(&"door_edge",edge);world.door_root.add_child(door)
	var system:=SYSTEM.install(world);system.set_physics_process(false)
	check(not world.key_root.get_children().is_empty(),"Deterministic wall mounting produces cylinders")
	for mounted in world.key_root.get_children():
		mounted.set_physics_process(false)
		check(not world.glass_wall_edges.has(mounted.get_meta("wall_edge_key")),"Never mount on glass")
		check(not world.door_opening_edges.has(mounted.get_meta("wall_edge_key")),"Never mount in door openings")
	var tank:=TANK.new();tank.world=world;tank.controller=system;tank.position=Vector2(32,32)
	world.key_root.add_child(tank);tank.set_physics_process(false)
	tank.take_damage(9,Vector2.RIGHT)
	check(not tank.broken and tank.hp==11,"Twenty HP cylinder survives sublethal damage")
	tank.take_damage(11,Vector2.RIGHT)
	check(tank.broken and tank.flying and tank.velocity.x>0,"Breaking starts a hit-directed gas-powered flight")
	check(system.sources.size()==1,"Breaking discharges smoke once")
	tank.take_damage(100,Vector2.LEFT)
	check(system.sources.size()==1,"Repeated hits cannot duplicate discharge")
	system.advance(1.0)
	check(system.contains(Vector2(32,32)),"Smoke fills source room quickly")
	check(not system.contains(Vector2(96,32)),"Intact door contains smoke")
	door.open_angle=PI*.5;system.rebuild_field()
	check(not system.contains(Vector2(96,32)),"Open but intact door still blocks smoke")
	check(not system.can_cross(Vector2i(1,0),Vector2i(2,0)),"Solid wall blocks smoke")
	check(not system.can_cross(Vector2i(0,0),Vector2i(0,1)),"Glass blocks smoke")
	check(not system.can_cross(Vector2i(0,0),Vector2i(-1,0)),"Smoke never expands into exterior void")
	door.is_destroyed=true;system.rebuild_field()
	check(system.contains(Vector2(64,32)),"Destroyed door allows smoke into its nearest doorway cell within the new size cap")
	check(system.cells.size()<=system.smallest_room_cells,"Single discharge never exceeds the smallest room floor area")
	check(system.smallest_room_cells==6,"Smallest room uses net floor cell count rather than container dimensions")
	check(system.blocks_sight(Vector2(64,32),Vector2(64,32)),"A target inside gas is hidden even at point-blank range")
	check(system.blocks_sight(Vector2(0,-32),Vector2(64,64)),"A sight segment crossing gas is blocked")
	check(not system.blocks_sight(Vector2(128,-32),Vector2(128,96)),"A clear sight segment outside gas remains visible")
	var victim:=Victim.new();world.key_root.add_child(victim);victim.position=Vector2(32,32);victim.add_to_group(&"dream_enemies")
	system.sources.clear();system.rebuild_field()
	var burn:=preload("res://scripts/dream/burning_effects.gd").install(world)
	burn.set_physics_process(false);burn.effects.set_process(false)
	check(burn.ignite(victim),"Victim initially burns outside suppressant")
	system.discharge(victim.global_position);system.advance(.1)
	check(burn.burning.is_empty(),"Smoke extinguishes an already-burning target")
	check(not burn.ignite(victim),"Covered target cannot be reignited")
	check(victim.get_meta("extinguisher_smoke",false),"Covered human is flagged for silhouette presentation")
	world.floor_transition_in_progress=true
	var age: float=system.sources[0].age
	system.advance(2)
	check(system.sources[0].age==age,"Floor transitions suspend smoke simulation")
	world.floor_transition_in_progress=false
	system.advance(12.0)
	check(system.cells.is_empty() and not victim.get_meta("extinguisher_smoke",false),"Expired smoke restores human presentation")
	check(burn.ignite(victim),"Extinguished target can burn again after smoke expires")
	var area:=Area2D.new();area.collision_layer=16;area.collision_mask=0
	area.set_script(load("res://scenes/dream/rooms/hurtbox.gd"))
	var collider:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=7;collider.shape=circle
	area.add_child(collider);victim.add_child(area)
	victim.position=Vector2(50,0)
	await physics_frame;await physics_frame
	tank._hit_enemies(Vector2.ZERO,Vector2(100,0))
	check(victim.current_health==90,"Swept flight deals exactly ten damage to an enemy")
	tank._hit_enemies(Vector2.ZERO,Vector2(100,0))
	check(victim.current_health==90,"Sustained overlap cannot deal damage every frame")
	tank._hit_enemies(Vector2(200,0),Vector2(240,0));tank._hit_enemies(Vector2.ZERO,Vector2(100,0))
	check(victim.current_health==80,"Separation allows a later distinct collision to damage again")
	tank.bounce(Vector2.LEFT)
	check(tank.bounces==1 and tank.velocity.x<0,"Wall collision reflects flight velocity")
	for i in 6:tank.bounce(Vector2.RIGHT)
	check(tank.bounces==7 and not tank.flying and tank.velocity==Vector2.ZERO,"Seventh wall collision stops propulsion")
	tank.flying=true;tank.flight_age=4.99;tank.advance_flight(.02)
	check(not tank.flying,"Five-second safety timeout stops flight")
	var wall:=StaticBody2D.new();wall.collision_layer=1;wall.position=Vector2(100,64)
	var wall_shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(4,300);wall_shape.shape=rect
	wall.add_child(wall_shape);world.key_root.add_child(wall)
	tank.global_position=Vector2(70,64);tank.velocity=Vector2.RIGHT*TANK.SPEED;tank.flying=true;tank.flight_age=0;tank.bounces=0
	await physics_frame;await physics_frame
	tank.advance_flight(.1)
	check(tank.bounces>=1 and tank.velocity.x<0 and tank.global_position.x<94,"Real swept wall collision reflects without tunneling through the wall")
	tank.stop_flight()
	for i in 8:system.discharge(Vector2.ZERO)
	system.advance(.1)
	check(system.puffs.size()<=SYSTEM.MAX_PUFFS and system.cells.size()<=SYSTEM.MAX_CELLS,"Smoke sources, cells and visual puffs stay bounded")
	check(tank.visual.get_child_count()==1 and tank.visual.get_child(0).mesh.get_surface_count()==2,"Cylinder shares two cached surfaces for lit hardware and exempt paint")
	world.free();await process_frame
	print("FIRE_EXTINGUISHER checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
