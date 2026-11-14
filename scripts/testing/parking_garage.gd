extends "res://scripts/dream/office_skeleton_world_base.gd"
## Level 0-2. The reference grid drives the floor, walls and collision.

const GARAGE_AREA := preload("res://scripts/testing/parking_garage_area.gd")
const VAN_AMBUSH := preload("res://scripts/testing/parking_van_ambush.gd")
const HALL = GARAGE_AREA.HALL
const ENTRY = GARAGE_AREA.ENTRY
const EXIT = GARAGE_AREA.EXIT
const END_FADE = GARAGE_AREA.END_FADE
const VEHICLE_RECESS = GARAGE_AREA.VEHICLE_RECESS
const SECTIONS = GARAGE_AREA.SECTIONS
const SECTION_NAMES = GARAGE_AREA.SECTION_NAMES
const SPAWN = GARAGE_AREA.SPAWN
const COLUMN_X = GARAGE_AREA.COLUMN_X
const COLUMN_Z = GARAGE_AREA.COLUMN_Z
const CEILING_HEIGHT = GARAGE_AREA.CEILING_HEIGHT
const PARKED_CARS = GARAGE_AREA.PARKED_CARS
const ENCOUNTER = GARAGE_AREA.ENCOUNTER

signal level_finished

var level_cleared := false
var _garage_area: GARAGE_AREA
var van_ambush: VAN_AMBUSH
var bed_player: AudioStreamPlayer
var bed_duck: Tween


func _ready() -> void:
	# Reflections belong to the garage concrete and the shared scene lights.
	set_meta(&"test_floor_reflections_disabled", true)
	configured_weapon_id = ""
	super._ready()
	preload("res://scripts/dream/office_light_optics.gd").install(self, true)
	player_has_left_elevator_cab = true
	night_lighting.set_flashlight_enabled(false)
	if is_instance_valid(objective_guidance):
		objective_guidance.queue_free()
		objective_guidance = null
	_start_garage_bed()


func uses_office_night_lighting() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


func uses_office_wall_cutaway() -> bool:
	return false


func _get_skeleton_source() -> Dictionary:
	return GARAGE_AREA.layout_source()


func _choose_elevator_anchor() -> bool:
	# This is a standalone pedestrian entrance and a marked ramp exit.
	spawn_cell = SPAWN
	main_entrance = {"start_cell": spawn_cell}
	elevator_room_id = -1
	return floor_cells.has(spawn_cell)


func _validate_layout() -> Dictionary:
	var report := _validate_floor_connectivity()
	report["valid"] = (
		report.all_floor_reachable
		and report.all_room_centers_reachable
		and floor_cells.has(EXIT.end - Vector2i.ONE)
	)
	return report


func _build_floor() -> void:
	_garage_area = GARAGE_AREA.new(self, floor_root, wall_root)
	authored_cutout = _garage_area.cutout
	_garage_area.build_floor()


func _build_walls() -> void:
	_garage_area.build_walls()


func _build_doors() -> void:
	pass


func _validate_rendered_edge_nodes() -> void:
	# Each authored boundary run can represent several compiled cell edges.
	rendered_edge_failures = 0


func _prepare_approved_office_art() -> void:
	get_combat_defense()


func _build_ceiling_lights() -> void:
	GARAGE_AREA.MAINTENANCE.configure_environment(self)
	var environment: Environment = $Lighting/WorldEnvironment.environment
	environment.background_color = Color.BLACK
	environment.ambient_light_color = Color("a7b3a8")
	environment.ambient_light_energy = .057
	$Lighting/KeyLight.hide()
	_garage_area.build_lighting(ceiling_light_root)


func _spawn_elevator() -> bool:
	van_ambush = _garage_area.build_portals(wake_exit_root, spawn_room_id)
	return true


func _spawn_random_content() -> void:
	_garage_area.spawn_guards(spawn_room_id)


func _set_room_content_active(room_id: int, active: bool) -> void:
	super._set_room_content_active(room_id, active)
	if room_id != spawn_room_id or enemy_root == null:
		return
	# The standalone entrance refreshes the room after placing its guards.
	var guard := enemy_root.get_node_or_null(^"UpperRightGuard") as EmployeeEnemy
	if guard != null and not guard.dead and guard.has_meta(&"garage_crash_guard"):
		guard.set_physics_process(false)


func _spawn_special_units() -> void:
	pass


func _start_garage_bed() -> void:
	if is_instance_valid(bed_player):
		return
	bed_player = GARAGE_AREA.make_room_tone()
	add_child(bed_player)
	bed_player.play()


func duck_garage_bed() -> void:
	if is_instance_valid(bed_player):
		bed_duck = GARAGE_AREA.duck_room_tone(bed_player, bed_duck)


func _clear_generated_building() -> void:
	level_cleared = false
	if is_instance_valid(van_ambush):
		van_ambush.reset_camera()
		van_ambush = null
	_garage_area = null
	super._clear_generated_building()


func _update_camera_and_actor_projection(delta: float = 0.0) -> void:
	var ordinary_fov := authoritative_camera_fov
	if is_instance_valid(van_ambush):
		authoritative_camera_fov = lerpf(ordinary_fov, 53.0, van_ambush.get_camera_weight())
	super._update_camera_and_actor_projection(delta)
	authoritative_camera_fov = ordinary_fov


func _process(delta: float) -> void:
	super._process(delta)
	var at := player.global_position / CELL_PIXELS
	if not level_cleared and EXIT.has_point(_cell_for_gameplay_position(player.global_position)) and at.x > EXIT.position.x + 1.35:
		level_cleared = true
		level_finished.emit()
