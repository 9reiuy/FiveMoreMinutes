extends SceneTree

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const EMPLOYEE_SCRIPT := preload("res://scripts/entities/employee_enemy.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)
		print("FAIL: ", message)
	else:
		print("PASS: ", message)

func frames(count: int = 4) -> void:
	for i in count:
		await process_frame

func _run() -> void:
	print("=== Starting Open Office Enemy Navigation Fix Verification ===")
	
	var world: Node = SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	
	# Find a seed that generates open office
	var found_open_office := false
	var open_office_room_id := -1
	var connected_room_id := -1
	
	for seed_val in [42001, 1337, 7777, 100, 2026, 42002, 42003]:
		world.regenerate(seed_val)
		await frames(4)
		
		for r_id in range(world.rooms.size()):
			var r: Dictionary = world.rooms[r_id]
			var arch: String = String(r.get("archetype", ""))
			var sample: String = String(r.get("sample_key", ""))
			var r_name: String = String(r.get("name", ""))
			var r_type: String = String(r.get("room_type", ""))
			if arch == "open_office" or sample == "office" or r_name.contains("office") or r_type.contains("office"):
				var conns: Array = r.get("connections", [])
				for conn_var in conns:
					var neighbor := int(conn_var)
					if world.are_rooms_openly_connected(r_id, neighbor):
						found_open_office = true
						open_office_room_id = r_id
						connected_room_id = neighbor
						break
			if found_open_office:
				break
		if found_open_office:
			print("Found open office setup at seed ", seed_val, ": open_office_room_id=", open_office_room_id, " connected_room_id=", connected_room_id)
			break
	
	_assert(found_open_office, "Should find at least one generated office layout with open_office and openly connected neighbor")
	
	if found_open_office:
		_test_openly_connected_logic(world, open_office_room_id, connected_room_id)
		_test_dynamic_door_plan(world, open_office_room_id, connected_room_id)
		_test_employee_combat_across_boundary(world, open_office_room_id, connected_room_id)
		_test_is_employee_position_clear(world, open_office_room_id, connected_room_id)
	
	world.queue_free()
	await frames(2)
	
	print("=== Verification Finished: ", checks, " checks, ", failures.size(), " failures ===")
	if failures.is_empty():
		print("TEST_OPEN_OFFICE_NAV_FIX_PASSED: All checks passed successfully.")
		quit(0)
	else:
		for fail in failures:
			printerr("  - ", fail)
		quit(1)

func _test_openly_connected_logic(dungeon: Node, open_room: int, conn_room: int) -> void:
	print("[Test 1] Testing are_rooms_openly_connected logic...")
	_assert(dungeon.are_rooms_openly_connected(open_room, open_room) == true, "A room must be openly connected to itself")
	_assert(dungeon.are_rooms_openly_connected(open_room, conn_room) == true, "Open office and its hallway should be openly connected")
	_assert(dungeon.are_rooms_openly_connected(conn_room, open_room) == true, "are_rooms_openly_connected must be symmetric")
	_assert(dungeon.are_rooms_openly_connected(-1, open_room) == false, "Invalid room -1 should return false")
	_assert(dungeon.are_rooms_openly_connected(open_room, 99999) == false, "Out of bounds room should return false")

func _test_dynamic_door_plan(dungeon: Node, open_room: int, conn_room: int) -> void:
	print("[Test 2] Testing dynamic door plan & transit grant...")
	var emp: EmployeeEnemy = dungeon.EMPLOYEE_SCENE.instantiate() as EmployeeEnemy
	emp.name = "TestEmployee"
	dungeon.enemy_root.add_child(emp)
	emp.set_meta(&"dream_room_id", open_room)
	emp.route_target_room_id = conn_room
	
	var open_edges: Array[Dictionary] = dungeon._get_open_boundary_edges_between(open_room, conn_room)
	print("Found ", open_edges.size(), " open boundary edges between rooms ", open_room, " and ", conn_room)
	
	if open_edges.size() >= 2:
		var pos_0: Vector2 = dungeon._boundary_edge_center_pixels(open_edges[0])
		emp.global_position = pos_0
		var plan_0: Dictionary = dungeon.get_employee_door_plan(emp, conn_room)
		_assert(not plan_0.is_empty(), "Plan 0 should not be empty")
		
		var pos_1: Vector2 = dungeon._boundary_edge_center_pixels(open_edges[open_edges.size() - 1])
		emp.global_position = pos_1
		var plan_1: Dictionary = dungeon.get_employee_door_plan(emp, conn_room)
		_assert(not plan_1.is_empty(), "Plan 1 should not be empty")
		
		var socket_0: Vector2 = plan_0.get("approach", Vector2.ZERO)
		var socket_1: Vector2 = plan_1.get("approach", Vector2.ZERO)
		_assert(socket_0.distance_to(socket_1) > 10.0, "Different employee positions must yield dynamic sockets, not a single bottle-necked point")
	
	var granted: bool = dungeon.request_employee_door_transit(emp, conn_room, &"", -1)
	_assert(granted == true, "request_employee_door_transit must grant immediately for open connected rooms")
	_assert(emp.door_transit_granted == true, "emp.door_transit_granted must be set to true")
	_assert(dungeon.employee_has_door_transit_grant(emp) == true, "employee_has_door_transit_grant must return true")
	
	emp.queue_free()

func _test_employee_combat_across_boundary(dungeon: Node, open_room: int, conn_room: int) -> void:
	print("[Test 3] Testing employee combat pursuit across open boundary...")
	var emp: EmployeeEnemy = dungeon.EMPLOYEE_SCENE.instantiate() as EmployeeEnemy
	emp.name = "CombatEmployee"
	dungeon.enemy_root.add_child(emp)
	emp.set_meta(&"dream_room_id", open_room)
	
	var player_node := CharacterBody2D.new()
	player_node.name = "TestPlayer"
	var player_center: Vector2 = Vector2(dungeon.rooms[conn_room]["center_cell"]) * dungeon.CELL_PIXELS
	player_node.global_position = player_center
	dungeon.add_child(player_node)
	dungeon.player = player_node
	
	emp.target = player_node
	emp.last_known_target_position = player_center
	emp.has_last_known_target_position = true
	emp.last_known_room = conn_room
	emp.held_weapon_id = "revolver"
	emp.hostile = true
	emp.state = EmployeeEnemy.State.ATTACK_PLAYER
	emp.can_see_target = true
	
	emp._update_attack_player(0.016)
	
	_assert(emp.state == EmployeeEnemy.State.ATTACK_PLAYER, "Enemy must stay in ATTACK_PLAYER state across open room boundary, not abort to MOVE_TO_DOOR (state was " + str(emp.state) + ")")
	
	emp.held_weapon_id = ""
	emp.panic_counterattack_active = true
	emp.state = EmployeeEnemy.State.ATTACK_PLAYER
	emp._update_attack_player(0.016)
	_assert(emp.state == EmployeeEnemy.State.ATTACK_PLAYER, "Unarmed enemy must also stay in ATTACK_PLAYER across open boundary (state was " + str(emp.state) + ")")
	_assert(emp.attack_movement_intent == true, "Unarmed enemy must have attack_movement_intent toward target")
	
	player_node.queue_free()
	emp.queue_free()

func _test_is_employee_position_clear(dungeon: Node, open_room: int, conn_room: int) -> void:
	print("[Test 4] Testing is_employee_position_clear across open boundary...")
	var emp: EmployeeEnemy = dungeon.EMPLOYEE_SCENE.instantiate() as EmployeeEnemy
	emp.name = "ProbeEmployee"
	dungeon.enemy_root.add_child(emp)
	emp.set_meta(&"dream_room_id", open_room)
	
	var candidate_pos: Vector2 = Vector2(dungeon.rooms[conn_room]["center_cell"]) * dungeon.CELL_PIXELS
	var is_clear: bool = dungeon.is_employee_position_clear(candidate_pos, emp)
	_assert(is_clear == true, "Candidate position in openly connected room should be clear for navigation/avoidance")
	
	var outside_pos := Vector2(-9999.0, -9999.0)
	var outside_clear: bool = dungeon.is_employee_position_clear(outside_pos, emp)
	_assert(outside_clear == false, "Position outside building must NOT be clear")
	
	emp.queue_free()
