extends SceneTree
const OUT:="res://.runtime/facing_light_20261030"
var main: Node
var world: Node
var checks:=0
var failures:=0
var results: Array=[]
func _initialize() -> void: call_deferred("run")
func frames(n:=4) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func shot(label: String) -> Image:
	await frames(5); await RenderingServer.frame_post_draw
	var im: Image=world.camera_3d.get_viewport().get_texture().get_image()
	im.save_png(OUT+"/"+label+".png"); return im
func brightness(im: Image) -> float:
	var total:=0.
	for y in range(50,310,2):
		for x in range(80,560,2):
			var c:=im.get_pixel(x,y); total+=c.r*.2126+c.g*.7152+c.b*.0722
	return total/(130*240)
func darkened_pixels(before: Image,after: Image) -> int:
	var count:=0
	for y in before.get_height():
		for x in before.get_width():
			var a:=before.get_pixel(x,y); var b:=after.get_pixel(x,y)
			var av:=a.r*.2126+a.g*.7152+a.b*.0722; var bv:=b.r*.2126+b.g*.7152+b.b*.0722
			if av-bv>.025 and bv<av*.65: count+=1
	return count
func lighting_probe(label: String,_legacy_ambient: float,_legacy_key: float) -> void:
	# Floor/readability coverage now lives in floor_furniture_balance_test.gd.
	# Do not regress to the superseded whole-world 0.015 ambient approach.
	var environment: Environment=world.get_node("Lighting/WorldEnvironment").environment
	var key: DirectionalLight3D=world.get_node("Lighting/KeyLight")
	check(is_equal_approx(environment.ambient_light_energy,.12) and key.light_energy==0.,label+" keeps navigable ground ambient without the old global key")
	check(world.get_node_or_null("OfficeDitherLighting/GroundReadabilityFill")==null,label+" uniform ground floodlight stays retired")
	await shot(label+"_local_lights")
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60; AudioServer.set_bus_mute(0,true)
	create_timer(180.,true,false,true).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(80)
	main.persistent_day_state=main._create_initial_state(); main.chapter_one.start_new(); main.chapter_one.resume(); await frames(110)
	world=main._supported_dream_world
	world.player.global_position=Vector2(11,7)*32.; world.camera_aim_offset=Vector3.ZERO
	world._update_camera_and_projection(0.); world.set_process(false)
	await lighting_probe("tutorial",.18,.08)
	main._show_dream("basic")
	while main.transition_running: await frames(1)
	world=main._supported_dream_world
	while world.floor_transition_in_progress: await frames(1)
	await frames(15)
	world.player.invulnerability_left=999.; world.player.set_physics_process(false)
	world._update_camera_and_actor_projection(0.); world.set_process(false); world.set_physics_process(false)
	await lighting_probe("formal",.17,.025)
	var bounds: Rect2=world._room_bounds_pixels(world.current_room_id,0.)
	var stage_point: Vector2=world.player.global_position
	var best_score:=-INF
	for cell in world.rooms[world.current_room_id].get("usable_cells",[]):
		var candidate:=Vector2(cell)*32.
		if not world._content_position_is_clear(candidate,18.,false): continue
		var score: float=minf(minf(candidate.x-bounds.position.x,bounds.end.x-candidate.x),minf(candidate.y-bounds.position.y,bounds.end.y-candidate.y))
		if score>best_score: best_score=score; stage_point=candidate
	check(is_finite(best_score),"face Camera sample uses a clear position inside the actual room")
	world.player.global_position=stage_point; world._update_camera_and_actor_projection(0.)
	var enemy=world._spawn_regular_employee(world.current_room_id,world.player.global_position,&"employee",false,"")
	enemy.sky_drop_active=false; enemy.knockdown_height=0.; enemy.set_physics_process(false); enemy.set_process(false)
	enemy.set_player_vision_visible(true); enemy.set_room_runtime_active(true); enemy.equip_weapon("basic")
	enemy.set_physics_process(false); enemy.set_process(false)
	world.player.hide()
	var ref: WeakRef=enemy.get_meta(&"depth_visual_bridge"); var bridge=ref.get_ref()
	bridge.set_meta(&"test_legacy_character_sync_every_frame",true)
	var position_before: Vector2=enemy.position; var collider_before: Vector2=enemy.body_collision.position
	# Use both the tutorial and formal camera orientations, with opposite movement.
	var camera_transform: Transform3D=world.camera_3d.transform
	for yaw in [45.,90.]:
		world.camera_3d.rotation_degrees=Vector3(-42.59,yaw,0)
		world.camera_3d.position=Vector3(14.142136*sin(deg_to_rad(yaw)),13,14.142136*cos(deg_to_rad(yaw)))
		for i in 8:
			var heading:=Vector2.RIGHT.rotated(i*PI/4.)
			enemy.hostile=true; enemy.state=enemy.State.INVESTIGATE_GUNSHOT
			enemy.gunshot_threat_position=enemy.global_position+heading*120.
			enemy.velocity=-heading*80.; enemy._update_weapon_aim()
			for tick in 4: enemy._update_human_animation(1./60.)
			check(enemy.last_facing_direction.dot(heading)>.999,"armed body follows muzzle rather than opposite motion yaw %d heading %d"%[yaw,i])
			bridge._process(0.)
			var index: int=bridge.source_roots.find(enemy.character_visual)
			var clone: Node2D=bridge.clone_roots[index]
			var projected: float=cos(enemy.weapon_root.global_rotation+bridge.weapon_capture_rotation_delta)
			check(absf(projected)<.001 or clone.transform.determinant()*projected*float(enemy.get_meta(&"character_authored_facing_x"))>0.,"captured face and projected muzzle share their side yaw %d heading %d"%[yaw,i])
			await shot("facing_%d_%d"%[yaw,i])
			bridge.render_viewport.get_texture().get_image().save_png(OUT+"/actor_%d_%d.png"%[yaw,i])
	world.camera_3d.transform=camera_transform
	# The last telegraph frames must retain the committed direction as well.
	enemy.state=enemy.State.ATTACK_PLAYER; enemy.hostile=true
	enemy.has_last_known_target_position=true; enemy.last_known_target_position=enemy.position+Vector2(100,0)
	enemy.ranged_attack_windup_pending=true; enemy.ranged_attack_windup_left=.05
	enemy.ranged_attack_target_snapshot=enemy.position+Vector2(-100,0)
	enemy._update_weapon_aim(); enemy._update_human_animation(.016)
	check(enemy.last_facing_direction.x<-.99 and enemy.character_visual.scale.x>0,"committed leftward shot keeps authored left face when tracked target moves right")
	check(enemy.position==position_before and enemy.body_collision.position==collider_before,"facing changes preserve actor and collision origins")
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"lighting":results},"\t"))
	print("DARK_FACING checks=",checks," failures=",failures)
	main.queue_free(); await frames(8); quit(1 if failures else 0)
