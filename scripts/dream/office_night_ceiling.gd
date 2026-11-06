extends RefCounted
## The two lights share one physical ceiling fixture. The fill sees only the
## structural shell, while the key also casts furniture and character shadows.

const ARCHITECTURE_CASTERS := 1 << 12
const ENEMY_CASTERS := 1 << 13
const ROOF := 1 << 17
const MIRROR := 1 << 18
const MAIN_ONLY := 1 << 19
const PRIMARY_RECEIVERS := 15 | ROOF | MIRROR | MAIN_ONLY
const MAX_SPAN := 24.0


static func build(root: Node3D, world: Node3D, floor_cells: Dictionary, room_cells: Dictionary) -> void:
	var cells_by_room := {}
	for cell: Vector2i in floor_cells:
		var room_id := int(room_cells.get(cell, -1))
		if room_id < 0:
			continue
		if not cells_by_room.has(room_id):
			cells_by_room[room_id] = {}
		cells_by_room[room_id][cell] = true
	var height: float = world.wall_height - .17
	for room: Dictionary in world.rooms:
		if str(room.get("archetype", "")) in ["corridor", "hallway"] or str(room.get("room_type", "")) == "corridor":
			continue
		var room_id := int(room.id)
		var index := 0
		for rect in _rectangles(cells_by_room.get(room_id, {})):
			var columns := maxi(1, ceili(rect.size.x / MAX_SPAN))
			var rows := maxi(1, ceili(rect.size.y / MAX_SPAN))
			var size := rect.size / Vector2(columns, rows)
			for y in rows:
				for x in columns:
					var point := rect.position + size * (Vector2(x, y) + Vector2.ONE * .5)
					var holder := Node3D.new()
					holder.name = "NightLightingRoom%dCeiling%d" % [room_id, index]
					holder.position = Vector3(point.x, height, point.y)
					holder.set_meta(&"dream_room_id", room_id)
					root.add_child(holder)
					var reach := maxf(6.0, Vector2(height, size.length() * .5).length() * 1.8)
					_add_light(holder, "RoomLight", reach, false)
					_add_light(holder, "RoomFill", reach, true)
					root._build_fixture_mesh(holder, str(room.get("archetype", "office")), Rect2i(Vector2i.ZERO, Vector2i(size)))
					index += 1


static func _add_light(holder: Node3D, label: String, reach: float, indirect: bool) -> void:
	var light := OmniLight3D.new()
	light.name = label
	light.light_color = Color("f1edff")
	light.light_energy = .16 if indirect else 1.05
	light.light_specular = 0.0
	light.omni_range = reach
	light.omni_attenuation = 0.0
	light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	light.shadow_enabled = true
	light.shadow_bias = .02 if indirect else .085
	light.shadow_normal_bias = .035 if indirect else .5
	light.light_size = 0.0 if indirect else .5
	light.light_cull_mask = ((PRIMARY_RECEIVERS & ~4) | ARCHITECTURE_CASTERS) if indirect else (PRIMARY_RECEIVERS | ENEMY_CASTERS)
	light.shadow_caster_mask = (ARCHITECTURE_CASTERS | ROOF) if indirect else (1 | 4 | 8 | ROOF)
	holder.add_child(light)


static func _rectangles(remaining: Dictionary) -> Array[Rect2]:
	var result: Array[Rect2] = []
	while not remaining.is_empty():
		var first: Vector2i = remaining.keys()[0]
		for point: Vector2i in remaining:
			if point.y < first.y or (point.y == first.y and point.x < first.x):
				first = point
		var width := 1
		while remaining.has(first + Vector2i(width, 0)):
			width += 1
		var height := 1
		while _row_is_full(remaining, first + Vector2i(0, height), width):
			height += 1
		for y in height:
			for x in width:
				remaining.erase(first + Vector2i(x, y))
		result.append(Rect2(Vector2(first) - Vector2.ONE * .5, Vector2(width, height)))
	return result


static func _row_is_full(cells: Dictionary, first: Vector2i, width: int) -> bool:
	for x in width:
		if not cells.has(first + Vector2i(x, 0)):
			return false
	return true
