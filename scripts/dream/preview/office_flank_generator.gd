extends RefCounted
## Experimental only: stochastic functional rooms around a circulation loop.
## Uses the production edge contract, never the authored-sample gameplay flag.
const PACK = preload("res://scripts/dream/office_level_pack_generator.gd")
const LEGACY = preload("res://scripts/dream/dream_otxo_mansion_generator.gd")
const THEME = preload("res://scripts/dream/dream_room_environment_theme.gd")
const SEEDS := [1, 2, 0, 5, 14]

static func generate(rng: RandomNumberGenerator, _options: Dictionary = {}) -> Dictionary:
	for attempt in 16:
		var candidate := _attempt(rng)
		if not candidate.is_empty():
			candidate["preview_attempts"] = attempt + 1
			return candidate
	return {}

static func _attempt(rng: RandomNumberGenerator) -> Dictionary:
	var widths: Array[int] = [rng.randi_range(14, 17), rng.randi_range(14, 17), rng.randi_range(14, 17)]
	var heights: Array[int] = [rng.randi_range(12, 14), rng.randi_range(14, 16), rng.randi_range(12, 14)]
	var width := widths[0] + widths[1] + widths[2] + 8
	var height := heights[0] + heights[1] + heights[2] + 8
	var origin := Vector2i(-width / 2, -height / 2)
	var xs: Array[int] = [origin.x, origin.x + widths[0] + 4, origin.x + widths[0] + widths[1] + 8]
	var ys: Array[int] = [origin.y, origin.y + heights[0] + 4, origin.y + heights[0] + heights[1] + 8]
	var roles := ["archive", "conference_large", "server", "open_office", "pantry", "manager", "lounge", "elevator_lobby", "restroom"]
	# Exchange non-entry roles while keeping the larger open office in the middle row.
	if rng.randf() < 0.5:
		roles[0] = "server"
		roles[2] = "archive"
	if rng.randf() < 0.5:
		roles[3] = "manager"
		roles[5] = "open_office"
	var variant := rng.randi_range(0, 4)
	var omitted: Array = []
	match variant:
		1: omitted = [[0, 2, 6, 8][rng.randi_range(0, 3)]]
		2: omitted = [0, 2]
		3: omitted = [0, 8] if rng.randf() < 0.5 else [2, 6]
		4: omitted = [4]
	var specs: Array[Dictionary] = []
	for row in 3:
		for col in 3:
			var index := row * 3 + col
			if omitted.has(index):
				continue
			specs.append({"kind": roles[index], "key": "room_%d" % index,
				"rect": Rect2i(xs[col], ys[row], widths[col], heights[row]),
				"elevator_reception": index == 7})
	var lift_id := -1
	for i in specs.size():
		if specs[i].kind == "elevator_lobby":
			lift_id = i
	for row in 2:
		specs.append({"kind": "corridor", "key": "spine_%d" % row,
			"rect": Rect2i(origin.x, ys[row] + heights[row], width, 4)})
	for row in 3:
		for col in 2:
			specs.append({"kind": "corridor", "key": "flank_%d_%d" % [row, col],
				"rect": Rect2i(xs[col] + widths[col], ys[row], 4, heights[row])})
	var boxes: Array = []
	for spec in specs:
		boxes.append({"grid_rect": spec.rect})
	var boundaries := LEGACY._find_shared_boundaries(boxes)
	var links: Array = []
	var room_frontages: Dictionary = {}
	for b in boundaries:
		var a := int(b.room_a)
		var c := int(b.room_b)
		if specs[a].kind == "corridor" and specs[c].kind == "corridor":
			# A four-cell corridor junction must stay fully open.
			links.append([specs[a].key, specs[c].key, int(b.span_start), "open"])
		else:
			var room_id := a if specs[a].kind != "corridor" else c
			if not room_frontages.has(room_id):
				room_frontages[room_id] = []
			room_frontages[room_id].append(b)
	for room_id in room_frontages:
		var candidates: Array = room_frontages[room_id]
		# Seeded Fisher-Yates: no dependency on the global random source.
		for i in range(candidates.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var temporary: Dictionary = candidates[i]
			candidates[i] = candidates[j]
			candidates[j] = temporary
		var count := mini(candidates.size(), 2 + (1 if rng.randf() < 0.3 else 0))
		if int(room_id) == lift_id:
			count = 1
			candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.axis) == "H" and String(b.axis) != "H")
		for i in count:
			var b: Dictionary = candidates[i]
			var a := int(b.room_a)
			var c := int(b.room_b)
			var kind: String = specs[int(room_id)].kind
			var style := "double" if kind == "conference_large" or int(room_id) == lift_id else "single"
			if kind == "open_office":
				style = "open"
			var opening := 4 if style == "open" else (3 if style == "double" else 2)
			var start := rng.randi_range(int(b.span_start) + 2, int(b.span_end) - opening - 2)
			links.append([specs[a].key, specs[c].key, start, style])
	# Every open-office frontage is physically open, so its graph must agree.
	for b in boundaries:
		var a := int(b.room_a)
		var c := int(b.room_b)
		if specs[a].kind != "open_office" and specs[c].kind != "open_office":
			continue
		var found := false
		for link in links:
			if link[0] == specs[a].key and link[1] == specs[c].key:
				found = true
		if not found:
			links.append([specs[a].key, specs[c].key, int(b.span_start) + 2, "open"])
	var layout: Dictionary = PACK.build_from_specs(rng, &"rectangle", specs, links)
	if layout.is_empty():
		return {}
	# The pack's authored-link input is only an edge assembler here, not sample identity.
	for room in layout.rooms:
		room.authored_sample = false
		room.office_visual_style = THEME.style_for_room(room)
		room["preview_flank_layout"] = true
	layout["preview_generator"] = "office_flank_v1"
	layout["preview_dimensions"] = Vector2i(width, height)
	layout["preview_topology"] = ["ring", "notched", "twin_notch", "diagonal_notches", "courtyard"][variant]
	return layout
