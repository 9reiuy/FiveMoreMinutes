extends SceneTree
const PREPARER=preload("res://scripts/dream/floor_exit_render_preparation.gd")
class MockWorld extends Node3D:
	var transition_generation_token:=1
	var floor_token:=1
	var setup_calls:=0
	func get_current_floor_token() -> int: return floor_token
	func setup() -> bool:
		setup_calls+=1
		return true
var checks:=0
var failures:=0
var result: Dictionary={}
var finished:=false
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func begin(world: MockWorld) -> void:
	result=await PREPARER.run(self,world,world.setup,1)
	finished=true
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	if DisplayServer.get_name()=="headless":
		var world:=MockWorld.new(); root.add_child(world)
		var report: Dictionary=await PREPARER.run(self,world,world.setup,1)
		check(not report.cancelled and world.setup_calls==1,"Headless exit still sets up the floor")
		check(not paused and not root.has_node("FloorExitRenderPreparationCover"),"Headless never waits for rendering or leaves cover")
		world.transition_generation_token=2
		report=await PREPARER.run(self,world,world.setup,1)
		check(report.cancelled and world.setup_calls==1,"Headless stale transition cannot set up floor")
		world.queue_free(); await process_frame
	else:
		for variant in 3:
			var world:=MockWorld.new(); root.add_child(world)
			paused=variant==1
			var previous_pause:=paused
			finished=false; begin(world)
			check(paused and root.has_node("FloorExitRenderPreparationCover"),"Root cover owns pause before first draw")
			await RenderingServer.frame_post_draw
			var cover_image:=root.get_texture().get_image()
			cover_image.convert(Image.FORMAT_RGBA8)
			var bytes:=cover_image.get_data()
			var opaque_black:=not bytes.is_empty()
			for pixel in range(0,bytes.size(),4):
				if bytes[pixel]!=0 or bytes[pixel+1]!=0 or bytes[pixel+2]!=0 or bytes[pixel+3]!=255:
					opaque_black=false; break
			check(opaque_black,"Actual output fully covered before changing floor")
			if variant==0: world.floor_token+=1
			elif variant==1: world.transition_generation_token+=1
			else: world.free()
			while not finished: await process_frame
			check(result.cancelled,"Floor replacement/token/free cancels old rendering")
			check(result.cover_released and not root.has_node("FloorExitRenderPreparationCover"),"Cancelled cover released")
			check(paused==previous_pause and result.pause_restored,"Original paused and running states restored")
			if is_instance_valid(world):
				check(world.setup_calls==0,"Stale setup not called")
				world.queue_free(); await process_frame
		paused=false
	print("FLOOR_EXIT_COVER_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
