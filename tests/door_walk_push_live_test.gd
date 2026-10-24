extends "res://tests/phone_tab_delivery.gd"
func run() -> void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"): quit(2); return
	output="res://.runtime/door_walk_push_20261023"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	Engine.max_fps=60
	main=load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await ready_main()
	main.persistent_day_state=main._create_initial_state()
	main.persistent_day_state.tutorial_completed=true
	main._show_dream("basic")
	await ready_main()
	world=main._supported_dream_world
	var deadline:=Time.get_ticks_msec()+60000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await wait(.05)
	world.spawn_content=false
	world.floor_transition_in_progress=true
	world.transition_phase=&"CAB_RIDE"
	if not await world._regenerate_staged(42002,1,world.transition_generation_token): quit(2); return
	world._set_floor_runtime_suspended_for_cab(false)
	world._set_building_exterior_visible(true)
	world.floor_transition_in_progress=false
	world.transition_phase=&"IDLE"
	var door: PhysicalDoor3D
	for node in world.door_root.get_children():
		if node is PhysicalDoor3D and not node.locked: door=node; break
	if door==null: quit(2); return
	var poses: Array[Transform3D]=[]
	for leaf in door._leaves: poses.append(leaf.transform)
	var center:=door.get_leaf_center_2d(0)
	var normal3:=door._get_map_basis().inverse()*door.global_basis.z
	var normal:=Vector2(normal3.x,normal3.z).normalized()
	world.player.invulnerability_left=1000.0
	var report: Array=[]
	for side in [-1.0,1.0]:
		for index in door._leaves.size():
			door._leaves[index].freeze=true
			door._leaves[index].transform=poses[index]
			door._leaves[index].angular_velocity=Vector3.ZERO
		door.latched=true
		door._passive_drive_left.fill(0.0)
		door._return_hold_left.fill(0.0)
		door._sync_gameplay_collision()
		var direction: Vector2=normal*float(side)
		world.player.global_position=center-direction*36.0-PhysicalDoor3D.CONFIG.player_collision_offset
		world.player.velocity=Vector2.ZERO
		await wait(.15)
		var start: Vector2=world.player.global_position
		var right: Vector2=world.player._camera_relative_movement_input(Vector2.RIGHT)
		var down: Vector2=world.player._camera_relative_movement_input(Vector2.DOWN)
		var input:=Transform2D(right,down,Vector2.ZERO).basis_xform_inv(direction).normalized()
		for pair in [["move_right",maxf(input.x,0)],["move_left",maxf(-input.x,0)],["move_down",maxf(input.y,0)],["move_up",maxf(-input.y,0)]]:
			if pair[1]>.001: Input.action_press(pair[0],pair[1])
		var angle:=0.0
		var crossed:=false
		for frame in 180:
			await physics_frame
			await process_frame
			angle=maxf(angle,door.get_open_angle())
			if frame in [30,60]:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output+"/side_%d_%d.png" % [int(side),frame])
			if (world.player.global_position+PhysicalDoor3D.CONFIG.player_collision_offset-center).dot(direction)>30.0:
				crossed=true; break
		for action in ["move_right","move_left","move_down","move_up"]: Input.action_release(action)
		check(crossed,"Player walks through door from side %d without E" % int(side))
		check(door.current_health==door.max_health,"Walking does not damage door")
		report.append({"side":side,"crossed":crossed,"angle_degrees":rad_to_deg(angle),"displacement":str(world.player.global_position-start)})
	print("DOOR_WALK_LIVE ",JSON.stringify({"checks":checks,"failures":failures,"cases":report}))
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":report},"\t")); file.close()
	main.free()
	quit(0 if failures.is_empty() else 1)
