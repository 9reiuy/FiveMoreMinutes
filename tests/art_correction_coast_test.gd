extends SceneTree
const OUT:="res://.runtime/art_corrections_20261103/coast"
var main: Node
var coast: Node3D
var checks:=0
var failures: Array[String]=[]
var measurements: Dictionary={}
func _initialize() -> void: call_deferred("run")
func frames(n:=6) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1; print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func snap(label: String) -> void:
	await frames(8); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+label+".png")
func rock_samples() -> Dictionary:
	var im: Image=coast.camera.get_viewport().get_texture().get_image()
	var sum:=Color(0,0,0,0); var count:=0
	for x in [-5.,-4.5,-4.]:
		for z in [8.,9.,10.,11.]:
			var p:=Vector3(x,coast.surface_height(x,z)+.03,z)
			var screen: Vector2=coast.camera.unproject_position(coast.to_global(p))
			if not Rect2(Vector2.ONE,Vector2(im.get_size())-Vector2.ONE*2.).has_point(screen): continue
			sum+=im.get_pixelv(Vector2i(screen)); count+=1
	var mean:=sum/float(maxi(count,1))
	return {"samples":count,"mean_rgb":[mean.r,mean.g,mean.b],"luminance":mean.get_luminance()}
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps=60; root.size=Vector2i(1280,720); AudioServer.set_bus_mute(0,true)
	create_timer(200.,true,false,true).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(80)
	main.persistent_day_state=main._create_initial_state(); main.chapter_one.start_new()
	main.chapter_one.state.stage="COAST"; main.chapter_one.resume()
	while main.transition_running: await process_frame
	await frames(30)
	var display: Node=main.current_screen; coast=display.coast
	check(coast.scene_file_path=="res://scenes/preview/night_coast_city_cliff_sample.tscn","formal chapter uses the revised cliff")
	check(coast.layout.vertices.size()==261*131,"saved height grid is intact")
	check(coast.atmosphere.city_signal and not display.already_observed,"fresh chapter still requires observing the beacon")
	coast.external_step=true; coast.player_position=Vector3(-3,0,6.3); coast._place_character(); coast.update_camera(0.,true)
	var times: Dictionary={}
	for i in 1800:
		var t:=i*.02; var v: float=coast.visibility_at(t)
		if v>.99 and not times.has("clear"): times["clear"]=t
		if v<.001 and coast.visibility_at(t+1.5)<.025 and not times.has("clouded"): times["clouded"]=t
	check(times.size()==2,"clear moon and clouded beacon window remain")
	for state in times:
		coast.clock=times[state]; coast._update_light(); await snap(state)
		measurements[state]=rock_samples()
		check(measurements[state].samples>=5 and measurements[state].luminance>.12,"rock retains readable color in "+state)
	coast.player_position=Vector3(-3,0,12); coast._place_character(); coast.update_camera(0.,true)
	var begin: Vector3=coast.player_position
	coast.external_step=false; Input.action_press("move_up")
	for i in 4:
		await create_timer(.8).timeout; await snap("walk_%d"%i)
	Input.action_release("move_up"); coast.external_step=true
	check(coast.player_position.z<begin.z-2.,"ordinary movement walks toward the cliff edge")
	check(absf(coast.player_position.y-coast.surface_height(coast.player_position.x,coast.player_position.z))<.01,"walking stays on the saved cliff surface")
	coast.player_position=Vector3(-3,0,6.3); coast._place_character(); coast.update_camera(0.,true)
	coast.atmosphere.configure_city_signal("S"); coast.clock=times["clouded"]; coast._update_light()
	for i in 65: coast.advance(1./30.); await frames(2)
	check(display.already_observed and main.chapter_one.state.stage=="COAST_READ","actual rooftop sequence saves the chapter clue")
	await snap("beacon_observed")
	main.chapter_one.resume()
	while main.transition_running: await process_frame
	check(main.current_screen.already_observed and main.current_screen.coast.atmosphere.city_signal,"continue restores the observed clue")
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rock":measurements,"scope":"Production Camera and ordinary movement; not a performance acceptance."},"\t"))
	main.queue_free(); await frames(8); print("COAST checks=",checks," failures=",failures); quit(1 if failures else 0)
