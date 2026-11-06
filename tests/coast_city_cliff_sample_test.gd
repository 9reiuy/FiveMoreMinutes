extends SceneTree
const OUT:="res://.runtime/coast_city_cliff_20261030/validation"
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func red_peak(image: Image,point: Vector2) -> float:
	var peak:=0.
	for y in range(maxi(0,int(point.y)-3),mini(360,int(point.y)+4)):
		for x in range(maxi(0,int(point.x)-3),mini(640,int(point.x)+4)):
			var c:=image.get_pixel(x,y)
			if c.r>c.g*2. and c.r>c.b*1.5: peak=maxf(peak,c.r)
	return peak
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60
	create_timer(120.,true,false,true).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	var display: Control=load("res://scenes/preview/night_coast_city_cliff_display.tscn").instantiate(); root.add_child(display)
	var coast: Node3D=display.coast; coast.external_step=true
	check(bool(coast.get_meta("cliff_platform_sample",false)),"independent cliff sample is selected")
	var city: Node3D=coast.get_node("OffshoreAtmosphere/DistantCity")
	check(city.find_children("Megastructure_*","Node3D",false,false).size()==13,"thirteen tiered megastructures form middle skyline")
	check(city.find_children("FarBlock_*","MeshInstance3D",false,false).size()==28,"far city retains separate haze layer")
	check(coast.get_node("OffshoreAtmosphere").find_children("SoftHorizonSignal_*","MeshInstance3D",false,false).is_empty(),"old floating sea-line lights are absent from sample")
	check(coast.atmosphere.city_signal and coast.atmosphere.signal_nodes.size()==7,"seven aviation beacons bind to actual rooftops")
	var visible: Array=[]
	for node in coast.atmosphere.signal_nodes:
		if node.visible: visible.append(node)
	check(visible.size()==3 and coast.atmosphere.signal_message=="S","chapter sample uses three roof beacons carrying S")
	var top_min:=INF; var top_max:=-INF
	for x in [-5.,-3.,-1.]:
		var h: float=coast.surface_height(x,14.)
		top_min=minf(top_min,h); top_max=maxf(top_max,h)
	check(top_max-top_min<.12 and top_min>2.,"platform has a broad nearly flat top rather than central mound")
	check(coast.surface_height(1.0,16.)-coast.surface_height(3.6,16.)>2.,"steep rock drop separates platform from low beach")
	check(coast.surface_height(3.0,16.)>coast.surface_height(3.6,16.)+.12 and coast.surface_height(3.6,16.)>coast.surface_height(4.1,16.)+.03,"sloped cliff foot descends gradually onto the sand")
	var owned:=true
	for node in city.find_children("*","",true,false):
		if node.owner!=coast: owned=false
	check(owned,"city geometry and roof lights are saved editable nodes")
	var mismatch:=0.
	for y in 40:
		for x in 48:
			mismatch=maxf(mismatch,absf(coast.flow.bed[y*48+x]-coast.surface_height(-12+(x+.5)*.5,-16+(y+.5)*.5)))
	check(mismatch<.00001,"flow bed agrees with authored cliff geometry")
	coast.player_position=Vector3(-3,0,6.3); coast._place_character(); coast.update_camera(0.,true)
	coast.clock=19.3; coast._update_light(); await frames(4); await RenderingServer.frame_post_draw
	var clear: Image=display.view.get_texture().get_image(); clear.save_png(OUT+"/clear_city.png")
	check(coast.camera_reveal>.99,"lookout reveals actual skyline Camera")
	var clear_peak: float=red_peak(clear,coast.camera.unproject_position(visible[1].global_position))
	# Find a long enough real cloud window at the current Camera angle.
	var dark_time:=-1.
	for i in 1800:
		var time: float=i*.02
		if coast.visibility_at(time)<.001 and coast.visibility_at(time+1.5)<.025:
			dark_time=time; break
	check(dark_time>=0.,"cloud has time to transmit all three short flashes")
	coast.atmosphere.configure_city_signal("S"); coast.clock=dark_time; coast._update_light()
	var observations: Array=[]
	for i in 46:
		coast.advance(1./30.)
		await frames(2); await RenderingServer.frame_post_draw
		var image: Image=display.view.get_texture().get_image()
		var peak: float=red_peak(image,coast.camera.unproject_position(visible[1].global_position))
		observations.append({"phase":coast.atmosphere.signal_elapsed,"peak":peak,"cloud":coast.moon_visibility})
		image.save_png(OUT+"/signal_%03d.png"%i)
	var flashes:=0; var was_on:=false; var brightest:=0.
	for observation in observations:
		var on: bool=observation.peak>.09
		brightest=maxf(brightest,observation.peak)
		if on and not was_on: flashes+=1
		was_on=on
	check(flashes==3,"actual GPU rooftop light produces exactly three short flashes")
	check(brightest>clear_peak+.1,"coded aviation light is clearer only under moon cover")
	check(coast.atmosphere.signal_complete,"message completes only after final short pulse")
	var saved_time: float=coast.clock; var saved_phase: float=coast.atmosphere.signal_elapsed
	coast.paused=true; coast.advance(.5)
	check(coast.clock==saved_time and coast.atmosphere.signal_elapsed==saved_phase,"pause freezes water, weather and Morse clock together")
	var original: Node3D=load("res://scenes/preview/night_coast.tscn").instantiate()
	check(not original.has_meta("cliff_platform_sample") and not original.has_node("OffshoreAtmosphere/DistantCity"),"legacy coast asset remains available without overwriting its editable nodes")
	original.free()
	var production_display:=preload("res://scripts/story/chapter_coast.gd").new()
	check(production_display.coast_scene.resource_path=="res://scenes/preview/night_coast_city_cliff_sample.tscn","production chapter display now defaults to the promoted coast")
	production_display.free()
	var report={"checks":checks,"failures":failures,"clear_peak":clear_peak,"brightest_peak":brightest,"decoded_short_flashes":flashes,"observations":observations,"gpu":RenderingServer.get_video_adapter_name()}
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CITY_CLIFF_GPU checks=",checks," failures=",failures," flashes=",flashes," clear=",clear_peak," covered=",brightest)
	display.queue_free(); await frames(6); quit(1 if failures else 0)
