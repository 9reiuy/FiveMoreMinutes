extends RefCounted

## Random-room fixtures reuse approved atlas meshes at native dimensions.
## Mount on doorway-bearing interior walls, away from all door openings;
## never scatter floor props into circulation or reuse fixed sample coordinates.
const THEME = preload("res://scripts/dream/dream_room_environment_theme.gd")
const ART = preload("res://scripts/dream/office_room_low_pixel_art.gd")
const EDGES = preload("res://scripts/dream/dream_office_v2_generator.gd")

static func build(room: Dictionary, doors: Array, wall_edges: Dictionary = {}, wall_thickness: float = .5, edge_states: Dictionary = {}, enhanced := true) -> Node3D:
	var root := Node3D.new()
	root.name = "ApprovedRandomRoomFixtures_%d" % int(room.get("id", -1))
	root.set_meta(&"dream_room_id", int(room.get("id", -1)))
	var key := THEME.approved_key(room)
	if key.is_empty() or (key == "office" and not enhanced) or not ART.enabled:
		return root
	var wall_directions: Array[Vector2i] = []
	for door_value in doors:
		if door_value is Dictionary:
			var direction: Vector2i = door_value.get("outward", Vector2i.ZERO)
			if direction != Vector2i.ZERO and not wall_directions.has(direction):
				wall_directions.append(direction)
	if enhanced:
		for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			if not wall_directions.has(direction): wall_directions.append(direction)
	# Unconnected rooms get no fabricated wall fixture; actual connected wall
	# directions avoid placing signs over perimeter glazing.
	var tiles: Array[String] = ["sign"]
	match key:
		"server": tiles.append("port")
		"pantry": tiles.append("kitchen")
		"restroom": tiles = ["mirror", "paper"]
		"lift": tiles.append("port")
		"corridor": tiles.append("door")
	if enhanced:
		match key:
			"office", "manager", "conference": tiles.append_array(["whiteboard","sign","fire","pipe"])
			"corridor": tiles.append_array(["fire","pipe","sign"])
			"pantry", "lounge", "reception", "archive", "server": tiles.append_array(["sign","fire","pipe"])
			_: tiles.append_array(["sign","fire"])
	var used: Array[Vector2] = []
	if enhanced and key in ["office","manager","conference","reception","pantry","lounge"]: tiles.append("clock")
	for tile in tiles:
		var size := Vector2(.65, .4)
		if tile == "mirror": size = Vector2(.65, .8)
		if tile == "paper": size = Vector2(.25, .2)
		if tile == "port": size = Vector2(.28, .42) if key == "lift" else Vector2(.65, .2)
		if tile == "door": size = Vector2(.35, .55)
		if tile == "whiteboard": size=Vector2(1.15,.75)
		var mount := _find_mount(room, doors, wall_directions, used, wall_edges, wall_thickness, edge_states)
		if mount.is_empty():
			continue
		var point: Vector2 = mount.point
		used.append(point)
		if tile in ["fire","pipe","clock"]:
			var detail: Node3D = preload("res://scripts/dream/office_extra_dressing.gd").wall_fixture(tile)
			detail.name="WallFixture_"+tile
			detail.set_meta(&"wall_fixture_edge",mount.edge)
			detail.position=Vector3(point.x,2.05 if tile=="clock" else 1.45,point.y)
			detail.rotation.y=float(mount.yaw)
			root.add_child(detail)
			continue
		var display := MeshInstance3D.new()
		display.name = "WallFixture_" + tile
		display.set_meta(&"wall_fixture_edge",mount.edge)
		display.mesh = ART._fixture_mesh(tile, size)
		display.material_override = ART.material()
		display.position = Vector3(point.x, 1.6 if tile == "mirror" else 1.9, point.y)
		display.rotation.y = float(mount.yaw)
		display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(display)
	return root

static func _find_mount(room: Dictionary, doors: Array, directions: Array[Vector2i], used: Array[Vector2], wall_edges: Dictionary, wall_thickness: float, edge_states: Dictionary) -> Dictionary:
	var rect: Rect2i = room.get("grid_rect", Rect2i())
	var shape_cells: Array = room.get("shape_cells", [])
	for direction in directions:
		var horizontal := direction.y != 0
		var start: int = rect.position.x if horizontal else rect.position.y
		var end: int = rect.end.x if horizontal else rect.end.y
		for slot in range(start + 1, end - 1):
			var cell := Vector2i(slot, rect.position.y if direction.y < 0 else rect.end.y - 1) if horizontal else Vector2i(rect.position.x if direction.x < 0 else rect.end.x - 1, slot)
			if not shape_cells.is_empty() and not shape_cells.has(cell):
				continue
			var edge := EDGES._edge_from_inside(cell, direction)
			var edge_key := EDGES._edge_key(edge)
			if not wall_edges.has(edge_key) or (not edge_states.is_empty() and String(edge_states.get(edge_key, "")) != "WALL"):
				continue
			# Integer-centered grid cells: edge planes sit half a cell from
			# their centers. Put the fixture back .02 inside the actual wall face.
			var edge_position: Vector3 = EDGES._edge_world_position(edge)
			var point := Vector2(edge_position.x, edge_position.z) - Vector2(direction) * (wall_thickness * .5 + .0225 + .02)
			var blocked := false
			for door_value in doors:
				if not door_value is Dictionary:
					continue
				var inside: Vector2i = door_value.get("inside_cell", Vector2i.ZERO)
				var clearance := 1.5 + float(door_value.get("opening_cells", 1)) * .5
				if point.distance_to(Vector2(inside)) < clearance:
					blocked = true
			for existing in used:
				if point.distance_to(existing) < 1.1:
					blocked = true
			if not blocked:
				var yaw := 0.0 if direction.y < 0 else PI if direction.y > 0 else PI * .5 if direction.x < 0 else -PI * .5
				return {"point": point, "yaw": yaw, "edge":edge}
	return {}
