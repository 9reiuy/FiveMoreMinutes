extends RefCounted
## The original Lower Harbor platform with a south-side ticket and security hall.

const M := preload("res://scripts/testing/maintenance_environment.gd")
const TRANSIT := preload("res://scripts/testing/transit_concourse_area.gd")
const SURFACE := preload("res://shaders/dream3d/transit_surfaces.gdshader")
const ASSETS := preload("res://art/Dream/MetroStation/LowerHarbor.scn")
const CUTOUT := preload("res://scripts/dream/authored_occlusion_cutout.gd")
const TRAIN := preload("res://scripts/testing/metro_station/metro_train.gd")
const REFERENCE_ART := preload("res://scripts/testing/metro_station/train_reference_art.gd")
const DEPARTURE := preload("res://scripts/testing/metro_station/metro_departure_cinematic.gd")
const PLATFORM := Rect2i(-24, 2, 48, 6)
const FAR_PLATFORM := Rect2i(-24, -5, 48, 3)
const CHECKPOINT := Rect2i(-3, 8, 5, 10)
const NECK := Rect2i(-2, 18, 4, 3)
const SECTIONS := [PLATFORM, CHECKPOINT, NECK]
const MODEL_OFFSET := Vector3(-.5, -.12, -.25)
const PLATFORM_SLAB_BOTTOM := -.72
const CEILING_LAYER := 1 << 17
const PLAYER_EDGE_LAYER := 1 << 6
const PLATFORM_REACH_Z := 7.04
const CHECKPOINT_LANE_X := -.50
const PLATFORM_MOUTH_Z := CHECKPOINT.position.y - .5
const TICKET_GATE_Z := 9.68
const DETECTOR_Z := 12.66
const CHECKPOINT_PASSAGES := [
	Vector2(PLATFORM_MOUTH_Z - .72, PLATFORM_MOUTH_Z + .72),
	Vector2(TICKET_GATE_Z - .90, TICKET_GATE_Z + .90),
	Vector2(DETECTOR_Z - .62, DETECTOR_Z + .62),
]
const SECURITY_GUARD_POST := Vector2(.39, 14.35)
const TRAIN_TRAVEL_SECONDS := 4.6
const TAIL_DOCK_X := 44.5
const TAIL_ENTRY_WIDTH := 1.34
const DOOR_LANE_OFFSET := .38
const RANGED_COUNT := 4
const STATION_STRUCTURE_FINISHES := [
	&"PBR_GlazedCeramicWall", &"PBR_PaintedStructuralSteel",
	&"PBR_DarkTunnelConcrete", &"PBR_ConcretePlatformEdging",
]
const STATION_COLUMN_FINISHES := [
	&"PBR_GlazedCeramicWall", &"PBR_PaintedStructuralSteel", &"PBR_BrushedRailSteel",
	&"PBR_LowerStainlessCarriage", &"ColdLuminousStrip",
]
const MELEE_POSTS := [
	Vector2(-12.70, 6.24), Vector2(-6.55, 6.22), Vector2(-2.80, 6.58),
	Vector2(3.60, 6.10), Vector2(10.80, 6.35),
]

enum Service { WAITING_AT_PLATFORM, UNLOADING, WAITING_FOR_CLEAR, NEXT_TRAIN }

var _world: Node3D
var _art: Node3D
var _offset: Vector2i
var _steel := M.metal(Color("7d8986"), .49)
var _dark := M.metal(Color("343e3b"), .68)
var _readout := M.metal(Color("70c0a0"), .42)
var cutout := CUTOUT.new()
var train: TRAIN
var _service := Service.WAITING_AT_PLATFORM
var _passenger_queue: Array[Dictionary] = []
var _passengers: Array[Dictionary] = []
var departure: DEPARTURE
var _track_edge: CollisionShape2D
var _tail_threshold := Vector2.INF


func _init(world: Node3D, art: Node3D, offset: Vector2i) -> void:
	_world = world
	_art = art
	_offset = offset
	_readout.emission_enabled = true
	_readout.emission = Color("66d6a8")
	_readout.emission_energy_multiplier = .81


static func room_source(offset: Vector2i) -> Dictionary:
	var bounds := PLATFORM
	var cells: Array[String] = []
	for section: Rect2i in SECTIONS + [FAR_PLATFORM]:
		bounds = bounds.merge(section)
		for z in range(section.position.y, section.end.y):
			for x in range(section.position.x, section.end.x):
				cells.append("%d,%d" % [x + offset.x, z + offset.y])
	bounds.position += offset
	return {"id": "metro", "label": "下港站台", "kind": "corridor", "cells": cells,
		"bounds": {"x": bounds.position.x, "y": bounds.position.y, "w": bounds.size.x, "h": bounds.size.y}}


static func enemy_waypoint(current: Vector2, destination: Vector2, far_side: bool) -> Vector2:
	if far_side:
		destination.y = clampf(destination.y, FAR_PLATFORM.position.y, FAR_PLATFORM.end.y - .76)
		return destination
	destination.y = clampf(destination.y, 2.12, NECK.end.y - .66)
	var direction := signf(destination.y - current.y)
	if direction == 0.0:
		return destination
	# The detector opening sits between grid centers. Approach each narrow
	# opening on its actual centerline before aiming farther into the hall.
	for index in CHECKPOINT_PASSAGES.size():
		var passage: Vector2 = CHECKPOINT_PASSAGES[index if direction > 0.0 else CHECKPOINT_PASSAGES.size() - 1 - index]
		var middle := (passage.x + passage.y) * .5
		var approach := passage.x if direction > 0.0 else passage.y
		var exit := passage.y if direction > 0.0 else passage.x
		if (destination.y - middle) * direction <= 0.0 or (current.y - exit) * direction >= 0.0:
			continue
		if absf(current.x - CHECKPOINT_LANE_X) > .28:
			if (current.y - middle) * direction >= 0.0:
				continue
			return Vector2(CHECKPOINT_LANE_X, approach)
		return Vector2(CHECKPOINT_LANE_X, clampf(destination.y, passage.x, passage.y))
	return destination


func build() -> void:
	var models := ASSETS.instantiate() as Node3D
	models.position = MODEL_OFFSET
	var station: Node3D = models.get_node("LowerHarborStation")
	station.get_node("TunnelRoofs").hide()
	for surface: MeshInstance3D in station.get_node("StationCeiling_Cutaway").find_children("*", "MeshInstance3D", true, false):
		surface.layers = CEILING_LAYER
	_world.camera_3d.cull_mask &= ~CEILING_LAYER
	var train_body: AnimatableBody3D = models.get_node("MetroTrain")
	train_body.set_script(TRAIN)
	train = train_body as TRAIN
	train.station_only = true
	train.journey_duration = TRAIN_TRAVEL_SECONDS
	train.door_fraction = 1.0
	train.doors_wanted_open = true
	if not _world.get_meta(&"test_train_reference_art_disabled", false):
		var reference_art := REFERENCE_ART.new()
		reference_art.apply_train(train_body)
		train_body.set_meta(&"train_reference_art", reference_art)
	_art.add_child(models)
	preload("res://scripts/dream/packed_fixture_sources.gd").mark_tree(station)
	_apply_station_top_black(station)
	departure = DEPARTURE.new()
	departure.name = "MetroDeparture"
	_art.add_child(departure)
	_build_platform_solids(station)

	var tile := _tile(Color("817b66"), Color("4a4c3d"), Vector2(.86, .86), false)
	var wall := _tile(Color("9d9e83"), Color("646553"), Vector2(.34, .34), true)
	var cells := {}
	for section: Rect2i in SECTIONS:
		if section != PLATFORM:
			var center := Vector2(section.position) + Vector2(section.size) * .5 - Vector2(.5, .5)
			M.box(_art, "InspectionFloor" if section == CHECKPOINT else "StationJoinFloor",
				Vector3(section.size.x, .12, section.size.y), Vector3(center.x, -.06, center.y), tile)
		for z in range(section.position.y, section.end.y):
			for x in range(section.position.x, section.end.x):
				cells[Vector2i(x, z)] = true
	_build_boundaries(cells, wall)
	_build_checkpoint(wall)
	_build_lighting()


func activate(room_id: int) -> void:
	_art.show()
	_art.process_mode = Node.PROCESS_MODE_INHERIT
	var far_doors := _boarding_doors(-1.0)
	if _world.spawn_content:
		_queue_first_train(far_doors, _boarding_doors(1.0))
		_post_security_guard(room_id)
	departure.play(_world, far_doors.front() if not far_doors.is_empty() else null, -DOOR_LANE_OFFSET)
	_service = Service.UNLOADING


func update_service(delta: float, room_id: int) -> void:
	if _service == Service.UNLOADING:
		# Prepare one actor at a time during the pan. All walkers use the same clock.
		if not _passenger_queue.is_empty():
			_stage_passenger(_passenger_queue.pop_front(), room_id)
			return
		departure.advance(delta)
		if departure.beat >= DEPARTURE.Beat.BOARD and train.phase == "DOCKED":
			# The speaker enters while the passengers step off through open doors.
			var progress := departure.boarding_progress()
			_update_exits(progress, delta)
			if progress >= 1.0:
				train.request_depart()
		if departure.beat == DEPARTURE.Beat.DONE:
			_release_passengers()
			_service = Service.WAITING_FOR_CLEAR
	elif _service == Service.WAITING_FOR_CLEAR and train.phase == "AWAY":
		if _world._get_alive_employee_count_in_room(room_id) == 0:
			var tail: Node3D = null
			for bridge in train.bridges:
				if bridge.position.z > 0.0 and (tail == null or bridge.global_position.x < tail.global_position.x):
					tail = bridge
			if tail != null and train.request_arrive(-TRAIN.TUNNEL_X, TAIL_DOCK_X, tail):
				_service = Service.NEXT_TRAIN
	elif _service == Service.NEXT_TRAIN and not _tail_threshold.is_finite():
		var tail := train.boarding_bridge
		if train.phase == "DOCKED" and tail != null and tail.visible and train.door_fraction >= .98:
			_open_tail_entry(tail)


func _open_tail_entry(bridge: Node3D) -> void:
	var local := _art.to_local(bridge.global_position)
	_tail_threshold = Vector2(local.x, local.z)
	var from_x := PLATFORM.position.x - .5
	var to_x := PLATFORM.end.x - .5
	var entry_left := local.x - TAIL_ENTRY_WIDTH * .5
	var entry_right := local.x + TAIL_ENTRY_WIDTH * .5
	_solid("TailPlatformEdgeWest", Rect2(from_x, 1.405, entry_left - from_x, .19), PLAYER_EDGE_LAYER)
	_solid("TailPlatformEdgeEast", Rect2(entry_right, 1.405, to_x - entry_right, .19), PLAYER_EDGE_LAYER)
	_track_edge.set_deferred("disabled", true)


func player_has_boarded(at: Vector2) -> bool:
	if not _tail_threshold.is_finite():
		return false
	var local: Vector2 = at / _world.CELL_PIXELS - Vector2(_offset)
	return absf(local.x - _tail_threshold.x) < TAIL_ENTRY_WIDTH * .5 and local.y < _tail_threshold.y - .48


func _post_security_guard(room_id: int) -> void:
	var post := (Vector2(_offset) + SECURITY_GUARD_POST) * float(_world.CELL_PIXELS)
	var guard: EmployeeEnemy = _world._spawn_regular_employee(room_id, post, &"employee", false, "assault_rifle")
	if guard == null:
		return
	guard.name = "MetroSecurityGuard"
	var patrol: Array[Vector2] = [post]
	guard.set_authored_patrol_route(patrol)
	guard._apply_live_facing(Vector2(-.42, -1.0))
	guard._update_weapon_aim()
	guard.set_room_runtime_active(true)


func _boarding_doors(side: float) -> Array[Node3D]:
	# Each usable boarding plate is the actual threshold of an open door.
	var doors: Array[Node3D] = []
	for bridge: Node3D in train.bridges:
		if bridge.position.z * side > 0.0 and bridge.visible:
			doors.append(bridge)
	var center_x := _art.global_position.x
	doors.sort_custom(func(a: Node3D, b: Node3D):
		return absf(a.global_position.x - center_x) < absf(b.global_position.x - center_x))
	return doors


func _queue_first_train(far_doors: Array[Node3D], near_doors: Array[Node3D]) -> void:
	for index in mini(RANGED_COUNT, far_doors.size()):
		var lane := DOOR_LANE_OFFSET if index == 0 else 0.0
		_passenger_queue.append({"name": "MetroRanged%d" % (index + 1), "weapon": "basic", "bridge": far_doors[index], "lane": lane})
	if near_doors.is_empty():
		return
	var center_x := _art.global_position.x
	var near_slots := {}
	for index in MELEE_POSTS.size():
		var post: Vector2 = MELEE_POSTS[index]
		var nearest := near_doors[0]
		for bridge in near_doors:
			if absf(bridge.global_position.x - center_x - post.x) < absf(nearest.global_position.x - center_x - post.x):
				nearest = bridge
		var slot := {"name": "PlatformMelee%d" % (index + 1), "weapon": "lucille", "bridge": nearest, "post": post}
		if near_slots.has(nearest):
			# The two center-left posts share a wide door. Use both halves of it.
			near_slots[nearest]["lane"] = -DOOR_LANE_OFFSET
			slot["lane"] = DOOR_LANE_OFFSET
		else:
			near_slots[nearest] = slot
		_passenger_queue.append(slot)


func _update_exits(progress: float, delta: float) -> void:
	var inside_train := progress < .42
	for step: Dictionary in _passengers:
		var actor: EmployeeEnemy = step.actor
		if not is_instance_valid(actor) or actor.dead:
			continue
		var start: Vector2 = step.start
		var sill: Vector2 = step.sill
		var next := start.lerp(sill, progress / .42) if inside_train else sill.lerp(step.end, (progress - .42) / .58)
		actor.velocity = (next - actor.global_position) / delta if progress < 1.0 else Vector2.ZERO
		actor.global_position = next
		if not inside_train and not actor.visible:
			actor.show()
		actor._update_human_animation(delta)


func _stage_passenger(slot: Dictionary, room_id: int) -> void:
	var bridge: Node3D = slot.bridge
	var sill := Vector2(bridge.global_position.x, bridge.global_position.z)
	var side := signf(bridge.position.z)
	var unit: float = _world.CELL_PIXELS
	var lane := float(slot.get("lane", 0.0))
	var landing := Vector2.INF
	var exits := [Vector2(lane, 1.19), Vector2(.62, 1.43), Vector2(-.62, 1.43),
		Vector2(.87, 2.04), Vector2(-.87, 2.04), Vector2(0.0, 2.30)]
	if side < 0.0:
		# Clear the speaker's path through the center of the far doorway.
		exits.push_front(Vector2(.86, 1.75))
	for offset: Vector2 in exits:
		var candidate := (sill + Vector2(offset.x, offset.y * side)) * unit
		if (candidate.distance_to(_world.player.global_position) >= 25.0
			and not _passengers.any(func(step: Dictionary): return candidate.distance_to(step.end) < 19.0)
			and _world._content_position_is_clear(candidate, 10.0, false)):
			landing = candidate
			break
	if not landing.is_finite():
		push_warning("No platform landing for %s" % slot.name)
		return
	sill.x += lane
	var start := (sill - Vector2(0.0, .57 * side)) * unit
	var actor: EmployeeEnemy = _world._spawn_regular_employee(room_id, start, &"employee", false, slot.weapon)
	if actor == null:
		return
	actor.name = slot.name
	actor.set_meta(&"metro_far_platform", side < 0.0)
	actor.set_room_runtime_active(false)
	actor.hide()
	# Step across the bridge without the track barrier catching the body.
	# Swept shots query the shape even while the Area is unmonitorable.
	# The end of the cutscene restores both the shape and the regular AI.
	actor.hurtbox_collision.set_deferred("disabled", true)
	actor.hurtbox.set_deferred("monitorable", false)
	actor._apply_live_facing(Vector2.DOWN * side)
	actor._update_weapon_aim()
	var post := Vector2(landing.x, (_offset.y + FAR_PLATFORM.end.y - .80) * unit)
	if slot.has("post"):
		post = (Vector2(_offset) + Vector2(slot.post)) * unit
	_passengers.append({"actor": actor, "start": start,
		"sill": (sill + Vector2(0.0, .24 * side)) * unit, "end": landing, "post": post})


func _release_passengers() -> void:
	for step: Dictionary in _passengers:
		var actor: EmployeeEnemy = step.actor
		if is_instance_valid(actor) and not actor.dead:
			actor.global_position = step.end
			actor.velocity = Vector2.ZERO
			actor.set_room_runtime_active(true)
			var route: Array[Vector2] = [step.post]
			actor.set_authored_patrol_route(route)
	_passengers.clear()


func _tile(colour: Color, joint: Color, pitch: Vector2, wall: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter("face_colour", colour)
	material.set_shader_parameter("joint_colour", joint)
	material.set_shader_parameter("tile_span", pitch)
	material.set_shader_parameter("skirting_colour", Color("41473b"))
	material.set_shader_parameter("finish_roughness", .59 if wall else .48)
	material.set_shader_parameter("wear", .28)
	material.set_shader_parameter("wall_surface", wall)
	material.set_shader_parameter("occlusion_cutout_enabled", wall)
	material.set_shader_parameter("south_fade", Vector2(NECK.end.y - 2.82, NECK.end.y - .5) + Vector2.ONE * _offset.y)
	return material


func _apply_station_top_black(station: Node3D) -> void:
	var architecture := station.get_node(^"StationArchitecture") as MeshInstance3D
	var local := architecture.global_transform.affine_inverse()
	var caps: Array[AABB] = []
	var columns: Array[AABB] = []
	for collider: CollisionShape3D in station.get_node(^"StationCollision").get_children():
		var box := collider.shape as BoxShape3D
		if box == null or box.size.y < 2.5:
			continue
		var bounds := (local * collider.global_transform) * AABB(-box.size * .5, box.size)
		# The original chamfered cap sits a little above its physics box.
		var top := AABB(Vector3(bounds.position.x, bounds.end.y - .10, bounds.position.z),
			Vector3(bounds.size.x, .17, bounds.size.z)).grow(.015)
		caps.append(top)
		if box.size.x < 2.0:
			# The steel collar and the sign on each column protrude past its collider.
			var column := bounds.grow(.10)
			columns.append(column)
			cutout.add_bounds(architecture.global_transform * column)
	_blacken_mesh_tops(architecture, caps, columns)


func _blacken_mesh_tops(visual: MeshInstance3D, structure_caps: Array[AABB] = [], columns: Array[AABB] = []) -> void:
	# Split only the column triangles out of the imported material batches.
	# Floor, track and furniture geometry keep their original surfaces.
	var original := visual.mesh
	var mesh := ArrayMesh.new()
	var black_positions := PackedVector3Array()
	var black_normals := PackedVector3Array()
	for surface in original.get_surface_count():
		var arrays := original.surface_get_arrays(surface)
		var material := visual.get_active_material(surface)
		var cap_finish := structure_caps.is_empty() or (material != null and material.resource_name in STATION_STRUCTURE_FINISHES)
		var column_finish := not columns.is_empty() and material != null and material.resource_name in STATION_COLUMN_FINISHES
		if cap_finish or column_finish:
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var indexed := not indices.is_empty()
			var count := indices.size() if indexed else positions.size()
			var keep := PackedInt32Array()
			var column_indices := PackedInt32Array()
			for triangle in range(0, count, 3):
				var a := indices[triangle] if indexed else triangle
				var b := indices[triangle + 1] if indexed else triangle + 1
				var c := indices[triangle + 2] if indexed else triangle + 2
				var center := (positions[a] + positions[b] + positions[c]) / 3.0
				var in_cap := structure_caps.is_empty()
				if cap_finish and normals[a].y + normals[b].y + normals[c].y > 1.5:
					if not in_cap and center.y >= 2.5:
						# The tall concrete trim at the tunnel mouths has no separate cap collider.
						in_cap = (material.resource_name == &"PBR_ConcretePlatformEdging" and center.y >= 3.74
							or structure_caps.any(func(bounds: AABB): return bounds.has_point(center)))
					if in_cap:
						black_positions.append_array(PackedVector3Array([positions[a], positions[b], positions[c]]))
						black_normals.append_array(PackedVector3Array([normals[a], normals[b], normals[c]]))
						continue
				if column_finish and columns.any(func(bounds: AABB): return bounds.has_point(center)):
					column_indices.append(a)
					column_indices.append(b)
					column_indices.append(c)
					continue
				keep.append(a)
				keep.append(b)
				keep.append(c)
			if not column_indices.is_empty():
				var column_arrays := arrays.duplicate()
				column_arrays[Mesh.ARRAY_INDEX] = column_indices
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, column_arrays)
				mesh.surface_set_material(mesh.get_surface_count() - 1, cutout.pbr_material(material as StandardMaterial3D))
			if keep.is_empty():
				continue
			if keep.size() != count:
				arrays[Mesh.ARRAY_INDEX] = keep
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	if black_positions.is_empty():
		return
	var cap_arrays := []
	cap_arrays.resize(Mesh.ARRAY_MAX)
	cap_arrays[Mesh.ARRAY_VERTEX] = black_positions
	cap_arrays[Mesh.ARRAY_NORMAL] = black_normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cap_arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, cutout.top_black)
	visual.mesh = mesh
	visual.material_override = null


func _build_platform_solids(station: Node3D) -> void:
	# Reuse the original footprints of the columns, seats and bins. The old
	# trench and tunnel shapes remain 3D supports for the imported train.
	for shape_node: CollisionShape3D in station.get_node("StationCollision").get_children():
		var shape := shape_node.shape as BoxShape3D
		if shape == null or absf(shape_node.position.z) < 1.75:
			continue
		var far_wall := shape_node.position.z < -5.30 and shape.size.y > 2.0
		if shape.size.x > 8.0 and not far_wall:
			continue
		var size := Vector2(shape.size.x, shape.size.z)
		var position := shape_node.position + MODEL_OFFSET
		_solid("PlatformFixture", Rect2(Vector2(position.x, position.z) - size * .5, size))


func _build_boundaries(cells: Dictionary, tile: Material) -> void:
	for outward: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
		var tangent := Vector2i(abs(outward.y), abs(outward.x))
		for cell: Vector2i in cells:
			var platform := PLATFORM.has_point(cell)
			if not _edge(cells, cell, outward, platform) or _edge(cells, cell - tangent, outward, platform):
				continue
			var end := cell + tangent
			while _edge(cells, end, outward, platform):
				end += tangent
			var center := Vector2(cell) + Vector2(outward) * .5 + Vector2(end - cell - tangent) * .5
			var size := Vector2(end - cell) + Vector2(outward).abs() * .19
			var footprint := Rect2(center - size * .5, size)
			if platform and outward != Vector2i.DOWN:
				var edge := _solid("PlatformEdge", footprint, PLAYER_EDGE_LAYER)
				if outward == Vector2i.UP:
					_track_edge = edge
			elif platform:
				var name := "PlatformSouthWallWest" if center.x < CHECKPOINT_LANE_X else "PlatformSouthWallEast"
				_wall(name, footprint, outward, tile, PLATFORM_SLAB_BOTTOM)
			else:
				_wall("StationWall", footprint, outward, tile)


func _edge(cells: Dictionary, cell: Vector2i, outward: Vector2i, platform: bool) -> bool:
	if outward == Vector2i.DOWN and cell.y == NECK.end.y - 1 and NECK.has_point(cell):
		return false
	return cells.has(cell) and not cells.has(cell + outward) and PLATFORM.has_point(cell) == platform


func _wall(title: String, footprint: Rect2, outward: Vector2i, tile: Material, base_y := 0.0) -> void:
	var visual := MeshInstance3D.new()
	visual.name = title
	visual.position.y = base_y
	visual.mesh = TRANSIT.top_black_wall(footprint, outward, 2.64 - base_y, tile, cutout.top_black)
	_art.add_child(visual)
	cutout.register_mesh(visual)
	_solid(title, footprint)


func _solid(title: String, footprint: Rect2, layer: int = 4) -> CollisionShape2D:
	var body := StaticBody2D.new()
	body.name = title
	body.position = (footprint.get_center() + Vector2(_offset)) * _world.CELL_PIXELS
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = footprint.size * _world.CELL_PIXELS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	_world.collision_root.add_child(body)
	return collision


func _build_checkpoint(wall: Material) -> void:
	var gate := Node3D.new()
	gate.name = "SecurityAndEntry"
	_art.add_child(gate)
	_wall("PlatformWing", Rect2(-3.50, 7.41, 1.0, .19), Vector2i.UP, wall)
	var platform_header := M.box(gate, "PlatformHeader", Vector3(4.19, .21, .26), Vector3(-.5, 2.43, 7.5), _dark)
	_blacken_mesh_tops(platform_header)
	cutout.register_mesh(platform_header)
	_sign(gate, "PLATFORM", Vector3(-.5, 2.42, 7.643), 0.0)
	var security_header := M.box(gate, "SecurityEntryHeader", Vector3(4.36, .20, .24), Vector3(-.5, 2.43, 17.48), _dark)
	_blacken_mesh_tops(security_header)
	cutout.register_mesh(security_header)
	_sign(gate, "SECURITY", Vector3(-.5, 2.43, 17.61), 0.0)
	var paint := M.metal(Color("9e8655"), .76)
	M.box(gate, "PlatformThreshold", Vector3(3.94, .014, .09), Vector3(-.5, .012, 7.625), paint)

	var first_equipment := gate.get_child_count()
	_baggage(gate, Vector2(-2.59, 12.77))
	_inspection_desk(gate)
	_detector(gate, Vector2(CHECKPOINT_LANE_X, DETECTOR_Z))
	for index in range(first_equipment, gate.get_child_count()):
		cutout.register_mesh(gate.get_child(index) as MeshInstance3D)
	for side: float in [-1.0, 1.0]:
		M.box(gate, "InspectionLanePaint", Vector3(.035, .011, 1.72), Vector3(-.5 + side * .73, .009, 14.2), paint)
	for ends: Vector2 in [Vector2(-3.39, -3.23), Vector2(-1.95, -1.39), Vector2(.39, 1.39)]:
		_rail(gate, ends, DETECTOR_Z)
	var first_turnstile := gate.get_child_count()
	for x: float in [-1.62, .64]:
		M.box(gate, "TicketGatePlinth", Vector3(.44, .14, 1.18), Vector3(x, .07, TICKET_GATE_Z), _dark)
		M.box(gate, "TicketGate", Vector3(.38, .91, 1.16), Vector3(x, .575, TICKET_GATE_Z), _steel)
		M.box(gate, "GateReader", Vector3(.25, .048, .31), Vector3(x, 1.053, TICKET_GATE_Z + .35), _dark)
		M.box(gate, "GateReady", Vector3(.151, .019, .071), Vector3(x, 1.087, TICKET_GATE_Z + .38), _readout)
		M.box(gate, "OpenGateLeaf", Vector3(.075, .29, .48), Vector3(x + .22, .62, TICKET_GATE_Z - .16), _dark)
		_solid("TicketGate", Rect2(x - .22, TICKET_GATE_Z - .59, .44, 1.18))
	for index in range(first_turnstile, gate.get_child_count()):
		cutout.register_mesh(gate.get_child(index) as MeshInstance3D)
	for ends: Vector2 in [Vector2(-3.39, -1.84), Vector2(.86, 1.39)]:
		_rail(gate, ends, TICKET_GATE_Z)
	for z: float in [14.91, 15.23]:
		M.box(gate, "QueueMark", Vector3(1.46, .012, .05), Vector3(-.50, .014, z), paint)


func _inspection_desk(parent: Node3D) -> void:
	var x := -2.69
	var z := 15.57
	M.box(parent, "InspectionDeskBase", Vector3(1.24, .85, .88), Vector3(x, .425, z), _dark)
	M.box(parent, "InspectionWorktop", Vector3(1.36, .13, 1.02), Vector3(x, .91, z), _steel)
	M.box(parent, "ControlConsoleFoot", Vector3(.48, .09, .31), Vector3(x - .30, 1.02, z - .12), _dark)
	M.box(parent, "ControlConsole", Vector3(.46, .33, .11), Vector3(x - .30, 1.20, z - .20), _dark)
	M.box(parent, "ControlStatus", Vector3(.31, .15, .023), Vector3(x - .30, 1.22, z - .135), _readout)
	M.box(parent, "InspectionTray", Vector3(.46, .046, .41), Vector3(x + .31, .998, z + .11), _dark)
	_solid("InspectionDesk", Rect2(x - .68, z - .51, 1.36, 1.02))


func _detector(parent: Node3D, at: Vector2) -> void:
	for x: float in [at.x - .79, at.x + .79]:
		M.box(parent, "DetectorStanchion", Vector3(.22, 2.17, .30), Vector3(x, 1.085, at.y), _steel)
		M.box(parent, "DetectorFoot", Vector3(.27, .083, .40), Vector3(x, .042, at.y), _dark)
		_solid("DetectorStanchion", Rect2(x - .133, at.y - .20, .266, .40))
	M.box(parent, "DetectorArch", Vector3(1.80, .20, .32), Vector3(at.x, 2.19, at.y), _steel)
	M.box(parent, "DetectorFace", Vector3(.37, .092, .032), Vector3(at.x, 2.19, at.y + .174), _dark)
	M.box(parent, "DetectorReady", Vector3(.18, .028, .019), Vector3(at.x, 2.19, at.y + .198), _readout)


func _baggage(parent: Node3D, at: Vector2) -> void:
	var x := at.x
	var z := at.y
	M.box(parent, "XRayBase", Vector3(1.25, .71, 2.18), Vector3(x, .355, z), _steel)
	M.box(parent, "BeltBed", Vector3(1.06, .115, 3.25), Vector3(x, .763, z), _dark)
	for side: float in [-.52, .52]:
		M.box(parent, "XRayTunnelSide", Vector3(.19, .91, 1.42), Vector3(x + side, 1.26, z), _steel)
		M.box(parent, "BeltRim", Vector3(.071, .091, 3.25), Vector3(x + side, .831, z), _steel)
	M.box(parent, "XRayCanopy", Vector3(1.25, .235, 1.46), Vector3(x, 1.72, z), _steel)
	for lip: float in [z - .72, z + .72]:
		for slat in 7:
			M.box(parent, "StripCurtain", Vector3(.119, .51, .035),
				Vector3(x - .375 + slat * .125, 1.34, lip), _dark)
	for n in 4:
		for side: float in [-1.0, 1.0]:
			var roll := M.cylinder(parent, "ConveyorRoller", .031, .95, Vector3(x, .839, z + side * (.91 + n * .19)), _steel)
			roll.rotation.z = PI * .5
	M.box(parent, "InspectionConsole", Vector3(.42, .36, .39), Vector3(x + .64, 1.31, z + .28), _dark)
	M.box(parent, "InspectionMonitor", Vector3(.29, .17, .034), Vector3(x + .64, 1.37, z + .494), _readout)
	_solid("XRayConveyor", Rect2(x - .64, z - 1.64, 1.28, 3.28))


func _rail(parent: Node3D, ends: Vector2, z: float) -> void:
	for x: float in [ends.x, ends.y]:
		M.cylinder(parent, "QueuePost", .043, .91, Vector3(x, .455, z), _steel)
		M.cylinder(parent, "QueueFoot", .09, .051, Vector3(x, .027, z), _dark)
	for y: float in [.49, .86]:
		M.pipe(parent, Vector3(ends.x, y, z), Vector3(ends.y, y, z), .033, _steel)
	_solid("QueueRail", Rect2(ends.x - .04, z - .061, ends.y - ends.x + .08, .122))


func _sign(parent: Node3D, words: String, at: Vector3, yaw: float) -> void:
	var sign := Node3D.new()
	sign.name = "StationWayfinding"
	sign.position = at
	sign.rotation.y = yaw
	parent.add_child(sign)
	M.box(sign, "EnamelSign", Vector3(1.70, .28, .045), Vector3.ZERO, _dark)
	var label := Label3D.new()
	label.text = words
	label.font_size = 23
	label.pixel_size = .011
	label.outline_size = 0
	label.modulate = Color("d8dfcf")
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.position.z = .026
	sign.add_child(label)


func _build_lighting() -> void:
	for at: Vector3 in [Vector3(1.36, 2.39, 18.87), Vector3(-3.36, 2.45, 14.07), Vector3(1.36, 2.45, 9.96)]:
		var yaw := PI * .5 if at.x < 0.0 else -PI * .5
		var fixture := M.cold_fixture(_art, "CheckpointFluorescent", at, 1, yaw)
		var light: OmniLight3D = fixture.get_node("ColdPool")
		light.light_color = Color("d7dfcd")
		light.light_energy = 1.85
		light.omni_range = 5.8
	for x: float in [-16.0, 0.0, 16.0]:
		var probe := ReflectionProbe.new()
		probe.name = "LowerHarborReflection"
		probe.position = Vector3(x, 2.68, .95) + Vector3(MODEL_OFFSET.x, 0, 0)
		probe.size = Vector3(22, 5.6, 13)
		probe.box_projection = true
		probe.interior = true
		probe.cull_mask = 1 | CEILING_LAYER
		probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.blend_distance = 3.0
		_art.add_child(probe)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, 150, 0)
	key.light_color = Color("d8e5e4")
	key.light_energy = .38
	key.shadow_enabled = true
	key.light_cull_mask = 15
	key.shadow_caster_mask = 15
	key.directional_shadow_max_distance = 44.0
	_art.add_child(key)
