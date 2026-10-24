extends Node

## Single presentation authority for the generated Room Graph.
##
## Gameplay still owns the floor-cell topology. This node only maintains the
## explored presentation (floor covers, content visibility and room lights) and
## the existing camera-near wall opacity rule. No collision object is created
## for fog covers, so a black room can never become an invisible wall.
var world: Node3D
var near_walls: Dictionary = {}
var near_corridor_walls: Dictionary = {}
## instance_id sets for O(1) membership in _commit (Array.has was O(n) per wall).
var _near_wall_ids: Dictionary = {}
var _near_corridor_wall_ids: Dictionary = {}
## Cached once per layout; _commit used to find_children every room change.
var _wall_fixtures: Array = []
var room_covers: Dictionary = {}
var corridor_covers: Dictionary = {}
var corridor_stub_covers: Dictionary = {}
var revealed_rooms: Dictionary = {}
var revealed_corridors: Dictionary = {}
var current_room_id := -1
var current_corridor_id := -1
var pending_room_id := -2
var pending_corridor_id := -2
var confirmation_time := 0.0
var cover_root: Node3D
var outside_black_gradient: ColorRect
var outside_mask_layer: CanvasLayer
var outside_mask_material: ShaderMaterial # Retired; no screen overlay is instantiated.
var view_snapshot: Dictionary = {}
var interior_void_backing: MeshInstance3D

const COVER_Y := 0.035
const FULL_FLOOR_CONTENT_VISIBLE := true


func configure(owner_world: Node3D) -> void:
	clear_layout()
	world = owner_world
	current_room_id = -1
	current_corridor_id = -1
	pending_room_id = -2
	pending_corridor_id = -2
	confirmation_time = 0.0
	if world == null or not is_instance_valid(world):
		return
	cover_root = Node3D.new()
	cover_root.name = "RoomFogRoot"
	world.generated_root.add_child(cover_root)
	var is_otxo: bool = (world.has_method("_is_otxo_mansion") and world.call("_is_otxo_mansion") == true)
	_build_interior_void_backing()
	var lazy_presentation := bool(world.get("lazy_room_presentation"))
	for room_variant in world.rooms:
		var room: Dictionary = room_variant
		var room_id := int(room.get("id", -1))
		if room_id < 0:
			continue
		revealed_rooms[room_id] = true
		if FULL_FLOOR_CONTENT_VISIBLE or lazy_presentation or is_otxo:
			continue
		var room_mesh := _build_cover_mesh(room.get("shape_cells", []))
		if room_mesh != null:
			var room_cover := _make_cover_node("RoomFog_%d" % room_id, room_mesh)
			cover_root.add_child(room_cover)
			room_covers[room_id] = room_cover
			_set_cover_visible(room_cover, true)
	# Build one cover for each endpoint stub instead of one cover for both sides of
	# a connection. The graph still owns one corridor id, but its two physical
	# presentation endpoints are revealed independently as rooms are entered.
	var transition_stubs_variant: Variant = world.get("transition_stubs")
	if not FULL_FLOOR_CONTENT_VISIBLE and not lazy_presentation and not is_otxo and transition_stubs_variant is Array and not transition_stubs_variant.is_empty():
		for stub_variant in transition_stubs_variant:
			if not stub_variant is Dictionary:
				continue
			var stub: Dictionary = stub_variant
			var corridor_id := int(stub.get("corridor_id", -1))
			var source_room_id := int(stub.get("source_room_id", -1))
			var stub_cells: Array = stub.get("stub_cells", [])
			if corridor_id < 0 or source_room_id < 0 or stub_cells.is_empty():
				continue
			var corridor_mesh := _build_cover_mesh(stub_cells)
			if corridor_mesh == null:
				continue
			var cover_key := _corridor_stub_key(corridor_id, source_room_id)
			var corridor_cover := _make_cover_node("CorridorFog_%s" % cover_key, corridor_mesh)
			cover_root.add_child(corridor_cover)
			corridor_stub_covers[cover_key] = corridor_cover
			revealed_corridors[corridor_id] = false
			_set_cover_visible(corridor_cover, true)
	elif not FULL_FLOOR_CONTENT_VISIBLE and not lazy_presentation and not is_otxo:
		# Compatibility path for authored/legacy scenes without explicit stubs.
		for corridor_variant in world.corridors:
			var corridor: Dictionary = corridor_variant
			var corridor_id := int(corridor.get("id", -1))
			if corridor_id < 0:
				continue
			var corridor_mesh := _build_cover_mesh(corridor.get("presentation_cells", corridor.get("cells", [])))
			if corridor_mesh != null:
				var corridor_cover := _make_cover_node("CorridorFog_%d" % corridor_id, corridor_mesh)
				cover_root.add_child(corridor_cover)
				corridor_covers[corridor_id] = corridor_cover
				revealed_corridors[corridor_id] = false
				_set_cover_visible(corridor_cover, true)
	if FULL_FLOOR_CONTENT_VISIBLE or is_otxo:
		for corridor_variant in world.corridors:
			var corridor: Dictionary = corridor_variant
			var corridor_id := int(corridor.get("id", -1))
			if corridor_id >= 0:
				revealed_corridors[corridor_id] = true
	# Build the camera-near wall index once per generated layout.  Room and
	# corridor walls use the same presentation path; room state and fog do not
	# infer a side from screen coordinates.
	var toward_camera := Vector2(0.0, 1.0)
	if world.camera_3d != null:
		toward_camera = _camera_direction_in_map()
	for wall in world.wall_root.get_children():
		var edge: Dictionary = wall.get_meta(&"edge", {})
		if edge.is_empty():
			continue
		if wall.has_method("set_wall_visual_visible"):
			wall.call("set_wall_visual_visible", true)
		if wall.has_method("set_wall_shadow_visible"):
			wall.call("set_wall_shadow_visible", true)
		var cells: Array = world.call("_edge_side_cells", edge)
		var is_near := false
		for i in 2:
			var room_id := int(world.room_cells.get(cells[i], -1))
			var edge_corridor_id := int(world.corridor_cells.get(cells[i], -1))
			var outward := Vector2(cells[1 - i] - cells[i]).normalized()
			if (room_id >= 0 or edge_corridor_id >= 0) and outward.dot(toward_camera) > 0.5:
				is_near = true
				if room_id >= 0:
					if not near_walls.has(room_id):
						near_walls[room_id] = []
						_near_wall_ids[room_id] = {}
					var wall_id: int = wall.get_instance_id()
					if not near_walls[room_id].has(wall):
						near_walls[room_id].append(wall)
						_near_wall_ids[room_id][wall_id] = true
				if edge_corridor_id >= 0:
					if not near_corridor_walls.has(edge_corridor_id):
						near_corridor_walls[edge_corridor_id] = []
						_near_corridor_wall_ids[edge_corridor_id] = {}
					var wall_id2: int = wall.get_instance_id()
					if not near_corridor_walls[edge_corridor_id].has(wall):
						near_corridor_walls[edge_corridor_id].append(wall)
						_near_corridor_wall_ids[edge_corridor_id][wall_id2] = true
		if is_near:
			if wall.has_method("set_cutaway_mode"):
				wall.set_cutaway_mode(true)
			else:
				wall.set_wall_opacity(0.30)
		else:
			wall.set_wall_opacity(1.0)
	_wall_fixtures.clear()
	if is_instance_valid(world.floor_root):
		for fixture in world.floor_root.find_children("WallFixture_*", "Node3D", true, false):
			if fixture.has_meta(&"wall_fixture_edge"):
				_wall_fixtures.append(fixture)
	# Everything with a world room id starts dormant in the normal encounter
	# lifecycle.  The explicit population-refill switch is retained for legacy
	# diagnostics; those tests intentionally pre-spawn a global population and
	# must keep every actor damageable/active so they exercise the old cadence.
	for room_id_variant in revealed_rooms.keys():
		world.call("_set_room_content_active", int(room_id_variant), true)
		_set_room_lights(int(room_id_variant), true)
	if world.spawn_room_id >= 0:
		if world.has_method("set_current_room_id"):
			world.call("set_current_room_id", int(world.spawn_room_id))
		reveal_room(world.spawn_room_id)
		world.call("activate_room", world.spawn_room_id)
	_commit(int(world.get_current_room_id()))
	process_priority = 100 # Follow the camera after its world-space movement update.
	set_process(true)


func clear_layout() -> void:
	if is_instance_valid(cover_root):
		cover_root.queue_free()
	cover_root = null
	if is_instance_valid(outside_black_gradient):
		outside_black_gradient.visible = false
	if is_instance_valid(outside_mask_layer):
		outside_mask_layer.queue_free()
	outside_mask_layer = null
	outside_mask_material = null
	view_snapshot.clear()
	interior_void_backing = null
	outside_black_gradient = null
	room_covers.clear()
	corridor_covers.clear()
	corridor_stub_covers.clear()
	revealed_rooms.clear()
	revealed_corridors.clear()
	near_walls.clear()
	near_corridor_walls.clear()
	_near_wall_ids.clear()
	_near_corridor_wall_ids.clear()
	_wall_fixtures.clear()
	world = null
	current_room_id = -1
	current_corridor_id = -1
	pending_room_id = -2
	pending_corridor_id = -2
	confirmation_time = 0.0
	set_process(false)


func _update_outside_mask() -> void:
	# Compatibility entrypoint: publishes camera data, never draws a screen mask.
	if world == null or not is_instance_valid(world): return
	if is_instance_valid(interior_void_backing):
		interior_void_backing.visible = StringName(world.get("transition_phase")) != &"CAB_RIDE"
	var camera: Camera3D = world.camera_3d
	if not is_instance_valid(camera): return
	var size := camera.get_viewport().get_visible_rect().size
	var origin := camera.project_ray_origin(Vector2.ZERO)
	var direction := camera.project_ray_normal(Vector2.ZERO)
	var right := camera.project_ray_normal(Vector2(size.x, 0))
	var bottom := camera.project_ray_normal(Vector2(0, size.y))
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var forward := -camera.global_basis.z
		direction /= maxf(direction.dot(forward), .001)
		right /= maxf(right.dot(forward), .001)
		bottom /= maxf(bottom.dot(forward), .001)
	var basis: Basis = world.global_basis
	view_snapshot = {
		"ray_origin_tl": origin,
		"ray_origin_dx": camera.project_ray_origin(Vector2(size.x, 0)) - origin,
		"ray_origin_dy": camera.project_ray_origin(Vector2(0, size.y)) - origin,
		"ray_direction_tl": direction, "ray_direction_dx": right - direction,
		"ray_direction_dy": bottom - direction, "map_origin": world.global_position,
		"map_x_axis": basis.x / maxf(basis.x.length_squared(), .001),
		"map_z_axis": basis.z / maxf(basis.z.length_squared(), .001)
	}


func refresh_active_presentation() -> void:
	"""Re-index newly rebuilt room-local walls after a lazy room swap."""
	if not is_instance_valid(world):
		return
	near_walls.clear()
	near_corridor_walls.clear()
	var toward_camera := Vector2(0.0, 1.0)
	if world.camera_3d != null:
		toward_camera = _camera_direction_in_map()
	if world.wall_root != null:
		for wall in world.wall_root.get_children():
			var edge: Dictionary = wall.get_meta(&"edge", {})
			if edge.is_empty():
				continue
			if wall.has_method("set_wall_visual_visible"):
				wall.call("set_wall_visual_visible", true)
			if wall.has_method("set_wall_shadow_visible"):
				wall.call("set_wall_shadow_visible", true)
			var cells: Array = world.call("_edge_side_cells", edge)
			for i in 2:
				var room_id := int(world.room_cells.get(cells[i], -1))
				var edge_corridor_id := int(world.corridor_cells.get(cells[i], -1))
				var outward := Vector2(cells[1 - i] - cells[i]).normalized()
				if room_id >= 0 and outward.dot(toward_camera) > 0.5:
					var room_walls: Array = near_walls.get(room_id, [])
					if not room_walls.has(wall):
						room_walls.append(wall)
						near_walls[room_id] = room_walls
				elif edge_corridor_id >= 0 and outward.dot(toward_camera) > 0.5:
					var corridor_walls: Array = near_corridor_walls.get(edge_corridor_id, [])
					if not corridor_walls.has(wall):
						corridor_walls.append(wall)
						near_corridor_walls[edge_corridor_id] = corridor_walls
			wall.set_wall_opacity(1.0)
	var active_room := int(world.get_current_room_id())
	var active_corridor := int(world.get_corridor_id_at_position()) if world.has_method("get_corridor_id_at_position") else -1
	_commit(active_room, active_corridor)
	var is_otxo: bool = (world.has_method("_is_otxo_mansion") and world.call("_is_otxo_mansion") == true)
	for room_variant in world.rooms:
		var room_id := int((room_variant as Dictionary).get("id", -1))
		if room_id >= 0:
			var should_be_lit := FULL_FLOOR_CONTENT_VISIBLE or is_otxo or (room_id == active_room) or bool(revealed_rooms.get(room_id, false))
			_set_room_lights(room_id, should_be_lit)


func _process(delta: float) -> void:
	_update_outside_mask()
	if not is_instance_valid(world):
		return
	var room_id := int(world.get_current_room_id())
	var corridor_id := int(world.get_corridor_id_at_position()) if world.has_method("get_corridor_id_at_position") else -1
	# Cross-room activation is no longer inferred from global coordinates.  The
	# room id is changed only by the explicit transition trigger/commit path.
	if room_id == current_room_id and corridor_id == current_corridor_id:
		pending_room_id = -2
		pending_corridor_id = -2
		confirmation_time = 0.0
		return
	if pending_room_id != room_id or pending_corridor_id != corridor_id:
		pending_room_id = room_id
		pending_corridor_id = corridor_id
		confirmation_time = 0.0
	confirmation_time += delta
	if confirmation_time >= 0.05:
		_commit(room_id, corridor_id)


func set_current_presentation_room(room_id: int, corridor_id: int = -1) -> void:
	if not is_instance_valid(world) or room_id < 0:
		return
	_commit(room_id, corridor_id)
	var is_otxo: bool = (world.has_method("_is_otxo_mansion") and world.call("_is_otxo_mansion") == true)
	for room_variant in world.rooms:
		var room_id_variant := int((room_variant as Dictionary).get("id", -1))
		if room_id_variant >= 0:
			var should_be_lit := FULL_FLOOR_CONTENT_VISIBLE or is_otxo or (room_id_variant == room_id) or bool(revealed_rooms.get(room_id_variant, false))
			_set_room_lights(room_id_variant, should_be_lit)


func _commit(room_id: int, corridor_id: int = -1) -> void:
	current_room_id = room_id
	current_corridor_id = corridor_id
	if not is_instance_valid(world):
		return
	var room_near: Dictionary = _near_wall_ids.get(room_id, {})
	var corridor_near: Dictionary = _near_corridor_wall_ids.get(corridor_id, {})
	for wall in world.wall_root.get_children():
		var wid: int = wall.get_instance_id()
		var enabled: bool = bool(room_near.get(wid, false)) or bool(corridor_near.get(wid, false))
		if wall.has_method("set_cutaway_mode"):
			wall.call("set_cutaway_mode", enabled)
	# The office U-shaped wall cut retains full doors and their complete frames.
	var cut_doors: bool=not (world.has_method("uses_office_wall_cutaway") and world.call("uses_office_wall_cutaway"))
	for door in world.door_root.get_children():
		if not door.has_method("set_architectural_cutaway"):
			continue
		var edge: Dictionary = door.get_meta(&"door_edge", {})
		door.call("set_architectural_cutaway", cut_doors and _edge_faces_camera(edge, room_id, corridor_id), world.wall_height)
	for fixture in world.floor_root.get_children():
		if fixture.has_method("set_architectural_cutaway") and fixture.has_meta(&"door_edge"):
			fixture.call("set_architectural_cutaway", cut_doors and _edge_faces_camera(fixture.get_meta(&"door_edge"), room_id, corridor_id), world.wall_height)
	# Wall-mounted details must disappear with the cut-away supporting wall.
	for fixture_variant in _wall_fixtures:
		if not is_instance_valid(fixture_variant):
			continue
		var fixture := fixture_variant as Node3D
		if fixture == null or not fixture.has_meta(&"wall_fixture_edge"):
			continue
		fixture.visible = not _edge_faces_camera(fixture.get_meta(&"wall_fixture_edge"), room_id, corridor_id)
	if world.has_method("refresh_office_wall_cutaway"):
		world.call("refresh_office_wall_cutaway")


func _edge_faces_camera(edge: Dictionary, room_id: int, corridor_id: int) -> bool:
	if edge.is_empty() or world.camera_3d == null:
		return false
	var sides: Array = world.call("_edge_side_cells", edge)
	if sides.size() != 2:
		return false
	var toward_camera := _camera_direction_in_map()
	for i in 2:
		var cell: Vector2i = sides[i]
		var owns_room := room_id >= 0 and int(world.room_cells.get(cell, -1)) == room_id
		var owns_corridor := corridor_id >= 0 and int(world.corridor_cells.get(cell, -1)) == corridor_id
		if not owns_room and not owns_corridor:
			continue
		var outward := Vector2(sides[1 - i] - cell).normalized()
		if outward.dot(toward_camera) > 0.5:
			return true
	return false


func _camera_direction_in_map() -> Vector2:
	var map_direction: Vector3 = world.global_basis.inverse() * world.camera_3d.global_basis.z
	return Vector2(map_direction.x, map_direction.z).normalized()


func reveal_room(room_id: int) -> void:
	if room_id < 0 or not revealed_rooms.has(room_id):
		return
	if bool(revealed_rooms.get(room_id, false)):
		if is_instance_valid(world) and world.has_method("_reveal_connected_corridors_for_room"):
			world.call("_reveal_connected_corridors_for_room", room_id)
		return
	revealed_rooms[room_id] = true
	if room_covers.has(room_id):
		_set_cover_visible(room_covers[room_id], false)
	if is_instance_valid(world):
		world.call("_set_room_content_active", room_id, true)
		if world.has_method("_reveal_connected_corridors_for_room"):
			world.call("_reveal_connected_corridors_for_room", room_id)
	_set_room_lights(room_id, true)


func reveal_corridor(corridor_id: int, source_room_id: int = -1) -> void:
	if corridor_id < 0:
		return
	var revealed_any := false
	if not corridor_stub_covers.is_empty():
		for key_variant in corridor_stub_covers.keys():
			var key := String(key_variant)
			var parts := key.split(":")
			if parts.size() != 2 or int(parts[0]) != corridor_id:
				continue
			if source_room_id >= 0 and int(parts[1]) != source_room_id:
				continue
			_set_cover_visible(corridor_stub_covers[key], false)
			revealed_any = true
		if revealed_any:
			revealed_corridors[corridor_id] = true
		return
	if corridor_stub_covers.is_empty() and corridor_covers.is_empty():
		revealed_corridors[corridor_id] = true
		return
	if not corridor_covers.has(corridor_id):
		return
	if bool(revealed_corridors.get(corridor_id, false)):
		return
	revealed_corridors[corridor_id] = true
	_set_cover_visible(corridor_covers[corridor_id], false)


func _corridor_stub_key(corridor_id: int, source_room_id: int) -> String:
	return "%d:%d" % [corridor_id, source_room_id]


func _set_cover_visible(cover: Node, value: bool) -> void:
	if cover != null and is_instance_valid(cover):
		cover.visible = value


func _set_room_lights(room_id: int, _active: bool) -> void:
	if not is_instance_valid(world) or world.ceiling_light_root == null:
		return
	# Room activation may still be lazy, but illumination belongs to the floor.
	# Keep every fixture at its normal intensity from generation onward.
	var is_current_room := (room_id == current_room_id)
	var managed: bool = world.ceiling_light_root.get("managed_shadows") == true
	for holder in world.ceiling_light_root.get_children():
		if int(holder.get_meta(&"dream_room_id", -1)) == room_id:
			holder.visible = true
			var spot := holder.get_node_or_null("RoomLight") as SpotLight3D
			if spot != null:
				if not managed:
					spot.shadow_enabled = is_current_room and (world.ceiling_light_root.get("shadow_enabled") == true)
				spot.visible = true
			var sconce := holder.get_node_or_null("WallLight") as SpotLight3D
			if sconce != null:
				if not managed:
					sconce.shadow_enabled = is_current_room
				sconce.visible = true


func _make_cover_node(node_name: String, mesh: ArrayMesh) -> MeshInstance3D:
	var cover := MeshInstance3D.new()
	cover.name = node_name
	cover.mesh = mesh
	cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cover.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cover.material_override = material
	return cover


func _build_interior_void_backing() -> void:
	if cover_root == null or world == null: return
	interior_void_backing = preload("res://scripts/dream/interior_void_geometry.gd").build(world.floor_cells, world.building_rect)
	cover_root.add_child(interior_void_backing)
	_update_outside_mask()


func _build_cover_mesh(cells: Array) -> ArrayMesh:
	if cells.is_empty():
		return null
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for cell_variant in cells:
		var cell: Vector2i = cell_variant
		var base := vertices.size()
		vertices.append(Vector3(cell.x - 0.5, COVER_Y, cell.y - 0.5))
		vertices.append(Vector3(cell.x + 0.5, COVER_Y, cell.y - 0.5))
		vertices.append(Vector3(cell.x + 0.5, COVER_Y, cell.y + 0.5))
		vertices.append(Vector3(cell.x - 0.5, COVER_Y, cell.y + 0.5))
		for _index in 4:
			normals.append(Vector3.UP)
		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(1, 1))
		uvs.append(Vector2(0, 1))
		# Counter-clockwise when viewed from above.
		indices.append(base + 0)
		indices.append(base + 2)
		indices.append(base + 1)
		indices.append(base + 0)
		indices.append(base + 3)
		indices.append(base + 2)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
