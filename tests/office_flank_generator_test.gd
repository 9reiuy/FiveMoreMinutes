extends SceneTree
const GENERATOR = preload("res://scripts/dream/preview/office_flank_generator.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var dimensions: Dictionary = {}
	var signatures: Dictionary = {}
	var topologies: Dictionary = {}
	for value in range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var layout := GENERATOR.generate(rng)
		if layout.is_empty():
			failures += 1
			print("EMPTY seed=", value)
			continue
		dimensions[str(layout.preview_dimensions)] = true
		if not topologies.has(layout.preview_topology):
			topologies[layout.preview_topology] = value
		signatures[str(layout.door_edges)] = true
		rng.seed = value
		if str(layout) != str(GENERATOR.generate(rng)):
			failures += 1
		var reached: Dictionary = {layout.spawn_room_id: true}
		var queue: Array = [layout.spawn_room_id]
		while not queue.is_empty():
			var id: int = queue.pop_front()
			for neighbor in layout.rooms[id].neighbors:
				if not reached.has(neighbor):
					reached[neighbor] = true
					queue.append(neighbor)
		if reached.size() != layout.rooms.size() or layout.connections.size() - layout.rooms.size() + 1 < 3:
			failures += 1
		for room in layout.rooms:
			if bool(room.authored_sample):
				failures += 1
		for edge in layout.door_edges.values():
			var axis := String(edge.axis)
			for slot in range(int(edge.opening_start), int(edge.opening_end)):
				var first := Vector2i(int(edge.x) - 1, slot) if axis == "V" else Vector2i(slot, int(edge.y) - 1)
				var second := first + (Vector2i.RIGHT if axis == "V" else Vector2i.DOWN)
				if not layout.floor_cells.has(first):
					failures += 1
				if int(edge.region_b_id) >= 0 and not layout.floor_cells.has(second):
					failures += 1
				var key := "V:%d:%d" % [edge.x, slot] if axis == "V" else "H:%d:%d" % [slot, edge.y]
				if layout.wall_edges.has(key):
					failures += 1
	print("FLANK topology examples=", topologies)
	print("FLANK seeds=100 dimensions=", dimensions.size(), " door_variants=", signatures.size(), " failures=", failures)
	quit(1 if failures else 0)
