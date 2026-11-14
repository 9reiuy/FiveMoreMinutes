extends SceneTree
## Identical actual Camera/pose/light energy; only the real lamp colour changes.
var lab: Control
var sample: Control
var out := "res://.runtime/character_rim_20261113/colors"
var failures: Array[String] = []
var measurements: Dictionary = {}
func _init() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); print("FAIL ",label)
func capture(name: String) -> Image:
	await frames(10); await RenderingServer.frame_post_draw
	var result: Image = sample.display.world_viewport.get_texture().get_image()
	result.save_png(out.path_join(name+".png")); return result
func added_rgb(before: Image, after: Image) -> Vector3:
	var sum := Vector3.ZERO
	# Only the two real actors; excludes the floor, fixture and HUD.
	for y in range(70,182):
		for x in range(280,410):
			var a := after.get_pixel(x,y); var b := before.get_pixel(x,y)
			var delta := Vector3(maxf(a.r-b.r,0),maxf(a.g-b.g,0),maxf(a.b-b.b,0))
			if maxf(delta.x,maxf(delta.y,delta.z)) > 3.1/255.0: sum += delta
	return sum
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(90.0,true,false,true).timeout.connect(func(): quit(2))
	Engine.max_fps = 60; DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var controller := root.get_node("DreamTimeController")
	controller.end_tactical_planning(); controller.clear_reaction_time(); controller.set_slow_time_enabled(false)
	lab = load("res://scenes/testing/CharacterRimLab.tscn").instantiate(); root.add_child(lab)
	await frames(2); sample=lab.presentation
	for i in 600:
		if sample.ready_world: break
		await frames(1)
	check(sample.ready_world,"actual Camera sample ready")
	if not sample.ready_world: quit(2); return
	sample.set_frozen(true); sample.world.process_mode=Node.PROCESS_MODE_DISABLED
	controller.set_process(false); controller.set_physics_process(false); Engine.time_scale=0.0
	sample.set_blocker(false); sample.set_light(1)
	var colors := {"white":Color(1,1,1),"red":Color(1,0.03,0.02),"blue":Color(0.02,0.12,1),"amber":Color(1,0.44,0.05)}
	for key in colors:
		sample.lamp.light_color=colors[key]
		sample.set_enabled(false); var before := await capture(key+"_before")
		sample.set_enabled(true); var after := await capture(key+"_after")
		var rgb := added_rgb(before,after)
		measurements[key]={"added_rgb":[rgb.x,rgb.y,rgb.z],"light_energy":sample.lamp.light_energy,"light_color":str(colors[key])}
		check(rgb.length()>1.0,"actual rim responds to "+key+" lamp")
	var red: Array = measurements.red.added_rgb; var blue: Array = measurements.blue.added_rgb; var amber: Array = measurements.amber.added_rgb
	check(red[0]>red[1]*2.0 and red[0]>red[2]*2.0,"red lamp produces red-dominant rim")
	check(blue[2]>blue[0]*2.0 and blue[2]>blue[1]*1.5,"blue lamp produces blue-dominant rim")
	check(amber[0]>amber[1]*1.1 and amber[1]>amber[2]*1.5,"warm lamp produces amber rim")
	var result := {"failures":failures,"measurements":measurements,"renderer":RenderingServer.get_current_rendering_method(),"camera":"640x360 actual production Camera","scope":"four colours, identical pose/location/lamp energy; positive added rim RGB compared against original under same lamp","audio_master_muted":AudioServer.is_bus_mute(0)}
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CHARACTER_RIM_COLORS ",JSON.stringify(result))
	lab.free(); Engine.time_scale=1.0; await frames(10); quit(0 if failures.is_empty() else 1)
