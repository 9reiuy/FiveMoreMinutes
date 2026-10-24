extends SceneTree
var main: Node
var world: Node
var samples: Array = []
var draw_samples: Array = []
var draw_captures := 0
func _init() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func ready_main() -> void:
	var deadline := Time.get_ticks_msec()+60000
	while main.transition_running and Time.get_ticks_msec()<deadline: await process_frame
	await frames(30)
func run() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size = Vector2i(1280,720)
	Engine.max_fps = 60
	main = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await ready_main()
	main.persistent_day_state = main._create_initial_state()
	main.persistent_day_state.tutorial_completed = true
	seed(120)
	main._show_dream("lucille")
	await ready_main()
	world = main._supported_dream_world
	if world == null:
		push_error("Formal Main did not enter Dream")
		quit(2)
		return
	var deadline := Time.get_ticks_msec()+90000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
	await frames(30)
	var player: Node = world.player
	# Normal live callbacks stay enabled. Move only the test actor to a clear
	# generated office, avoiding the entrance's foreground wall and blink state.
	for room in world.rooms:
		if String(room.get("archetype","")) != "open_office": continue
		var found := false
		for cell in room.get("usable_cells",[]):
			var point := Vector2(cell)*32.0
			if world._content_position_is_clear(point,85.0):
				player.global_position = point
				world.activate_room(int(room.id))
				found = true
				break
		if found: break
	player.maximum_health = 1000000.0
	player.current_health = 1000000.0
	player.invulnerability_left = 0.0
	await frames(30)
	if player.selected_weapon_id != "lucille": player.equip_weapon("lucille",world.config,{})
	var weapon: Node = player.lucille_weapon
	var pre_capture := func() -> void:
		var visual: Node3D = weapon._visual
		draw_samples.append({"frame":Engine.get_process_frames(),"visible":is_instance_valid(visual) and visual.is_visible_in_tree(),
			"sweep":weapon.sweep_progress,"action":weapon.melee_action_active,"elapsed":weapon.swing_elapsed,
			"opacity":visual.material.get_shader_parameter("opacity") if is_instance_valid(visual) else -1,
			"same_world":visual.get_world_3d()==world.camera_3d.get_world_3d() if is_instance_valid(visual) else false})
	var post_capture := func() -> void:
		if draw_captures >= 6 or draw_samples.is_empty(): return
		var sample: Dictionary = draw_samples[-1]
		if sample.visible and sample.sweep > .4 and float(sample.opacity)>.4:
			root.get_texture().get_image().save_png("res://.runtime/melee_sweep_20261021/draw_arc_%d.png" % draw_captures)
			draw_captures += 1
	RenderingServer.frame_pre_draw.connect(pre_capture)
	RenderingServer.frame_post_draw.connect(post_capture)
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_visible_rect().size*.5+Vector2(100,0)
	Input.parse_input_event(motion)
	var button := InputEventMouseButton.new()
	button.position = motion.position
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	Input.parse_input_event(button)
	var began := Time.get_ticks_msec()
	var seen_action := false
	var seen_arc := false
	var max_rotation := 0.0
	var captured := 0
	var output := "res://.runtime/melee_sweep_20261021/live_camera_fixed"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for frame in 240:
		await process_frame
		if Time.get_ticks_msec()-began>1800 and button.pressed:
			button = button.duplicate()
			button.pressed = false
			Input.parse_input_event(button)
		var arc_visible: bool = is_instance_valid(weapon._visual) and weapon._visual.is_visible_in_tree()
		var diag := {}
		if arc_visible:
			var material: ShaderMaterial = weapon._visual.material
			diag = {"minimum_limit":Array(weapon._reach_limits).min(),"maximum_limit":Array(weapon._reach_limits).max(),
				"mesh_aabb":weapon._visual.mesh.get_aabb(),"mesh_scale":weapon._visual.mesh.global_basis.get_scale(),
				"mesh_position":weapon._visual.mesh.global_position,"material_matches":weapon._visual.mesh.material_override==material,
				"instance_valid":weapon._visual.mesh.get_instance().is_valid(),"mesh_world_matches":weapon._visual.mesh.get_world_3d()==world.camera_3d.get_world_3d(),
				"visibility_range":weapon._visual.mesh.visibility_range_end,"shadow_mode":weapon._visual.mesh.cast_shadow,
				"material_sweep":material.get_shader_parameter("sweep"),"material_opacity":material.get_shader_parameter("opacity"),
				"global_position":weapon._visual.global_position,"screen_position":world.camera_3d.unproject_position(weapon._visual.global_position),
				"mesh_visible":weapon._visual.mesh.is_visible_in_tree(),"layers":weapon._visual.mesh.layers,"camera_mask":world.camera_3d.cull_mask,
				"player_position":player.global_position,"floor_y":world.floor_root.position.y}
		seen_action = seen_action or weapon.melee_action_active
		seen_arc = seen_arc or arc_visible
		max_rotation = maxf(max_rotation,absf(player.weapon_motion.rotation))
		samples.append({"frame":frame,"real_ms":Time.get_ticks_msec()-began,"selected":player.selected_weapon_id,
			"active":weapon.active,"attack_allowed":player.attacking_enabled,"movement_allowed":player.movement_enabled,
			"input_gate":player._presentation_pointer_input_allowed(),"trigger":player.should_trigger_weapon_attack(),
			"weapon_physics":weapon.is_physics_processing(),"weapon_process":weapon.is_processing(),"paused":paused,
			"action":weapon.melee_action_active,"elapsed":weapon.swing_elapsed,"sweep":weapon.sweep_progress,
			"arc_visible":arc_visible,"rotation":player.weapon_motion.rotation,"time_scale":Engine.time_scale,"diag":diag})
		if frame%2 == 0 and "--record-all" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"/frame_%03d.png" % captured)
			captured += 1
		if Time.get_ticks_msec()-began>3500: break
	button = button.duplicate()
	button.pressed = false
	Input.parse_input_event(button)
	var result := {"seen_action":seen_action,"seen_arc":seen_arc,"max_rotation":max_rotation,"samples":samples,"draw_samples":draw_samples}
	var material_mismatches := 0
	for sample in samples:
		if sample.arc_visible and not sample.diag.material_matches: material_mismatches += 1
	result["material_mismatches"] = material_mismatches
	var file := FileAccess.open("res://.runtime/melee_sweep_20261021/live_input_fixed.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("MELEE_LIVE_INPUT action=",seen_action," arc=",seen_arc," rotation=",max_rotation)
	RenderingServer.frame_pre_draw.disconnect(pre_capture)
	RenderingServer.frame_post_draw.disconnect(post_capture)
	main.free()
	await frames(4)
	quit(0 if seen_action and seen_arc and max_rotation>.1 and material_mismatches==0 else 1)
