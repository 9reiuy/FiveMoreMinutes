extends RefCounted
## Shared compiler bridge: exact whitebox cells, no rectangle reconstruction.
const LEGACY = preload("res://scripts/dream/dream_otxo_mansion_generator.gd")
const CATALOG = preload("res://scripts/dream/office_furniture_catalog.gd")
const LOGIC = preload("res://scenes/dream/props/desk.tscn")
const CHAIR = preload("res://scenes/dream/props/office_chair_01.tscn")
const HALLS := ["hub", "ring", "transition", "flank", "rear", "lower", "service", "crosshall"]
const KINDS := {"main":"open_office", "west":"open_office", "east":"open_office", "meeting":"conference_large", "training":"conference_large", "deep":"manager", "inner":"manager", "finance":"small_office", "print":"printing", "smoking":"lounge"}
const FURNITURE := {"接待台":"reception", "工作桌":"workstation", "办公桌":"desk", "办公椅":"chair", "会议椅":"chair", "餐椅":"chair", "会议桌":"table", "矮茶几":"coffee_table", "等候沙发":"sofa", "沙发":"sofa", "靠墙长椅":"sofa", "档案柜":"cabinet", "文件柜":"cabinet", "机柜":"server", "冰箱":"fridge", "水槽台面":"sink", "咖啡台面":"appliance_counter", "餐桌":"dining_table", "打印机":"copier", "整理台":"sorting_table", "烟灰桶":"bin", "饮水机":"water_dispenser"}

static func is_hall(id: String) -> bool:
	return HALLS.has(id)

static func cell(value: String) -> Vector2i:
	var parts := value.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

static func rect(value: Dictionary) -> Rect2i:
	return Rect2i(int(value.x), int(value.y), int(value.w), int(value.h))

## Glass parallel to a corridor can remain as side enclosure. A perpendicular
## span across its end must be a walking opening, including mirrored layouts.
static func corridor_crossing_span(segments: Array, edge: Dictionary) -> Dictionary:
	for segment in segments:
		if String(segment.room) not in [String(edge.a),String(edge.b)]: continue
		var vertical := bool(edge.vertical)
		if not ((vertical and int(segment.w)>int(segment.h)) or (not vertical and int(segment.h)>int(segment.w))): continue
		var ends: Array=[int(segment.x),int(segment.x)+int(segment.w)] if vertical else [int(segment.y),int(segment.y)+int(segment.h)]
		if int(edge.line) not in ends: continue
		var start: int=segment.y if vertical else segment.x
		var width: int=segment.h if vertical else segment.w
		if int(edge.start)<start+width and int(edge.start)+int(edge.width)>start:
			return {"start":start,"width":width}
	return {}

static func compile(data: Dictionary) -> Dictionary:
	if not bool(data.get("checks", {}).get("ok", false)):
		return {}
	var layout := {"rooms":[], "partitions":[], "corridors":[], "connections":[], "floor_cells":{}, "room_cells":{}, "corridor_cells":{}, "wall_edges":{}, "internal_wall_edges":{}, "door_edges":{}, "door_opening_edges":{}, "glass_wall_edges":{}, "edge_states":{}, "plans":{}, "glass_runs":{}}
	var ids: Dictionary = {}
	for source in data.rooms:
		if source.id == "lift":
			continue # The whitebox elevator symbol is not playable floor/cab geometry.
		var id: int = layout.rooms.size()
		ids[source.id] = id
		var hall := is_hall(String(source.id))
		var arch: String = "corridor" if hall else String(KINDS.get(source.kind, source.kind))
		var safe: bool = source.id in ["entry", "smoking", "storage"] or hall
		if source.id == "entry":
			arch = "reception"
		var cells: Array[Vector2i] = []
		for raw in source.cells:
			var c := cell(raw)
			cells.append(c)
			layout.floor_cells[c] = &"room"
			layout.room_cells[c] = id
		var bounds := rect(source.bounds)
		var anchor := cell(data.anchors[source.id])
		layout.rooms.append({"id":id, "name":source.label, "sample_key":source.id, "archetype":arch, "grid_rect":bounds, "center_cell":anchor, "geometric_center_cell":anchor, "macro_coord":Vector2i(id,0), "shape":&"irregular", "size_class":&"large" if arch == "open_office" else &"medium", "shape_cells":cells, "usable_cells":cells.duplicate(), "connections":[], "neighbors":[], "room_type":&"elevator_lobby" if source.id == "entry" else (&"corridor" if hall else &"normal"), "navigation_role":&"circulation" if hall else &"room", "combat_room":not safe, "elevator_reception":source.id == "entry", "office_combat_layout":true, "office_visual_style":"approved_office" if arch == "open_office" else "approved_room", "authored_sample":false, "state":&"UNSEEN", "revealed":false, "activated":false, "cleared":safe})
		layout.plans[id] = {"success":true, "furniture_placements":[], "enemy_spawns":[], "drop_spawns":[]}
	for source_d in data.doors:
		var d: Dictionary=source_d.duplicate(true)
		if not ids.has(d.a) or not ids.has(d.b):
			continue # Exterior glass remains solid facade; never makes an outside route.
		if bool(d.glass):
			var span := corridor_crossing_span(data.get("corridorSegments",[]),d)
			if not span.is_empty():
				var existing_opening := false
				for other in data.doors:
					if not bool(other.glass) and bool(other.vertical)==bool(d.vertical) and int(other.line)==int(d.line) and int(other.start)<int(span.start)+int(span.width) and int(other.start)+int(other.width)>int(span.start): existing_opening=true; break
				if existing_opening: continue
				# Also normalize older authored sources at the compiler boundary.
				d.glass=false; d.open=true
				var full_span_shared := true
				for slot in range(int(span.start),int(span.start)+int(span.width)):
					var inside := Vector2i(int(d.line)-1,slot) if bool(d.vertical) else Vector2i(slot,int(d.line)-1)
					var step := Vector2i.RIGHT if bool(d.vertical) else Vector2i.DOWN
					var first_room: int=layout.room_cells.get(inside,-1)
					var second_room: int=layout.room_cells.get(inside+step,-1)
					if not ((first_room==ids[d.a] and second_room==ids[d.b]) or (first_room==ids[d.b] and second_room==ids[d.a])): full_span_shared=false; break
				# Never widen a legacy opening over a void or a third room.
				if full_span_shared: d.start=span.start; d.width=span.width
		var vertical: bool = d.vertical
		var start := int(d.start)
		var cut := int(d.line)
		var width := int(d.width)
		var first := {"axis":"V" if vertical else "H", "x":cut if vertical else start, "y":start if vertical else cut}
		if bool(d.glass):
			var group := LEGACY._edge_key(first)
			for slot in range(start, start + width):
				var e := {"axis":first.axis, "x":cut if vertical else slot, "y":slot if vertical else cut, "preview_glass_group":group}
				layout.glass_wall_edges[LEGACY._edge_key(e)] = e
			layout.glass_runs[group] = {"edge":first, "width":width}
			continue
		var a: int = ids[d.a]
		var b: int = ids[d.b]
		var inside := Vector2i(cut - 1, start + width / 2) if vertical else Vector2i(start + width / 2, cut - 1)
		var step := Vector2i.RIGHT if vertical else Vector2i.DOWN
		# Source room ordering is not necessarily negative-side/positive-side ordering.
		a = int(layout.room_cells[inside])
		b = int(layout.room_cells[inside + step])
		var id: int = layout.connections.size()
		var style := "open" if bool(d.get("open", false)) or (is_hall(String(d.a)) and is_hall(String(d.b))) else "double"
		var e := first.duplicate()
		e.merge({"opening_cells":width, "opening_start":start, "opening_end":start+width, "region_a_id":a, "region_b_id":b, "door_id":id, "connection_id":id, "door_direction":first.axis, "hinge_side":"left", "shared_boundary_length":width+2, "door_style":style, "is_elevator_sliding_door":false})
		e["wall_edge"] = e.duplicate(true)
		e["door_position"] = LEGACY._edge_world_position(e)
		layout.door_edges[LEGACY._edge_key(e)] = e
		for slot in range(start,start+width):
			var p := {"axis":first.axis, "x":cut if vertical else slot, "y":slot if vertical else cut, "door_id":id, "connection_id":id, "region_a_id":a, "region_b_id":b, "door_style":style}
			layout.door_opening_edges[LEGACY._edge_key(p)] = p
		layout.connections.append({"id":id, "door_id":id, "a":a, "b":b, "length":0, "door_a":{"inside_cell":inside, "outside_cell":inside+step, "outward":step, "room_id":a, "opening_cells":width}, "door_b":{"inside_cell":inside+step, "outside_cell":inside, "outward":-step, "room_id":b, "opening_cells":width}, "door_edge":e, "door_style":style, "is_elevator_sliding_door":false})
		layout.rooms[a].connections.append(b)
		layout.rooms[a].neighbors.append(b)
		layout.rooms[b].connections.append(a)
		layout.rooms[b].neighbors.append(a)
	for c in layout.floor_cells:
		for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var other: Vector2i = c + direction
			if layout.room_cells.get(c) == layout.room_cells.get(other):
				continue
			var e: Dictionary = LEGACY._edge_from_inside(c,direction)
			var k: String = LEGACY._edge_key(e)
			if layout.door_opening_edges.has(k):
				layout.edge_states[k] = &"OPEN" if String(layout.door_opening_edges[k].get("door_style","")) == "open" else (&"DOOR" if layout.door_edges.has(k) else &"DOOR_OPENING")
				continue
			if layout.glass_wall_edges.has(k):
				e = layout.glass_wall_edges[k]
				layout.edge_states[k] = &"GLASS_WINDOW"
			else:
				layout.edge_states[k] = &"WALL"
			layout.wall_edges[k] = e
			if layout.floor_cells.has(other):
				layout.internal_wall_edges[k] = e
	var entry: int = ids.entry
	var reception: Rect2i = layout.rooms[entry].grid_rect
	var facade := {"axis":"H", "x":reception.position.x+5, "y":reception.end.y, "opening_cells":3, "opening_start":reception.position.x+5, "opening_end":reception.position.x+8, "region_a_id":entry, "region_b_id":-1, "door_id":layout.connections.size(), "connection_id":-1, "door_direction":"H", "door_style":"elevator", "is_elevator_sliding_door":true, "elevator_cab_inward":Vector2.DOWN}
	facade["wall_edge"] = facade.duplicate(true)
	facade["door_position"] = LEGACY._edge_world_position(facade)
	layout.rooms[entry]["elevator_facade_edge"] = facade
	layout.door_edges[LEGACY._edge_key(facade)] = facade
	for slot in range(int(facade.opening_start),int(facade.opening_end)):
		var e := {"axis":"H", "x":slot, "y":reception.end.y, "door_id":facade.door_id, "region_a_id":entry, "region_b_id":-1, "is_elevator_sliding_door":true}
		var k: String = LEGACY._edge_key(e)
		layout.door_opening_edges[k] = e
		layout.wall_edges.erase(k)
		layout.edge_states[k] = &"DOOR" if slot == int(facade.opening_start) else &"DOOR_OPENING"
	for item in data.furniture:
		if not FURNITURE.has(item.kind) and item.kind != "盆栽":
			push_error("Unmapped preview furniture: " + String(item.kind))
			return {}
		var kind: String = "plant" if item.kind == "盆栽" else FURNITURE[item.kind]
		var rotation := 0.0
		if item.facing != null:
			rotation = atan2(-float(item.facing[0]),float(item.facing[1]))
		elif float(item.h) > float(item.w):
			rotation = PI * .5
		var position := Vector2(float(item.x)+float(item.w)*.5-.5,float(item.y)+float(item.h)*.5-.5)*32.0
		var collision_rect: Rect2 = preload("res://scripts/dream/otxo_room_layout_planner.gd")._office_rotated_rect(CATALOG.footprint(kind),rotation)
		layout.plans[ids[item.room]].furniture_placements.append({"scene":CHAIR if kind == "chair" else LOGIC, "office_kind":kind, "position":position, "rotation":rotation, "collision_rect":collision_rect, "half_extents":collision_rect.size*.5, "preview_group":item.group})
		if kind=="coffee_table":
			var plan: Dictionary=layout.plans[ids[item.room]]
			if not plan.has("functional_areas"): plan["functional_areas"]=[]
			plan.functional_areas.append({"category":"seating","center_cell":Vector2i((position/32.0).round())})
	for item in data.enemies:
		layout.plans[ids[item.room]].enemy_spawns.append({"type":&"employee", "ground_position":Vector2(cell(item.cell))*32.0})
	# Formal enemy budgets may exceed the whitebox's illustrative red dots.
	# Extra spawns must sample real free floor, not furniture bounding boxes.
	for room in layout.rooms:
		var usable: Array[Vector2i] = []
		for c in room.shape_cells:
			var blocked := false
			for item in layout.plans[room.id].furniture_placements:
				var obstacle: Rect2 = item.collision_rect
				obstacle.position += item.position
				if obstacle.grow(24.0).has_point(Vector2(c)*32.0):
					blocked = true
					break
			if not blocked:
				usable.append(c)
		room.usable_cells = usable
	layout.merge({"building_rect":rect(data.bounds), "floor_shape":StringName("skeleton_"+String(data.type)), "spawn_room_id":entry, "spawn_cell":Vector2i(reception.position.x+6,reception.end.y-3), "main_entrance":{}, "next_door_id":layout.connections.size()+1, "source":data})
	return layout
