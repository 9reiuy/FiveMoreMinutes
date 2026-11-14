extends SceneTree
const OUTPUT := "res://.runtime/surface_blood_20261113/review"
var sample: Control
var checks: Dictionary = {}

func _initialize() -> void:
	root.size = Vector2i(640,360)
	create_timer(110.0,true,false,true).timeout.connect(func(): print("BLOOD_REVIEW_TIMEOUT"); quit(3))
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	AudioServer.set_bus_mute(0,true)
	sample = load("res://scenes/testing/BloodSurfacePreview.tscn").instantiate(); root.add_child(sample)
	while not sample.ready_world: await process_frame
	var controller := root.get_node_or_null("DreamTimeController")
	if controller != null:
		controller.end_tactical_planning(); controller.clear_reaction_time(); controller.set_slow_time_enabled(false)
		controller.set_process(false); controller.set_physics_process(false)
	Engine.time_scale = 1.0
	sample.world.player.set_physics_process(false)
	sample.hide_hud = true; sample._update_label()
	await _frames(12)
	_capture("before.png")
	var names: Array[String] = []
	for receiver in sample.blood.receivers: names.append(receiver.name)
	print("BLOOD_RECEIVERS ",JSON.stringify(names))
	for mode in 4:
		sample.set_preset(mode)
		await _frames(3)
		for hit in 3:
			sample.hit_target()
			await _frames(10)
		await _frames(55)
		_capture("preset_%d.png" % mode)
		print("BLOOD_PRESET ",mode," ",JSON.stringify(sample.blood.stats()))
	sample.set_dark(true); await _frames(15); _capture("dark.png")
	var file := FileAccess.open(OUTPUT+"/diagnostic.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"stats":sample.blood.stats(),"events":sample.world.accepted_blood_events,"receivers":names},"\t")); file.close()
	sample.free(); await _frames(3)
	quit(0)

func _frames(count: int) -> void:
	for i in count: await process_frame
	await RenderingServer.frame_post_draw

func _capture(name: String) -> void:
	var image: Image = sample.display.world_viewport.get_texture().get_image()
	image.save_png(OUTPUT+"/"+name)
