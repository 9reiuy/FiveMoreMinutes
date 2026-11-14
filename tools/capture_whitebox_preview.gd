extends SceneTree
## Actual gameplay Camera replay. Capture-only damage immunity, live enemy AI.
var artifact_dir := "res://.runtime/megastructure_rebuild_20261107/preview"
var display: Node
var world: Node3D
var frames: Array[Dictionary]=[]

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):artifact_dir=argument.trim_prefix("--artifact-dir=")
	call_deferred("_run")

func _capture(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(artifact_dir.path_join(title+".png"))
	frames.append({"file":title+".png","player":str(world.player.global_position),
		"time_scale":Engine.time_scale,"weapon":world.player.selected_weapon_id,
		"alive_enemies":world._get_alive_employee_count()})

func _walk_toward(target: Vector2) -> void:
	var offset: Vector2=target-world.player.global_position
	for spec in [["move_right",offset.x],["move_left",-offset.x],["move_down",offset.y],["move_up",-offset.y]]:
		if float(spec[1])>6.0:Input.action_press(String(spec[0]))
		else:Input.action_release(String(spec[0]))

func _release_movement() -> void:
	for action in ["move_right","move_left","move_up","move_down"]:Input.action_release(action)

func _run() -> void:
	await process_frame
	var master := AudioServer.get_bus_index(&"Master")
	if master<0 or not AudioServer.is_bus_mute(master):
		if master>=0:AudioServer.set_bus_mute(master,true)
		push_error("Capture requires private Master=0 before scene entry")
		quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(artifact_dir))
	display=load("res://scenes/testing/MegastructureWhiteboxDisplay.tscn").instantiate()
	root.add_child(display);current_scene=display
	world=display.world
	var player: CharacterBody2D=world.player
	player.invulnerability_left=0.0
	player.dash_invulnerability_left=100.0
	for frame in 35:await process_frame
	await _capture("01_opening")
	var opening_target: EmployeeEnemy=world.opening_enemy
	player.last_aim_direction=player.global_position.direction_to(opening_target.global_position)
	var data: Dictionary=player.take_active_weapon_for_throw()
	data.direction=player.global_position.direction_to(opening_target.global_position)
	player.weapon_drop_requested.emit(data)
	Input.action_press("move_right")
	var opening_frames := 0
	for frame in 2400:
		await physics_frame
		opening_frames=frame+1
		for pickup in world.world_weapon_root.get_children():
			if bool(pickup.get_meta(&"whitebox_opening_gun",false)):
				_walk_toward(pickup.global_position)
				break
		if frame%60==0:await _capture("opening_%04d" % frame)
		if player.selected_weapon_id=="basic" and is_instance_valid(opening_target) and not opening_target.dead and player.auto_weapon.cooldown_left<=0.0:player._execute_tactical_attack(opening_target.global_position)
		if world.opening_complete and world.opening_gun_collected:break
	_release_movement()
	var opening_clock: Node=world._get_dream_time_controller()
	var pickup_clock := {"scale":Engine.time_scale,"planning":bool(opening_clock.tactical_planning_active),"slow_time":bool(opening_clock.slow_time_enabled),"reaction":bool(opening_clock.is_reaction_time_active()),"hit_stop":bool(opening_clock.hitstop_active)}
	# A newly dodged projectile can trigger normal combat feedback after the
	# intro has released. Let that native feedback expire before the x1 photo;
	# keep the immediate clock state in the report rather than clearing it.
	var feedback_deadline := Time.get_ticks_msec()+1500
	var feedback_frames := 0
	while world.opening_complete and world.opening_gun_collected and (opening_clock.is_reaction_time_active() or opening_clock.hitstop_active) and Time.get_ticks_msec()<feedback_deadline:
		await process_frame
		feedback_frames+=1
	await _capture("02_pickup")
	var opening_passed: bool=world.opening_complete and (not is_instance_valid(opening_target) or opening_target.dead) and world.opening_gun_collected and player.selected_weapon_id=="basic" and not opening_clock.is_tactical_planning_active() and not opening_clock.slow_time_enabled and is_equal_approx(Engine.time_scale,1.0)
	var saved_corridor := false
	var saved_arena := false
	var observed_guard := false
	Input.action_press("move_right")
	for frame in 2400:
		await physics_frame
		var nearest: EmployeeEnemy=null
		var closest := INF
		for enemy in world.enemy_root.get_children():
			if enemy.dead:continue
			var distance := player.global_position.distance_to(enemy.global_position)
			if distance<closest:closest=distance;nearest=enemy
		if is_instance_valid(nearest) and (nearest!=world.exit_guard or observed_guard) and closest<400.0 and player.auto_weapon.cooldown_left<=0.0 and not player.is_weapon_empty_for_attack():
			player._execute_tactical_attack(nearest.global_position)
		if not saved_corridor and player.global_position.x>14.0*32.0:
			await _capture("03_corridor");saved_corridor=true
		if not saved_arena and player.global_position.x>30.0*32.0:
			Input.action_release("move_right")
			player.velocity=Vector2.ZERO
			await _capture("04_exit_arena");saved_arena=true
			for guard_frame in 120:
				await physics_frame
				if guard_frame%15==0:await _capture("guard_move_%03d" % guard_frame)
			observed_guard=true
			Input.action_press("move_right")
		if frame%30==0:await _capture("advance_%04d" % frame)
		if world.level_cleared:break
	Input.action_release("move_right")
	await _capture("05_finish")
	var completed: bool=world.level_cleared
	var finished_player := player.global_position
	var finished_remaining: int=world._get_alive_employee_count()
	# Separate clean art probes from the live combat replay above. They retain
	# the actual game camera, geometry and lights, with enemy logic held for photos.
	world.restart_current_floor_after_death()
	for frame in 5:await process_frame
	for enemy in world.enemy_root.get_children():enemy.process_mode=Node.PROCESS_MODE_DISABLED
	for projectile in get_nodes_in_group(&"dream_projectiles"):projectile.queue_free()
	world.opening_complete=true
	var controller: Node=world._get_dream_time_controller()
	controller.end_tactical_planning();controller.set_slow_time_enabled(false);controller.reset_hit_stop()
	player.invulnerability_left=0.0;player.dash_invulnerability_left=100.0
	for photo in [["art_entry",Vector2(3,5.5)],["art_corridor",Vector2(18.5,5.5)],["art_exit",Vector2(33.5,5.5)]]:
		player.global_position=Vector2(photo[1])*32.0
		for frame in 25:await process_frame
		await _capture(String(photo[0]))
	var report := {"pid":OS.get_process_id(),"renderer":RenderingServer.get_current_rendering_method(),
		"level_id":String(world.get_meta(&"level_id")),"window_title":root.title,
		"removed_corner_ui":{"brief_present":world.ui_layer.has_node("WhiteboxBrief"),"controls_present":world.ui_layer.has_node("WhiteboxControls")},
		"driver":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),
		"world_size":str(display.world_viewport.size),"window_size":str(root.size),"map_metres":"38 x 12",
		"camera_fov":world.camera_3d.fov,"opening_passed":opening_passed,"opening_physics_frames":opening_frames,
		"clock_at_pickup_before_feedback_expiry":pickup_clock,"feedback_settle_frames":feedback_frames,
		"completed":completed,"final_player":str(finished_player),"remaining":finished_remaining,
		"frames":frames,"audio_driver":AudioServer.get_driver_name(),
		"scope":"Native throw/pickup/weapon actions, live AI and real Camera; replay-only damage immunity. art_* are separate clean camera photographs with AI held. Screenshot readbacks, no performance benchmark"}
	var file := FileAccess.open(artifact_dir.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WHITEBOX_CAPTURE opening=",opening_passed," completed=",completed," renderer=",report.renderer," driver=",report.driver," PID=",report.pid)
	var passed := opening_passed and completed
	current_scene=null;display.queue_free()
	for frame in 8:await process_frame
	quit(0 if passed else 1)
