extends "res://scripts/dream/dream_3d_random_dungeon.gd"
const FLANK_GENERATOR = preload("res://scripts/dream/preview/office_flank_generator.gd")
var preview_topology := ""
var preview_rejected_furniture_candidates := 0

func _generate_building_layout() -> bool:
	var generated: Dictionary = FLANK_GENERATOR.generate(_rng)
	if generated.is_empty():
		return false
	lazy_room_presentation = false
	preview_topology = String(generated.preview_topology)
	building_rect = generated.building_rect
	floor_shape = generated.floor_shape
	rooms.assign(generated.rooms)
	partitions.assign(generated.partitions)
	corridors.assign(generated.corridors)
	connections.assign(generated.connections)
	floor_cells = generated.floor_cells.duplicate(true)
	room_cells = generated.room_cells.duplicate(true)
	corridor_cells = generated.corridor_cells.duplicate(true)
	wall_edges = generated.wall_edges.duplicate(true)
	internal_wall_edges = generated.internal_wall_edges.duplicate(true)
	door_edges = generated.door_edges.duplicate(true)
	door_opening_edges = generated.door_opening_edges.duplicate(true)
	glass_wall_edges = generated.glass_wall_edges.duplicate(true)
	edge_states = generated.edge_states.duplicate(true)
	spawn_room_id = int(generated.spawn_room_id)
	spawn_cell = generated.spawn_cell
	main_entrance = generated.main_entrance.duplicate(true)
	_next_door_id = int(generated.next_door_id)
	room_states.clear()
	room_encounters.clear()
	room_layout_plans.clear()
	corridor_states.clear()
	for room in rooms:
		room_states[int(room.id)] = room.state
		room_encounters[int(room.id)] = {"enemy_spawns": [], "drop_spawns": [], "activated": false, "completed": false}
	if not _room_graph_is_connected():
		return false
	_choose_key_and_boss_rooms()
	_reserve_content_routes()
	if not _choose_elevator_anchor():
		return false
	# Gate the candidate against the real approved furniture and enemy budget,
	# before any presentation/physics nodes are built. Outer seeded retries own
	# recovery; failed rooms are never silently left empty.
	_build_room_encounter_plans()
	for room in rooms:
		if String(room.archetype) == "corridor":
			continue
		var plan := _plan_otxo_room_layout(int(room.id))
		if not bool(plan.get("success", false)) or plan.get("furniture_placements", []).is_empty():
			preview_rejected_furniture_candidates += 1
			return false
	return true
