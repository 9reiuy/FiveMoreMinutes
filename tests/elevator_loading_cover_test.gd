extends SceneTree
const COVER=preload("res://scripts/dream/elevator_loading_cover.gd")
class MockWorld extends Node3D:
	var transition_generation_token:=1
var checks:=0
var failures:=0
var finished:=false
var report: Dictionary={}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func job(reference: WeakRef,variant: int) -> Dictionary:
	check(paused and root.has_node("ElevatorLoadingCover"),"Heavy work only starts behind paused black cover")
	var escape:=InputEventAction.new(); escape.action=&"ui_cancel"; escape.pressed=true
	root.push_input(escape)
	check(root.is_input_handled() and paused,"Loading cover consumes escape without changing pause")
	escape.pressed=false; root.push_input(escape)
	for frame in 2: await process_frame
	var world: Node=reference.get_ref()
	if variant==1: world.transition_generation_token+=1
	elif variant==2: world.free()
	if variant==2:
		check(not paused,"World teardown immediately releases global pause")
	for frame in 2: await process_frame
	return {"cancelled":false}
func begin(world: MockWorld,variant: int) -> void:
	report=await COVER.run(self,world,job.bind(weakref(world),variant),1)
	finished=true
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	for variant in 4:
		var world:=MockWorld.new(); root.add_child(world)
		var old_pause: bool=variant==3
		paused=old_pause
		finished=false; begin(world,variant)
		while not finished: await process_frame
		check(bool(report.cancelled)==(variant==1 or variant==2),"Success versus stale token/world teardown")
		check(report.cover_released and not root.has_node("ElevatorLoadingCover"),"No loading cover left behind")
		check(report.pause_restored and paused==old_pause,"Original pause state restored")
		if is_instance_valid(world): world.queue_free()
		paused=false; await process_frame
	print("ELEVATOR_LOADING_COVER_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
