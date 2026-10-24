extends SceneTree
const TEST=preload("res://tests/fire_extinguisher_test.gd")
const SYSTEM=preload("res://scripts/dream/fire_extinguisher_system.gd")
class Enemy extends Node2D:
	var dead:=false
	var visual:=Node3D.new()
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	create_timer(40,true,false,true).timeout.connect(func()->void:quit(2))
	var world=TEST.World.new();root.add_child(world);world.add_to_group(&"dream_world")
	world.rooms=[{"type":"office"}]
	for y in 5:
		for x in 10:world.floor_cells[Vector2i(x,y)]="room";world.room_cells[Vector2i(x,y)]=0
	for y in 5:world.wall_edges["V:5:%d" % y]={"axis":"V","x":5,"y":y}
	var smoke=SYSTEM.install(world);smoke.set_physics_process(false)
	for tank in world.key_root.get_children():tank.set_physics_process(false)
	var id: int=smoke.discharge(Vector2(64,64));smoke.advance(.5)
	check(smoke.cells.size()==25,"Walls restrict physical smoke coverage to reachable side")
	check(smoke.clouds.size()==100,"Wall-blocked cloud groups are redistributed without losing release quantity")
	for cloud in smoke.clouds:check(int(cloud.cell.x)<5,"Redistributed groups never cross the wall")
	check(not smoke.contains(Vector2(224,64)),"No suppressant leaks into the separated room")
	world.player=Node2D.new();world.key_root.add_child(world.player);world.player.position=Vector2(-64,64)
	var enemy:=Enemy.new();world.key_root.add_child(enemy);enemy.add_to_group(&"dream_enemies");world.add_child(enemy.visual)
	enemy.position=Vector2(224,64);smoke.apply_coverage()
	check(not smoke.contains(world.player.position) and not smoke.contains(enemy.position),"Observer and target can both stand outside smoke")
	check(smoke.blocks_sight(world.player.position,enemy.position),"Intervening smoke blocks a clear-endpoint sight segment")
	check(enemy.visible and enemy.can_process() and not enemy.visual.visible,"Player concealment hides presentation without disabling enemy gameplay")
	check(enemy.get_meta(&"smoke_hidden_from_player",false),"Hidden enemy is flagged to suppress outline and targeting hints")
	var highlight:=preload("res://scripts/dream/dream_3d_target_highlight.gd").new()
	check(highlight._resolve(enemy)==null,"Hidden enemies are excluded from player targeting outlines")
	highlight.free()
	smoke.disperse_segment(Vector2(-16,64),Vector2(144,64));smoke.advance(.01)
	check(not smoke.contains(Vector2(64,64)),"A bullet corridor clears its actual traversed smoke cells")
	check(smoke.contains(Vector2(64,32)),"Smoke beside the bullet corridor remains")
	check(not smoke.blocks_sight(world.player.position,enemy.position),"Both sides regain sight through the cleared corridor")
	check(enemy.visual.visible and not enemy.get_meta(&"smoke_hidden_from_player",false),"Enemy visuals and targeting visibility restore after clearing")
	smoke.advance(.3)
	check(not smoke.contains(Vector2(64,64)),"The same old smoke cannot immediately refill a dispersed corridor")
	smoke.emit_trail(Vector2(64,64),Vector2(96,64),id);smoke.advance(.1)
	check(smoke.contains(Vector2(64,64)),"A later real emission can cover the dispersed corridor again")
	var age: float=smoke.sources[0].age
	smoke.emit_trail(Vector2(224,64),Vector2(256,64),id);smoke.advance(.1)
	check(smoke.contains(Vector2(256,64)),"Actual flight in another room leaves full suppressant clouds along its path")
	check(float(smoke.sources[0].age)<age+.11,"Trail generation does not reset the release timer")
	check(smoke.cells.size()<=smoke.smallest_room_cells,"Recent trail and original gas share one maximum footprint")
	var tank:=TEST.TANK.new();tank.world=world;tank.controller=smoke;tank.position=Vector2(256,64);world.key_root.add_child(tank);tank.set_physics_process(false)
	smoke.apply_coverage()
	check(tank.smoke_silhouette and tank.visual.get_child(0).material_overlay!=null,"A cylinder inside gas has a complete black silhouette")
	tank.position=Vector2(400,400);smoke.apply_coverage()
	check(not tank.smoke_silhouette and tank.visual.get_child(0).material_overlay==null,"Leaving gas restores cylinder paint and hardware")
	# Test the REAL shared projectile sweep against a collision wall. Its range
	# end is beyond the wall, but only the contact segment may disperse smoke.
	world.wall_edges.clear();smoke.sources.clear();smoke.discharge(Vector2(144,64));smoke.advance(.5)
	var wall:=StaticBody2D.new();wall.collision_layer=1;wall.position=Vector2(144,64)
	var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=Vector2(4,200);shape.shape=rectangle;wall.add_child(shape);world.key_root.add_child(wall)
	await physics_frame;await physics_frame
	var bullet:=preload("res://scripts/entities/basic_projectile.gd").new();world.key_root.add_child(bullet)
	bullet.set_physics_process(false);bullet.office_ballistics=true;bullet.position=Vector2(0,64);bullet._sweep_office_to(Vector2(256,64),true)
	check(bullet.global_position.x<=142.1,"Actual shared bullet stops at the collision wall")
	check(not smoke.contains(Vector2(96,64)),"Actual player bullet clears smoke before its wall contact")
	check(smoke.contains(Vector2(160,64)),"Actual bullet does not disperse smoke behind a blocking wall")
	var enemy_bullet:=preload("res://scripts/entities/basic_projectile.gd").new();world.key_root.add_child(enemy_bullet)
	enemy_bullet.set_physics_process(false);enemy_bullet.office_ballistics=true;enemy_bullet.source_faction=&"enemy"
	enemy_bullet.position=Vector2(0,32);enemy_bullet._sweep_office_to(Vector2(256,32),true)
	check(not smoke.contains(Vector2(96,32)),"Enemy bullets use the same path dispersal rule as player bullets")
	check(smoke.contains(Vector2(160,32)),"Enemy bullets also stop dispersal at the actual blocking wall")
	bullet.queue_free();enemy_bullet.queue_free();wall.queue_free()
	var remaining: float=SYSTEM.DURATION-float(smoke.sources[0].age)
	smoke.advance(remaining-.05)
	check(not smoke.sources.is_empty(),"Smoke release remains alive just before twelve seconds")
	smoke.advance(.1)
	check(smoke.sources.is_empty() and smoke.cells.is_empty(),"Smoke release and all path cells expire at twelve seconds")
	check(enemy.visual.visible and not enemy.get_meta(&"smoke_hidden_from_player",false),"Expiration restores hidden enemy presentation")
	# Let visibility/material restoration reach the rendering server before
	# disposing the complete fixture in one synchronous tree free.
	await process_frame;await process_frame
	world.free();await process_frame
	print("EXTINGUISHER_SMOKE_RULES checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
