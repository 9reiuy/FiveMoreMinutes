extends SceneTree

const PLANNER = preload("res://scripts/dream/otxo_room_layout_planner.gd")

func _initialize() -> void:
	var cells: Array[Vector2i] = []
	for x in range(21):
		for y in range(13):
			cells.append(Vector2i(x, y))
	var doors := [{"inside_cell": Vector2i(0, 6), "outward": Vector2i.LEFT}, {"inside_cell": Vector2i(20, 6), "outward": Vector2i.RIGHT}]
	var failures := 0
	for width in [96.0, 94.0, 64.0]:
		var upper_end: float = 192 - width * .5
		var lower_start: float = 192 + width * .5
		var props := [{"position": Vector2.ZERO, "collision_rect": Rect2(-16, -16, 672, upper_end + 16)}, {"position": Vector2.ZERO, "collision_rect": Rect2(-16, lower_start, 672, 400 - lower_start)}]
		var result: bool = PLANNER._office_wide_routes(cells, props, doors, 32)
		if result != (width >= 96):
			failures += 1
			push_error("Main route width %.1f incorrectly classified" % width)
	var edge_doors := [{"inside_cell": Vector2i(0, 0), "outward": Vector2i.LEFT}, {"inside_cell": Vector2i(20, 0), "outward": Vector2i.RIGHT}]
	var edge_props := [{"position": Vector2.ZERO, "collision_rect": Rect2(96, 60, 480, 340)}]
	if PLANNER._office_wide_routes(cells, edge_props, edge_doors, 32):
		failures += 1
		push_error("76px floor-edge bypass must not qualify as96px mainroute")
	var table := {"office_kind": "table", "position": Vector2(320, 192), "collision_rect": Rect2(-72, -21, 144, 42)}
	if not PLANNER._office_group_bypasses("conference", cells, [table], 32):
		failures += 1
		push_error("Unobstructed table has two64px bypasses")
	var boxed := [table, {"office_kind": "cabinet", "position": Vector2.ZERO, "collision_rect": Rect2(190, 150, 50, 84)}, {"office_kind": "cabinet", "position": Vector2.ZERO, "collision_rect": Rect2(248, 130, 144, 30)}, {"office_kind": "cabinet", "position": Vector2.ZERO, "collision_rect": Rect2(248, 224, 144, 30)}]
	if PLANNER._office_group_bypasses("conference", cells, boxed, 32):
		failures += 1
		push_error("Only one free table side is insufficient for opposite bypasses")
	print("RANDOM ROUTE WIDTH failures=", failures)
	quit(1 if failures else 0)
