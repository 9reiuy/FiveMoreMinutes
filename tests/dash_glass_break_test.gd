extends SceneTree
## Actual generated glass owners, proxies and their already-connected callbacks.
const GLASS := preload("res://scripts/dream/dash_glass_break.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
	print("PASS " if ok else "FAIL ", label)
func segment(owner: Node3D) -> Array[Vector2]:
	var shape: CollisionShape2D = owner.collision_shape_2d
	var size: Vector2 = shape.shape.size
	var normal := Vector2.RIGHT if size.x < size.y else Vector2.DOWN
	var heading := shape.global_transform.basis_xform(normal).normalized()
	var reach := minf(size.x, size.y) * .5 + 6.0
	return [shape.global_position - heading * reach, shape.global_position + heading * reach]
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
	var exterior: Node3D
	var continuous: Node3D
	for node in get_nodes_in_group(&"breakable_glass_windows"):
		if not world.wall_root.is_ancestor_of(node): continue
		if bool(node.exterior) and exterior == null: exterior = node
		if node.get_script().resource_path == "res://scripts/dream/continuous_office_glass.gd" and continuous == null:
			var sides: Array = world._edge_side_cells(node.edge_data)
			var a: int = int(world.room_cells.get(sides[0], -1))
			var b: int = int(world.room_cells.get(sides[1], -1))
			if a >= 0 and b >= 0 and a != b and world.floor_cells.has(sides[0]) and world.floor_cells.has(sides[1]): continuous = node
	check(exterior != null, "real facade has an exterior breakable pane")
	check(continuous != null, "native office has continuous-glass cell owner")
	if exterior == null or continuous == null: world.free(); quit(1); return
	for owner in [continuous, exterior]:
		var label := "exterior" if bool(owner.exterior) else "native cell"
		var path := segment(owner)
		var token: int = world.get_current_floor_token()
		var edge_key: String = owner.edge_key
		var original_edges: Dictionary = world.edge_states.duplicate(true)
		var original_walls: Dictionary = world.wall_edges.duplicate(true)
		var original_health: float = owner.current_health
		var collision: StaticBody2D = owner.collision_body_2d
		var layers: int = collision.collision_layer
		var node_count: int = world.floor_root.get_child_count()
		var targets := GLASS.query(world, path[0], path[1], 2.0)
		check(targets.has(owner), label + " real swept collision finds correct 3D owner")
		check(owner.current_health == original_health and not owner.is_shattered and collision.collision_layer == layers and world.edge_states == original_edges and world.wall_edges == original_walls and world.floor_root.get_child_count() == node_count, label + " query changes no health, collision, graph or effects")
		check(GLASS.query(world, path[0], path[0], 8.0).is_empty(), label + " zero travelled segment is pure and empty")
		var offset := (path[1] - path[0]).normalized().orthogonal() * 24.0
		check(not GLASS.query(world, path[0] + offset, path[1] + offset, 2.0).has(owner), label + " body-radius sweep excludes nearby untouched pane")
		check(GLASS.commit(world, targets, token - 1, Vector2.RIGHT) == 0 and not owner.is_shattered, label + " previous floor token cannot shatter")
		check(GLASS.commit(world, targets, token + 1, Vector2.RIGHT) == 0 and not owner.is_shattered, label + " future floor token cannot shatter")
		world.floor_transition_in_progress = true
		check(GLASS.commit(world, targets, token, Vector2.RIGHT) == 0 and not owner.is_shattered, label + " transition gate rejects commit")
		world.floor_transition_in_progress = false
		var notifications := {"count":0}
		owner.window_shattered.connect(func(_pane): notifications.count += 1)
		var before_neighbors := {}
		for pane in get_nodes_in_group(&"breakable_glass_windows"):
			if pane != owner and world.wall_root.is_ancestor_of(pane): before_neighbors[pane.get_instance_id()] = bool(pane.is_shattered)
		var side_cells: Array = world._edge_side_cells(owner.edge_data)
		var room_a: int = int(world.room_cells.get(side_cells[0], -1))
		var room_b: int = int(world.room_cells.get(side_cells[1], -1))
		if room_a >= 0 and room_b >= 0:
			world.are_rooms_openly_connected(room_a, room_b) # Prime the old cache before shattering.
		check(GLASS.commit(world, [owner, owner], token, Vector2.RIGHT) == 1, label + " duplicate owner commits one existing shatter")
		check(notifications.count == 1 and owner.is_shattered, label + " existing signal callback runs once")
		check(GLASS.commit(world, [owner], token, Vector2.RIGHT) == 0 and notifications.count == 1, label + " repeat commit is idempotent")
		check(world.edge_states.get(edge_key) == &"OPEN" and not world.wall_edges.has(edge_key) and not world.glass_wall_edges.has(edge_key), label + " connected world callback opens authoritative edge maps")
		var sides: Array = world._edge_side_cells(owner.edge_data)
		if world.floor_cells.has(sides[0]) and world.floor_cells.has(sides[1]):
			check(world._can_cross_floor_edge(sides[0], sides[1]) and world._current_floor_path_adjacency()[sides[0]].has(sides[1]), label + " existing floor path cache sees opened glass edge")
			if room_a >= 0 and room_b >= 0 and room_a != room_b:
				check(world.dash_breach_links.has(edge_key) and world.rooms[room_a].connections.has(room_b) and world.rooms[room_b].connections.has(room_a) and world.rooms[room_a].neighbors.has(room_b) and world.rooms[room_b].neighbors.has(room_a), label + " real opening registers symmetric room links and neighbors")
				check(world.are_rooms_openly_connected(room_a, room_b) and world._next_route_room(room_a, room_b) == room_b, label + " enemy room route recognizes the opened glass shortcut")
				var employee = load("res://scripts/entities/employee_enemy.gd").new()
				employee.position = Vector2(sides[0]) * world.CELL_PIXELS
				employee.set_meta(&"dream_room_id", room_a)
				employee.held_weapon_id = "pistol"
				var plan: Dictionary = world.get_employee_door_plan(employee, room_b)
				check(not plan.is_empty() and String(plan.door_edge_key) == edge_key and int(plan.door_id) == -1 and world.can_employee_hear_gunshot(employee, room_b), label + " enemy navigation and hearing use the real glass hole without a synthetic door")
				employee.free()
				var links_before: int = world.dash_breach_links.size()
				var connection_count: int = world.rooms[room_a].connections.size()
				world.register_dash_open_edge(edge_key, owner.edge_data)
				check(world.dash_breach_links.size() == links_before and world.rooms[room_a].connections.size() == connection_count and notifications.count == 1, label + " repeated route registration is idempotent and never reshatters")
		if bool(owner.exterior):
			var falls: Node = world.floor_root.get_node_or_null("ExteriorFalls")
			check(falls != null and falls.openings.has(edge_key) and bool(owner.get_parent().get_meta(&"exterior_shattered", false)), "facade existing callback registers one exterior opening")
			var clean_graph: bool = not world.dash_breach_links.has(edge_key)
			for room in world.rooms: clean_graph = clean_graph and not room.connections.has(-1) and not room.connections.has(int(room.id))
			check(clean_graph, "exterior glass opening never creates a void or self room adjacency")
		var neighbors_intact := true
		for pane in get_nodes_in_group(&"breakable_glass_windows"):
			if before_neighbors.has(pane.get_instance_id()): neighbors_intact = neighbors_intact and bool(pane.is_shattered) == before_neighbors[pane.get_instance_id()]
		check(neighbors_intact, label + " only contacted owner shatters")
		await process_frame
		check(collision.collision_layer == 0 and owner.collision_shape_2d.disabled and not owner.glass_pane.visible, label + " existing deferred teardown removes actual collision and pane")
		check(not GLASS.query(world, path[0], path[1], 2.0).has(owner), label + " shattered pane no longer appears in pure query")
	# A shatter from an existing non-dash caller must register the same route.
	var direct: Node3D
	for pane in get_nodes_in_group(&"breakable_glass_windows"):
		if pane.is_shattered or not world.wall_root.is_ancestor_of(pane): continue
		var sides: Array = world._edge_side_cells(pane.edge_data)
		var a: int = int(world.room_cells.get(sides[0], -1))
		var b: int = int(world.room_cells.get(sides[1], -1))
		if a >= 0 and b >= 0 and a != b and world.floor_cells.has(sides[0]) and world.floor_cells.has(sides[1]): direct = pane; break
	check(direct != null, "another intact interior pane exists for non-dash callback regression")
	if direct != null:
		direct.shatter(Vector2.RIGHT)
		check(world.dash_breach_links.has(String(direct.edge_key)), "existing non-dash shatter callback registers the same physical room opening")
	# Old, still-valid owners stashed beside the current roots are never eligible.
	var stashed: Node3D
	for pane in get_nodes_in_group(&"breakable_glass_windows"):
		if not pane.is_shattered and world.wall_root.is_ancestor_of(pane): stashed = pane; break
	check(stashed != null, "remaining intact pane is available for active-root tests")
	if stashed == null: world.free(); quit(1); return
	var old_path := segment(stashed)
	check(GLASS.query(world, old_path[0], old_path[1], 2.0).has(stashed), "intact pane is eligible before moving its real collider")
	var proxy: StaticBody2D = stashed.collision_body_2d
	var saved_position := proxy.global_position
	proxy.global_position += Vector2(5000,4000)
	proxy.rotation = .37
	var moved_path := segment(stashed)
	check(GLASS.query(world, moved_path[0], moved_path[1], 2.0).has(stashed) and not GLASS.query(world, old_path[0], old_path[1], 2.0).has(stashed), "query follows translated and rotated real collision center instead of edge metadata")
	proxy.rotation = 0
	proxy.global_position = saved_position
	var old_root := Node3D.new()
	world.add_child(old_root)
	stashed.reparent(old_root)
	check(GLASS.commit(world, [stashed], world.get_current_floor_token(), Vector2.RIGHT) == 0 and not stashed.is_shattered, "foreign/stashed intact glass owner cannot commit on active floor")
	check(not GLASS.query(world, old_path[0], old_path[1], 2.0).has(stashed), "stashed intact owner is absent from active-root query")
	world.free()
	await process_frame
	print("DASH_GLASS_BREAK checks=",checks," failures=",failures)
	quit(1 if failures else 0)
