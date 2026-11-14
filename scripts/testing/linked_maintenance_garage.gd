extends "res://scripts/testing/megastructure_whitebox.gd"
## The authored regions share one Player, Camera and floor graph.

const GARAGE_AREA := preload("res://scripts/testing/parking_garage_area.gd")
const STORAGE_AREA := preload("res://scripts/testing/storage_warehouse_area.gd")
const TRANSIT_AREA := preload("res://scripts/testing/transit_concourse_area.gd")
const METRO_AREA := preload("res://scripts/testing/metro_station/linked_metro_area.gd")
const TRAIN_CHAPTER := preload("res://scripts/testing/metro_station/train_chapter.gd")
const VAN_AMBUSH := preload("res://scripts/testing/parking_van_ambush.gd")
const LINK := Rect2i(38, 5, 3, 2)
const GARAGE_OFFSET := Vector2i(43, -19)
const GARAGE_ROOM_ID := 4
const STORAGE_ROOM_ID := GARAGE_ROOM_ID + 1
const STORAGE_OFFSET := GARAGE_OFFSET + Vector2i(GARAGE_AREA.EXIT.end.x, GARAGE_AREA.EXIT.position.y)
const STORAGE_MOUTH_X := STORAGE_OFFSET.x + STORAGE_AREA.WEST_EDGE
const STORAGE_REVEAL_X := STORAGE_MOUTH_X + .42
const TRANSIT_ROOM_ID := STORAGE_ROOM_ID + 1
const STORAGE_EXIT_EDGE := STORAGE_OFFSET + Vector2i(STORAGE_AREA.EXIT.end.x, STORAGE_AREA.EXIT.position.y)
const TRANSIT_OFFSET := STORAGE_EXIT_EDGE - TRANSIT_AREA.SERVICE.position
const TRANSIT_MOUTH_X := STORAGE_EXIT_EDGE.x - .5
const TRANSIT_REVEAL_X := TRANSIT_MOUTH_X + .42
const METRO_ROOM_ID := TRANSIT_ROOM_ID + 1
const TRANSIT_NORTH_EDGE := TRANSIT_OFFSET + TRANSIT_AREA.SPINE.position
const METRO_OFFSET := TRANSIT_NORTH_EDGE - Vector2i(METRO_AREA.NECK.position.x, METRO_AREA.NECK.end.y)
const METRO_MOUTH_Z := TRANSIT_NORTH_EDGE.y - .5
const METRO_REVEAL_Z := METRO_MOUTH_Z - .85
const MAINTENANCE_ROOM_COUNT := 3
const LINK_START_X := LINK.position.x - .5
const GARAGE_MOUTH_X := LINK.end.x - .5
# Let the player's collision circle clear the return plane before sealing it.
const GARAGE_REVEAL_X := GARAGE_MOUTH_X + .42
const JOINED_MAINTENANCE_FADE := Vector4(-.5, 2.2, 36.6, GARAGE_REVEAL_X)
const UNLOAD_BATCH_SIZE := 8

signal linked_level_finished
signal train_chapter_started
signal train_chapter_completed

var garage_visible := false
var garage_exit_reached := false
var storage_finished := false
var transit_finished := false
var metro_reached_platform := false
var _exit_unlocked := false
var van_ambush: VAN_AMBUSH
var _garage: GARAGE_AREA
var _garage_art: Array[Node3D] = []
var _maintenance_nodes: Array[Node] = []
var _garage_nodes: Array[Node] = []
var _storage_nodes: Array[Node] = []
var _transit_nodes: Array[Node] = []
var _unload_queue: Array[WeakRef] = []
var _backstop: CollisionShape2D
var _storage_art: Node3D
var _storage_cutout: AUTHORED_CUTOUT
var _storage_backstop: CollisionShape2D
var _storage_door: PhysicalDoor3D
var _transit_art: Node3D
var _transit_cutout: AUTHORED_CUTOUT
var _transit_backstop: CollisionShape2D
var _metro: METRO_AREA
var _metro_backstop: CollisionShape2D
var _train: TRAIN_CHAPTER
var _train_transfer := false
var _train_cover: CanvasLayer
var _storage_blocked_cells: Dictionary = {}
var _storage_exit_wave_started := false
var _pending_guards: Array[Dictionary] = []
var _garage_bed: AudioStreamPlayer
var _garage_bed_duck: Tween
var _garage_return_zoom := -1.0


func _ready() -> void:
	super._ready()
	player.collision_mask |= METRO_AREA.PLAYER_EDGE_LAYER
	_garage_bed = GARAGE_AREA.make_room_tone()
	add_child(_garage_bed)


func _get_skeleton_source() -> Dictionary:
	var layout := WHITEBOX_LAYOUT.build()
	var parking := GARAGE_AREA.layout_source("garage", GARAGE_OFFSET)
	var storage := STORAGE_AREA.room_source(STORAGE_OFFSET)
	var transit := TRANSIT_AREA.room_source(TRANSIT_OFFSET)
	var metro := METRO_AREA.room_source(METRO_OFFSET)
	var cells: Array[String] = []
	for z in range(LINK.position.y, LINK.end.y):
		for x in range(LINK.position.x, LINK.end.x):
			cells.append("%d,%d" % [x, z])
	layout.type = "LINKED_MAINTENANCE_GARAGE_STORAGE_TRANSIT_METRO"
	layout.rooms.append({"id":"service", "label":"维修通道", "kind":"corridor", "cells":cells,
		"bounds":{"x":LINK.position.x, "y":LINK.position.y, "w":LINK.size.x, "h":LINK.size.y}})
	layout.anchors.service = "%d,%d" % [LINK.get_center().x, LINK.get_center().y]
	layout.rooms.append(parking.rooms[0])
	layout.rooms.append(storage)
	layout.rooms.append(transit)
	layout.rooms.append(metro)
	layout.anchors.merge(parking.anchors)
	var stockroom := STORAGE_AREA.HALL.get_center() + STORAGE_OFFSET
	layout.anchors.storage = "%d,%d" % [stockroom.x, stockroom.y]
	var concourse := TRANSIT_AREA.SPINE.get_center() + TRANSIT_OFFSET
	layout.anchors.transit = "%d,%d" % [concourse.x, concourse.y]
	var platform := METRO_OFFSET + Vector2i(2, 6)
	layout.anchors.metro = "%d,%d" % [platform.x, platform.y]
	var bounds := ADAPTER.rect(layout.bounds).merge(LINK).merge(ADAPTER.rect(parking.bounds))
	bounds = bounds.merge(ADAPTER.rect(storage.bounds)).merge(ADAPTER.rect(transit.bounds))
	bounds = bounds.merge(ADAPTER.rect(metro.bounds))
	layout.bounds = {"x":bounds.position.x, "y":bounds.position.y, "w":bounds.size.x, "h":bounds.size.y}
	layout.doors.append({"a":"arena", "b":"service", "vertical":true, "line":LINK.position.x,
		"start":LINK.position.y, "width":LINK.size.y, "glass":false, "open":true})
	layout.doors.append({"a":"service", "b":"garage", "vertical":true, "line":LINK.end.x,
		"start":LINK.position.y, "width":LINK.size.y, "glass":false, "open":true})
	layout.doors.append({"a":"garage", "b":"storage", "vertical":true, "line":STORAGE_OFFSET.x,
		"start":STORAGE_OFFSET.y, "width":STORAGE_AREA.ENTRY.size.y, "glass":false, "open":true})
	layout.doors.append({"a":"storage", "b":"transit", "vertical":true, "line":STORAGE_EXIT_EDGE.x,
		"start":STORAGE_EXIT_EDGE.y, "width":STORAGE_AREA.EXIT.size.y, "glass":false, "open":true})
	layout.doors.append({"a":"transit", "b":"metro", "vertical":false, "line":TRANSIT_NORTH_EDGE.y,
		"start":TRANSIT_NORTH_EDGE.x, "width":METRO_AREA.NECK.size.x, "glass":false, "open":true})
	return layout


func _validate_layout() -> Dictionary:
	var report := _validate_floor_connectivity()
	report["graph_connected"] = _room_graph_is_connected()
	var far_cells := METRO_AREA.FAR_PLATFORM.get_area()
	var far_start := METRO_OFFSET + METRO_AREA.FAR_PLATFORM.position
	report["far_platform_connected"] = _floor_distances(far_start).size() == far_cells
	report["all_player_floor_reachable"] = int(report.reachable_floor_count) + far_cells == floor_cells.size()
	var last_cell := METRO_AREA.PLATFORM.position + METRO_OFFSET
	report["valid"] = (rooms.size() == METRO_ROOM_ID + 1 and report.graph_connected
		and report.all_player_floor_reachable and report.far_platform_connected and report.all_room_centers_reachable
		and floor_cells.has(spawn_cell) and floor_cells.has(last_cell))
	return report


func _area_root(parent: Node3D, title: String, offset: Vector2i) -> Node3D:
	var area := Node3D.new()
	area.name = title
	area.position = Vector3(offset.x, 0.0, offset.y)
	area.hide()
	parent.add_child(area)
	return area


func _garage_root(parent: Node3D) -> Node3D:
	var area := _area_root(parent, "GarageArea", GARAGE_OFFSET)
	_garage_art.append(area)
	_garage_nodes.append(area)
	return area


func _build_floor() -> void:
	_build_maintenance_floor(MAINTENANCE_ROOM_COUNT, JOINED_MAINTENANCE_FADE)
	var concrete := MAINTENANCE.concrete(true)
	concrete.set_shader_parameter("passage_end_fade", JOINED_MAINTENANCE_FADE)
	MAINTENANCE.box(floor_root, "LinkSlab", Vector3(GARAGE_REVEAL_X - LINK_START_X, .12, LINK.size.y),
		Vector3((LINK_START_X + GARAGE_REVEAL_X) * .5, -.06, LINK.position.y + .5), concrete)
	_track_children(_maintenance_nodes, floor_root)
	var first_body := collision_root.get_child_count()
	_garage = GARAGE_AREA.new(self, _garage_root(floor_root), _garage_root(wall_root), GARAGE_OFFSET, true, true)
	_garage.build_floor()
	_track_children(_garage_nodes, collision_root, first_body)


func _build_walls() -> void:
	authored_cutout = AUTHORED_CUTOUT.new()
	var first_wall := wall_root.get_child_count()
	var first_body := collision_root.get_child_count()
	var north := LINK.position.y - .5
	var south := LINK.end.y - .5
	WHITEBOX_GEOMETRY.build_boundaries(self, Vector2(north, south), JOINED_MAINTENANCE_FADE)
	for edge: Vector2 in [Vector2(north - .19, north), Vector2(south, south + .19)]:
		var outline := PackedVector2Array([Vector2(LINK_START_X, edge.x), Vector2(GARAGE_REVEAL_X, edge.x),
			Vector2(GARAGE_REVEAL_X, edge.y), Vector2(LINK_START_X, edge.y)])
		var is_front := edge.x == south
		WHITEBOX_GEOMETRY._add_boundary(self, outline, .65 if is_front else 2.6, "LinkSideWall", JOINED_MAINTENANCE_FADE)
	_track_children(_maintenance_nodes, collision_root, first_body)
	var frame := MAINTENANCE.metal(Color("33404a"), .60)
	for z: float in [north - .045, south + .045]:
		authored_cutout.register_mesh(MAINTENANCE.box(wall_root, "LinkJamb", Vector3(.24, 2.18, .17),
			Vector3(GARAGE_MOUTH_X, 1.09, z), frame))
	authored_cutout.register_mesh(MAINTENANCE.box(wall_root, "LinkLintel", Vector3(.26, .16, LINK.size.y + .23),
		Vector3(GARAGE_MOUTH_X, 2.17, (north + south) * .5), frame))
	_track_children(_maintenance_nodes, wall_root, first_wall)
	first_body = collision_root.get_child_count()
	_garage.build_walls()
	_track_children(_garage_nodes, collision_root, first_body)
	_backstop = _make_backstop("LinkBackstop", Vector2(GARAGE_MOUTH_X, (north + south) * .5),
		LINK.size.y, not spawn_content)
	_garage_nodes.append(_backstop.get_parent())
	_storage_backstop = _make_backstop("StorageBackstop", Vector2(STORAGE_MOUTH_X, STORAGE_OFFSET.y + .5),
		STORAGE_AREA.ENTRY.size.y, not spawn_content)
	_storage_nodes.append(_storage_backstop.get_parent())
	first_body = collision_root.get_child_count()
	_storage_art = _area_root(floor_root, "StorageArea", STORAGE_OFFSET)
	_storage_nodes.append(_storage_art)
	var storage := STORAGE_AREA.new(self, _storage_art, STORAGE_OFFSET)
	storage.build()
	_storage_cutout = storage.cutout
	_track_children(_storage_nodes, collision_root, first_body)
	_storage_blocked_cells = STORAGE_AREA.blocked_cells(STORAGE_OFFSET)
	var exit_center_z := STORAGE_EXIT_EDGE.y + (STORAGE_AREA.EXIT.size.y - 1) * .5
	_transit_backstop = _make_backstop("TransitBackstop", Vector2(TRANSIT_MOUTH_X, exit_center_z),
		STORAGE_AREA.EXIT.size.y, not spawn_content)
	_transit_nodes.append(_transit_backstop.get_parent())
	first_body = collision_root.get_child_count()
	_transit_art = _area_root(floor_root, "TransitArea", TRANSIT_OFFSET)
	_transit_nodes.append(_transit_art)
	var transit := TRANSIT_AREA.new(self, _transit_art, TRANSIT_OFFSET)
	transit.build()
	_transit_cutout = transit.cutout
	_track_children(_transit_nodes, collision_root, first_body)
	var metro_center_x := TRANSIT_NORTH_EDGE.x + (METRO_AREA.NECK.size.x - 1) * .5
	# The collision circle is above the player's feet. Seal the northward join at the feet.
	var metro_stop_z := METRO_MOUTH_Z + config.player_collision_offset.y / CELL_PIXELS
	_metro_backstop = _make_backstop("MetroBackstop", Vector2(metro_center_x, metro_stop_z),
		METRO_AREA.NECK.size.x, not spawn_content, true)
	var metro_art := _area_root(floor_root, "MetroArea", METRO_OFFSET)
	metro_art.process_mode = Node.PROCESS_MODE_DISABLED
	_metro = METRO_AREA.new(self, metro_art, METRO_OFFSET)
	_metro.build()


func _make_backstop(title: String, at: Vector2, width: float, disabled: bool, horizontal := false) -> CollisionShape2D:
	var body := StaticBody2D.new()
	body.name = title
	body.position = at * CELL_PIXELS
	body.collision_layer = 4
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = (Vector2(width + .22, .08) if horizontal else Vector2(.08, width + .22)) * CELL_PIXELS
	collision.shape = shape
	collision.disabled = disabled
	body.add_child(collision)
	collision_root.add_child(body)
	return collision


func _build_doors() -> void:
	var center := Vector2(STORAGE_OFFSET) + STORAGE_AREA.RETURN_DOOR_CENTER
	_storage_door = DOOR_SCENE.instantiate() as PhysicalDoor3D
	_storage_door.name = "StorageServiceDoor"
	_storage_door.position = Vector3(center.x, 0.0, center.y)
	_storage_door.set_meta(&"door_id", _next_door_id)
	_storage_door.set_meta(&"office_metal_door", true)
	_storage_door.set_meta(&"surface_tint", Color("748982"))
	_storage_door.configure(STORAGE_AREA.RETURN_DOOR_WIDTH, STORAGE_AREA.RETURN_DOOR_HEIGHT,
		.095, "right", _next_door_id, &"single")
	_storage_door.hide()
	door_root.add_child(_storage_door)
	_storage_cutout.register_tree(_storage_door, true)
	var first_body := collision_root.get_child_count()
	_storage_door.configure_gameplay_collision(collision_root, CELL_PIXELS, WORLD_WALL_LAYER)
	_storage_door.set_gameplay_collision_enabled(false)
	_storage_door.set_physics_process(false)
	_storage_nodes.append(_storage_door)
	_track_children(_storage_nodes, collision_root, first_body)


func _build_ceiling_lights() -> void:
	super._build_ceiling_lights()
	var fixture := MAINTENANCE.cold_fixture(ceiling_light_root, "LinkCeilingLamp",
		Vector3((LINK_START_X + GARAGE_MOUTH_X) * .5, 2.31, LINK.position.y + .22), 2, PI * .5)
	var light: OmniLight3D = fixture.get_node("ColdPool")
	light.omni_range = 3.6
	light.light_energy = 1.30
	_track_children(_maintenance_nodes, ceiling_light_root)
	_garage.build_lighting(_garage_root(ceiling_light_root))


func _spawn_random_content() -> void:
	super._spawn_random_content()
	_garage.spawn_guards(GARAGE_ROOM_ID)
	_set_garage_enemies_active(false)


func _spawn_room_encounter(room_id: int) -> void:
	# Downstream regions use their authored rosters and triggers.
	if _train == null and room_id < GARAGE_ROOM_ID:
		super._spawn_room_encounter(room_id)


func _set_room_content_active(room_id: int, active: bool) -> void:
	if _train != null:
		return
	# The station controls when its train passengers start combat.
	if ((room_id < GARAGE_ROOM_ID and not garage_visible and not garage_exit_reached)
		or (room_id == STORAGE_ROOM_ID and garage_exit_reached and not storage_finished)
		or (room_id == TRANSIT_ROOM_ID and storage_finished and not transit_finished)):
		super._set_room_content_active(room_id, active)


func _update_otxo_room_tracking() -> void:
	if _train != null:
		var room_id := int(room_cells.get(_cell_for_gameplay_position(player.global_position), -1))
		if room_id >= 0 and room_id != current_room_id:
			set_current_room_id(room_id)
		return
	# Wait until the collision circle clears the seam to activate the next area.
	var player_x := player.global_position.x / CELL_PIXELS
	if (garage_visible and player_x >= STORAGE_MOUTH_X
		or garage_exit_reached and not storage_finished and player_x >= TRANSIT_MOUTH_X
		or storage_finished and not transit_finished and player.global_position.y / CELL_PIXELS <= METRO_MOUTH_Z):
		return
	super._update_otxo_room_tracking()


func _spawn_elevator() -> bool:
	super._spawn_elevator()
	_track_children(_maintenance_nodes, wake_exit_root)
	van_ambush = _garage.build_portals(_garage_root(wake_exit_root), GARAGE_ROOM_ID)
	if is_instance_valid(van_ambush):
		van_ambush.set_physics_process(false)
	return true


func _clear_generated_building() -> void:
	if _train != null:
		_train.reset()
		_train = null
	_train_transfer = false
	if is_instance_valid(_train_cover):
		_train_cover.queue_free()
		_train_cover = null
	if is_instance_valid(van_ambush):
		van_ambush.reset_camera()
	if _garage_return_zoom >= 0.0:
		clear_dialogue_focus()
		dialogue_camera.dialogue_zoom_factor = _garage_return_zoom
		_garage_return_zoom = -1.0
	van_ambush = null
	if is_instance_valid(_garage_bed):
		_garage_bed.stop()
		_garage_bed.volume_db = -18.0
	if _garage_bed_duck != null and _garage_bed_duck.is_valid():
		_garage_bed_duck.kill()
	_garage_art.clear()
	_garage_nodes.clear()
	_storage_nodes.clear()
	_transit_nodes.clear()
	_maintenance_nodes.clear()
	_unload_queue.clear()
	_backstop = null
	_storage_art = null
	_storage_cutout = null
	_storage_backstop = null
	_storage_door = null
	_transit_art = null
	_transit_cutout = null
	_transit_backstop = null
	if _metro != null and is_instance_valid(_metro.departure):
		_metro.departure.cancel()
	_metro = null
	_metro_backstop = null
	_storage_blocked_cells.clear()
	_storage_exit_wave_started = false
	_pending_guards.clear()
	_garage = null
	garage_visible = false
	garage_exit_reached = false
	storage_finished = false
	transit_finished = false
	metro_reached_platform = false
	_exit_unlocked = false
	super._clear_generated_building()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _train_transfer:
		return
	if _train != null:
		_train.advance(delta)
		return
	if player.dead:
		if _metro != null and is_instance_valid(_metro.departure):
			_metro.departure.cancel()
		return
	var at := _player_ground_anchor_position()
	var cell := _cell_for_gameplay_position(at)
	var x := at.x / CELL_PIXELS
	var z := at.y / CELL_PIXELS
	var room_id := int(room_cells.get(cell, -1))
	if transit_finished:
		var platform_depth := z - METRO_OFFSET.y
		if (not metro_reached_platform and platform_depth <= METRO_AREA.PLATFORM_REACH_Z
			and METRO_AREA.PLATFORM.has_point(cell - METRO_OFFSET)):
			metro_reached_platform = true
			linked_level_finished.emit()
		_metro.update_service(delta, METRO_ROOM_ID)
		if _metro.player_has_boarded(at):
			begin_train_chapter.call_deferred()
	elif storage_finished:
		var cleared := not spawn_content or (_pending_guards.is_empty() and _get_alive_employee_count() == 0)
		_set_exit_access(_metro_backstop, cleared)
		if cleared and z <= METRO_REVEAL_Z and room_id == METRO_ROOM_ID:
			_arrive_in_metro()
	elif garage_exit_reached:
		var storage_at := at / CELL_PIXELS - Vector2(STORAGE_OFFSET)
		if (spawn_content and not _storage_exit_wave_started and room_id == STORAGE_ROOM_ID
			and STORAGE_AREA.is_in_stockroom(storage_at)):
			_storage_exit_wave_started = true
			_pending_guards.append_array(STORAGE_AREA.EXIT_WAVE)
		var cleared := not spawn_content or (_storage_exit_wave_started and _pending_guards.is_empty() and _get_alive_employee_count() == 0)
		_set_exit_access(_transit_backstop, cleared)
		if cleared and x >= TRANSIT_REVEAL_X and room_id == TRANSIT_ROOM_ID:
			_arrive_in_transit()
	elif garage_visible:
		var cleared := not spawn_content or (is_instance_valid(van_ambush) and van_ambush.stage == VAN_AMBUSH.Stage.COMPLETE
			and _get_alive_employee_count() == 0)
		_set_exit_access(_storage_backstop, cleared)
		if cleared and x >= STORAGE_REVEAL_X and room_id == STORAGE_ROOM_ID:
			_arrive_in_storage()
	else:
		var cleared := not spawn_content or (opening_complete and _get_alive_employee_count() == _get_alive_employee_count_in_room(GARAGE_ROOM_ID))
		_set_exit_access(_backstop, cleared)
		if cleared and x >= GARAGE_REVEAL_X and room_id == GARAGE_ROOM_ID:
			_arrive_in_garage()


func _set_exit_access(gate: CollisionShape2D, unlocked: bool) -> void:
	_exit_unlocked = unlocked
	if is_instance_valid(gate) and gate.disabled != unlocked:
		gate.set_deferred("disabled", unlocked)


func is_player_dash_landing_allowed(position: Vector2) -> bool:
	if _train != null:
		return _train.dash_landing_allowed(position)
	var cell := _cell_for_gameplay_position(position)
	var room_id := int(room_cells.get(cell, -1))
	if transit_finished:
		return room_id == METRO_ROOM_ID and not METRO_AREA.FAR_PLATFORM.has_point(cell - METRO_OFFSET)
	if storage_finished:
		return room_id == TRANSIT_ROOM_ID or (_exit_unlocked and room_id == METRO_ROOM_ID)
	if garage_exit_reached:
		return room_id == STORAGE_ROOM_ID or (_exit_unlocked and room_id == TRANSIT_ROOM_ID)
	if garage_visible:
		return room_id == GARAGE_ROOM_ID or (_exit_unlocked and room_id == STORAGE_ROOM_ID)
	return (room_id >= 0 and room_id < GARAGE_ROOM_ID) or (_exit_unlocked and room_id == GARAGE_ROOM_ID)


func _arrive_in_garage() -> void:
	garage_visible = true
	_set_exit_access(_backstop, false)
	_retire_region(_maintenance_nodes, 0, GARAGE_ROOM_ID)
	for area in _garage_art:
		area.show()
	authored_cutout = _garage.cutout
	_set_garage_enemies_active(true)
	if is_instance_valid(van_ambush):
		van_ambush.begin_player_tracking()
	if is_instance_valid(_garage_bed):
		_garage_bed.play()


func _arrive_in_storage() -> void:
	garage_exit_reached = true
	garage_visible = false
	_set_exit_access(_storage_backstop, false)
	if is_instance_valid(van_ambush):
		_garage_return_zoom = van_ambush.release_for_area_exit()
	van_ambush = null
	if _garage_bed_duck != null and _garage_bed_duck.is_valid():
		_garage_bed_duck.kill()
	if is_instance_valid(_garage_bed):
		_garage_bed.stop()
	_retire_region(_garage_nodes, GARAGE_ROOM_ID, STORAGE_ROOM_ID)
	_backstop = null
	_garage_art.clear()
	_garage = null
	var environment: Environment = $Lighting/WorldEnvironment.environment
	environment.ambient_light_color = Color("929f96")
	environment.ambient_light_energy = .12
	_storage_art.show()
	authored_cutout = _storage_cutout
	_storage_door.show()
	_storage_door.set_gameplay_collision_enabled(true)
	_storage_door.wake_door_physics()
	if spawn_content:
		_pending_guards.assign(STORAGE_AREA.GUARDS)


func _arrive_in_transit() -> void:
	storage_finished = true
	_set_exit_access(_transit_backstop, false)
	_pending_guards.clear()
	_storage_blocked_cells.clear()
	_retire_region(_storage_nodes, STORAGE_ROOM_ID, TRANSIT_ROOM_ID)
	_storage_art = null
	_storage_cutout = null
	_storage_door = null
	_storage_backstop = null
	var environment: Environment = $Lighting/WorldEnvironment.environment
	environment.ambient_light_color = Color("a7a695")
	environment.ambient_light_energy = .16
	_transit_art.show()
	authored_cutout = _transit_cutout
	if spawn_content:
		_pending_guards.assign(TRANSIT_AREA.GUARDS)


func _arrive_in_metro() -> void:
	transit_finished = true
	_pending_guards.clear()
	_set_exit_access(_metro_backstop, false)
	_retire_region(_transit_nodes, TRANSIT_ROOM_ID, METRO_ROOM_ID)
	_transit_art = null
	_transit_cutout = null
	_transit_backstop = null
	var environment: Environment = $Lighting/WorldEnvironment.environment
	environment.ambient_light_color = Color("9abdb4")
	environment.ambient_light_energy = .16
	if spawn_content:
		var pickup := (Vector2(METRO_OFFSET) + Vector2(.92, 8.36)) * CELL_PIXELS
		_spawn_room_drop(METRO_ROOM_ID, {"type": &"weapon", "weapon_id": "basic", "ground_position": pickup})
	_metro.activate(METRO_ROOM_ID)
	authored_cutout = _metro.cutout


func _track_children(target: Array[Node], parent: Node, first := 0) -> void:
	for index in range(first, parent.get_child_count()):
		target.append(parent.get_child(index))


func begin_train_chapter(start_black := false) -> void:
	if _train_transfer or _train != null or player.dead:
		return
	_train_transfer = true
	_finish_opening_time()
	var movement: bool = player.movement_enabled
	var attack: bool = player.attacking_enabled
	var dash: bool = player.dash_enabled
	player.movement_enabled = false
	player.set_attacking_enabled(false)
	player.set_dash_enabled(false)
	player.velocity = Vector2.ZERO
	_clear_room_transition_transients()
	var black := _make_train_cover()
	if start_black:
		black.color.a = 1.0
		await get_tree().process_frame
	else:
		var fade := create_tween().set_ignore_time_scale(true)
		fade.tween_property(black, "color:a", 1.0, .24)
		await fade.finished
	if not _train_transfer or not is_instance_valid(black):
		return
	# Hide and disable the station before constructing the new area under black.
	# The Player and its depth bridge stay in the same world throughout.
	var retiring: Array[Node] = []
	for root in [floor_root, wall_root, door_root, collision_root, ceiling_light_root,
			wake_exit_root, transition_root, transition_trigger_root]:
		if is_instance_valid(root):
			_track_children(retiring, root)
	_retire_region(retiring, 0, rooms.size())
	if _metro != null:
		_metro._art.queue_free()
	_metro = null
	_garage = null
	if is_instance_valid(_garage_bed):
		_garage_bed.stop()
	_pending_guards.clear()
	await get_tree().process_frame
	if not _train_transfer or not is_instance_valid(black):
		return
	_train = TRAIN_CHAPTER.new(self)
	_train.build(bool(get_meta(&"test_train_whitebox", false)))
	train_chapter_started.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(black):
		return
	var reveal := create_tween().set_ignore_time_scale(true)
	reveal.tween_property(black, "color:a", 0.0, .34)
	await reveal.finished
	if not is_instance_valid(black):
		return
	_train_cover.queue_free()
	_train_cover = null
	_train_transfer = false
	if not player.dead:
		player.movement_enabled = movement
		player.set_attacking_enabled(attack)
		player.set_dash_enabled(dash)


func _make_train_cover() -> ColorRect:
	_train_cover = CanvasLayer.new()
	_train_cover.name = "TrainChapterBlack"
	_train_cover.layer = 90
	add_child(_train_cover)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_train_cover.add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return black


func finish_train_chapter() -> void:
	var black := _make_train_cover()
	var fade := create_tween().set_ignore_time_scale(true)
	fade.tween_property(black, "color:a", 1.0, .62)
	await fade.finished
	if is_instance_valid(black):
		train_chapter_completed.emit()


func _retire_region(nodes: Array[Node], first_room: int, next_room: int) -> void:
	# This gate is one way. Retire the old area immediately from the frame and
	# physics space, then release its scene objects over several idle frames.
	for root in [enemy_root, furniture_root, world_weapon_root, pickup_root, key_root, ground_debris_root, world_effects_root]:
		for child in root.get_children():
			# Preserve the dormant garage guards during the first transfer.
			# The storage roster is spawned after the garage is retired.
			if child != dash_aim_presentation and (next_room != GARAGE_ROOM_ID
				or int(child.get_meta(&"dream_room_id", -1)) != GARAGE_ROOM_ID):
				nodes.append(child)
	var retiring: Dictionary = {}
	for node in nodes:
		if not is_instance_valid(node):
			continue
		retiring[node.get_instance_id()] = true
		if node is Node3D or node is CanvasItem:
			node.hide()
		node.process_mode = Node.PROCESS_MODE_DISABLED
		_unload_queue.append(weakref(node))
	nodes.clear()
	for bridge in actor_depth_bridges_root.get_children():
		var actor: Variant = bridge.get_meta(&"source_actor") if bridge.has_meta(&"source_actor") else null
		if is_instance_valid(actor) and retiring.has(actor.get_instance_id()):
			bridge.hide()
			if bridge.has_method("set_room_presentation_active"):
				bridge.set_room_presentation_active(false)
	_clear_room_transition_transients()
	_clear_muzzle_and_burning_vfx()
	_cached_enemy_cutout_slots.clear()
	_cached_enemy_cutout_dists.clear()
	for index in OCCLUSION_CUTOUT_SLOT_COUNT:
		RenderingServer.global_shader_parameter_set(_occlusion_cutout_param_name(index), Vector4.ZERO)
	_last_cutout_slots.clear()
	pending_enemy_pickup_requests.clear()
	_settled_blood_buckets.clear()
	for room_id in range(first_room, next_room):
		for cell in rooms[room_id].shape_cells:
			floor_cells.erase(cell)
			room_cells.erase(cell)
			presentation_floor_cells.erase(cell)
			corridor_cells.erase(cell)
	employee_path_cache.clear()


func _commit_employee_weapon_drop(request: Dictionary) -> void:
	if _train != null:
		if is_instance_valid(_train.derailment) and _train.derailment.retired.has(int(request.get("room_id",-1))): return
		super._commit_employee_weapon_drop(request)
		return
	var room_id := int(request.get("room_id", -1))
	var active_region := -1
	if transit_finished:
		active_region = METRO_ROOM_ID
	elif storage_finished:
		active_region = TRANSIT_ROOM_ID
	elif garage_exit_reached:
		active_region = STORAGE_ROOM_ID
	elif garage_visible:
		active_region = GARAGE_ROOM_ID
	if active_region >= 0 and room_id != active_region:
		return
	super._commit_employee_weapon_drop(request)


func _set_garage_enemies_active(active: bool) -> void:
	for child in enemy_root.get_children():
		var enemy := child as EmployeeEnemy
		if enemy == null or int(enemy.get_meta(&"dream_room_id", -1)) != GARAGE_ROOM_ID:
			continue
		enemy.set_room_runtime_active(active)
		enemy.set_player_vision_visible(active)
		if active and bool(enemy.get_meta(&"garage_crash_guard", false)):
			enemy.set_physics_process(false)
		if not active and enemy.hurtbox != null:
			enemy.hurtbox.set_deferred("monitorable", false)
	for bridge in actor_depth_bridges_root.get_children():
		var actor: Variant = bridge.get_meta(&"source_actor") if bridge.has_meta(&"source_actor") else null
		if is_instance_valid(actor) and actor is EmployeeEnemy and bridge.has_method("set_room_presentation_active"):
			if int(actor.get_meta(&"dream_room_id", -1)) == GARAGE_ROOM_ID and bridge.room_presentation_active != active:
				bridge.set_room_presentation_active(active)


func can_employee_hear_gunshot_at(employee: EmployeeEnemy, sound_position: Vector2, source_room_id: int) -> bool:
	if not super.can_employee_hear_gunshot_at(employee,sound_position,source_room_id): return false
	if _train != null or source_room_id != STORAGE_ROOM_ID or int(employee.get_meta(&"dream_room_id",-1)) != STORAGE_ROOM_ID: return true
	if not sound_position.is_finite(): return false
	var origin := Vector2(STORAGE_OFFSET)
	var source_inside := STORAGE_AREA.sound_is_on_stockroom_side(sound_position/CELL_PIXELS-origin)
	var listener_inside := STORAGE_AREA.sound_is_on_stockroom_side(employee.global_position/CELL_PIXELS-origin)
	if source_inside == listener_inside: return true
	if not is_instance_valid(_storage_door): return false
	# A real open or destroyed service door connects the two sound zones. Use
	# the leaf angle, not just `locked` or `latched` (an unlocked door can be shut).
	return _storage_door.is_destroyed or _storage_door.get_open_angle() > deg_to_rad(maxf(3.0,_storage_door.latch_closed_angle_degrees))


func get_employee_navigation_target(enemy: EmployeeEnemy, destination: Vector2) -> Vector2:
	if _train != null:
		return super.get_employee_navigation_target(enemy, destination)
	var room_id := int(enemy.get_meta(&"dream_room_id", -1))
	match room_id:
		GARAGE_ROOM_ID:
			destination.x = clampf(destination.x, (GARAGE_MOUTH_X + .45) * CELL_PIXELS, (STORAGE_MOUTH_X - .45) * CELL_PIXELS)
		STORAGE_ROOM_ID:
			destination.x = clampf(destination.x, (STORAGE_MOUTH_X + .45) * CELL_PIXELS, (TRANSIT_MOUTH_X - .45) * CELL_PIXELS)
		METRO_ROOM_ID:
			var origin := Vector2(METRO_OFFSET)
			var local := METRO_AREA.enemy_waypoint(enemy.global_position / CELL_PIXELS - origin,
				destination / CELL_PIXELS - origin, bool(enemy.get_meta(&"metro_far_platform", false)))
			destination = (origin + local) * CELL_PIXELS
		_:
			if room_id < GARAGE_ROOM_ID:
				destination.x = minf(destination.x, (LINK_START_X - .30) * CELL_PIXELS)
	return super.get_employee_navigation_target(enemy, destination)


func _can_cross_floor_edge(from_cell: Vector2i, to_cell: Vector2i, ignore_boss_lock: bool = true) -> bool:
	if _train != null:
		return super._can_cross_floor_edge(from_cell, to_cell, ignore_boss_lock)
	# Keep the floor under furniture for lighting and impacts, while routing
	# the active storage enemies around the cabinet and pier footprints.
	if garage_exit_reached and _storage_blocked_cells.has(to_cell):
		return false
	if STORAGE_AREA.blocks_return_edge(from_cell - STORAGE_OFFSET, to_cell - STORAGE_OFFSET):
		return false
	return super._can_cross_floor_edge(from_cell, to_cell, ignore_boss_lock)


func get_projected_projectile_wall_layer() -> int:
	return TRAIN_CHAPTER.CONSIST.PROJECTED_BALLISTIC_WALL if _train != null else 0


func _update_camera_aim_offset(ground: Vector2, delta: float) -> Vector3:
	if _train != null and _train.phase == TRAIN_CHAPTER.Phase.APPROACH:
		var weight := 1.0 - exp(-maxf(config.camera_aim_smoothing, .01) * delta)
		return camera_aim_offset.lerp(TRAIN_CHAPTER.TAUNT_CAMERA_OFFSET, weight)
	return super._update_camera_aim_offset(ground, delta)


func _update_camera_and_actor_projection(delta: float = 0.0) -> void:
	var original_fov := authoritative_camera_fov
	var garage_weight := 0.0
	if _metro != null and is_instance_valid(_metro.departure):
		_metro.departure.apply_camera_pose()
	if is_instance_valid(van_ambush):
		garage_weight = van_ambush.get_camera_weight()
	elif _garage_return_zoom >= 0.0:
		garage_weight = dialogue_camera.get_dialogue_weight()
		if dialogue_camera.state == Dream3DDialogueCamera.FocusState.INACTIVE:
			dialogue_camera.dialogue_zoom_factor = _garage_return_zoom
			_garage_return_zoom = -1.0
	authoritative_camera_fov = lerpf(original_fov, 53.0, garage_weight)
	super._update_camera_and_actor_projection(delta)
	authoritative_camera_fov = original_fov
	if _metro != null and is_instance_valid(_metro.departure):
		_metro.departure.update_speech_anchor()
	if _train != null:
		_train.update_speech_anchor()


func duck_garage_bed() -> void:
	if is_instance_valid(_garage_bed):
		_garage_bed_duck = GARAGE_AREA.duck_room_tone(_garage_bed, _garage_bed_duck)


func _process(delta: float) -> void:
	if _train != null:
		_train.present()
	# One actor capture setup per frame while the old region is being retired.
	if not _pending_guards.is_empty() and not player.dead:
		var slot: Dictionary = _pending_guards.pop_front()
		if storage_finished:
			STORAGE_AREA.spawn_guard(self, TRANSIT_OFFSET, TRANSIT_ROOM_ID, slot)
		else:
			STORAGE_AREA.spawn_guard(self, STORAGE_OFFSET, STORAGE_ROOM_ID, slot)
	super._process(delta)
	for index in mini(_unload_queue.size(), UNLOAD_BATCH_SIZE):
		var reference: WeakRef = _unload_queue.pop_back()
		var retiring := reference.get_ref() as Node
		if is_instance_valid(retiring) and not retiring.is_queued_for_deletion():
			retiring.queue_free()


func are_rooms_openly_connected(a: int, b: int) -> bool:
	return _train.rooms_open(a, b) if _train != null else super.are_rooms_openly_connected(a, b)
