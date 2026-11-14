extends "res://tests/rendering_backend_unification_camera_test.gd"
## Native Main -> reception elevator -> two production floors -> bedroom.
var first_blood: WeakRef
var facts: Dictionary = {}

func _initialize() -> void:
	out = "res://.runtime/surface_blood_20261114/promotion/formal"
	case_name = "campaign"
	call_deferred("run")

func run() -> void:
	create_timer(360.0,true,false,true).timeout.connect(func(): quit(3))
	await process_frame
	if not AudioServer.is_bus_mute(0): AudioServer.set_bus_mute(0,true); quit(2); return
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	backend("Engine startup")
	# Hidden off-screen native rendering, without the minimized force_draw loop.
	await campaign()
	check(AudioServer.is_bus_mute(0),"Private test audio stays muted")
	var failures: int = checks.filter(func(row: Dictionary)->bool: return not row.pass).size()
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"checks":checks,"failures":failures,"photos":photos},"\t"))
	if is_instance_valid(app): app.queue_free()
	preload("res://scripts/audio/sfx_manager.gd").stop_music(0.0)
	await frames(8)
	print("SURFACE_BLOOD_PROMOTION checks=",checks.size()," failures=",failures)
	quit(1 if failures else 0)

func photo(label: String) -> void:
	await super.photo(label)
	if label not in ["office_floor_1","office_floor_2"]:
		if label=="chapter_bedroom": check(first_blood==null or first_blood.get_ref()==null,"Leaving floor releases surface blood host")
		return
	var world: Node3D = app._supported_dream_world
	var blood: Node3D = world.office_art_root.get_node_or_null("SurfaceBlood")
	if not check(is_instance_valid(blood),label+" prewarms one floor-owned promoted blood system"): return
	check(world.surface_blood_enabled and world.pixel_drag_enabled,label+" enables both approved blood styles")
	check(world.office_art_root.find_children("SurfaceBlood","Node3D",false,false).size()==1,label+" has one surface host")
	if first_blood!=null: check(first_blood.get_ref()==null,label+" releases the preceding floor and its receiver bodies")
	first_blood = weakref(blood)
	check(blood.find_children("*","Light3D",true,false).is_empty(),label+" blood adds no illuminating light")
	blood.record_diagnostics = true
	var collision_ok := true
	var labels: Dictionary = {}
	for receiver in blood.receivers:
		var body: StaticBody3D = receiver.body.get_ref()
		if is_instance_valid(body): collision_ok = collision_ok and (body.collision_layer & ~blood.QUERY_LAYER)==0 and body.collision_mask==0
		labels[receiver.name] = int(labels.get(receiver.name,0))+1
	check(collision_ok,label+" surface queries are isolated from gameplay physics")
	check(labels.has("地面") and labels.has("墙壁") and labels.has("家具"),label+" registers production floor walls and actual furniture")
	var old_player_physics: bool = world.player.is_physics_processing()
	var clock: Node = root.get_node("DreamTimeController")
	clock.end_tactical_planning(); clock.clear_reaction_time(); clock.reset_hit_stop()
	clock.set_lifecycle_enabled(false); clock.set_process(false); clock.set_physics_process(false)
	Engine.time_scale = 1.0
	world.player.invulnerability_left = 999.0
	world.player.set_physics_process(false)
	var actors: Array = []
	for actor in world.enemy_root.get_children():
		actors.append({"ref":weakref(actor),"physics":actor.is_physics_processing(),"process":actor.is_processing(),"mode":actor.process_mode})
		actor.process_mode = Node.PROCESS_MODE_DISABLED
	var style: Node = world.floor_root.get_node_or_null("OfficeSurfaceStyle")
	if is_instance_valid(style): style.materials.focus("metal")
	await frames(15)
	var room_id: int = world.current_room_id
	var origin: Vector2 = world.player.global_position
	var clear := false
	for cell in world.rooms[room_id].get("usable_cells",[]):
		var position := Vector2(cell)*32.0
		if world._content_position_is_clear(position,24.0,false): origin = position; clear = true; break
	check(clear,label+" finds real traversable floor for an accepted damage event")
	world.player.global_position = origin-Vector2(32,32)
	world._update_camera_and_actor_projection(0.0)
	var enemy: EmployeeEnemy = world._spawn_regular_employee(room_id,origin,&"employee",false,"basic")
	enemy.set_room_runtime_active(true); enemy.set_player_vision_visible(true)
	enemy.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.set_physics_process(false); enemy.set_process(false)
	enemy.current_health = 1000.0; enemy.sky_drop_height = 0.0; enemy.sky_drop_delay_left = 0.0
	enemy._update_sky_drop(.001)
	await frames(8)
	var before: int = blood.accepted_blood_events
	enemy.take_damage(1.0,origin-Vector2(16,0),0.0,&"enemy_projectile")
	await create_timer(1.3,true,false,true).timeout
	check(blood.accepted_blood_events==before+1,label+" actual enemy damage uses the promoted spray once")
	check(blood.hit_count>0 and not blood.faces.is_empty(),label+" airborne blood reaches actual production receivers")
	var state: int = world._content_rng.state
	check(world.spawn_corpse_drag_trail(origin,origin+Vector2(22,3),room_id,1.0,24.0),label+" accepts corpse drag on real floor")
	var drag: BlackBloodEffect
	for effect in world.world_effects_root.get_children():
		if effect is BlackBloodEffect and effect.has_meta(&"pixel_drag_art"): drag = effect
	check(is_instance_valid(drag) and not drag.ground_pixels.is_empty(),label+" uses sharp pixel drag through the original capture lifecycle")
	if is_instance_valid(drag):
		var info: Dictionary = drag.get_meta(&"pixel_drag_art")
		check(info.added==0 and info.before_bounds==info.after_bounds and info.removed>0,label+" carves only pixels while retaining width direction endpoints and grooves")
	check(world._content_rng.state==state,label+" cosmetic drag does not advance content RNG")
	var probe_from: Vector3 = world.get_gameplay_world_position(origin,2.0)
	var probe_to: Vector3 = world.get_gameplay_world_position(origin,-.15)
	var hit: Dictionary = blood.trace(probe_from,probe_to)
	check(not hit.is_empty(),label+" native visual-only surface queries meet the floor")
	if not hit.is_empty():
		var body: StaticBody3D = hit.collider
		var receiver: Dictionary = blood.receivers[int(body.get_meta(&"blood_receiver"))]
		var mesh: Node3D = receiver.owner.get_ref()
		mesh.hide(); await physics_frame
		check(body.collision_layer==0,label+" hiding a receiving mesh disables its visual query body")
		mesh.show(); await physics_frame
		check(body.collision_layer==blood.QUERY_LAYER,label+" showing it restores visual queries without a whole-floor scan")
	await frames(12); await RenderingServer.frame_post_draw
	world.camera_3d.get_viewport().get_texture().get_image().save_png(out.path_join(label+"_blood.png"))
	facts[label] = {"receivers":blood.receivers.size(),"receiver_types":labels,"stats":blood.stats(),"drag_passes":world.drag_art_reports.size(),"lights_added":0}
	if label=="office_floor_1":
		facts["performance"] = await measure(world,blood,origin,room_id)
	else:
		await rollback(world,blood,probe_from,probe_to)
	FileAccess.open(out.path_join("blood_facts.json"),FileAccess.WRITE).store_string(JSON.stringify(facts,"\t"))
	for record in actors:
		var actor: Node = record.ref.get_ref()
		if is_instance_valid(actor):
			actor.process_mode = record.mode
			actor.set_physics_process(record.physics); actor.set_process(record.process)
	if is_instance_valid(enemy): enemy.queue_free()
	world.player.set_physics_process(old_player_physics)
	clock.set_lifecycle_enabled(true); clock.set_process(true); clock.set_physics_process(true)

func measure(world: Node3D, blood: Node3D, origin: Vector2, room_id: int) -> Array:
	var results: Array = []
	var fps := Engine.max_fps; Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Same actual Camera/light/geometry and hit schedule, no screenshots inside.
	for enabled in [false,true,true,false]:
		world.surface_blood_enabled = enabled; world.pixel_drag_enabled = enabled
		blood.clear_blood()
		for effect in world.world_effects_root.get_children():
			if effect is BlackBloodEffect: effect.queue_free()
		await frames(45)
		# Warm both actual effect paths before steady measurements. The cold
		# activation above remains covered by entry/lifecycle evidence.
		world.spawn_black_blood(origin,Vector2.RIGHT,false,room_id)
		await create_timer(1.4,true,false,true).timeout
		blood.clear_blood()
		for effect in world.world_effects_root.get_children():
			if effect is BlackBloodEffect: effect.queue_free()
		await frames(12)
		var begin := Time.get_ticks_usec(); var previous := begin; var event := 0
		var times: Array = []; var rows: Array = []
		while Time.get_ticks_usec()-begin<3000000:
			await process_frame
			var now := Time.get_ticks_usec(); var seconds := (now-begin)/1000000.0
			if event<10 and seconds>=event*.3:
				world.spawn_black_blood(origin,Vector2.from_angle(float(event)*.4),false,room_id)
				world.spawn_corpse_drag_trail(origin,origin+Vector2(8,2),room_id,1.0,24.0)
				event += 1
			var ms := (now-previous)/1000.0; previous = now; times.append(ms)
			rows.append([seconds,ms,blood.query_usec/1000.0,blood.drops.size(),blood.faces.size()])
		results.append({"enabled":enabled,"events":event,"frame_wall":preload("res://scripts/testing/lab_recorder.gd").stats(times),"raw":rows})
	world.surface_blood_enabled = true; world.pixel_drag_enabled = true
	Engine.max_fps = fps
	return results

func rollback(world: Node3D, blood: Node3D, from: Vector3, to: Vector3) -> void:
	var old_floor: int = world.floor_index
	var old_id := blood.get_instance_id(); var face_count: int = blood.faces.size()
	world.transition_generation_token += 1
	var token: int = world.transition_generation_token
	var staged: bool = await world._regenerate_staged(world.active_seed+173,old_floor+1,token,true)
	check(staged,"Staged floor generation completes while original blood is stashed")
	var staged_blood: Node3D = world.office_art_root.get_node_or_null("SurfaceBlood")
	var staged_ref: WeakRef = weakref(staged_blood) if is_instance_valid(staged_blood) else null
	check(is_instance_valid(staged_blood) and staged_blood!=blood and staged_blood.faces.is_empty(),"Staged floor gets a clean independent blood host")
	var old_queries_disabled := true
	for receiver in blood.receivers:
		var body: StaticBody3D = receiver.body.get_ref()
		if is_instance_valid(body): old_queries_disabled = old_queries_disabled and body.collision_layer==0
	check(old_queries_disabled,"Rollback stash disables old visual ray receivers")
	world._rollback_failed_transition(token,old_floor)
	await frames(16)
	var restored: Node3D = world.office_art_root.get_node_or_null("SurfaceBlood")
	check(is_instance_valid(restored) and restored.get_instance_id()==old_id and restored.faces.size()==face_count,"Failure rollback restores original surface blood and attached stains")
	check(staged_ref!=null and staged_ref.get_ref()==null,"Failure rollback releases discarded floor receiver bodies")
	check(not restored.trace(from,to).is_empty(),"Restored floor reactivates original visual queries")
	check(world.player.movement_enabled,"Failure rollback restores player controls")
