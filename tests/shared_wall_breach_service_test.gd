extends SceneTree
## Direct service regression on the real generated office floor; headless only.
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	var world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.set_meta(&"test_floor_reflections_disabled", true)
	root.add_child(world)
	await process_frame
	check(world.regenerate(90210), "real office floor generates")
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var eligible: Array[String] = []
	for key in world.wall_edges:
		if world.SHARED_WALL_BREACH.wall_for_key(world, key) == null: continue
		var candidate_sides: Array = world._edge_side_cells(world.wall_edges[key])
		var candidate_a: int = int(world.room_cells.get(candidate_sides[0], -1))
		var candidate_b: int = int(world.room_cells.get(candidate_sides[1], -1))
		if candidate_a >= 0 and candidate_b >= 0 and candidate_a != candidate_b and world.floor_cells.has(candidate_sides[0]) and world.floor_cells.has(candidate_sides[1]): eligible.append(key)
	check(eligible.size() >= 2, "real floor has multiple eligible shared solid walls")
	if eligible.size() < 2: world.free(); quit(1); return
	var key: String = eligible[0]
	var edge: Dictionary = world.wall_edges[key].duplicate(true)
	var sides: Array = world._edge_side_cells(edge)
	var a: int = int(world.room_cells[sides[0]])
	var b: int = int(world.room_cells[sides[1]])
	var from: Vector2 = Vector2(sides[0]) * world.CELL_PIXELS
	var to: Vector2 = Vector2(sides[1]) * world.CELL_PIXELS
	var walls_before: int = world.wall_edges.size()
	var bodies_before: int = world.collision_root.get_child_count()
	var doors_before: Dictionary = world.door_edges.duplicate(true)
	var query: Array[String] = world.query_dash_breakable_walls(from, to, 1.0)
	check(query.has(key), "actual swept segment finds a shared wall")
	check(world.wall_edges.size() == walls_before and world.collision_root.get_child_count() == bodies_before and world.broken_shared_walls.is_empty(), "preview does not mutate topology, collision or durable state")
	check(world.query_dash_breakable_walls(from, from, 8.0).is_empty(), "zero actual travel cannot destroy walls")
	var exterior_checked := 0
	for outside_key in world.wall_edges.keys():
		var outside_edge: Dictionary = world.wall_edges[outside_key]
		var outside_sides: Array = world._edge_side_cells(outside_edge)
		if world.floor_cells.has(outside_sides[0]) and world.floor_cells.has(outside_sides[1]): continue
		if world.SHARED_WALL_BREACH.wall_for_key(world, outside_key) == null: continue
		check(world._commit_dash_wall_breaches([outside_key], world.get_current_floor_token(), to - from) == 1, "actual exterior masonry wall is destructible")
		var clean_graph := true
		for room in world.rooms:
			clean_graph = clean_graph and not room.connections.has(-1) and not room.connections.has(int(room.id))
		check(world.broken_shared_walls.has(outside_key) and not world.dash_breach_links.has(outside_key) and clean_graph, "exterior opening never creates void or self room adjacency")
		exterior_checked += 1
		if exterior_checked == 2: break
	check(exterior_checked == 2, "real generated floor exposes multiple breakable exterior walls")
	check(world._commit_dash_wall_breaches([key], world.get_current_floor_token() - 1, to - from) == 0, "stale floor token cannot commit")
	var fixture := Node3D.new()
	fixture.set_meta(&"wall_fixture_edge", edge)
	world.floor_root.add_child(fixture)
	world.room_visibility._wall_fixtures.append(fixture)
	var fixture_ref: WeakRef = weakref(fixture)
	check(world._commit_dash_wall_breaches([key, key], world.get_current_floor_token(), to - from) == 1, "duplicate keys commit one actual destruction")
	check(fixture_ref.get_ref() == null, "room-root dressing is removed with its supporting wall")
	check(world._commit_dash_wall_breaches([key], world.get_current_floor_token(), to - from) == 0, "repeat commit is idempotent")
	check(not world.wall_edges.has(key) and not world.internal_wall_edges.has(key) and world.edge_states[key] == &"OPEN", "all authoritative edge maps agree on the opening")
	check(world.broken_shared_walls.has(key) and world.dash_breach_links.has(key), "opening is recorded in both floor-owned maps")
	var blockers := 0
	for body in world.collision_root.get_children():
		if String(body.get_meta(&"generated_wall_edge", "")) == key or String(body.get_meta(&"generated_air_wall_edge", "")) == key: blockers += 1
	check(blockers == 0 and world.wall_root.get_node_or_null("Wall_" + key.replace(":", "_")) == null, "visual, solid blocker and actor air wall are removed")
	check(world._can_cross_floor_edge(sides[0], sides[1]) and world._current_floor_path_adjacency()[sides[0]].has(sides[1]), "physical opening agrees with cached floor navigation")
	check(world.are_rooms_openly_connected(a, b) and world._next_route_room(a, b) == b, "ordinary rooms have a real open graph route through the breach")
	check(world.door_edges == doors_before, "breaking a shared wall preserves authored door and lock metadata")
	var employee = load("res://scripts/entities/employee_enemy.gd").new()
	employee.position = from
	employee.set_meta(&"dream_room_id", a)
	employee.held_weapon_id = "pistol"
	var plan: Dictionary = world.get_employee_door_plan(employee, b)
	check(not plan.is_empty() and int(plan.door_id) == -1 and String(plan.door_edge_key) == key, "enemy plan uses the physical breach without inventing a door")
	check(world.can_employee_hear_gunshot(employee, b), "adjacent armed enemy can hear through the new graph route")
	employee.free()
	var batches = world.wall_root.get_node_or_null("WallShadowBatches")
	check(batches == null or not batches.edge_instances.has(key), "removed wall has no copied batch caster")
	if world.office_wall_cutaway != null:
		var invalid_neighbors := 0
		for record in world.office_wall_cutaway.records.values():
			for property in ["aligned_left", "aligned_right", "perp_left", "perp_right"]:
				for neighbor in record[property]:
					if not is_instance_valid(neighbor): invalid_neighbors += 1
		check(invalid_neighbors == 0, "cutaway adjacency contains no removed wall references")
	# A pending actual-segment request must not run against a staged/rolled-back floor.
	var pending_key: String = eligible[1]
	var pending_sides: Array = world._edge_side_cells(world.wall_edges[pending_key])
	world.queue_dash_wall_breaches(Vector2(pending_sides[0]) * world.CELL_PIXELS, Vector2(pending_sides[1]) * world.CELL_PIXELS, 1.0, world.get_current_floor_token())
	check(not world._pending_dash_wall_breaches.is_empty(), "actual movement request queues a deferred commit")
	var glass_from := Vector2.INF
	var glass_to := Vector2.INF
	for glass_edge: Dictionary in world.glass_wall_edges.values():
		var center: Vector2 = world._edge_gameplay_position(glass_edge)
		var normal := Vector2.DOWN if String(glass_edge.axis) == "H" else Vector2.RIGHT
		var start := center - normal * 2.0
		var finish := center + normal * 2.0
		if world.query_dash_breakable_walls(start, finish, 1.0).is_empty() and not world.DASH_GLASS_BREAK.query(world, start, finish, 1.0).is_empty():
			glass_from = start
			glass_to = finish
			break
	check(glass_from.is_finite(), "real floor exposes a glass-only swept segment")
	if glass_from.is_finite():
		world.queue_dash_wall_breaches(glass_from, glass_to, 1.0, world.get_current_floor_token())
		var glass_count: int = world._pending_dash_glass_breaks.size()
		world.queue_dash_wall_breaches(glass_from, glass_to, 1.0, world.get_current_floor_token())
		check(glass_count > 0 and world._pending_dash_glass_breaks.size() == glass_count, "glass-only pending requests deduplicate real owners")
	world._stash_current_floor_for_rollback()
	world._reset_layout_data()
	check(world.broken_shared_walls.is_empty() and world.dash_breach_links.is_empty(), "new layout attempt starts with no old breaches")
	await world._rollback_failed_transition(world.transition_generation_token, world.floor_index)
	await process_frame
	check(world.broken_shared_walls.has(key) and world.dash_breach_links.has(key) and not world.wall_edges.has(key), "failed floor transition restores the old durable opening")
	check(world.wall_edges.has(pending_key) and world._pending_dash_wall_breaches.is_empty(), "staged transition invalidates pending destruction callbacks")
	check(world._pending_dash_glass_breaks.is_empty(), "staged transition also clears all pending glass owners")
	if glass_from.is_finite():
		check(not world.DASH_GLASS_BREAK.query(world, glass_from, glass_to, 1.0).is_empty(), "rollback preserves glass targeted only by a stale pending request")
	check(world.are_rooms_openly_connected(a, b) and world._next_route_room(a, b) == b, "restored floor retains breach routing")
	if eligible.size() >= 3:
		var same_key: String = eligible[2]
		var same_sides: Array = world._edge_side_cells(world.wall_edges[same_key])
		var original_room: int = int(world.room_cells[same_sides[1]])
		world.room_cells[same_sides[1]] = world.room_cells[same_sides[0]]
		check(world._commit_dash_wall_breaches([same_key], world.get_current_floor_token(), to - from) == 1 and not world.dash_breach_links.has(same_key), "same-room solid wall breaks without fabricating a room link")
		world.room_cells[same_sides[1]] = original_room
	world.floor_transition_in_progress = true
	check(world._commit_dash_wall_breaches([pending_key], world.get_current_floor_token(), to - from) == 0, "floor transition boundary rejects destruction")
	world.floor_transition_in_progress = false
	world.queue_dash_wall_breaches(Vector2(pending_sides[0]) * world.CELL_PIXELS, Vector2(pending_sides[1]) * world.CELL_PIXELS, 1.0, world.get_current_floor_token())
	check(world.wall_edges.has(pending_key), "queuing actual movement leaves physics intact until deferred commit")
	await process_frame
	check(not world.wall_edges.has(pending_key) and world.broken_shared_walls.has(pending_key), "deferred actual movement commits the new opening")
	if glass_from.is_finite():
		world.queue_dash_wall_breaches(glass_from, glass_to, 1.0, world.get_current_floor_token())
		check(world._pending_dash_wall_breaches.is_empty() and not world._pending_dash_glass_breaks.is_empty(), "glass-only movement schedules a flush without masonry keys")
		await process_frame
		check(world.DASH_GLASS_BREAK.query(world, glass_from, glass_to, 1.0).is_empty() and world._pending_dash_glass_breaks.is_empty(), "glass-only deferred flush breaks the owner and clears pending state")
	check(world.regenerate(90211) and world.broken_shared_walls.is_empty() and world.dash_breach_links.is_empty(), "successful regeneration does not inherit prior floor openings")
	world._reset_layout_data()
	check(world.broken_shared_walls.is_empty() and world.dash_breach_links.is_empty(), "retry/reset clears durable openings")
	world.free()
	await process_frame
	print("SHARED_WALL_BREACH_SERVICE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
