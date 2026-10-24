extends SceneTree
class Walker extends CharacterBody2D:
	var dead:=false
class Actor extends Node2D:
	var dead:=false
	var death_landed:=true
	var character_visual:=Node2D.new()
	var target:CharacterBody2D
	var impulses:=0
	func _init()->void:add_child(character_visual)
	func receive_corpse_contact(_impulse:Vector2)->void:impulses+=1
var checks:=0
var failures:Array=[]
var sensor:Area2D
var actor:Actor
var events:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func ticks(n:int)->void:
	for i in n:await physics_frame;await process_frame
func run()->void:
	var isolated:=ProjectSettings.globalize_path("res://.runtime/").replace("\\","/").simplify_path()+"/"
	if not OS.get_user_data_dir().replace("\\","/").simplify_path().begins_with(isolated):quit(2);return
	var script_path:="res://scripts/entities/corpse_contact_motion.gd"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sensor-script="):script_path=arg.trim_prefix("--sensor-script=")
	var source:GDScript=load(script_path)
	var arena:=Node2D.new();root.add_child(arena)
	actor=Actor.new();arena.add_child(actor)
	var body:=Walker.new();body.collision_layer=1;body.collision_mask=0
	var body_shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=7;body_shape.shape=circle;body.add_child(body_shape);arena.add_child(body)
	actor.target=body
	var detector:=Area2D.new();detector.collision_mask=1;detector.collision_layer=0
	var detector_shape:=CollisionShape2D.new();var area_circle:=CircleShape2D.new();area_circle.radius=32;detector_shape.shape=area_circle;detector.add_child(detector_shape)
	detector.body_entered.connect(func(_body:Node2D)->void:
		if events>0:return
		events+=1;sensor=Area2D.new();sensor.set_script(source);actor.add_child(sensor))
	arena.add_child(detector)
	await ticks(5)
	check(events==1 and is_instance_valid(sensor),"Real body_entered creates one corpse contact sensor")
	check(sensor.collision_layer==0 and sensor.collision_mask==(1|8),"Passive corpse mask remains unchanged")
	check(not sensor.monitorable,"Contact sensor remains unmonitorable after creation inside physics signal")
	check(sensor.get_child_count()==1 and sensor.get_child(0) is CollisionShape2D,"Deferred callback installs exactly one real collision shape")
	var footprint:ConvexPolygonShape2D=sensor.get_child(0).shape
	check(footprint.points.size()>=4,"Full-body convex footprint replaces the old small capsule")
	actor.dead=true;sensor._physics_process(1.0/60)
	body.position=sensor.position-Vector2(7,0);body.velocity=Vector2(150,0)
	await ticks(5)
	check(sensor.get_overlapping_bodies().has(body),"Real physics overlap still detects the player")
	check(actor.impulses>0,"Moving player still pushes a landed corpse through actual overlap")
	arena.free();await ticks(2)
	print("CORPSE_SENSOR_CALLBACK checks=",checks," failures=",failures.size())
	quit(1 if not failures.is_empty() else 0)
