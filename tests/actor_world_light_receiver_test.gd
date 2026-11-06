extends SceneTree
const OUT:="res://.runtime/actor_world_light_20261030"
var world: Node
var main: Node
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n:=8) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func shot(label: String) -> Image:
	await frames(10); await RenderingServer.frame_post_draw
	var im: Image=world.camera_3d.get_viewport().get_texture().get_image(); im.save_png(OUT+"/"+label+".png"); return im
func measure(im: Image,point: Vector2) -> float:
	var total:=0.; var count:=0
	for y in range(int(point.y)-10,int(point.y)+10):
		for x in range(int(point.x)-8,int(point.x)+8):
			if x<0 or y<0 or x>=im.get_width() or y>=im.get_height(): continue
			var c:=im.get_pixel(x,y); total+=c.r*.2126+c.g*.7152+c.b*.0722; count+=1
	return total/maxi(count,1)
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60; AudioServer.set_bus_mute(0,true)
	create_timer(180.,true,false,true).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(70)
	main.persistent_day_state=main._create_initial_state(); main._show_dream("basic")
	while main.transition_running: await frames(1)
	world=main._supported_dream_world
	while world.floor_transition_in_progress: await frames(1)
	await frames(40)
	var bounds: Rect2=world._room_bounds_pixels(world.current_room_id,0.)
	var best:=-INF; var point: Vector2=world.player.global_position
	for cell in world.rooms[world.current_room_id].get("usable_cells",[]):
		var candidate:=Vector2(cell)*32.
		if not world._content_position_is_clear(candidate,24.,false): continue
		var score: float=minf(minf(candidate.x-bounds.position.x,bounds.end.x-candidate.x),minf(candidate.y-bounds.position.y,bounds.end.y-candidate.y))
		if score>best: best=score; point=candidate
	world.player.global_position=point; world.player.invulnerability_left=999.; world.player.set_physics_process(false)
	world._update_camera_and_actor_projection(0.); world.set_process(false); world.set_physics_process(false)
	for actor in world.enemy_root.get_children():
		if actor is EmployeeEnemy: actor.set_physics_process(false); actor.set_process(false)
	var enemy=world._spawn_regular_employee(world.current_room_id,point+Vector2(40,0),&"employee",false,"")
	enemy.sky_drop_active=false; enemy.set_player_vision_visible(true); enemy.set_room_runtime_active(true); enemy.set_process(false); enemy.set_physics_process(false)
	var bridges: Array=[world.player_depth_bridge,enemy.get_meta(&"depth_visual_bridge").get_ref()]
	var volumes: Array=[]
	for bridge in bridges:
		bridge.set_meta(&"test_legacy_character_sync_every_frame",true)
		check(not bridge.lit_material.shader.code.contains("render_mode shadows_disabled"),"character receiver uses actual scene shadows")
		check(float(bridge.lit_material.get_shader_parameter("character_emission_strength"))<=.011,"character visibility floor no longer washes out shadows")
		check(bridge.volume_shadow!=null,"existing body shadow caster remains")
		volumes.append(bridge.volume_shadow)
	var lights: Array=[]
	for light in world.find_children("*","Light3D",true,false):
		if light.name=="GroundReadabilityFill": continue
		lights.append([light,light.visible]); light.hide()
	var center:=Vector3(point.x/32.,.8,point.y/32.)
	var lamp:=OmniLight3D.new(); lamp.name="ReceiverProofLamp"; lamp.position=center+Vector3(-2.5,1.8,1.2)
	lamp.light_energy=3.; lamp.omni_range=8.; lamp.omni_attenuation=.6; lamp.light_color=Color(1.,.78,.48); lamp.shadow_enabled=true
	lamp.shadow_bias=.02; lamp.shadow_normal_bias=.05; lamp.light_cull_mask=1|2|4|8; lamp.shadow_caster_mask=1|2|8
	world.add_child(lamp)
	var blocker:=MeshInstance3D.new(); blocker.name="ReceiverProofOccluder"; var box:=BoxMesh.new(); box.size=Vector3(.16,3.,3.)
	blocker.mesh=box; blocker.position=center+Vector3(-1.1,.4,.52); blocker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	world.add_child(blocker)
	# Keep the controlled blocker comparison free of a body's own volume, then
	# restore every volume before the actual-scene screenshot.
	for volume in volumes: volume.hide(); volume.get_parent().set_process(false); volume.get_parent().set_physics_process(false)
	blocker.hide(); lamp.hide(); var dark:=await shot("lamp_off")
	lamp.show(); var lit:=await shot("lamp_on")
	blocker.show(); var shadow:=await shot("occluded")
	var measurements: Array=[]
	for i in 2:
		var actor: Node2D=world.player if i==0 else enemy
		var p: Vector2=world.camera_3d.unproject_position(world.get_gameplay_world_position(actor.global_position,.85))
		var a:=measure(dark,p); var b:=measure(lit,p); var c:=measure(shadow,p)
		print("ACTOR_LIGHT ",i," off=",a," lit=",b," occluded=",c," pixel=",p)
		check(b>a+.015,"real lamp increases actor %d brightness"%i)
		check(b>c+.01,"real occluder casts shadow on actor %d"%i)
		measurements.append({"actor":i,"off":a,"lit":b,"shadow":c,"pixel_x":p.x,"pixel_y":p.y})
	blocker.queue_free(); lamp.queue_free()
	for pair in lights: pair[0].visible=pair[1]
	for bridge in bridges: bridge.set_process(true); bridge.set_physics_process(true); bridge._process(0.)
	await shot("actual_room_lighting")
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"actors":measurements},"\t"))
	print("ACTOR_WORLD_LIGHT checks=",checks," failures=",failures)
	main.queue_free(); await frames(8); quit(1 if failures else 0)
