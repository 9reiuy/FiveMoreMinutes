extends Control
class_name DreamMinimap

## Lightweight topology minimap for Random Dream.
##
## The dungeon generator remains the only source of room and connection data.
## This Control caches that static topology once, then only redraws room state
## as those small pieces of state change.  It never
## renders a second camera or scans the 3D scene.

## The minimap is intentionally a transparent graph overlay.  Keep these
## exports for scene compatibility, but do not paint a panel or an outer frame.
@export var panel_color := Color.TRANSPARENT
@export var border_color := Color.TRANSPARENT
@export var discovered_room_color := Color(0.28, 0.34, 0.40, 0.92)
@export var active_room_color := Color(0.78, 0.86, 0.92, 0.98)
@export var cleared_room_color := Color(0.45, 0.55, 0.62, 0.95)
@export var adjacent_room_color := Color(0.48, 0.50, 0.54, 0.82)
@export var connection_color := Color(0.38, 0.45, 0.53, 0.82)
@export var adjacent_connection_color := Color(0.43, 0.45, 0.49, 0.72)
@export var gameplay_cell_pixels := 32.0
@export var content_padding := 10.0
## One visual scale controls the small non-topology marks.  The Control itself
## is also laid out at half its former size, so the graph geometry and spacing
## naturally scale together instead of each room being hand-tuned.
@export_range(0.1, 1.0, 0.05) var minimap_visual_scale := 0.5

var _rooms: Array[Dictionary] = []
var _connections: Array[Dictionary] = []
var _corridors: Array[Dictionary] = []
var _room_by_id: Dictionary = {}
var _room_states: Dictionary = {}
var _corridor_states: Dictionary = {}
var _room_screen_rects: Dictionary = {}
var _room_screen_centers: Dictionary = {}
var _connection_screen_lines: Array[Dictionary] = []
var _macro_min := Vector2i.ZERO
var _macro_span := Vector2i.ONE
var _map_rect := Rect2()
var _geometry_dirty := true
var _geometry_ready := false
var _player_room_id := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_geometry_dirty = true
		queue_redraw()


func configure(
	layout_rooms: Array,
	layout_connections: Array,
	layout_corridors: Array,
	_cell_pixels: float = 32.0
) -> void:
	_rooms.clear()
	_connections.clear()
	_corridors.clear()
	_room_by_id.clear()
	_room_states.clear()
	_corridor_states.clear()
	_room_screen_rects.clear()
	_room_screen_centers.clear()
	_connection_screen_lines.clear()
	gameplay_cell_pixels = maxf(_cell_pixels, 0.001)
	for room_variant in layout_rooms:
		if not (room_variant is Dictionary):
			continue
		var room: Dictionary = room_variant
		var room_id := int(room.get("id", -1))
		if room_id < 0:
			continue
		_rooms.append(room)
		_room_by_id[room_id] = room
		_room_states[room_id] = StringName(str(room.get("state", &"UNSEEN")))
	for connection_variant in layout_connections:
		if connection_variant is Dictionary:
			_connections.append(connection_variant)
	for corridor_variant in layout_corridors:
		if corridor_variant is Dictionary:
			var corridor: Dictionary = corridor_variant
			_corridors.append(corridor)
			var corridor_id := int(corridor.get("id", -1))
			if corridor_id >= 0:
				_corridor_states[corridor_id] = StringName(str(corridor.get("state", &"UNSEEN")))
	_geometry_dirty = true
	_geometry_ready = not _rooms.is_empty()
	visible = _geometry_ready
	queue_redraw()


func set_room_state(room_id: int, state: StringName) -> void:
	if room_id < 0:
		return
	_room_states[room_id] = state
	queue_redraw()


func set_corridor_state(corridor_id: int, state: StringName) -> void:
	if corridor_id < 0:
		return
	_corridor_states[corridor_id] = state
	queue_redraw()


func set_player_state(_position: Vector2, room_id: int) -> void:
	# Keep the public bridge for existing world/HUD callers, but deliberately do
	# not render a player marker.  The minimap is a room-state graph, not a
	# player-position locator; the room id is still needed to highlight CURRENT.
	_player_room_id = room_id
	queue_redraw()


func _rebuild_geometry() -> void:
	_geometry_dirty = false
	_room_screen_rects.clear()
	_room_screen_centers.clear()
	_connection_screen_lines.clear()
	if _rooms.is_empty() or size.x <= 1.0 or size.y <= 1.0:
		_geometry_ready = false
		visible = false
		return
	_geometry_ready = true
	visible = true
	var min_x := 2147483647
	var min_y := 2147483647
	var max_x := -2147483647
	var max_y := -2147483647
	for room in _rooms:
		var macro_coord := _as_vector2i(room.get("macro_coord", Vector2i.ZERO))
		min_x = mini(min_x, macro_coord.x)
		min_y = mini(min_y, macro_coord.y)
		max_x = maxi(max_x, macro_coord.x)
		max_y = maxi(max_y, macro_coord.y)
	_macro_min = Vector2i(min_x, min_y)
	_macro_span = Vector2i(
		maxi(1, max_x - min_x + 1),
		maxi(1, max_y - min_y + 1)
	)
	var scaled_padding: float = content_padding * minimap_visual_scale
	var panel_size: Vector2 = size - Vector2.ONE * scaled_padding * 2.0
	_map_rect = Rect2(Vector2.ONE * scaled_padding, panel_size)
	var step := Vector2(
		_map_rect.size.x / float(_macro_span.x),
		_map_rect.size.y / float(_macro_span.y)
	)
	# Every topology node is deliberately the same square.  The actual room
	# footprint/shape belongs to the world generator, not this graph display.
	var base_block: float = maxf(minf(step.x, step.y) * 0.58, 4.0)
	for room in _rooms:
		var room_id := int(room.get("id", -1))
		var center := _macro_to_screen(_as_vector2i(room.get("macro_coord", Vector2i.ZERO)))
		var block_size: Vector2 = Vector2.ONE * minf(
			base_block,
			minf(maxf(step.x * 0.82, 4.0), maxf(step.y * 0.82, 4.0))
		)
		var rect := Rect2(center - block_size * 0.5, block_size)
		_room_screen_rects[room_id] = rect
		_room_screen_centers[room_id] = center
	for connection in _connections:
		var a := int(connection.get("a", -1))
		var b := int(connection.get("b", -1))
		if not _room_screen_centers.has(a) or not _room_screen_centers.has(b):
			continue
		_connection_screen_lines.append({
			"a": a,
			"b": b,
			"corridor_id": int(connection.get("corridor_id", -1)),
			"from": _room_screen_centers[a],
			"to": _room_screen_centers[b],
		})


func _draw() -> void:
	if _geometry_dirty:
		_rebuild_geometry()
	if not _geometry_ready:
		return
	for line in _connection_screen_lines:
		var a := int(line.get("a", -1))
		var b := int(line.get("b", -1))
		var corridor_id := int(line.get("corridor_id", -1))
		# A revealed corridor never exposes a second hidden graph layer by
		# itself.  Both endpoints must be visible, so a gray first-hop node does
		# not draw a line onward into the next hidden room.
		if not _is_room_visible(a) or not _is_room_visible(b):
			continue
		var from_position: Vector2 = line["from"]
		var to_position: Vector2 = line["to"]
		var line_color: Color = connection_color
		if _room_display_state(a) == &"ADJACENT_UNKNOWN" or _room_display_state(b) == &"ADJACENT_UNKNOWN":
			line_color = adjacent_connection_color
		var line_width: float = maxf(1.0, 2.0 * minimap_visual_scale)
		draw_line(from_position, to_position, line_color, line_width, true)
	for room in _rooms:
		var room_id := int(room.get("id", -1))
		if not _is_room_visible(room_id) or not _room_screen_rects.has(room_id):
			continue
		var rect: Rect2 = _room_screen_rects[room_id]
		var display_state: StringName = _room_display_state(room_id)
		var room_color: Color = discovered_room_color
		if display_state == &"CURRENT":
			room_color = active_room_color
		elif display_state == &"ADJACENT_UNKNOWN":
			room_color = adjacent_room_color
		elif StringName(str(_room_states.get(room_id, &"UNSEEN"))) == &"CLEARED":
			room_color = cleared_room_color
		draw_rect(rect, room_color, true)
func _is_room_visible(room_id: int) -> bool:
	return _room_display_state(room_id) != &"HIDDEN"


func _room_display_state(room_id: int) -> StringName:
	if room_id < 0 or not _room_by_id.has(room_id):
		return &"HIDDEN"
	if room_id == _player_room_id:
		return &"CURRENT"
	var state: StringName = StringName(str(_room_states.get(room_id, &"UNSEEN")))
	# While the player is between rooms get_current_room_id() can briefly be -1;
	# the single ACTIVE room is still the authoritative current node for the
	# minimap during that transition.
	if state == &"ACTIVE" and _player_room_id < 0:
		return &"CURRENT"
	if state != &"UNSEEN":
		return &"EXPLORED"
	if _has_explored_neighbor(room_id):
		return &"ADJACENT_UNKNOWN"
	return &"HIDDEN"


func _has_explored_neighbor(room_id: int) -> bool:
	for connection_variant in _connections:
		var connection: Dictionary = connection_variant
		var neighbor_id: int = -1
		var a_id: int = int(connection.get("a", -1))
		var b_id: int = int(connection.get("b", -1))
		if a_id == room_id:
			neighbor_id = b_id
		elif b_id == room_id:
			neighbor_id = a_id
		if neighbor_id < 0:
			continue
		if neighbor_id == _player_room_id:
			return true
		var neighbor_state: StringName = StringName(str(_room_states.get(neighbor_id, &"UNSEEN")))
		if neighbor_state != &"UNSEEN":
			return true
	return false


func _is_corridor_visible(corridor_id: int) -> bool:
	return corridor_id >= 0 and _corridor_states.get(corridor_id, &"UNSEEN") != &"UNSEEN"


func _macro_to_screen(coord: Vector2i) -> Vector2:
	var normalized := Vector2(
		(float(coord.x - _macro_min.x) + 0.5) / float(_macro_span.x),
		(float(coord.y - _macro_min.y) + 0.5) / float(_macro_span.y)
	)
	return _map_rect.position + normalized * _map_rect.size


func _as_vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(roundi(value.x), roundi(value.y))
	return Vector2i.ZERO


func _as_rect2i(value: Variant) -> Rect2i:
	if value is Rect2i:
		return value
	return Rect2i(0, 0, 1, 1)
