extends SceneTree
const OUT:="res://.runtime/shared_wall_dash_20261102"
const WALK=preload("res://tests/support/world_walk_input.gd")
var main: Node
var world: Node
var checks:=0
var failures:=0
var images:=0
var capture_times: Array=[]
var no_record:=false
var ablation:=""
class DormantDashVisual extends Node3D:
	func begin(_world,_player,_start,_end)->void: pass
	func sync_pose(_world,_player,_progress,_alpha,_refreshed)->void: pass
	func finish(_end,_killed)->void: pass
	func fade(_alpha)->void: pass
func _initialize() -> void: call_deferred("run")
func frames(n:=5) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func screenshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	world.camera_3d.get_viewport().get_texture().get_image().save_png(OUT+"/"+label+".png")
func freeze_enemies() -> void:
	for actor in world.enemy_root.get_children():
		if actor is Node2D: actor.set_physics_process(false)
func choose_wall() -> Dictionary:
	var player: Node=world.player
	var offset: Vector2=player.body_collision.global_position-player.global_position
	var phase: Node=player.phase_dash
	var best: Dictionary={}; var score:=-INF
	var facing: Vector3=world.global_basis.inverse()*world.camera_3d.global_basis.z
	var toward:=Vector2(facing.x,facing.z).normalized()
	for key in world.wall_edges:
		if world.SHARED_WALL_BREACH.wall_for_key(world,key)==null: continue
		var edge: Dictionary=world.wall_edges[key]
		var center: Vector2=world._edge_gameplay_position(edge)
		for sign_value in [-1.0,1.0]:
			var direction: Vector2=(Vector2.DOWN if edge.axis=="H" else Vector2.RIGHT)*sign_value
			var start: Vector2=center-direction*player.dash_distance*.46-offset
			var end: Vector2=start+direction*player.dash_distance
			if not phase._standable(start,player.collision_mask) or not phase._standable(end,player.collision_mask): continue
			if phase._supported_travel_distance(start,direction,player.dash_distance)<player.dash_distance-0.1: continue
			var a: int=world._room_id_at_position(start); var b: int=world._room_id_at_position(end)
			if a<0 or b<0 or a==b: continue
			var value: float=-direction.dot(toward)*100.0
			if value>score: score=value; best={"key":key,"start":start,"end":end,"direction":direction,"a":a,"b":b}
	return best
func prepare_world() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60; AudioServer.set_bus_mute(0,true)
	no_record=OS.get_cmdline_user_args().has("--no-record")
	if OS.get_cmdline_user_args().has("--no-wall-vfx"): ablation="no_vfx"
	if OS.get_cmdline_user_args().has("--no-break"): ablation="no_break"
	if OS.get_cmdline_user_args().has("--no-local-shadow"): ablation="no_local_shadow"
	if OS.get_cmdline_user_args().has("--no-phase-visual"): ablation="no_phase_visual"
	if OS.get_cmdline_user_args().has("--legacy-casters"):
		ablation+="_legacy_casters"
		node_added.connect(func(node: Node) -> void:
			if node.has_method("get_current_floor_token"): node.set_meta(&"test_legacy_wall_shadow_batches",true))
	DirAccess.make_dir_recursive_absolute(OUT+"/motion")
	create_timer(300.,true,false,true).timeout.connect(func():quit(2))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(70)
	main.persistent_day_state=main._create_initial_state(); seed(424242); main._show_dream("basic")
	while main.transition_running: await frames(1)
	world=main._supported_dream_world
	while world.floor_transition_in_progress: await frames(1)
	await frames(35); freeze_enemies()
	world.set_meta(&"test_profile_shared_wall_breach",true)
	var player: Node=world.player
	player.invulnerability_left=999.; player.set_physics_process(false)
	player.phase_dash=preload("res://scripts/entities/player_phase_dash.gd").new()
	player.phase_dash.name="PhaseDash"; player.add_child(player.phase_dash); player.phase_dash.configure(player)

func run() -> void:
	await prepare_world()
	if OS.get_cmdline_user_args().has("--no-local-shadow"):
		RenderingServer.frame_pre_draw.connect(func() -> void:
			if not is_instance_valid(world): return
			var batches: Node=world.wall_root.get_node_or_null("WallShadowBatches")
			if batches==null: return
			for id in batches.local_originals:
				var mesh: Node=instance_from_id(id)
				if is_instance_valid(mesh): mesh.hide())
	var player: Node=world.player
	if OS.get_cmdline_user_args().has("--no-phase-visual"):
		player.phase_dash.effect=DormantDashVisual.new(); world.floor_root.add_child(player.phase_dash.effect)
	var selection:=choose_wall()
	check(not selection.is_empty(),"actual Main floor has a shared wall with legal dash endpoints")
	if selection.is_empty(): main.queue_free(); await frames(5); quit(1); return
	world.set_current_room_id(selection.a); world.activate_room(selection.a)
	player.global_position=selection.start; player.velocity=Vector2.ZERO
	world.camera_aim_offset=Vector3.ZERO; world._update_camera_and_actor_projection(0.0)
	await frames(20); freeze_enemies()
	var count_before: int=world.wall_edges.size()
	var offset: Vector2=player.body_collision.global_position-player.global_position
	var queries: Array[String]=world.query_dash_breakable_walls(selection.start+offset,selection.end+offset,8.0)
	player.phase_dash.find_landing(selection.start,selection.direction,player.dash_distance,player.collision_mask)
	check(queries.has(selection.key) and world.wall_edges.size()==count_before and world.broken_shared_walls.is_empty(),"query and landing search leave the actual wall intact")
	await screenshot("before")
	var motion:=InputEventMouseMotion.new(); motion.position=root.get_visible_rect().size*.5; Input.parse_input_event(motion); await frames(2)
	player.movement_enabled=true; player.set_attacking_enabled(true); player.dash_charges=1; player.dash_cooldown_left=0.0
	player.set_physics_process(true); WALK.hold(player,selection.direction)
	var key:=InputEventKey.new(); key.keycode=KEY_SPACE; key.physical_keycode=KEY_SPACE; key.pressed=true; Input.parse_input_event(key)
	if ablation.begins_with("no_vfx"): world.set_meta(&"test_disable_shared_wall_vfx",true)
	if ablation=="no_break": world.set_meta(&"test_disable_shared_wall_breaches",true)
	var active_seen:=false; var effects_seen:=false
	var frame_samples: Array=[]; var previous_tick:=Time.get_ticks_usec()
	for i in 100:
		await frames(1)
		var now:=Time.get_ticks_usec(); frame_samples.append(float(now-previous_tick)/1000.0); previous_tick=now
		active_seen=active_seen or player.is_phase_dash_active()
		effects_seen=effects_seen or not get_nodes_in_group(&"shared_wall_break_effects").is_empty()
		if i==1:
			WALK.release(); key.pressed=false; Input.parse_input_event(key)
		if i<65 and not no_record:
			await RenderingServer.frame_post_draw
			capture_times.append(Time.get_ticks_msec())
			world.camera_3d.get_viewport().get_texture().get_image().save_png(OUT+"/motion/%03d.png"%images); images+=1
		if i==14 and not no_record: await screenshot("impact")
	if not ablation.is_empty():
		frame_samples.sort()
		check(active_seen,"diagnostic uses an actual Space dash")
		check(world.current_room_id==selection.b,"diagnostic crosses into the same target room")
		check(world.broken_shared_walls.has(selection.key) if ablation!="no_break" else world.broken_shared_walls.is_empty(),"diagnostic destruction mode matches actual topology")
		var report:={"mode":ablation,"active_seen":active_seen,"room":world.current_room_id,"checks":checks,"failures":failures,"selection":selection,"broken":world.broken_shared_walls.keys(),"interval_ms":frame_samples,"max_ms":frame_samples.back(),"p95_ms":frame_samples[94],"profile":world.last_shared_wall_breach_profile,"scope":"Actual Space, first dash and same target-room activation; no image readback in sampled interval; diagnostic only"}
		FileAccess.open(OUT+"/ablation_"+ablation+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		print("WALL_ABLATION ",JSON.stringify(report))
		main.queue_free(); await frames(8); quit(1 if failures else 0); return
	check(active_seen,"physical Space input runs the existing phase dash")
	check(effects_seen,"actual dash contact produces wall fragments and dust")
	check(world.broken_shared_walls.has(selection.key),"Space destroys the real shared wall, not only an effect mesh")
	check(world.edge_states.get(selection.key)==&"OPEN" and not world.wall_edges.has(selection.key),"wall topology remains open after the effect")
	var blockers:=0
	for body in world.collision_root.get_children():
		if body.get_meta(&"generated_wall_edge","")==selection.key or body.get_meta(&"generated_air_wall_edge","")==selection.key: blockers+=1
	check(blockers==0,"solid and upper actor blockers are removed")
	check(world.current_room_id==selection.b and bool(world.room_encounters[selection.b].get("activated",false)),"crossing the breach activates the actual destination room")
	var middle: Vector2=world._edge_gameplay_position(world.broken_shared_walls[selection.key].edge)-offset
	var clear:=true
	for body in world.collision_root.get_children():
		if body.get_meta(&"generated_wall_edge","")==selection.key or body.get_meta(&"generated_air_wall_edge","")==selection.key: clear=false
	check(clear and player.phase_dash._floor_supported(middle),"opening has ground support and no generated wall/air blocker; dynamic actors are checked separately by walking")
	await screenshot("after")
	# Return through the same opening using ordinary movement, without another dash.
	var reached:=false
	for i in 180:
		var delta: Vector2=selection.start-player.global_position
		if delta.length()<9.0: reached=true; break
		WALK.hold(player,delta); await physics_frame; await process_frame
	WALK.release(); await frames(6)
	check(reached and world.current_room_id==selection.a,"ordinary WASD movement returns through the persistent opening")
	check(world.broken_shared_walls.has(selection.key),"room revisiting does not restore destroyed masonry")
	var outside_found:=false
	for edge_key in world.wall_edges:
		var sides: Array=world._edge_side_cells(world.wall_edges[edge_key])
		if world.floor_cells.has(sides[0]) and world.floor_cells.has(sides[1]): continue
		outside_found=true
		check(world.SHARED_WALL_BREACH.wall_for_key(world,edge_key)!=null or world.window_wall_edges.has(edge_key) or world.glass_wall_edges.has(edge_key),"exterior wall uses masonry or glass destruction, while phase floor support constrains travel")
		break
	check(outside_found,"exterior guard was checked against a real boundary")
	await screenshot("return_through_hole")
	FileAccess.open(OUT+"/capture_times.json",FileAccess.WRITE).store_string(JSON.stringify(capture_times))
	frame_samples.sort()
	FileAccess.open(OUT+("/result_no_record.json" if no_record else "/result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"selection":selection,"broken":world.broken_shared_walls.keys(),"frames":images,"interval_ms":frame_samples,"max_ms":frame_samples.back(),"p95_ms":frame_samples[94],"profile":world.last_shared_wall_breach_profile,"scope":"Actual Main fixed-seed first shared-wall dash; minimized native GPU, Engine max_fps 60; no readback inside measured interval when --no-record; excludes loading, not full combat route or GPU-only timing","preparation":world.last_firearm_render_preparation.get("destruction",{})},"\t"))
	print("SHARED_WALL_DASH_CAMERA checks=",checks," failures=",failures)
	main.queue_free(); await frames(8); quit(1 if failures else 0)
