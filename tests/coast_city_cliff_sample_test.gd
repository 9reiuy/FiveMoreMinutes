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
func red_peak(image: Image,point: Vector2,warm:=false) -> float:
	var peak:=0.
	for y in range(maxi(0,int(point.y)-3),mini(image.get_height(),int(point.y)+4)):
		for x in range(maxi(0,int(point.x)-3),mini(image.get_width(),int(point.x)+4)):
			var c:=image.get_pixel(x,y)
			if (warm and c.r>=c.g*.9) or (not warm and c.r>c.g*2. and c.r>c.b*1.5): peak=maxf(peak,c.r)
	return peak
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60
	create_timer(120.,true,false,true).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	var display: Control=load("res://scenes/preview/night_coast_city_cliff_display.tscn").instantiate(); root.add_child(display)
	var coast: Node3D=display.coast; coast.external_step=true
	if coast.atmosphere.static_horizon:
		await check_static_coast(display,coast)
		return
	check(bool(coast.get_meta("cliff_platform_sample",false)),"independent cliff sample is selected")
	var city: Node3D=coast.get_node("OffshoreAtmosphere/DistantCity")
	check(city.get_node("LandmarkTowers").get_child_count()==13,"thirteen landmark towers form the middle skyline")
	check(city.get_node("FarDistricts").get_child_count()==18 and city.get_node("HarbourFront").get_child_count()==17,"the skyline has separate harbour and distant rows")
	check(coast.get_node("OffshoreAtmosphere").find_children("SoftHorizonSignal_*","MeshInstance3D",false,false).is_empty(),"old floating sea-line lights are absent from sample")
	var shore_channel: bool=coast.atmosphere.horizon_signal
	check(coast.atmosphere.city_signal and coast.atmosphere.signal_nodes.size()==(6 if shore_channel else 7),"the selected physical Morse sources bind to the scene")
	var visible: Array=[]
	for node in coast.atmosphere.signal_nodes:
		if node.visible: visible.append(node)
	check(visible.size()==(6 if shore_channel else 3) and coast.atmosphere.signal_message=="S","the selected source channel carries S")
	var top_min:=INF; var top_max:=-INF
	for x in [-5.,-3.,-1.]:
		var h: float=coast.surface_height(x,14.)
		top_min=minf(top_min,h); top_max=maxf(top_max,h)
	if coast.right_shore:
		check(top_min>0.0 and top_max>top_min+1.0,"rock terraces rise beside the right shore route")
		check(coast.surface_height(-3.0,23.)>coast.surface_height(-3.0,6.3)+1.5,"approach descends toward the low waterfront")
		check(coast.surface_height(8.0,6.3)>coast.surface_height(-3.0,6.3)+2.0,"higher rock shore supports the buildings on the right")
	else:
		check(top_max-top_min<.12 and top_min>.1 and top_max<.8,"beach approach is broad and low")
		check(coast.surface_height(-3.0,23.)>top_max+1.5,"rock approach descends onto the beach")
		check(absf(coast.surface_height(-9.0,6.3)-coast.surface_height(3.0,6.3))<.15,"shore stays low across the walking area")
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
	var clear_peak: float=red_peak(clear,coast.camera.unproject_position(visible[1].global_position),shore_channel)
	# Find a long enough real cloud window at the current Camera angle.
	var dark_time:=-1.
	for i in 1800:
		var time: float=i*.02
		if coast.visibility_at(time)<.001 and coast.visibility_at(time+1.5)<.025:
			dark_time=time; break
	check(dark_time>=0.,"cloud has time to transmit all three short flashes")
	coast.atmosphere.configure_city_signal("S"); coast.clock=dark_time; coast._update_light()
	var observations: Array=[]
	var sequence_finished := false
	for i in 52:
		coast.advance(1./30.)
		sequence_finished = sequence_finished or coast.atmosphere.signal_complete
		await frames(2); await RenderingServer.frame_post_draw
		var image: Image=display.view.get_texture().get_image()
		var peak: float=red_peak(image,coast.camera.unproject_position(visible[1].global_position),shore_channel)
		observations.append({"phase":coast.atmosphere.signal_elapsed,"peak":peak,"cloud":coast.moon_visibility})
		image.save_png(OUT+"/signal_%03d.png"%i)
	var flashes:=0; var was_on:=false; var brightest:=0.
	for observation in observations:
		var on: bool=observation.peak>(.55 if shore_channel else .09)
		brightest=maxf(brightest,observation.peak)
		if on and not was_on: flashes+=1
		was_on=on
	check(flashes==3,"actual GPU signal produces exactly three short flashes")
	check(brightest>clear_peak+.1,"coded aviation light is clearer only under moon cover")
	check(sequence_finished,"message completes after the final short pulse")
	var saved_time: float=coast.clock; var saved_phase: float=coast.atmosphere.signal_elapsed
	coast.paused=true; coast.advance(.5)
	check(coast.clock==saved_time and coast.atmosphere.signal_elapsed==saved_phase,"pause freezes water, weather and Morse clock together")
	var original: Node3D=load("res://scenes/preview/night_coast.tscn").instantiate()
	check(not original.has_meta("cliff_platform_sample") and not original.has_node("OffshoreAtmosphere/DistantCity"),"legacy coast asset remains available without overwriting its editable nodes")
	original.free()
	var production_display: Control=load("res://scripts/story/chapter_coast.gd").new()
	check(production_display.coast_scene.resource_path=="res://scenes/preview/night_coast_city_cliff_sample.tscn","production chapter display now defaults to the promoted coast")
	production_display.free()
	var report={"checks":checks,"failures":failures,"clear_peak":clear_peak,"brightest_peak":brightest,"decoded_short_flashes":flashes,"observations":observations,"gpu":RenderingServer.get_video_adapter_name()}
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CITY_CLIFF_GPU checks=",checks," failures=",failures," flashes=",flashes," clear=",clear_peak," covered=",brightest)
	display.queue_free(); await frames(6); quit(1 if failures else 0)

func check_static_coast(display: Control,coast: Node3D) -> void:
	check(display.native_resolution and display.view.size==display.get_window().size,"coastal preview uses window-native resolution")
	check(coast.atmosphere.signal_message=="LOVE" and coast.atmosphere.signals.size()==12,"LOVE occupies twelve fixed coastal symbols")
	check(preload("res://scripts/preview/coast_morse_sequence.gd").code_for("LOVE")==".-.. --- ...- .","LOVE has the correct international Morse symbols")
	check(coast.atmosphere.sequence.pulses.is_empty(),"fixed coastal pattern has no timed pulse sequence")
	var groups:=PackedStringArray()
	var previous_letter:=""
	var constants: Array=[]
	var ordered:=true
	var previous_x:=-INF
	for node: MeshInstance3D in coast.atmosphere.signal_nodes:
		var letter: String=node.get_meta(&"morse_letter")
		if letter!=previous_letter: groups.append(""); previous_letter=letter
		groups[-1]+=String(node.get_meta(&"morse_symbol"))
		constants.append(node.material_override.get_shader_parameter(&"power"))
		ordered=ordered and node.position.x>previous_x and node.position.z< -1000.0
		previous_x=node.position.x
	check(" ".join(groups)==".-.. --- ...- ." and ordered,"fixed dots and dashes run left to right in four letter groups")
	var steady:=true
	for time in [0.0,.24,.48,.96,1.20,9.0,19.3,24.4,30.4,60.0]:
		coast.clock=time; coast._update_light()
		for i in constants.size(): steady=steady and coast.atmosphere.signals[i].get_shader_parameter(&"power")==constants[i]
	check(steady,"emitter radiance stays constant across clear and covered weather")
	var roof_off:=true
	for node in coast.get_node("OffshoreAtmosphere/DistantCity").find_children("RoofAviationBeacon","MeshInstance3D",true,false): roof_off=roof_off and not node.visible
	check(roof_off,"rooftop Morse emitters remain inactive in this preview")
	coast.player_position=Vector3(-3,0,6.3); coast._place_character(); coast.update_camera(0.0,true)
	coast.clock=19.3; coast._update_light(); await frames(16); await RenderingServer.frame_post_draw
	display.view.get_texture().get_image().save_png(OUT+"/ambient_light.png")
	check(not display.already_observed,"ordinary light does not complete the coastal observation")
	coast.clock=0.0; coast._update_light(); await frames(100); await RenderingServer.frame_post_draw
	display.view.get_texture().get_image().save_png(OUT+"/cloud_cover.png")
	check(display.already_observed,"cloud cover and the normal viewing duration complete observation")
	check(display.return_hint.label.text.contains("远岸光点") and not display.return_hint.label.text.contains("短闪"),"observation hint describes steady coastal light")
	var clock: float=coast.clock; coast.paused=true; coast.advance(.5)
	check(coast.clock==clock,"pause retains the weather clock")
	var exits:=PackedInt32Array([0])
	display.completed.connect(func():exits[0]+=1)
	var key:=InputEventKey.new(); key.physical_keycode=KEY_E; key.pressed=true
	display._unhandled_input(key)
	check(exits[0]==1 and display.leaving,"normal E input completes the observation screen")
	var id:=display.get_instance_id(); display.queue_free(); await frames(6)
	check(not is_instance_id_valid(id),"native coastal display and optics release")
	var result:={"checks":checks,"failures":failures,"mode":"constant spatial LOVE","code":".-.. --- ...- .","constant_power":constants}
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("STATIC_COAST_CONTRACT ",result)
	quit(1 if failures else 0)
