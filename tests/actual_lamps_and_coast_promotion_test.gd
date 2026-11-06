extends SceneTree
const OUT:="res://.runtime/coast_and_actual_lamps_20261030"
var main: Node
var world: Node
var checks:=0
var failures:=0
var measurements: Array=[]
func _initialize() -> void: call_deferred("run")
func frames(n:=5) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func snapshot(label: String) -> Image:
	await frames(8); await RenderingServer.frame_post_draw
	var im: Image=world.camera_3d.get_viewport().get_texture().get_image(); im.save_png(OUT+"/"+label+".png"); return im
func luminance(im: Image,p: Vector2) -> float:
	if not Rect2(2,2,636,356).has_point(p): return -1.
	var total:=0.
	for y in range(int(p.y)-1,int(p.y)+2):
		for x in range(int(p.x)-1,int(p.x)+2):
			var c:=im.get_pixel(x,y); total+=c.r*.2126+c.g*.7152+c.b*.0722
	return total/9.
func tutorial_lamp(zone: int,z: float) -> void:
	world.player.global_position=Vector2(11,z)*32.; world.camera_aim_offset=Vector3.ZERO
	world._update_camera_and_projection(0.); world.set_process(false)
	for i in 3: world.set_training_zone_enabled(i,false)
	var dark:=await snapshot("tutorial_zone%d_off"%zone)
	world.set_training_zone_enabled(zone,true)
	var lit:=await snapshot("tutorial_zone%d_on"%zone)
	var ground_changed:=0; var wall_changed:=0; var ground_samples:=0
	for x in range(3,6):
		for dz in [-1.5,-.5,.5,1.5]:
			var p: Vector2=world.camera_3d.unproject_position(world.get_gameplay_world_position(Vector2(x,z+dz)*32.,.035))
			var a:=luminance(dark,p); var b:=luminance(lit,p)
			if a<0: continue
			ground_samples+=1
			if b-a>.025: ground_changed+=1
	for height in [.5,1.2,1.8]:
		for dz in [-1.,0.,1.]:
			var wall_x: float=0.57 if zone==2 else 1.57 if zone==0 else 2.57
			var p: Vector2=world.camera_3d.unproject_position(world.get_gameplay_world_position(Vector2(wall_x,z+dz)*32.,height))
			var a:=luminance(dark,p); var b:=luminance(lit,p)
			if a>=0 and b-a>.015: wall_changed+=1
	check(ground_changed>=3,"tutorial actual fixture %d changes floor brightness (%d/%d samples)"%[zone,ground_changed,ground_samples])
	check(wall_changed>=1,"tutorial actual fixture %d reaches vertical walls (%d samples)"%[zone,wall_changed])
	measurements.append({"zone":zone,"floor_changed":ground_changed,"wall_changed":wall_changed})
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60; AudioServer.set_bus_mute(0,true)
	create_timer(300.,true,false,true).timeout.connect(func():quit(2)); DirAccess.make_dir_recursive_absolute(OUT)
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(70)
	main.persistent_day_state=main._create_initial_state(); main.chapter_one.start_new(); main.chapter_one.resume(); await frames(110)
	world=main._supported_dream_world
	world.get_node("ChapterTraining").set_process(false); world.get_node("ChapterTraining").set_physics_process(false)
	world.player.set_physics_process(false)
	check(world.get_node_or_null("OfficeDitherLighting/GroundReadabilityFill")==null,"tutorial has no uniform floor-only floodlight")
	var valid:=true
	for holder in world.tutorial_ceiling_lights.get_children():
		var lamp: SpotLight3D=holder.get_node("RoomLight")
		valid=valid and lamp.spot_angle<89. and lamp.shadow_enabled
	check(valid,"every tutorial ceiling lamp has a valid cone and real shadows")
	await tutorial_lamp(0,21.)
	await tutorial_lamp(1,13.)
	await tutorial_lamp(2,5.)
	world.player.global_position=Vector2(11,15)*32.; world._update_camera_and_projection(0.)
	world.set_training_zone_enabled(0,true); world.set_training_zone_enabled(1,false); world.set_training_zone_enabled(2,false)
	await snapshot("tutorial_only_registration")
	world.set_training_zone_enabled(1,true); await snapshot("tutorial_next_room_enabled")
	main._show_dream("basic")
	while main.transition_running: await frames(1)
	world=main._supported_dream_world
	while world.floor_transition_in_progress: await frames(1)
	await frames(40)
	world.player.invulnerability_left=999.; world.player.set_physics_process(false)
	var bounds: Rect2=world._room_bounds_pixels(world.current_room_id,0.)
	var point: Vector2=world.player.global_position; var best:=-INF
	for cell in world.rooms[world.current_room_id].get("usable_cells",[]):
		var p:=Vector2(cell)*32.
		if not world._content_position_is_clear(p,18.,false): continue
		var score: float=minf(minf(p.x-bounds.position.x,bounds.end.x-p.x),minf(p.y-bounds.position.y,bounds.end.y-p.y))
		if score>best: best=score; point=p
	world.player.global_position=point; world._update_camera_and_actor_projection(0.); world.set_process(false); world.set_physics_process(false)
	check(world.get_node_or_null("OfficeDitherLighting/GroundReadabilityFill")==null,"formal floors have no uniform floor-only floodlight")
	var lamps: Array=[]
	for light in world.find_children("*","Light3D",true,false): lamps.append([light,light.visible]); light.hide()
	var off:=await snapshot("formal_actual_lamps_off")
	for pair in lamps: pair[0].visible=pair[1]
	var on:=await snapshot("formal_actual_lamps_on")
	var changed:=0
	for y in range(10,350,2):
		for x in range(10,630,2):
			var a:=off.get_pixel(x,y); var b:=on.get_pixel(x,y)
			if b.get_luminance()-a.get_luminance()>.04: changed+=1
	check(changed>200,"formal existing scene lamps produce readable illumination (%d pixels)"%changed)
	# Restore a real story checkpoint, then use the production route and save path.
	main.chapter_one.state.stage="COAST"; main.chapter_one.resume()
	while main.transition_running: await frames(1)
	var display: Node=main.current_screen; var coast: Node3D=display.coast
	check(coast.scene_file_path=="res://scenes/preview/night_coast_city_cliff_sample.tscn","actual chapter entry selects the promoted cliff/city coast")
	check(coast.has_node("OffshoreAtmosphere/DistantCity") and coast.atmosphere.city_signal,"production coast includes megastructure city and roof beacons")
	check(coast.atmosphere.signal_message=="S" and not display.already_observed,"fresh chapter clue requires actual observation")
	coast.external_step=true; coast.player_position=Vector3(-3,0,6.3); coast._place_character(); coast.update_camera(0.,true)
	var dark_time:=-1.
	for i in 1800:
		var t: float=i*.02
		if coast.visibility_at(t)<.001 and coast.visibility_at(t+1.5)<.025: dark_time=t; break
	check(dark_time>=0.,"promoted coast retains a complete cloud-hidden Morse window")
	coast.atmosphere.configure_city_signal("S"); coast.clock=dark_time; coast._update_light()
	for i in 65: coast.advance(1./30.); await frames(2)
	check(display.already_observed and main.chapter_one.state.stage=="COAST_READ","real rooftop sequence commits the chapter clue through the production route")
	await RenderingServer.frame_post_draw; display.view.get_texture().get_image().save_png(OUT+"/promoted_coast.png")
	main.chapter_one.resume()
	while main.transition_running: await frames(1)
	check(main.current_screen.already_observed and main.current_screen.coast.atmosphere.city_signal,"continue restores the observed clue on the promoted coast")
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"tutorial":measurements,"formal_changed_pixels":changed},"\t"))
	print("ACTUAL_LAMPS_COAST checks=",checks," failures=",failures)
	main.queue_free(); await frames(8); quit(1 if failures else 0)
