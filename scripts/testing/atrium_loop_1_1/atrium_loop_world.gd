extends "res://scripts/dream/office_skeleton_world_base.gd"
## Parallel Level 1-1: Chronon Research Unit '回' Stairwell & Central H06 Containment Bay.

const L := preload("res://scripts/testing/atrium_loop_1_1/atrium_loop_layout.gd")
const ART := preload("res://scripts/testing/atrium_loop_1_1/atrium_loop_art.gd")
const OPTICS := preload("res://scripts/dream/office_light_optics.gd")

var _art: ART
var _camera_elevation := L.CORRIDOR_ENTRY_Y
var _camera_initialized := false
var _diag_dir := ""
var _diag_running := false
var _spotlight_triggered := false
var _player_readability_light: OmniLight3D


func _ready() -> void:
	set_meta(&"test_floor_reflections_disabled", true)
	configured_weapon_id = ""
	_parse_diag_arg()
	super._ready()
	OPTICS.install(self, true)
	player_has_left_elevator_cab = true
	if night_lighting != null:
		night_lighting.set_flashlight_enabled(false)
	if is_instance_valid(objective_guidance):
		objective_guidance.queue_free()
		objective_guidance = null
	_ensure_player_readability_light()
	_sync_height_immediate()
	if not _diag_dir.is_empty():
		call_deferred(&"_run_diagnostic_capture")


func _parse_diag_arg() -> void:
	for arg: String in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--atrium-diag="):
			_diag_dir = arg.trim_prefix("--atrium-diag=").strip_edges()


func uses_office_night_lighting() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


func uses_office_wall_cutaway() -> bool:
	return false


func _get_skeleton_source() -> Dictionary:
	return L.layout_source()


func _choose_elevator_anchor() -> bool:
	spawn_cell = L.SPAWN_CELL
	main_entrance = {"start_cell": spawn_cell}
	elevator_room_id = -1
	return floor_cells.has(spawn_cell)


func _validate_layout() -> Dictionary:
	var report := _validate_floor_connectivity()
	report["valid"] = report.all_floor_reachable and report.all_room_centers_reachable and floor_cells.has(L.SPAWN_CELL)
	return report


func _build_floor() -> void:
	_art = ART.new(self)
	authored_cutout = _art.cutout
	_art.build()


func _build_walls() -> void:
	pass


func _build_doors() -> void:
	pass


func _validate_rendered_edge_nodes() -> void:
	rendered_edge_failures = 0


func _prepare_approved_office_art() -> void:
	get_combat_defense()


func _build_ceiling_lights() -> void:
	if _art != null:
		_art.build_lighting(ceiling_light_root)


func _spawn_elevator() -> bool:
	return true


func _spawn_random_content() -> void:
	pass


func _spawn_special_units() -> void:
	pass


func _player_world_xz() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2(L.SPAWN_CELL)
	var gp := _player_ground_anchor_position()
	return gp / CELL_PIXELS


func _ensure_player_readability_light() -> void:
	if _player_readability_light != null and is_instance_valid(_player_readability_light):
		return
	_player_readability_light = OmniLight3D.new()
	_player_readability_light.name = "PlayerReadabilityFill"
	_player_readability_light.light_color = Color("ddebf4")
	_player_readability_light.light_energy = 2.05
	_player_readability_light.omni_range = 6.0
	_player_readability_light.omni_attenuation = 1.15
	_player_readability_light.shadow_enabled = false
	_player_readability_light.light_cull_mask = 2
	add_child(_player_readability_light)


func _sync_player_readability(xz: Vector2, h: float) -> void:
	if _player_readability_light != null and is_instance_valid(_player_readability_light):
		_player_readability_light.position = Vector3(xz.x - 0.45, h + 1.85, xz.y + 1.55)
	if player_depth_bridge != null:
		var mat := player_depth_bridge.get("lit_material") as ShaderMaterial
		if mat != null and not mat.has_meta(&"atrium_readability_tuned"):
			mat.set_meta(&"atrium_readability_tuned", true)
			mat.set_shader_parameter("character_emission_strength", 0.085)
			mat.set_shader_parameter("character_light_scale", 0.90)
			mat.set_shader_parameter("actor_pixel_rim_strength", 0.42)


func _sync_height_immediate() -> void:
	var xz := _player_world_xz()
	var h := L.ground_height(xz)
	_camera_elevation = h
	_camera_initialized = true
	if player_depth_bridge != null:
		player_depth_bridge.ground_surface_height = h
		if player_depth_bridge.has_method("_process"):
			player_depth_bridge._process(0.0)
	_sync_player_readability(xz, h)
	_update_camera_and_actor_projection(0.0)


func _physics_process(delta: float) -> void:
	_sync_runtime_height(delta)
	_check_spotlight_reveal_trigger()


func _check_spotlight_reveal_trigger() -> void:
	if _spotlight_triggered or _art == null or _diag_running:
		return
	var xz := _player_world_xz()
	if xz.x <= 8.15 or xz.y <= 4.30:
		_spotlight_triggered = true
		_art.play_spotlight_reveal(false)


func _sync_runtime_height(delta: float) -> void:
	var xz := _player_world_xz()
	var h := L.ground_height(xz)
	if not _camera_initialized:
		_camera_elevation = h
		_camera_initialized = true
	else:
		_camera_elevation = move_toward(_camera_elevation, h, maxf(0.02, delta * 7.5))
	if player_depth_bridge != null:
		player_depth_bridge.ground_surface_height = h
	_sync_player_readability(xz, h)
	if authored_cutout != null and camera_3d != null and player_depth_bridge != null:
		var sprite := player_depth_bridge.get("actor_sprite") as Sprite3D
		authored_cutout.update_slots(camera_3d, [], 0.20, sprite, true)


func _update_camera_and_actor_projection(delta: float = 0.0) -> void:
	super._update_camera_and_actor_projection(delta)
	if player == null or camera_rig == null or camera_3d == null or gameplay_canvas == null:
		return
	var gp := _player_ground_anchor_position()
	var xz := gp / CELL_PIXELS
	var h := L.ground_height(xz)
	if not _camera_initialized:
		_camera_elevation = h
		_camera_initialized = true
	camera_rig.position.y += _camera_elevation
	var elevated_ground := Vector3(xz.x, h, xz.y)
	var screen_pos := camera_3d.unproject_position(to_global(elevated_ground))
	gameplay_canvas.transform = Transform2D(Vector2.RIGHT, Vector2.DOWN, screen_pos - gp)


func get_gameplay_aim_position() -> Vector2:
	if camera_3d == null or not is_instance_valid(camera_3d) or not camera_3d.is_inside_tree():
		return player.global_position + player.last_aim_direction * 100.0
	var h := L.ground_height(_player_world_xz())
	var mouse: Vector2 = player.get_presentation_pointer_position()
	var origin := camera_3d.project_ray_origin(mouse)
	var direction := camera_3d.project_ray_normal(mouse)
	var point: Variant = Plane(Vector3.UP, h).intersects_ray(origin, direction)
	if point is Vector3:
		var map_point := to_local(point)
		return Vector2(map_point.x, map_point.z) * CELL_PIXELS
	return player.global_position + player.last_aim_direction * 100.0


func _run_diagnostic_capture() -> void:
	if _diag_running:
		return
	_diag_running = true
	DirAccess.make_dir_recursive_absolute(_diag_dir)
	var report := {"level": "1-1-AtriumLoop", "samples": [], "walk_checks": [], "rendered_edge_failures": rendered_edge_failures}

	for _f in 6:
		await get_tree().process_frame

	# Ensure spotlights start dark before SE entry
	_spotlight_triggered = false
	if _art != null:
		_art.reset_spotlight_reveal()

	var ov := Camera3D.new()
	ov.name = "OverviewDiagCamera"
	ov.projection = Camera3D.PROJECTION_PERSPECTIVE
	ov.fov = 38.0
	ov.far = 200.0
	add_child(ov)
	var cam_target := to_global(Vector3(-0.2, 1.1, -0.4))
	var cam_pos := to_global(Vector3(11.5, 17.0, 20.5))
	ov.global_transform = Transform3D(Basis.looking_at((cam_target - cam_pos).normalized(), Vector3.UP), cam_pos)

	# Capture unlit moody overview before player enters SE Overlook
	var prev_canvas_vis := gameplay_canvas.visible if gameplay_canvas != null else false
	if gameplay_canvas != null:
		gameplay_canvas.visible = false
	ov.current = true
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_diag_dir.path_join("00a_overview_before_reveal.png"))
	if camera_3d != null:
		camera_3d.current = true
	if gameplay_canvas != null:
		gameplay_canvas.visible = prev_canvas_vis

	# Check physics walkability along the elevated suspended L-corridor (no descent stair to 1F base platform)
	var waypoints := [
		["se_entry_spur", Vector2(10.0, 6.0), Vector2(-1.0, 0.0)],
		["se_landing_overlook", Vector2(5.5, 6.2), Vector2(-1.0, -0.3)],
		["east_lower_201", Vector2(5.5, 4.2), Vector2(-0.5, -1.0)],
		["east_stair_climb", Vector2(5.5, 0.5), Vector2(-0.5, -1.0)],
		["east_upper_stair", Vector2(5.5, -1.8), Vector2(-0.5, -1.0)],
		["ne_landing_203", Vector2(5.5, -5.8), Vector2(-1.0, 0.0)],
		["north_amaral_204", Vector2(2.2, -6.2), Vector2(-1.0, 0.0)],
		["north_stair_205", Vector2(-0.8, -6.2), Vector2(-1.0, 0.0)],
		["nw_gallery_206", Vector2(-5.2, -6.2), Vector2(0.0, 1.0)],
	]

	for i in waypoints.size():
		var name: String = waypoints[i][0]
		var target_xz: Vector2 = waypoints[i][1]
		var aim_dir: Vector2 = waypoints[i][2].normalized()
		player.global_position = target_xz * CELL_PIXELS
		player.velocity = Vector2.ZERO
		player.last_aim_direction = aim_dir
		_sync_height_immediate()
		if not _spotlight_triggered and (target_xz.x <= 8.15 or target_xz.y <= 4.30):
			_spotlight_triggered = true
			if _art != null:
				_art.play_spotlight_reveal(false)
			# Allow the real runtime Tween (~1.3s) to finish illuminating the H06 bay
			for _tw in 95:
				await get_tree().physics_frame
				await get_tree().process_frame
		for _step in 4:
			await get_tree().physics_frame
			await get_tree().process_frame
		# Also perform real physics velocity step test at each point
		var before_pos := player.global_position
		player.velocity = aim_dir * 40.0
		player.move_and_slide()
		var moved_dist := before_pos.distance_to(player.global_position)
		player.global_position = target_xz * CELL_PIXELS
		player.velocity = Vector2.ZERO
		_sync_height_immediate()
		await get_tree().process_frame
		await get_tree().process_frame

		var shot_name := "%02d_%s.png" % [i + 1, name]
		var out_path := _diag_dir.path_join(shot_name)
		get_viewport().get_texture().get_image().save_png(out_path)
		var sprite := player_depth_bridge.get("actor_sprite") as Sprite3D
		report.samples.append({
			"file": shot_name,
			"xz": [target_xz.x, target_xz.y],
			"expected_height": L.ground_height(target_xz),
			"bridge_height": player_depth_bridge.ground_surface_height if player_depth_bridge != null else -999.0,
			"sprite_y": sprite.global_position.y if sprite != null else -999.0,
			"moved_px": moved_dist,
		})

	report["spotlight_triggered"] = _spotlight_triggered
	report["spotlight_key_energy"] = _art._spot_key.light_energy if (_art != null and is_instance_valid(_art._spot_key)) else -1.0
	report["viewport_size"] = [get_viewport().size.x, get_viewport().size.y]
	# Overview cameras after spotlight reveal
	if gameplay_canvas != null:
		gameplay_canvas.visible = false
	ov.global_transform = Transform3D(Basis.looking_at((cam_target - cam_pos).normalized(), Vector3.UP), cam_pos)
	ov.current = true
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_diag_dir.path_join("00_overview_full_atrium.png"))

	var top_target := to_global(Vector3(0.0, 1.1, -0.8))
	var top_pos := to_global(Vector3(0.0, 25.0, 14.4))
	ov.global_transform = Transform3D(Basis.looking_at((top_target - top_pos).normalized(), Vector3.UP), top_pos)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_diag_dir.path_join("00b_overview_topdown_gamecam.png"))

	var bay_target := to_global(Vector3(-3.0, 0.9, 1.2))
	var bay_pos := to_global(Vector3(-3.0, 13.5, 11.5))
	ov.global_transform = Transform3D(Basis.looking_at((bay_target - bay_pos).normalized(), Vector3.UP), bay_pos)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_diag_dir.path_join("00c_overview_h06_bay.png"))
	if camera_3d != null:
		camera_3d.current = true
	if gameplay_canvas != null:
		gameplay_canvas.visible = prev_canvas_vis
	ov.queue_free()

	var f := FileAccess.open(_diag_dir.path_join("runtime_report.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("ATRIUM_LOOP_DIAG_OK")
	get_tree().quit()
