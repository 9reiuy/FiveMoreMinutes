extends RefCounted
## Native seeded generation from topology and functional-group rules, never a map bank.
const RULES = preload("res://scripts/dream/office_skeleton_rules.gd")
const ADAPTER = preload("res://scripts/dream/office_skeleton_layout_adapter.gd")
const PLANNER = preload("res://scripts/dream/otxo_room_layout_planner.gd")
const TYPES := ["A1","B2","C3","V3"]
const HALLS := ADAPTER.HALLS
const DIRS := [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]
const LABELS := {"entry":"安全接待", "main":"主战办公区", "west":"西办公厅", "east":"东办公厅", "deep":"外办公室", "inner":"内嵌经理室", "meeting":"会议室", "training":"培训室", "archive":"档案区", "storage":"储藏间", "server":"机房", "print":"打印区", "pantry":"茶水间", "lounge":"休息室", "finance":"财务室", "smoking":"吸烟室"}
var random := RandomNumberGenerator.new()
var rooms: Dictionary = {}
var owners: Dictionary = {}
var doors: Array = []
var segments: Array = []
var furniture: Array = []
var groups: Array = []
var occupied: Dictionary = {}
var door_buffer: Dictionary = {}
var compact := false
var enhanced_dressing := true
var last_rejection := ""
static var validation_reason := ""
const SAMPLE_SIZES := {"meeting":Vector2i(12,14), "training":Vector2i(12,14), "deep":Vector2i(12,10), "inner":Vector2i(12,10), "finance":Vector2i(12,10), "archive":Vector2i(11,10), "server":Vector2i(11,10), "pantry":Vector2i(10,10), "lounge":Vector2i(10,10), "print":Vector2i(10,10), "storage":Vector2i(7,6)}

static func generate(master: RandomNumberGenerator, options: Dictionary = {}) -> Dictionary:
	return _generate_validated(master,options,false)

static func generate_compiled(master: RandomNumberGenerator, options: Dictionary = {}) -> Dictionary:
	# The native generator already compiles every accepted source for validation.
	# Give the formal caller that same layout rather than compiling it again.
	return _generate_validated(master,options,true)

static func _generate_validated(master: RandomNumberGenerator, options: Dictionary, include_layout: bool) -> Dictionary:
	# Choose once before retries, so difficult skeletons are not underweighted.
	var type: String = String(options.get("type",TYPES[master.randi_range(0,3)]))
	if not TYPES.has(type):
		return {}
	var child_seed := master.randi()
	var builder := new()
	builder.compact = bool(options.get("compact", false))
	builder.enhanced_dressing = bool(options.get("enhanced_dressing",true))
	var requested_seed: int = int(options.get("seed",master.seed))
	var smoking_rng := RandomNumberGenerator.new()
	smoking_rng.seed = child_seed ^ 0x534D4F4B
	var smoking := smoking_rng.randf() < .45
	var rejection_counts: Dictionary = {}
	for attempt in 64:
		builder.random.seed = child_seed + attempt*104729
		var data := builder._attempt(type,requested_seed,smoking)
		if data.is_empty():
			rejection_counts[builder.last_rejection] = int(rejection_counts.get(builder.last_rejection,0))+1
			continue
		var layout: Dictionary = ADAPTER.compile(data)
		if _validate(layout):
			data["native_attempts"] = attempt+1
			return {"source":data,"layout":layout} if include_layout else data
		builder.last_rejection = "compiled " + validation_reason
		rejection_counts[builder.last_rejection] = int(rejection_counts.get(builder.last_rejection,0))+1
	push_error("Native skeleton generation exhausted: %s seed=%d (%s)" % [type,requested_seed,str(rejection_counts)])
	return {}

static func _validate(layout: Dictionary) -> bool:
	if layout.is_empty():
		return false
	var visited: Dictionary = {layout.spawn_room_id:true}
	for iteration in layout.rooms.size():
		for connection in layout.connections:
			if visited.has(connection.a): visited[connection.b]=true
			if visited.has(connection.b): visited[connection.a]=true
	if visited.size() != layout.rooms.size():
		validation_reason="disconnected graph"
		return false
	for room in layout.rooms:
		var room_doors: Array = []
		for connection in layout.connections:
			if int(connection.a) == int(room.id):
				room_doors.append(connection.door_a)
			elif int(connection.b) == int(room.id):
				room_doors.append(connection.door_b)
		var plan: Dictionary = layout.plans[room.id]
		if not PLANNER._office_wide_routes(room.shape_cells,plan.furniture_placements,room_doors,32.0):
			validation_reason="routes " + String(room.sample_key)
			return false
		for item in plan.furniture_placements:
			var actual: Rect2 = item.collision_rect
			actual.position += item.position
			if not PLANNER._office_rect_on_floor(actual,room.shape_cells,32.0):
				validation_reason="footprint " + String(room.sample_key)
				return false
	return true

func _reset() -> void:
	last_rejection = "topology/links"
	rooms.clear()
	owners.clear()
	doors.clear()
	segments.clear()
	furniture.clear()
	groups.clear()
	occupied.clear()
	door_buffer.clear()

static func _cells(rect: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			result.append(Vector2i(x,y))
	return result

static func _bounds(cells: Dictionary) -> Rect2i:
	var low := Vector2i(2147483647,2147483647)
	var high := -low
	for c in cells:
		low = Vector2i(mini(low.x,c.x),mini(low.y,c.y))
		high = Vector2i(maxi(high.x,c.x),maxi(high.y,c.y))
	return Rect2i(low,high-low+Vector2i.ONE)

static func _box(rect: Rect2i) -> Dictionary:
	return {"x":rect.position.x,"y":rect.position.y,"w":rect.size.x,"h":rect.size.y}

static func _text(c: Vector2i) -> String:
	return "%d,%d" % [c.x,c.y]

func _add(id: String,rect: Rect2i) -> bool:
	if not rooms.has(id):
		rooms[id] = {"id":id,"kind":id,"cells":{}}
	for c in _cells(rect):
		if owners.has(c) and owners[c] != id:
			return false
		owners[c] = id
		rooms[id].cells[c] = true
	return true

func _nest(parent: String,id: String,links: Array) -> bool:
	last_rejection = "nested " + parent + "/" + id
	var bounds: Rect2i = _bounds(rooms[parent].cells)
	var size := Vector2i(maxi(10 if id == "inner" else 7,int(bounds.size.x*.48)),maxi(11 if id == "inner" else (6 if compact else 8),int(bounds.size.y*.44)))
	if compact and id == "storage": size = Vector2i(7,6)
	var x := bounds.position.x if random.randf() < .5 else bounds.end.x-size.x
	var region := Rect2i(Vector2i(x,bounds.position.y),size)
	var cells: Dictionary = {}
	for c in _cells(region):
		if owners.get(c) != parent:
			return false
		rooms[parent].cells.erase(c)
		owners[c] = id
		cells[c] = true
	rooms[id] = {"id":id,"kind":id,"parent":parent,"cells":cells}
	links.append([parent,id])
	return true

func _runs(a: String,b: String) -> Array:
	var edges: Array = []
	for c in rooms[a].cells:
		for direction in DIRS:
			if String(owners.get(c+direction,"outside")) != b:
				continue
			var vertical: bool = direction.x != 0
			edges.append({"a":c,"b":c+direction,"vertical":vertical,"line":maxi(c.x,c.x+direction.x) if vertical else maxi(c.y,c.y+direction.y),"pos":c.y if vertical else c.x})
	edges.sort_custom(func(l: Dictionary,r: Dictionary) -> bool:
		if l.vertical != r.vertical: return not l.vertical
		if l.line != r.line: return l.line < r.line
		return l.pos < r.pos)
	var runs: Array = []
	for e in edges:
		if not runs.is_empty():
			var previous: Dictionary = runs.back().back()
			if previous.vertical == e.vertical and previous.line == e.line and previous.pos+1 == e.pos:
				runs.back().append(e)
				continue
		runs.append([e])
	runs.sort_custom(func(l: Array,r: Array) -> bool: return l.size() > r.size())
	return runs

func _door(a: String,b: String,run: Array,glass: bool,open: bool = false) -> void:
	if glass:
		var span := ADAPTER.corridor_crossing_span(segments,{"a":a,"b":b,"vertical":run[0].vertical,"line":run[0].line,"start":run[0].pos,"width":run.size()})
		if not span.is_empty():
			for contact_run in _runs(a,b):
				if contact_run[0].vertical!=run[0].vertical or int(contact_run[0].line)!=int(run[0].line): continue
				if int(contact_run[0].pos)>int(run[0].pos) or int(contact_run[-1].pos)<int(run[-1].pos): continue
				# A proper entrance already exists: keep its surrounding border,
				# but never fill the remaining corridor end with glass.
				if contact_run.any(func(e: Dictionary) -> bool: return _is_door(e)): return
				run=contact_run; glass=false; open=true; break
	var cells: Array = []
	for e in run:
		cells.append(_text(e.a))
		cells.append(_text(e.b))
	doors.append({"a":a,"b":b,"vertical":run[0].vertical,"line":run[0].line,"start":run[0].pos,"width":run.size(),"glass":glass,"open":open,"cells":cells,"officeFrontage":(a in ["main","west","east"] and HALLS.has(b)) or (b in ["main","west","east"] and HALLS.has(a))})

func _is_door(e: Dictionary) -> bool:
	for d in doors:
		if d.vertical == e.vertical and int(d.line) == int(e.line) and int(e.pos) >= int(d.start) and int(e.pos) < int(d.start)+int(d.width):
			return true
	return false

func _attempt(type: String,seed: int,smoking: bool) -> Dictionary:
	_reset()
	var topology: Dictionary = RULES.data.topologies[type].duplicate(true)
	var widths: Array[int] = []
	var heights: Array[int] = []
	for i in 11:
		widths.append(random.randi_range(8,10) if compact else random.randi_range(9,12))
		heights.append(random.randi_range(8,10) if compact else random.randi_range(9,12))
	var side := random.randi_range(3,4)
	var main := random.randi_range(4,5)
	var hub := random.randi_range(6,8)
	# Reduce repeated combat spans, not furniture size or mandatory corridor widths.
	# Reception coordinates below still override these to exactly 14x10.
	if compact:
		for i in [2,5]: widths[i] = random.randi_range(6,8)
		widths[0] = 12 # Nested storage plus archive bank and its continuous aisle.
		for i in [3,4]: heights[i] = 8
		heights[6] = random.randi_range(6,8)
		if type == "A1": heights[1] = 12 # Print/pantry swap must fit both groups.
		if type == "V3": heights[5] = 12
		if type == "B2":
			widths[2]=11; widths[3]=11; widths[9]=12; widths[5]=11
		if type == "C3": widths[7]=11
		if type == "V3": widths[6]=11; widths[2]=5
	match type:
		"A1":
			widths[3]=7; widths[4]=7; heights[6]=5; heights[7]=5
			widths[1]=side; widths[6]=side; heights[2]=main
		"B2":
			widths[0]=side; widths[1]=14-side; heights[5]=10
			widths[4]=hub; heights[2]=hub; widths[8]=side
		"C3":
			widths[3]=4; widths[4]=5; widths[5]=5; heights[7]=10
			widths[1]=side; widths[8]=side; heights[3]=main
		"V3":
			widths[3]=7; widths[4]=7; heights[6]=10
			widths[1]=side; widths[9]=side
	var xs: Array[int] = [0]
	var ys: Array[int] = [0]
	for i in 11:
		xs.append(xs.back()+widths[i]); ys.append(ys.back()+heights[i])
	for spec in topology.rooms:
		var id := String(spec.id)
		if id == "lift": continue
		var x := xs[int(spec.x)]
		var y := ys[int(spec.y)]
		var w := xs[int(spec.x+spec.w)]-x
		var h := ys[int(spec.y+spec.h)]-y
		var classification := "side"
		var corridor_width := side
		var pocket := Rect2i()
		if HALLS.has(id):
			if id == "hub" and type == "B2":
				classification="junction"; corridor_width=hub
			elif id == "hub" and type == "V3":
				y=ys[int(spec.y+spec.h)]-main; h=main; classification="main"; corridor_width=main
				pocket=Rect2i(xs[5],ys[int(spec.y+spec.h)]-hub,hub,hub)
			elif int(spec.h) == 1:
				corridor_width=main if id in ["ring","transition"] else side
				classification="main" if id in ["ring","transition"] else "side"
				if id == "crosshall": y += h-corridor_width
				h=corridor_width
			else: w=side
		var region := Rect2i(x,y,w,h)
		if not _add(id,region): return {}
		if HALLS.has(id):
			segments.append(_box(region).merged({"room":id,"class":classification,"width":corridor_width}))
		if pocket.has_area():
			if not _add(id,pocket): return {}
			segments.append(_box(pocket).merged({"room":id,"class":"junction","width":hub}))
	var links: Array = topology.links.filter(func(link: Array) -> bool: return not link.has("lift"))
	if compact:
		# The elevator is on the south facade. Only the opposite (north) wall
		# connects reception to play; side loops are reached through the office.
		links = links.filter(func(link: Array) -> bool:
			if not link.has("entry"): return true
			var other: String = String(link[1] if link[0] == "entry" else link[0])
			return _runs("entry",other).any(func(run: Array) -> bool: return not run[0].vertical and int(run[0].line) == _bounds(rooms.entry.cells).position.y))
	if not _nest("deep","inner",links): return {}
	if not rooms.has("storage") and not _nest("archive","storage",links): return {}
	if smoking:
		var added := false
		for hall in ["rear","flank"]:
			if not rooms.has(hall): continue
			for c in rooms[hall].cells:
				for sign in [1,-1]:
					var region := Rect2i(c.x+1 if sign == 1 else c.x-10,c.y,10,10)
					var valid := true
					for q in _cells(region):
						if owners.has(q): valid=false; break
					for dy in 10:
						if not rooms[hall].cells.has(c+Vector2i(0,dy)): valid=false; break
					if valid:
						_add("smoking",region); links.append([hall,"smoking"]); added=true; break
				if added: break
			if added: break
		if not added: return {}
	var swap := random.randf() < .5
	for room in rooms.values():
		if swap:
			if room.id == "print": room.kind="pantry"
			elif room.id == "pantry": room.kind="print"
			elif room.id == "finance": room.kind="training"
		room["bounds"]=_box(_bounds(room.cells))
		room["label"]=LABELS.get(room.kind,"走廊")
	if compact and not _sample_room_footprints(links,type): return {}
	for link in links:
		var a := String(link[0]); var b := String(link[1])
		last_rejection = "door link " + a + "/" + b
		var runs: Array = _runs(a,b)
		if runs.is_empty() or runs[0].size() < 3: return {}
		var run: Array = runs[0]
		var width: int = run.size() if ADAPTER.is_hall(a) and ADAPTER.is_hall(b) else mini(run.size(),5 if a in ["main","west","east"] and ADAPTER.is_hall(b) else 3)
		var margin := 1 if run.size() >= width+2 else 0
		var start := random.randi_range(margin,run.size()-width-margin)
		if a == "entry" or b == "entry":
			var entry: Rect2i = _bounds(rooms.entry.cells)
			var desired := entry.position.y+1 if run[0].vertical else entry.position.x+6
			start=clampi(desired-int(run[0].pos),margin,run.size()-width-margin)
		_door(a,b,run.slice(start,start+width),false,(a in ["main","west","east"] and ADAPTER.is_hall(b)) or (b in ["main","west","east"] and ADAPTER.is_hall(a)) or (ADAPTER.is_hall(a) and ADAPTER.is_hall(b)))
	for office in ["main","west","east"]:
		if not rooms.has(office): continue
		for hall in HALLS:
			if not rooms.has(hall): continue
			for run in _runs(office,hall):
				var pending: Array = []
				for e in run.slice(1,run.size()-1):
					if _is_door(e):
						if pending.size() >= 2: _door(office,hall,pending,true)
						pending=[]
					else: pending.append(e)
				if pending.size() >= 2: _door(office,hall,pending,true)
	# Observation glass is separate from essential doorway connectivity.
	var pair: Array = ["meeting","west"] if type == "B2" else (["meeting","main"] if type == "V3" else (["main","ring"] if type == "A1" else ["meeting","transition"]))
	for run in _runs(pair[0],pair[1]):
		var done := false
		for offset in range(1,run.size()-3):
			var section: Array = run.slice(offset,offset+3)
			if section.all(func(e: Dictionary) -> bool: return not _is_door(e)):
				_door(pair[0],pair[1],section,true); done=true; break
		if done: break
	for d in doors:
		if d.glass: continue
		for raw in d.cells:
			var c := ADAPTER.cell(raw)
			for offset in range(-2,3):
				door_buffer[c+Vector2i(offset,0) if d.vertical else c+Vector2i(0,offset)] = true
	if not _furnish(): return {}
	var anchors: Dictionary = {}
	for room in rooms.values():
		var clear := _clear(room,{})
		if clear.is_empty():
			last_rejection="empty anchor " + String(room.id)
			return {}
		var candidates: Array = clear.keys()
		var center: Vector2 = _bounds(room.cells).get_center()
		candidates.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center))
		anchors[room.id]=_text(candidates[0])
	var decor: Array = _decor()
	var bounds := _bounds(owners)
	var raw_rooms: Array = []
	for room in rooms.values():
		var r: Dictionary = room.duplicate(true)
		r.cells=room.cells.keys().map(func(c: Vector2i) -> String: return _text(c))
		raw_rooms.append(r)
	var data := {"type":type,"seed":seed,"bounds":_box(bounds),"rooms":raw_rooms,"doors":doors.duplicate(true),"furniture":furniture.duplicate(true),"groups":groups.duplicate(true),"enemies":[],"anchors":anchors,"decor":decor,"corridorSegments":segments.duplicate(true),"checks":{"ok":true},"smokingRequested":smoking}
	if random.randf() < .5: _mirror(data,bounds.position.x*2+bounds.size.x)
	return data

static func _rect_cells_available(region: Rect2i, available: Dictionary) -> bool:
	# Match _cells(region).all(...) without allocating a cell array per candidate.
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			if not available.has(Vector2i(x,y)): return false
	return true

static func _runs_contact_region(runs: Array, region: Rect2i) -> bool:
	for run in runs:
		var contact := 0
		for edge in run:
			if region.has_point(edge.a):
				contact += 1
				if contact >= 3: return true
	return false

static func _rectangle_floor_index(cells: Dictionary, bounds: Rect2i) -> Dictionary:
	# A summed-area table counts missing cells in any candidate rectangle.
	var stride := bounds.size.x+1
	var sums := PackedInt32Array()
	sums.resize(stride*(bounds.size.y+1))
	for y in range(1,bounds.size.y+1):
		var row_missing := 0
		for x in range(1,bounds.size.x+1):
			if not cells.has(bounds.position+Vector2i(x-1,y-1)): row_missing+=1
			sums[y*stride+x]=sums[(y-1)*stride+x]+row_missing
	return {"bounds":bounds,"stride":stride,"sums":sums}

static func _indexed_rectangle_available(region: Rect2i, index: Dictionary) -> bool:
	var bounds: Rect2i=index.bounds
	if not bounds.encloses(region): return false
	var low := region.position-bounds.position
	var high := region.end-bounds.position
	var stride: int=index.stride
	var sums: PackedInt32Array=index.sums
	return sums[high.y*stride+high.x]-sums[low.y*stride+high.x]-sums[high.y*stride+low.x]+sums[low.y*stride+low.x]==0

static func _rectangle_contact_count(a: Rect2i,b: Rect2i) -> int:
	# Callers reject intersecting rectangles. Count adjacent cell pairs along
	# shared borders, exactly as the original four-neighbor per-cell scan.
	var count := 0
	if a.end.x==b.position.x or a.position.x==b.end.x:
		count+=maxi(0,mini(a.end.y,b.end.y)-maxi(a.position.y,b.position.y))
	if a.end.y==b.position.y or a.position.y==b.end.y:
		count+=maxi(0,mini(a.end.x,b.end.x)-maxi(a.position.x,b.position.x))
	return count

func _sample_room_footprints(links: Array,type: String) -> bool:
	# Ordinary rooms take a sample-scale footprint attached to circulation.
	# Nested suites are packed together, not linked through an oversized parent.
	var original_links := links.duplicate(true)
	var pairs := {"deep":"inner", "archive":"storage"}
	for parent in pairs:
		var child: String = pairs[parent]
		if rooms.has(parent) and rooms.has(child) and String(rooms[child].get("parent","")) == parent:
			rooms[parent].cells.merge(rooms[child].cells)
			for c in rooms[child].cells: owners[c]=parent
	var retained: Array = []
	for link in original_links:
		if link.has("smoking"):
			retained.append(link); continue
		if (ADAPTER.is_hall(String(link[0])) or link[0] in ["entry","main","west","east"]) and (ADAPTER.is_hall(String(link[1])) or link[1] in ["entry","main","west","east"]):
			retained.append(link)
	var distances: Dictionary = {}
	for id in rooms:
		if ADAPTER.is_hall(String(id)) or id in ["entry","main","west","east"]: distances[id]=0
	for pass_index in rooms.size():
		for link in original_links:
			for side in 2:
				if distances.has(link[side]):
					var other: String = String(link[1-side])
					distances[other]=mini(int(distances.get(other,999)),int(distances[link[side]])+1)
	var order: Array = SAMPLE_SIZES.keys()
	order.sort_custom(func(a: String,b: String) -> bool: return int(distances.get(a,999)) < int(distances.get(b,999)))
	var completed: Dictionary = {}
	var bridge_rooms := {"B2":{"lounge":["east","rear"]},"C3":{"deep":["transition","rear"]},"V3":{"lounge":["main","service"],"meeting":["flank","hub"]}}
	var required_bridges: Dictionary = bridge_rooms.get(type,{})
	for id in order:
		if not rooms.has(id) or rooms[id].has("parent"): continue
		var room: Dictionary = rooms[id]
		var old: Dictionary = room.cells.duplicate()
		var bounds := _bounds(old)
		var floor_index := _rectangle_floor_index(old,bounds)
		var parents: Array = []
		for link in original_links:
			if not link.has(id): continue
			var other: String = String(link[1] if link[0] == id else link[0])
			if ADAPTER.is_hall(other) or other in ["main","west","east"] or completed.has(other): parents.append(other)
		if parents.is_empty():
			last_rejection="sample room parent " + String(id)
			return false
		var target: Vector2i = SAMPLE_SIZES.get(String(room.kind),SAMPLE_SIZES[id])
		var child: String = String(pairs.get(id,""))
		if not rooms.has(child) or String(rooms[child].get("parent","")) != id: child=""
		var best := Rect2i()
		var child_best := Rect2i()
		var chosen_parent := ""
		var best_score := INF
		# This room's cells/owners stay fixed throughout candidate evaluation.
		# Boundary sorting is identical for every candidate, so do it once.
		var bridge_contacts: Array = []
		for endpoint in required_bridges.get(id,[]):
			bridge_contacts.append(_runs(String(id),String(endpoint)))
		for parent in parents:
			var contacts := _runs(String(id),String(parent))
			for orientation in [target,Vector2i(target.y,target.x)]:
				var size := Vector2i(mini(orientation.x,bounds.size.x),mini(orientation.y,bounds.size.y))
				for y in range(bounds.position.y,bounds.end.y-size.y+1):
					for x in range(bounds.position.x,bounds.end.x-size.x+1):
						var candidate := Rect2i(Vector2i(x,y),size)
						if not _indexed_rectangle_available(candidate,floor_index): continue
						if not _runs_contact_region(contacts,candidate): continue
						if required_bridges.has(id):
							var bridges := true
							for endpoint_contacts in bridge_contacts:
								if not _runs_contact_region(endpoint_contacts,candidate): bridges=false
							if not bridges: continue
						var nested := Rect2i()
						if not child.is_empty():
							var child_size: Vector2i = Vector2i(12,10) if child == "inner" else Vector2i(7,6)
							for cy in range(bounds.position.y,bounds.end.y-child_size.y+1):
								for cx in range(bounds.position.x,bounds.end.x-child_size.x+1):
									var test := Rect2i(Vector2i(cx,cy),child_size)
									if candidate.intersects(test): continue
									if not _indexed_rectangle_available(test,floor_index): continue
									var shared := _rectangle_contact_count(test,candidate)
									if shared >= 3: nested=test; break
								if nested.has_area(): break
							if not nested.has_area(): continue
						var score := Vector2(candidate.get_center()).distance_squared_to(Vector2(bounds.get_center()))
						if score < best_score: best=candidate; child_best=nested; chosen_parent=parent; best_score=score
		if not best.has_area():
			last_rejection="sample footprint " + String(id)
			return false
		for c in old: owners.erase(c)
		room.cells={}
		for c in _cells(best): room.cells[c]=true; owners[c]=id
		room.bounds=_box(best)
		retained.append([id,chosen_parent])
		if required_bridges.has(id):
			for endpoint in required_bridges[id]:
				if endpoint != chosen_parent: retained.append([id,endpoint])
		completed[id]=true
		if not child.is_empty():
			rooms[child].cells={}
			for c in _cells(child_best): rooms[child].cells[c]=true; owners[c]=child
			rooms[child].bounds=_box(child_best)
			retained.append([id,child])
	links.clear()
	links.append_array(retained)
	return true
func _clear(room: Dictionary,extra: Dictionary) -> Dictionary:
	var clear: Dictionary = {}
	for c in room.cells:
		var valid := true
		for dx in range(-1,2):
			for dy in range(-1,2):
				var q: Vector2i = c+Vector2i(dx,dy)
				if not room.cells.has(q) or occupied.has(q) or extra.has(q): valid=false; break
			if not valid: break
		if valid: clear[c]=true
	return clear

func _room_clear(room: Dictionary,extra: Dictionary,base_clear: Dictionary={}) -> bool:
	var clear: Dictionary
	if base_clear.is_empty():
		clear=_clear(room,extra)
	else:
		# Occupied cells do not change while _place tries its candidates. Compute
		# room/occupied clearance once, then remove only the candidate's halo.
		# Keep this cache local to one placement, never across committed groups.
		clear=base_clear.duplicate()
		for cell in extra:
			for dx in range(-1,2):
				for dy in range(-1,2): clear.erase(cell+Vector2i(dx,dy))
	var approaches: Array[Vector2i] = []
	for d in doors:
		if d.glass or (d.a != room.id and d.b != room.id): continue
		var slot := int(d.start)+int(d.width)/2
		var c := Vector2i(int(d.line),slot) if d.vertical else Vector2i(slot,int(d.line))
		var direction := Vector2i.RIGHT if d.vertical else Vector2i.DOWN
		c = c+direction*2 if owners.get(c) == room.id else c-direction*3
		if not clear.has(c): return false
		approaches.append(c)
	if approaches.is_empty(): return false
	var seen: Dictionary = {approaches[0]:true}
	var queue: Array[Vector2i] = [approaches[0]]
	var head := 0
	while head < queue.size():
		var c := queue[head]; head+=1
		for direction in DIRS:
			var q: Vector2i = c+direction
			if clear.has(q) and not seen.has(q): seen[q]=true; queue.append(q)
	return approaches.all(func(c: Vector2i) -> bool: return seen.has(c))

func _template(name: String,turn: int) -> Array:
	var extras := {
		"sideboard":[{"kind":"文件柜","x":0,"y":0,"w":2,"h":1,"high":true,"facing":[0,1],"target":null}],
		"plant":[{"kind":"盆栽","x":0,"y":0,"w":1,"h":1,"high":false,"facing":null,"target":null}],
		"bin":[{"kind":"烟灰桶","x":0,"y":0,"w":1,"h":1,"high":false,"facing":null,"target":null}],
		"refreshments":[{"kind":"咖啡台面","x":0,"y":0,"w":2,"h":1,"high":false,"facing":[0,1],"target":null}],
		"water":[{"kind":"饮水机","x":0,"y":0,"w":1,"h":1,"high":true,"facing":[0,1],"target":null}]
	}
	var pieces: Array = (extras[name] if extras.has(name) else RULES.data.templates["counter" if name == "pantry_compact" else name]).duplicate(true)
	if name == "pantry_compact":
		var dining: Array = RULES.data.templates.dining.duplicate(true)
		dining[0].y=5; dining[1].y=4; dining[2].y=7
		for piece in dining:
			if piece.target != null: piece.target=int(piece.target)+pieces.size()
		pieces.append_array(dining)
	if compact and name == "dining":
		# Chairs sit beside the table, as in the approved pantry, rather than
		# consuming an extra empty tile on both sides of a ten-cell room.
		pieces[1].y=-1; pieces[2].y=2
	for i in turn:
		for p in pieces:
			var x := int(p.x); var w := int(p.w)
			p.x=-int(p.y)-int(p.h); p.y=x; p.w=int(p.h); p.h=w
			if p.facing != null: p.facing=[-int(p.facing[1]),int(p.facing[0])]
	var low := Vector2i(2147483647,2147483647)
	for p in pieces: low=Vector2i(mini(low.x,int(p.x)),mini(low.y,int(p.y)))
	for p in pieces: p.x=int(p.x)-low.x; p.y=int(p.y)-low.y
	return pieces

func _place(room: Dictionary,name: String,mode: String="center",turn_override: int=-1) -> bool:
	var bounds := _bounds(room.cells)
	var candidates: Array = []
	for turn in ([turn_override] if turn_override >= 0 else [0,1,2,3]):
		var pieces := _template(name,turn)
		if name == "reception": pieces=RULES.data.templates.reception.duplicate(true)
		var size := Vector2i.ZERO
		for p in pieces: size=Vector2i(maxi(size.x,int(p.x+p.w)),maxi(size.y,int(p.y+p.h)))
		if name == "reception":
			candidates.append({"x":bounds.position.x,"y":bounds.position.y,"pieces":pieces,"size":size,"turn":0,"score":0.0}); break
		for y in range(bounds.position.y+1,bounds.end.y-size.y):
			for x in range(bounds.position.x+1,bounds.end.x-size.x):
				if mode == "rows" and not groups.is_empty():
					var previous: Dictionary = groups.back()
					if (turn % 2 == 0 and x != int(previous.x)) or (turn % 2 == 1 and y != int(previous.y)): continue
				# Compact combat rooms fit complete banks around doors and cover rather
				# than reserving unused lattice slots. Physical clearance is checked below.
				if name == "workstation" and not compact and (posmod(x-bounds.position.x-1,size.x+3) != 0 or posmod(y-bounds.position.y-1,size.y+3) != 0): continue
				var wall := mini(mini(x-bounds.position.x,y-bounds.position.y),mini(bounds.end.x-x-size.x,bounds.end.y-y-size.y))
				var center := Vector2(x,y)+Vector2(size)*.5
				var distance := center.distance_to(Vector2(bounds.get_center()))
				var score := (wall*100.0+distance if mode == "wall" else (y*2.0+x*.1 if mode == "bank" else distance))+random.randf()*.2
				if mode == "wall":
					var facing_valid := true
					for p in pieces:
						if p.facing != null and (p.high or p.target == null):
							var facing := Vector2(float(p.facing[0]),float(p.facing[1]))
							if (Vector2(bounds.get_center())-Vector2(x+float(p.x)+float(p.w)*.5,y+float(p.y)+float(p.h)*.5)).dot(facing)<0: facing_valid=false; break
					if not facing_valid: continue
				candidates.append({"x":x,"y":y,"pieces":pieces,"size":size,"turn":turn,"score":score})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.score < b.score)
	var base_clear:=_clear(room,{})
	for candidate in candidates:
		var extra: Dictionary = {}
		var valid := true
		for p in candidate.pieces:
			var region := Rect2i(int(candidate.x+p.x),int(candidate.y+p.y),int(p.w),int(p.h))
			if room.id == "entry" and name != "reception" and region.intersects(Rect2i(bounds.position+Vector2i(5,0),Vector2i(4,bounds.size.y))):
				valid=false; break
			for c in _cells(region):
				if owners.get(c) != room.id or occupied.has(c) or door_buffer.has(c): valid=false; break
				extra[c]=true
			if not valid: break
			if name != "reception":
				for c in _cells(region.grow(2)):
					if occupied.has(c): valid=false; break
			if not valid: break
		if not valid or not _room_clear(room,extra,base_clear): continue
		var id := "%s:%d" % [room.id,groups.size()]
		for i in candidate.pieces.size():
			var p: Dictionary = candidate.pieces[i].duplicate(true)
			p.x=int(p.x)+int(candidate.x); p.y=int(p.y)+int(candidate.y)
			p["room"]=room.id; p["group"]=id; p["member"]=i
			if p.target != null:
				var target: Dictionary = candidate.pieces[int(p.target)]
				p.target={"x":float(candidate.x+target.x)+float(target.w)*.5,"y":float(candidate.y+target.y)+float(target.h)*.5}
			furniture.append(p)
		occupied.merge(extra)
		groups.append({"id":id,"room":room.id,"template":name,"x":candidate.x,"y":candidate.y,"w":candidate.size.x,"h":candidate.size.y,"turn":candidate.turn,"members":candidate.pieces.size()})
		return true
	last_rejection = "furniture " + String(room.id) + "/" + name
	return false

func _furnish() -> bool:
	for room in rooms.values():
		if ADAPTER.is_hall(String(room.id)): continue
		if room.id == "entry":
			if not _place(room,"reception"): return false
		elif room.id in ["main","west","east"]:
			var turn := random.randi_range(0,1)
			if not _place(room,"workstation","bank",turn): return false
			for i in range(1,maxi(2,room.cells.size()/(48 if compact else 85))):
				if not _place(room,"workstation","bank",turn): break
			if not _place(room,"shelf","wall"): return false
			if compact:
				# A couple of cabinet islands interrupt empty cross-room sightlines.
				# Every placement still passes the same three-cell route validation.
				for i in 2: _place(room,"shelf","center")
		elif room.kind in ["meeting","training"]:
			if not _place(room,"conference"): return false
			_place(room,"shelf","wall")
		elif room.kind in ["archive","server"]:
			if not _place(room,room.kind): return false
			var first: Dictionary = groups.back()
			_place(room,room.kind,"rows",int(first.turn))
		elif room.kind == "lounge":
			if not _place(room,"lounge"): return false
			_place(room,"shelf","wall")
		elif room.kind == "pantry":
			if compact:
				if not _place(room,"pantry_compact","wall"): return false
			elif not _place(room,"counter","wall") or not _place(room,"dining"): return false
		elif room.kind in ["print","storage","smoking"]:
			if not _place(room,room.kind,"wall"): return false
		else:
			if not _place(room,"desk"): return false
			if not _place(room,"shelf","wall") and room.id == "inner": return false
			if room.id == "deep": _place(room,"lounge")
	if enhanced_dressing:
		# Decoration must not advance topology randomness (including final mirroring).
		var topology_random_state := random.state
		for room in rooms.values():
			if ADAPTER.is_hall(String(room.id)): continue
			# Same footprint, door-buffer and three-cell route checks as core groups.
			if room.id in ["main","west","east"]:
				_place_extra(room,"print")
				for i in 2: _place_extra(room,"sideboard")
			elif room.kind not in ["server","archive","storage","smoking"] and room.id != "entry":
				_place_extra(room,"sideboard")
			elif room.kind in ["archive","storage"]:
				_place_extra(room,"shelf")
			if room.kind not in ["server","storage","archive"]:
				for i in (2 if room.id in ["entry","main","west","east"] else 1):
					_place_extra(room,"plant")
			_place_extra(room,"bin")
			if room.id in ["entry","main","west","east"] or room.kind in ["pantry","lounge"]: _place_extra(room,"water")
			if room.kind in ["pantry","lounge"]: _place_extra(room,"refreshments")
			if room.id in ["main","west","east"]:
				_place_extra(room,"plant")
				_place_extra(room,"sideboard")
		random.state=topology_random_state
	return true

func _place_extra(room: Dictionary, template: String) -> void:
	var old_occupied := occupied.duplicate()
	var old_items := furniture.size()
	var old_groups := groups.size()
	var old_rejection := last_rejection
	if _place(room,template,"wall"):
		var plan: Array = []
		for item in furniture:
			if item.room != room.id: continue
			var kind: String = "plant" if item.kind == "盆栽" else ADAPTER.FURNITURE[item.kind]
			var yaw := 0.0
			if item.facing != null: yaw=atan2(-float(item.facing[0]),float(item.facing[1]))
			elif float(item.h)>float(item.w): yaw=PI*.5
			plan.append({"office_kind":kind,"position":Vector2(float(item.x)+float(item.w)*.5-.5,float(item.y)+float(item.h)*.5-.5)*32.0,"rotation":yaw,"collision_rect":PLANNER._office_rotated_rect(ADAPTER.CATALOG.footprint(kind),yaw)})
		var entrances: Array = []
		for door in doors:
			if door.glass or (door.a != room.id and door.b != room.id): continue
			var inside := Vector2i(int(door.line)-1,int(door.start)+int(door.width)/2) if door.vertical else Vector2i(int(door.start)+int(door.width)/2,int(door.line)-1)
			var step := Vector2i.RIGHT if door.vertical else Vector2i.DOWN
			if owners.get(inside) != room.id: inside+=step; step=-step
			entrances.append({"inside_cell":inside,"outward":step,"opening_cells":int(door.width)})
		if PLANNER._office_wide_routes(room.cells.keys(),plan,entrances,32.0): return
	# Optional dressing may be omitted, never the approved core group or passage.
	furniture.resize(old_items)
	groups.resize(old_groups)
	occupied=old_occupied
	last_rejection=old_rejection

func _decor() -> Array:
	var fixtures: Array = []
	for room in rooms.values():
		if not ADAPTER.is_hall(String(room.id)) and room.id != "smoking": continue
		var selected: Array[Vector2i] = []
		for c in room.cells:
			if selected.size() >= mini(6,maxi(2,room.cells.size()/60)): break
			for direction in DIRS:
				if owners.get(c+direction) == room.id: continue
				var nearby := false
				for d in doors:
					for raw in d.cells:
						var p := ADAPTER.cell(raw)
						if absi(p.x-c.x)+absi(p.y-c.y) <= 2: nearby=true; break
					if nearby: break
				for p in selected:
					if absi(p.x-c.x)+absi(p.y-c.y)<7: nearby=true; break
				if nearby: continue
				var kind: String = ["告示牌","消防箱","管线","门牌"][selected.size()%4]
				if room.id == "smoking": kind="通风设施" if selected.is_empty() else "吸烟标识"
				fixtures.append({"room":room.id,"kind":kind,"x":float(c.x)+(.5 if direction.x==0 else (1.0 if direction.x>0 else 0.0)),"y":float(c.y)+(.5 if direction.y==0 else (1.0 if direction.y>0 else 0.0)),"dx":direction.x,"dy":direction.y,"inside":_text(c),"outside":_text(c+direction),"wallMounted":true,"collision":false})
				selected.append(c); break
	return fixtures

static func _mirror(data: Dictionary,axis: int) -> void:
	for room in data.rooms:
		var cells: Array = []
		for raw in room.cells:
			var c := ADAPTER.cell(raw); c.x=axis-1-c.x; cells.append(_text(c))
		room.cells=cells; room.bounds.x=axis-int(room.bounds.x)-int(room.bounds.w)
	for id in data.anchors:
		var c := ADAPTER.cell(data.anchors[id]); c.x=axis-1-c.x; data.anchors[id]=_text(c)
	for d in data.doors:
		var cells: Array = []
		for raw in d.cells:
			var c := ADAPTER.cell(raw); c.x=axis-1-c.x; cells.append(_text(c))
		d.cells=cells
		if d.vertical: d.line=axis-int(d.line)
		else: d.start=axis-int(d.start)-int(d.width)
	for item in data.furniture:
		item.x=axis-int(item.x)-int(item.w)
		if item.facing != null: item.facing[0]=-int(item.facing[0])
		if item.target != null: item.target.x=axis-float(item.target.x)
	for group in data.groups:
		group.x=axis-int(group.x)-int(group.w); group["mirror"]=true
	for segment in data.corridorSegments: segment.x=axis-int(segment.x)-int(segment.w)
	for fixture in data.decor:
		fixture.x=axis-float(fixture.x); fixture.dx=-int(fixture.dx)
		for key in ["inside","outside"]:
			var c := ADAPTER.cell(fixture[key]); c.x=axis-1-c.x; fixture[key]=_text(c)
