extends SceneTree
class Walkers extends Node:
	var actors: Array=[]
	var running:=false
	var elapsed:=0.0
	func _physics_process(delta:float)->void:
		elapsed+=delta
		for i in actors.size():
			var actor: Node=actors[i]
			if not is_instance_valid(actor) or actor.dead: continue
			actor.velocity=Vector2(42 if fmod(elapsed+i*.3,1.8)<.9 else -42,0) if running else Vector2.ZERO
			actor.move_and_slide()
			# Keep genuine hit-flash and visual timers advancing while autonomous
			# AI/physics are disabled for the controlled route.
			actor._process(delta)
var main: Node
var world: Node3D
var smoke: Node3D
var walkers: Walkers
var actors: Array=[]
var checks:=0
var failures: Array=[]
var clips: Dictionary={}
var shots: Array=[]
var metrics: Dictionary={}
var output:="res://.runtime/nyangeon_vfx_sample_20261016/camera"
var clip:=""
var started:=0
var captured:=0
var index:=0
func _initialize()->void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output=argument.trim_prefix("--artifact-dir=")
	node_added.connect(func(node:Node)->void:
		if node.get_script()!=null and String(node.get_script().resource_path)=="res://scripts/dream/office_skeleton_world_base.gd": node.persist_profile=false)
	call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func capture(force:=false)->void:
	if clip.is_empty(): return
	var now:=Time.get_ticks_usec()
	if not force and now-captured<33000: return
	var image: Image=root.get_texture().get_image()
	var file:="%s_%04d.png"%[clip,index]; index+=1
	image.save_png(output+"/"+file)
	clips[clip].append({"file":file,"seconds":(now-started)/1000000.0})
	captured=now
func begin(label:String)->void:
	clip=label; clips[label]=[]; started=Time.get_ticks_usec(); captured=0; capture(true)
func wait(seconds:float)->void:
	var until:=Time.get_ticks_usec()+int(seconds*1000000)
	while Time.get_ticks_usec()<until:
		await RenderingServer.frame_post_draw
		for actor in actors:
			if is_instance_valid(actor) and actor.dead: actor.process_mode=Node.PROCESS_MODE_INHERIT; actor.set_physics_process(true); actor.set_process(true)
		capture()
func finish()->void: capture(true); clip=""
func fire(kind:String)->void:
	var p: Node=world.player
	p.equip_weapon(kind,world.config,{})
	p.set_attacking_enabled(false); p.set_meta(&"aim_direction_override",Vector2.RIGHT)
	for i in 3:
		await wait(.04)
		p.set_meta(&"aim_direction_override",p.get_projectile_origin().direction_to(actors[0].hurtbox_collision.global_position))
	var direction: Vector2=p.get_projectile_origin().direction_to(actors[0].hurtbox_collision.global_position)
	if kind=="shotgun": p.shotgun_weapon._fire_full_volley(direction,false)
	elif kind=="assault_rifle": p.assault_rifle_weapon._fire(direction,false)
	else: p.auto_weapon._fire(direction,false)
	shots.append({"weapon":kind,"at":Time.get_ticks_usec(),"clip":clip})
func sample_performance(label:String,enabled:bool)->void:
	smoke.enabled=enabled
	var values: Array=[]
	var last:=Time.get_ticks_usec()
	for i in 150:
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		if i>=30: values.append((now-last)/1000.0)
		last=now
	values.sort()
	metrics[label]={"frames":values.size(),"median_ms":values[values.size()/2],"p95_ms":values[int(values.size()*.95)],"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),"active_puffs":smoke.puffs.size()}

func warm_effects()->void:
	for enabled in [false,true]:
		world.set_meta(&"pixel_combat_vfx_enabled",enabled)
		for kind in [&"pistol",&"assault_rifle",&"shotgun"]:
			world.spawn_weapon_muzzle(world.player.get_projectile_origin(),Vector2.RIGHT,kind,world.player)
		world.spawn_combat_feedback(world.player.global_position,Vector2.RIGHT,false,enabled,world.player)
		world.spawn_combat_feedback(world.player.global_position,Vector2.RIGHT,true,enabled,world.player)
		await wait(.5)
	world.set_meta(&"pixel_combat_vfx_enabled",true)

func effect_performance(label:String,enabled:bool)->void:
	world.set_meta(&"pixel_combat_vfx_enabled",enabled)
	var times: Array=[]; var draws: Array=[]; var last:=Time.get_ticks_usec()
	for i in 150:
		if i%20==0:
			for kind in [&"pistol",&"assault_rifle",&"shotgun"]:
				world.spawn_weapon_muzzle(world.player.get_projectile_origin(),Vector2.RIGHT,kind,world.player)
			world.spawn_combat_feedback(world.player.global_position,Vector2.RIGHT,false,enabled)
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		if i>=30: times.append((now-last)/1000.0); draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		last=now
	times.sort(); draws.sort()
	metrics[label]={"frames":times.size(),"median_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)],"median_draw_calls":draws[draws.size()/2],"peak_draw_calls":draws.back(),"fixture":"Three muzzle kinds plus one hit every 20 submitted frames, no damage or PNG readback"}
	world.set_meta(&"pixel_combat_vfx_enabled",true)
	await wait(.3)
func dense_performance(room_id:int,origin:Vector2)->void:
	var extra: Array=[]
	for i in 21:
		var actor: Node=world._spawn_regular_employee(room_id,origin+Vector2((i%7-3)*18,(i/7-1)*24),&"employee",false,"basic")
		actor.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		actor.hurtbox.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		actor.process_mode=Node.PROCESS_MODE_DISABLED; actor.sky_drop_active=false; actor.sky_drop_height=0; actor.knockdown_height=0
		actor.set_room_runtime_active(true); actor.set_player_vision_visible(true)
		extra.append(actor)
	walkers.actors=actors+extra; walkers.running=true
	await sample_performance("dense_24_smoke_off",false)
	var before_updates:int=smoke.updates; var before_usec:int=smoke.update_usec
	await sample_performance("dense_24_smoke_on",true)
	metrics["dense_fixture"]={"moving_enemies":24,"total_enemies":world.enemy_root.get_child_count(),"capacity":smoke.LIMIT,"peak_active":smoke.peak_active}
	metrics["dense_24_manager_ms"]=float(smoke.update_usec-before_usec)/maxi(1,smoke.updates-before_updates)/1000
	check(smoke.puffs.size()<=72 and smoke.get_child_count()==72,"Dense crowd remains within the shared native pool")
	walkers.running=false; walkers.actors=actors
	for actor in extra: actor.queue_free()
	await wait(.5)
func all_skeletons()->void:
	if is_instance_valid(walkers): walkers.queue_free()
	actors.clear(); world.enable_game_start_cab_exit=false
	for kind in ["A1","B2","C3","V3"]:
		world.native_skeleton_type=kind
		check(world.regenerate(42001),"Actual GPU formal generation "+kind)
		smoke=world.floor_root.get_node("FootstepSmoke")
		world.floor_transition_in_progress=false; world.transition_phase=&"IDLE"
		for enemy in world.enemy_root.get_children(): enemy.process_mode=Node.PROCESS_MODE_DISABLED
		var chosen:=false
		for room in world.rooms:
			if String(room.get("archetype",""))!="open_office": continue
			for cell in room.get("usable_cells",[]):
				var point:=Vector2(cell)*32.0
				if not world._content_position_is_clear(point,55): continue
				world.player.global_position=point; world.activate_room(room.id); chosen=true; break
			if chosen: break
		check(chosen,"Actual office room found "+kind)
		world.player.movement_enabled=true; world.player.set_attacking_enabled(false)
		world._update_camera_and_actor_projection(0.0)
		await wait(.5)
		var emitted_before:int=smoke.emitted
		var direction:=Vector2.ZERO
		for candidate in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			if not world.player.test_move(world.player.global_transform,candidate*50): direction=candidate; break
		check(direction!=Vector2.ZERO,"Collision-tested walking route "+kind)
		begin("floor_"+kind)
		world.player.set_scripted_locomotion(direction,60); await wait(.7)
		world.player.clear_scripted_locomotion(); await wait(.3); finish()
		check(smoke.get_child_count()==72 and world.uses_pixel_combat_vfx() and smoke.emitted>emitted_before,"Automatic bounded VFX and moving smoke in actual "+kind+" Camera")
func run()->void:
	if DisplayServer.get_name()=="headless": quit(2); return
	# Display settings can restore the native mode after the initial minimize.
	# Keep this background-only delivery minimized before every forced draw.
	process_frame.connect(func()->void:
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); Engine.max_fps=60; root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state["tutorial_completed"]=true
	seed(120); main._show_dream("basic")
	var deadline:=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		await RenderingServer.frame_post_draw
		if is_instance_valid(main._supported_dream_world): world=main._supported_dream_world
		if is_instance_valid(world) and not main.transition_running and not world.floor_transition_in_progress: break
	check(is_instance_valid(world) and not main.transition_running,"Actual Main entry is ready")
	if not is_instance_valid(world): quit(1); return
	# A controlled normal-speed visual fixture; production time rules are untouched.
	var time_controller: Node=root.get_node_or_null("DreamTimeController")
	if time_controller!=null: time_controller.set_process(false)
	Engine.time_scale=1
	if "--floors-only" in OS.get_cmdline_user_args():
		await all_skeletons()
		var report:={"checks":checks,"failures":failures,"clips":clips}
		var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
		print("PIXEL_VFX_FLOORS_CAMERA ",JSON.stringify({"checks":checks,"failures":failures}))
		main.free(); quit(1 if failures.size() else 0); return
	var origin:=Vector2.ZERO; var room_id:=-1
	for room in world.rooms:
		if String(room.get("archetype",""))!="open_office": continue
		for cell in room.get("usable_cells",[]):
			var point:=Vector2(cell)*32.0
			if world._content_position_is_clear(point,75.0): origin=point; room_id=int(room.id); break
		if room_id>=0: break
	check(room_id>=0,"A naturally generated clear office is used")
	if room_id<0: main.free(); quit(1); return
	world.activate_room(room_id)
	for enemy in world.enemy_root.get_children():
		enemy.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		enemy.hurtbox.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		enemy.process_mode=Node.PROCESS_MODE_DISABLED
	world.player.global_position=origin+Vector2(-45,48)
	world.player.invulnerability_left=0; world.player.invulnerability_reason=&""; world.player.hurt_flash_left=0; world.player.revive_flash_left=0
	world.player.set_attacking_enabled(false)
	for offset in [Vector2(-25,-38),Vector2(20,-12),Vector2(62,-45)]:
		var enemy: Node=world._spawn_regular_employee(room_id,origin+offset,&"employee",false,"basic")
		enemy.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		enemy.hurtbox.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		enemy.process_mode=Node.PROCESS_MODE_DISABLED; enemy.sky_drop_active=false; enemy.sky_drop_height=0; enemy.knockdown_height=0
		enemy.set_room_runtime_active(true); enemy.set_player_vision_visible(true)
		actors.append(enemy)
	walkers=Walkers.new(); world.add_child(walkers); walkers.actors=actors
	await wait(.7)
	smoke=world.floor_root.get_node("FootstepSmoke")
	check(smoke.get_child_count()==72,"Formal Main automatically installs bounded smoke without sample opt-in")
	await warm_effects()
	begin("walk_stop")
	walkers.running=true; world.player.set_scripted_locomotion(Vector2.RIGHT,70)
	await wait(.85)
	world.player.set_scripted_locomotion(Vector2.LEFT,70); await wait(.7)
	world.player.clear_scripted_locomotion(); walkers.running=false; await wait(.6)
	finish()
	check(smoke.emitted>6,"Player and enemy movement produces visible smoke")
	var count: int=smoke.emitted; await wait(.25)
	check(smoke.emitted==count,"Smoke emission stops with the actors")
	# No screenshot readback during these two controlled frame-time samples.
	walkers.running=true
	await sample_performance("smoke_off",false); await sample_performance("smoke_on",true)
	walkers.running=false; smoke.enabled=true
	metrics["smoke_mean_update_ms"]=float(smoke.update_usec)/maxi(1,smoke.updates)/1000
	metrics["smoke_peak_active"]=smoke.peak_active; metrics["carrier_limit"]=smoke.LIMIT
	await effect_performance("old_gun_hit",false); await effect_performance("sample_gun_hit",true)
	if "--rollout" in OS.get_cmdline_user_args(): await dense_performance(room_id,origin)
	for i in actors.size():
		actors[i].global_position=origin+Vector2(45,20+i*32)
		actors[i].current_health=1000; actors[i].set_physics_process(false)
	world.player.global_position=origin+Vector2(-50,20)
	world.player.set_meta(&"aim_direction_override",Vector2.RIGHT)
	await wait(.5)
	for kind in ["basic","assault_rifle","shotgun"]:
		# Reset only fixture stains between weapons for a readable comparison.
		for effect in world.world_effects_root.get_children():
			if effect is BlackBloodEffect: effect.queue_free()
		await wait(.1)
		print("SAMPLE_SHOT_START ",kind," target_valid=",is_instance_valid(actors[0])," health=",actors[0].current_health if is_instance_valid(actors[0]) else -1)
		begin("fire_"+kind)
		var before: float=actors[0].current_health
		await fire(kind); await wait(.8)
		if kind=="assault_rifle": await fire(kind); await wait(.35)
		finish()
		check(is_instance_valid(actors[0]) and actors[0].current_health<before,"Actual "+kind+" projectile produces a nonlethal enemy hit")
		if not is_instance_valid(actors[0]): quit(1); return
	check(actors[0].hit_flash_left<=0,"Body hit flash completes normally in the controlled fixture")
	# One lethal actual projectile; no synthetic duplicate kill burst.
	actors[0].current_health=1
	begin("lethal_hit"); await fire("basic"); await wait(.85); finish()
	check(actors[0].dead,"Actual lethal shot uses the death path")
	begin("enemy_fire")
	var shooter: Node=actors[1]
	shooter.target=world.player; shooter.can_see_target=true; shooter.pickup_pause_left=0; shooter.reload_left=0
	shooter._remember_player_damage_awareness()
	shooter._fire_held_weapon(); await wait(.5); finish()
	# Pause freezes the transient age; clearing the owner removes all native slots.
	smoke.emit_puff(world.player.global_position,Vector2.LEFT)
	var age: float=smoke.puffs.back().age
	paused=true; await wait(.1)
	check(is_equal_approx(float(smoke.puffs.back().age),age),"Pause freezes smoke lifetime")
	paused=false
	var slots: Array=smoke.sprites.duplicate()
	smoke.free(); await wait(.05)
	check(slots.all(func(slot)->bool: return not is_instance_valid(slot)),"Deleting the floor-owned sample leaves no smoke carriers")
	if "--rollout" in OS.get_cmdline_user_args(): await all_skeletons()
	# Reception installs its manager automatically without a combat floor root.
	main._show_reception("basic"); deadline=Time.get_ticks_msec()+15000
	while main.transition_running and Time.get_ticks_msec()<deadline: await wait(.02)
	var reception: Node3D=main._supported_dream_world
	var hall_smoke: Node3D=reception.floor_root.get_node("FootstepSmoke")
	begin("hall_walk"); reception.player.set_scripted_locomotion(Vector2.UP,70); await wait(.7)
	reception.player.clear_scripted_locomotion(); await wait(.5); finish()
	check(hall_smoke.emitted>0,"Reception player uses the same floor smoke")
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"GPU delivery remains minimized")
	var report:={"checks":checks,"failures":failures,"clips":clips,"shots":shots,"metrics":metrics,"gpu":RenderingServer.get_video_adapter_name(),"room_id":room_id,"origin":origin,"scope":"Actual Main and gameplay Camera. Controlled natural office with three staged real enemies, scripted player locomotion and collision-respecting enemy motion, AI disabled. Real weapon projectiles and damage. Normal time fixture, unchanged production time rules. Performance samples exclude PNG readback; not combat FPS acceptance."}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("NYANGEON_VFX_DELIVERY ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	main.free(); quit(1 if failures.size() else 0)
