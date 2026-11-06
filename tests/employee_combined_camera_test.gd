extends SceneTree
const OUT:="res://.runtime/employee_combined_20261030"
const ENEMY=preload("res://scenes/entities/employee_enemy.tscn")
var checks:=0
var failures:=0
var world: Node3D
var victim: EmployeeEnemy
var bridge: Node
var times: Array=[]
var frame_index:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func shot(label: String) -> void:
	bridge._process(0.); await frames(3); await RenderingServer.frame_post_draw
	world.camera_3d.get_viewport().get_texture().get_image().save_png(OUT+"/"+label+".png")
	bridge.render_viewport.get_texture().get_image().save_png(OUT+"/"+label+"_actor.png")
func clip(n: int,motion: Vector2=Vector2.ZERO,dying: bool=false) -> void:
	var previous:=Time.get_ticks_usec()
	for i in n:
		await create_timer(1./30.,true,false,true).timeout
		var now:=Time.get_ticks_usec(); var dt: float=(now-previous)/1000000.; previous=now
		if dying: victim._update_death_presentation(dt)
		else:
			victim.velocity=motion; victim._process(dt)
		bridge._process(0.); await RenderingServer.frame_post_draw
		world.camera_3d.get_viewport().get_texture().get_image().save_png(OUT+"/motion/%03d.png"%frame_index)
		bridge.render_viewport.get_texture().get_image().save_png(OUT+"/motion/actor_%03d.png"%frame_index)
		times.append(Time.get_ticks_msec()); frame_index+=1
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60
	AudioServer.set_bus_mute(0,true)
	create_timer(150.,true,false,true).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(OUT+"/motion")
	world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.enable_game_start_cab_exit=false; world.persist_profile=false
	root.add_child(world); await frames(5)
	check(world.regenerate(41002),"formal dungeon generation succeeds with the new employee rig")
	await frames(30)
	for actor in world.enemy_root.get_children():
		if actor is EmployeeEnemy: actor.set_physics_process(false); actor.set_process(false)
	world.player.set_physics_process(false)
	world.player.hide()
	world._update_camera_and_actor_projection(0.)
	victim=world._spawn_regular_employee(world.current_room_id,world.player.global_position,&"employee",false,"")
	victim.sky_drop_active=false; victim.knockdown_height=0.; victim.set_physics_process(false); victim.set_process(false)
	victim.set_player_vision_visible(true); victim.set_room_runtime_active(true)
	# Use the level's actual gameplay cells and collider clearance, never a ray
	# in a different viewport's coordinate system.
	var room_id: int=world.current_room_id
	var bounds: Rect2=world._room_bounds_pixels(room_id,0.)
	var stage_point: Vector2=world.player.global_position
	var best_score:=-INF
	for cell in world.rooms[room_id].get("usable_cells",[]):
		var candidate:=Vector2(cell)*32.
		if not world._content_position_is_clear(candidate,18.,false): continue
		var score: float=minf(minf(candidate.x-bounds.position.x,bounds.end.x-candidate.x),minf(candidate.y-bounds.position.y,bounds.end.y-candidate.y))
		if score>best_score: best_score=score; stage_point=candidate
	check(is_finite(best_score) and world._is_blood_ground_allowed(stage_point),"sample stands on a verified clear floor tile inside the formal room")
	world.player.global_position=stage_point; victim.global_position=stage_point
	world._update_camera_and_actor_projection(1.)
	world.set_process(false); world.set_physics_process(false)
	victim.set_physics_process(false); victim.set_process(false)
	victim.outline_controller.set_outline_state(0)
	var ref: WeakRef=victim.get_meta(&"depth_visual_bridge")
	bridge=ref.get_ref(); bridge.set_meta(&"test_legacy_character_sync_every_frame",true)
	var fixed_position: Vector2=victim.position
	var shape_position: Vector2=victim.body_collision.position
	var upper: Image=victim.head.texture.get_image()
	check(upper.get_size()==Vector2i(32,32) and not victim.body.visible,"actual formal employee uses one complete upper body")
	await shot("idle")
	for eye in 3:
		victim._set_enemy_head_frame(eye); await shot("eye_%d"%eye)
		check((victim.head.texture as AtlasTexture).region==Rect2(32,eye*32,32,32),"formal eye frame %d changes the combined cell"%eye)
	# Restore the normal state after inspecting each authored expression. The
	# previous review left frame 2 selected while the blink timer was waiting.
	victim.enemy_blink_phase=0; victim.enemy_blink_phase_left=0.
	victim.enemy_blink_time_left=.30; victim._set_enemy_head_frame(0)
	await shot("idle")
	# Let the actual unpaused _process drive the blink; do not set its frames.
	DirAccess.make_dir_recursive_absolute(OUT+"/blink")
	victim.velocity=Vector2.ZERO; victim.set_process(true)
	var blink_times: Array=[]
	var blink_states: Array=[]
	var first_state_shots: Dictionary={}
	var blink_start:=Time.get_ticks_msec()
	var blink_index:=0
	while Time.get_ticks_msec()-blink_start<2600:
		await create_timer(1./30.,true,false,true).timeout
		bridge._process(0.); await RenderingServer.frame_post_draw
		var state: int=victim.enemy_head_frame_index
		world.camera_3d.get_viewport().get_texture().get_image().save_png(OUT+"/blink/%03d.png"%blink_index)
		bridge.render_viewport.get_texture().get_image().save_png(OUT+"/blink/actor_%03d.png"%blink_index)
		if not first_state_shots.has(state):
			bridge.render_viewport.get_texture().get_image().save_png(OUT+"/blink/state_%d.png"%state)
			first_state_shots[state]=true
		if blink_states.is_empty() or blink_states[-1]!=state: blink_states.append(state)
		blink_times.append(Time.get_ticks_msec()); blink_index+=1
	victim.set_process(false)
	check(blink_states.size()>=4 and blink_states.slice(0,4)==[0,1,2,0],"actual live process cycles open to half-closed to closed and back to open")
	check(first_state_shots.has(0) and first_state_shots.has(1) and first_state_shots.has(2),"real GPU capture includes all three eye states")
	check(victim.enemy_head_frame_index==0 and not victim.dead,"living enemy rests with open eyes after blinking")
	FileAccess.open(OUT+"/blink/times.json",FileAccess.WRITE).store_string(JSON.stringify(blink_times))
	FileAccess.open(OUT+"/blink/states.json",FileAccess.WRITE).store_string(JSON.stringify(blink_states))
	await clip(20,Vector2(80,0)); await shot("walking_right")
	await clip(20,Vector2(-80,0)); await shot("walking_left")
	check(not victim.body.visible and victim.position==fixed_position and victim.body_collision.position==shape_position,"both walking directions keep one torso and unchanged gameplay origin")
	victim.velocity=Vector2.ZERO; victim.equip_weapon("basic"); victim._update_weapon_aim()
	check(victim.held_weapon_sprite.visible,"equipped firearm remains visible on the new body")
	await shot("armed"); await clip(12)
	victim.take_damage(1.,victim.global_position-Vector2(20,0),1.,&"player_projectile_rifle")
	victim.set_physics_process(false); victim.set_process(false); victim._process(.001)
	victim.set_physics_process(false); victim.set_process(false)
	bridge._process(0.); await shot("hit")
	check(victim.hit_flash_left>0. and victim.head.material is ShaderMaterial,"nonlethal damage retains the existing whole-upper-body hit flash")
	await clip(8)
	var logical_hit: Vector3=bridge.get_hit_feedback_world_position()
	check(logical_hit.is_finite(),"combined upper body provides a valid torso hit location")
	# Use the normal death pipeline, with its presentation branch fixed for this sample.
	victim.feedback_config=victim.feedback_config.duplicate(true)
	victim.feedback_config.employee_dismember_chance=0.
	victim.take_damage(9999.,victim.global_position-Vector2(20,0),260.,&"shotgun")
	victim.set_physics_process(false); victim.set_process(false)
	check(victim.dead and victim.ragdoll_active and victim.body.visible,"death switches to the existing neck-jointed ragdoll")
	check((victim.head.texture as AtlasTexture).region==Rect2(32,64,32,23) and (victim.body.texture as AtlasTexture).region==Rect2(32,87,32,9),"formal corpse uses disjoint head and torso pixels from the closed-eye row")
	await shot("death_start"); await clip(48,Vector2.ZERO,true); await shot("landed")
	check(victim.death_landed and victim.death_pool_spawned,"corpse lands and retains normal blood-pool emission")
	check(bridge.get_corpse_blood_ground_position().is_finite(),"corpse blood lookup still finds the visible torso")
	# Detached parts must never carry an extra entire upper body.
	# The existing fragment helper is checked directly; this atlas migration
	# does not change the game's conditions for invoking dismemberment.
	victim._spawn_detached_body_parts(0.); await frames(5); await shot("fragment_helper")
	var parts:=get_nodes_in_group(&"enemy_body_parts")
	if parts.is_empty():
		parts=world.find_children("*","EnemyBodyPart",true,false)
	var has_head:=false; var has_torso:=false
	for part in parts:
		var sprite: Sprite2D=part.get_node_or_null("Sprite2D")
		if sprite==null:
			var found:=part.find_children("*","Sprite2D",true,false)
			if not found.is_empty(): sprite=found[0]
		if sprite!=null and sprite.texture is AtlasTexture:
			var region: Rect2=sprite.texture.region
			has_head=has_head or region==Rect2(32,64,32,23)
			has_torso=has_torso or region==Rect2(32,87,32,9)
	check(has_head and has_torso,"existing fragment helper receives a head and torso without duplicated whole bodies")
	FileAccess.open(OUT+"/motion/times.json",FileAccess.WRITE).store_string(JSON.stringify(times))
	world.queue_free(); await frames(10)
	FileAccess.open(OUT+"/camera_result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"gpu":RenderingServer.get_video_adapter_name()},"	"))
	print("EMPLOYEE_COMBINED_CAMERA checks=",checks," failures=",failures)
	quit(1 if failures else 0)
