extends "res://scripts/dream/office_skeleton_world_base.gd"
## Parallel Level 1-1: Chronon Research Unit '回' Stairwell & Central H06 Containment Bay.

const L := preload("res://scripts/testing/h06_chapter/h06_base_layout.gd")
const ART := preload("res://scripts/testing/h06_chapter/h06_gallery_art.gd")
const OPTICS := preload("res://scripts/dream/office_light_optics.gd")

var _art: ART
var _camera_elevation := L.CORRIDOR_ENTRY_Y
var _camera_initialized := false
var _spotlight_triggered := false


func _ready() -> void:
	set_meta(&"test_floor_reflections_disabled", true)
	if not campaign_run:
		configured_weapon_id = ""
	super._ready()
	OPTICS.install(self, true, true)
	player_has_left_elevator_cab = true
	if night_lighting != null:
		night_lighting.set_flashlight_enabled(false)
	if is_instance_valid(objective_guidance):
		objective_guidance.queue_free()
		objective_guidance = null
	_sync_height_immediate()


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


func _sync_player_readability() -> void:
	if player_depth_bridge == null:
		return
	for mat_key: StringName in [&"lit_material", &"weapon_material"]:
		var mat := player_depth_bridge.get(mat_key) as ShaderMaterial
		if mat != null and not mat.has_meta(&"h06_readability_tuned"):
			mat.set_meta(&"h06_readability_tuned", true)
			# No local readability light bulb; keep only a faint dark-room visibility floor.
			mat.set_shader_parameter("character_emission_strength", 0.018)
			mat.set_shader_parameter("character_light_scale", 0.50)
			mat.set_shader_parameter("actor_pixel_rim_strength", 0.42)


func _sync_height_immediate() -> void:
	var xz := _player_world_xz()
	var h := _floor_height_at(xz)
	_camera_elevation = h
	_camera_initialized = true
	if player_depth_bridge != null:
		player_depth_bridge.ground_surface_height = h
		if player_depth_bridge.has_method("_process"):
			player_depth_bridge._process(0.0)
	_sync_player_readability()
	_update_camera_and_actor_projection(0.0)


func _physics_process(delta: float) -> void:
	_sync_runtime_height(delta)
	_check_spotlight_reveal_trigger()


func _check_spotlight_reveal_trigger() -> void:
	if _spotlight_triggered or _art == null:
		return
	var xz := _player_world_xz()
	if xz.x <= 8.15 or xz.y <= 4.30:
		_spotlight_triggered = true
		_art.play_spotlight_reveal(false)


func _floor_height_at(xz: Vector2) -> float:
	return L.ground_height(xz)


func _sync_runtime_height(delta: float) -> void:
	var xz := _player_world_xz()
	var h := _floor_height_at(xz)
	if not _camera_initialized:
		_camera_elevation = h
		_camera_initialized = true
	else:
		_camera_elevation = move_toward(_camera_elevation, h, maxf(0.02, delta * 7.5))
	if player_depth_bridge != null:
		player_depth_bridge.ground_surface_height = h
	_sync_player_readability()
	if authored_cutout != null and camera_3d != null and player_depth_bridge != null:
		var sprite := player_depth_bridge.get("actor_sprite") as Sprite3D
		authored_cutout.update_slots(camera_3d, [], 0.20, sprite, true)


func _update_camera_and_actor_projection(delta: float = 0.0) -> void:
	super._update_camera_and_actor_projection(delta)
	if player == null or camera_rig == null or camera_3d == null or gameplay_canvas == null:
		return
	var gp := _player_ground_anchor_position()
	var xz := gp / CELL_PIXELS
	var h := _floor_height_at(xz)
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
	var h := _floor_height_at(_player_world_xz())
	var mouse: Vector2 = player.get_presentation_pointer_position()
	var origin := camera_3d.project_ray_origin(mouse)
	var direction := camera_3d.project_ray_normal(mouse)
	var point: Variant = Plane(Vector3.UP, h).intersects_ray(origin, direction)
	if point is Vector3:
		var map_point := to_local(point)
		return Vector2(map_point.x, map_point.z) * CELL_PIXELS
	return player.global_position + player.last_aim_direction * 100.0
