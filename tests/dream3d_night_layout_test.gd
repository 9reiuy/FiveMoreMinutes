extends SceneTree
const GENERATOR = preload("res://scripts/dream/dream_3d_random_dungeon.gd")
func _init() -> void:
	var failures := 0
	var counts := {&"rectangle":0, &"irregular":0, &"courtyard":0}
	var multidoor_small := 0
	for seed in range(41001, 41031):
		var world = GENERATOR.new()
		world.generate_on_ready = false
		var success: bool = world.generate_layout_only(seed)
		if not success:
			print("INVALID DETAILS ",world._validate_layout())
			failures += 1
			world.free()
			break
		for room in world.rooms:
			if room.is_large:
				counts[room.shape] += 1
			elif world._get_room_degree(room.id) >= 2:
				multidoor_small += 1
			if room.usable_cells.size() != room.grid_rect.get_area() and not room.is_large:
				failures += 1
			if room.shape == &"courtyard":
				var hole: Rect2i = room.void_rect
				# Both paths around the core exist and never enter the solid center.
				for y in range(hole.position.y-1,hole.end.y+1):
					for x in [hole.position.x-1,hole.end.x]:
						if not world.floor_cells.has(Vector2i(x,y)): failures += 1
				for x in range(hole.position.x-1,hole.end.x+1):
					for y in [hole.position.y-1,hole.end.y]:
						if not world.floor_cells.has(Vector2i(x,y)): failures += 1
		if world._get_room_degree(world.boss_room_id) != 1: failures += 1
		if world.min_room_width != 10 or world.min_room_height != 10 or world.max_partition_depth != 4: failures += 1
		var signature: String = world.get_layout_signature()
		if not world.generate_layout_only(seed) or signature != world.get_layout_signature(): failures += 1
		print("LAYOUT seed=",seed," floor=",world.floor_cells.size()," edges=",world.connections.size()," attempt=",world.last_validation_report.layout_attempt)
		world.free()
	if counts.irregular < 3 or counts.courtyard < 3 or counts.rectangle < 3 or multidoor_small == 0: failures += 1
	print("NIGHT LAYOUT shapes=",counts," small_multi=",multidoor_small," failures=",failures)
	quit(1 if failures else 0)
