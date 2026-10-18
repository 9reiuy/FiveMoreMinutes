extends SceneTree
const DIRECTOR=preload("res://scripts/ui/transition_director.gd")
var checks:=0
var failures:=0
var jobs: Dictionary={}
class Probe extends Control:
	var sequence: Array
	var main: Node
	var observations: Dictionary
	var loaded_under_overlay:=false
	signal generation_progress(ratio: float,message: String)
	func _ready()->void:
		sequence.append(name)
		loaded_under_overlay=main.loading_overlay.is_active
		observations[name]=loaded_under_overlay
func _initialize()->void: call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value: failures+=1; push_error(label)
func frames(count:int)->void:
	for i in count: await process_frame
func cover(d:Control,key:String,seconds:float)->void: jobs[key]=await d.cover("pixel_blocks",seconds)
func reveal(d:Control,key:String,seconds:float)->void: jobs[key]=await d.reveal(seconds)
func run()->void:
	var d:=DIRECTOR.new(); root.add_child(d); await frames(2)
	cover(d,"cover",.06); await frames(1)
	check(not await d.reveal(.01) and d.current_state==DIRECTOR.State.COVERING,"Premature reveal cannot tear down a cover in progress")
	var key:=InputEventKey.new(); key.keycode=KEY_E; key.pressed=true; root.push_input(key)
	check(root.is_input_handled(),"Cover consumes keyboard interaction")
	while not jobs.has("cover"): await process_frame
	check(jobs.cover and d.current_state==DIRECTOR.State.WAITING_FOR_SCENE,"Cover finishes opaque and waits for scene readiness")
	reveal(d,"reveal",.06)
	check(float(d.material_instance.get_shader_parameter("progress"))>.99 and not d.material_instance.get_shader_parameter("invert"),"Reveal starts fully covered without an inversion flash")
	while not jobs.has("reveal"): await process_frame
	check(jobs.reveal and not d.color_rect.visible and d.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Finished reveal releases its overlay and input")
	cover(d,"cancelled",.2); await frames(1); d.cancel_transition()
	cover(d,"replacement",.03)
	while not jobs.has("cancelled") or not jobs.has("replacement"): await process_frame
	check(not jobs.cancelled and jobs.replacement and d.current_state==DIRECTOR.State.WAITING_FOR_SCENE,"A cancelled coroutine cannot reset a newer cover")
	await d.reveal(.01); d.free()
	var loading=load("res://scenes/ui/loading_overlay.tscn").instantiate(); root.add_child(loading)
	loading.show_loading("first"); loading.set_progress(.7); loading.set_progress(.2)
	check(loading.target_ratio>=.7,"Loading progress does not visibly move backward")
	loading.hide_loading(); loading.show_loading("replacement"); await frames(3)
	check(loading.visible and loading.is_active,"An obsolete hide cannot remove a new loading overlay")
	await loading.hide_loading(); loading.free()
	var main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(2)
	var sequence: Array=[]
	var observations: Dictionary={}
	var screens: Array=[]
	for label in ["first","dream","last"]:
		var screen:=Probe.new(); screen.name=label; screen.sequence=sequence; screen.main=main; screen.observations=observations; screens.append(screen)
	main._transition_to(screens[0],.02)
	main._transition_to_dream(screens[1],.02)
	main._transition_to(screens[2],.02)
	while main.transition_running: await process_frame
	check(sequence==[&"first",&"dream",&"last"],"Mixed scene and dream requests drain in their original order")
	check(observations.dream and not observations.first and not observations.last,"A queued dream still receives its loading preparation path")
	check(main.current_screen==screens[2] and main.transition_queue.is_empty(),"Queued final scene remains interactive")
	check(main.scene_container.process_mode==Node.PROCESS_MODE_PAUSABLE and not paused,"Scene process mode and global pause are restored")
	main.free(); print("PIXEL_TRANSITION_LIFECYCLE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
