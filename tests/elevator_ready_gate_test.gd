extends SceneTree
const READY=preload("res://scripts/dream/elevator_render_readiness.gd")
class MockWorld extends Node3D:
	var transition_generation_token:=1
	var floor_token:=2
	var last_firearm_render_preparation:Dictionary={}
	func get_current_floor_token()->int:return floor_token
	func complete_firearm_render_preparation(report:Dictionary)->void:last_firearm_render_preparation=report
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var world:=MockWorld.new();root.add_child(world)
	check(not READY.is_ready(world,{}),"Empty result never opens door")
	check(not READY.is_ready(world,{"cancelled":false,"skipped":"world_not_ready"}),"Non-cancelled skip is not a success")
	var blocked:Dictionary=await READY.run(self,world)
	check(not READY.is_ready(world,blocked),"Live gameplay cannot be prepared without freezing")
	paused=true
	var report:Dictionary=await READY.run(self,world)
	check(READY.is_ready(world,report),"Explicit headless test completes its logical gate")
	check(not report.render_verified,"Headless never claims GPU verification")
	var other:=MockWorld.new();root.add_child(other)
	check(not READY.is_ready(other,report),"Another world cannot reuse receipt")
	world.floor_token+=1
	check(not READY.is_ready(world,report),"Changed floor invalidates receipt")
	world.floor_token-=1;world.transition_generation_token+=1
	check(not READY.is_ready(world,report),"Changed journey invalidates receipt")
	world.transition_generation_token-=1
	for key in ["ready","cancelled"]:
		var bad:=report.duplicate();bad[key]=key=="cancelled"
		check(not READY.is_ready(world,bad),"Incomplete or cancelled receipt stays locked")
	world.queue_free()
	check(not READY.is_ready(world,report),"Queued teardown immediately invalidates receipt")
	await process_frame
	check(not READY.is_ready(world,report),"Freed world safely invalidates receipt")
	other.queue_free();paused=false
	print("ELEVATOR_READY_GATE checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
