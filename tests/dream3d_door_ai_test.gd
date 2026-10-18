extends "res://tests/dream3d_combat_parity_test.gd"

func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41003), "generation")
	player = world.player
	player.set_physics_process(false)
	world.target_highlight.set_physics_process(false)
	anchor = Vector2(world.rooms[world.spawn_room_id].center_cell) * 32
	player.global_position = anchor - Vector2(120,0)
	await frames(3)
	# Real rigid leaf hits the formal Player and Enemy pipelines, not test bodies.
	for kind in ["enemy", "player", "gentle_push"]:
		var door: Node3D = DOOR.instantiate()
		door.configure(1.84,3,0.1,"left",998)
		door.position = Vector3(anchor.x/32,0,anchor.y/32)
		world.add_child(door)
		door.configure_gameplay_collision(world.collision_root,32,4)
		var victim: Node2D
		if kind == "player":
			victim = player
			player.global_position = anchor + Vector2(20,32)
			player.invulnerability_left = 0
		else:
			victim = enemy_at(anchor + Vector2(20,19), 1000)
		await frames(3)
		var health: float = victim.current_health
		var force: float = 260.0 if kind == "gentle_push" else CONFIG.get_kick_knockback_force()
		door.apply_door_impact(&"push" if kind == "gentle_push" else &"kick", door.door_leaf.global_position, Vector3.BACK, force)
		await frames(25)
		if kind == "gentle_push":
			check(not door.has_meta("last_swing_target"), "gentle E does not launch")
			check(victim.current_health == health, "gentle E no attack damage")
		else:
			check(door.has_meta("last_swing_target") and int(door.get_meta("last_swing_target")) == victim.get_instance_id(), "fast door hits "+kind)
			check(victim.current_health < health, "fast door damages "+kind)
			check(door._target_hit_times.size() == 1, "target cooldown "+kind)
			if kind == "enemy":
				check(victim.knockdown_inertia_active, "door uses Enemy launch")
			else:
				check(victim.external_knockback_velocity.length() == 0, "door does not knock back player")
		door.free()
		if kind != "player":
			victim.free()
		player.global_position = anchor - Vector2(120,0)
		await frames(3)
	# Existing Enemy route state physically opens a generated latched door.
	var route_enemy := enemy_at(anchor)
	var destination := -1
	var from_room := -1
	var chosen_edge: Dictionary = {}
	for edge in world.door_edges.values():
		if int(edge.get("door_id",-1)) == world.boss_door_id:
			continue
		var sides: Array = world._edge_side_cells(edge)
		from_room = int(world.room_cells.get(sides[0],-1))
		destination = int(world.room_cells.get(sides[1],-1))
		if from_room >= 0 and destination >= 0:
			chosen_edge = edge
			break
	check(not chosen_edge.is_empty(), "interior physical door selected")
	route_enemy.set_meta("dream_room_id", from_room)
	route_enemy.set_room_bounds(world._room_bounds_pixels(from_room,2))
	var plan: Dictionary = world.get_employee_door_plan(route_enemy, destination)
	var direction := Vector2(plan.transit).direction_to(Vector2(plan.approach))
	route_enemy.global_position = Vector2(plan.approach) + direction * 12
	world._spawn_actor_physics_proxy(route_enemy, true)
	route_enemy._begin_route_to_room(destination)
	route_enemy.set_physics_process(true)
	var start_position := route_enemy.global_position
	var max_step := 0.0
	var previous := start_position
	var reached := false
	for i in 800:
		await frames(1)
		max_step = maxf(max_step, route_enemy.global_position.distance_to(previous))
		previous = route_enemy.global_position
		if int(route_enemy.get_meta("dream_room_id")) == destination:
			reached = true
			break
	check(reached, "Enemy intent opens and crosses generated door")
	check(max_step < 10.0, "Enemy crosses continuously without teleport")
	print("AI ROUTE ", reached, " state=", route_enemy.state, " displacement=", route_enemy.global_position-start_position, " step=",max_step)
	# Cross the same still-solid door from the other side. Its leaves initially
	# point into this actor's approach, so this catches the old rebound/stall.
	for _settle in 300:
		if route_enemy.state != EmployeeEnemy.State.ROOM_TRANSIT:
			break
		await frames(1)
	var reverse_enemy := enemy_at(anchor)
	reverse_enemy.set_meta("dream_room_id", destination)
	reverse_enemy.set_room_bounds(world._room_bounds_pixels(destination, 2))
	var reverse_plan: Dictionary = world.get_employee_door_plan(reverse_enemy, from_room)
	check(not reverse_plan.is_empty(), "reverse route plan exists")
	if not reverse_plan.is_empty():
		reverse_enemy.global_position = Vector2(reverse_plan.approach)
		world._spawn_actor_physics_proxy(reverse_enemy, true)
		reverse_enemy._begin_route_to_room(from_room)
		reverse_enemy.set_physics_process(true)
		var reverse_health: float = reverse_enemy.current_health
		var reverse_previous := reverse_enemy.global_position
		var reverse_max_step := 0.0
		var reverse_reached := false
		for _reverse_frame in 900:
			await frames(1)
			reverse_max_step = maxf(reverse_max_step, reverse_enemy.global_position.distance_to(reverse_previous))
			reverse_previous = reverse_enemy.global_position
			if int(reverse_enemy.get_meta("dream_room_id", -1)) == from_room:
				reverse_reached = true
				break
		check(reverse_reached, "enemy crosses an inward-open door in reverse")
		check(reverse_max_step < 10.0, "reverse crossing has no teleport")
		check(reverse_enemy.current_health == reverse_health, "passive reverse door does not hurt enemy")
	reverse_enemy.free()
	# Remote destinations return an adjacent next hop, using the original graph.
	var remote := -1
	for room in world.rooms:
		var id := int(room.id)
		if id != from_room and not world.rooms[from_room].connections.has(id) and id != world.boss_room_id:
			remote = id
			break
	route_enemy.set_physics_process(false)
	route_enemy.set_meta("dream_room_id", from_room)
	var remote_plan: Dictionary = world.get_employee_door_plan(route_enemy, remote)
	check(not remote_plan.is_empty() and world.rooms[from_room].connections.has(int(remote_plan.get("target_room_id",-1))), "remote chase uses adjacent first hop")
	route_enemy.hostile = false
	route_enemy.equip_weapon("basic")
	route_enemy.state = EmployeeEnemy.State.NEUTRAL_WANDER
	var sound: Vector2 = world._door_center_pixels(chosen_edge) + Vector2(10,10)
	route_enemy.on_room_gunshot(sound, destination)
	check(route_enemy.state == EmployeeEnemy.State.INVESTIGATE_GUNSHOT and not route_enemy.hostile, "adjacent armed hearing does not aggro")
	check(route_enemy.gunshot_threat_position == sound, "hearing stores sound not Player position")
	route_enemy._update_investigate_gunshot()
	check(route_enemy.state == EmployeeEnemy.State.MOVE_TO_DOOR, "investigation uses formal door route")
	check(is_equal_approx(route_enemy._get_current_move_speed(), route_enemy.movement_speed * route_enemy._cfg("employee_run_speed_multiplier", 1.6)), "investigate route runs at run speed multiplier")
	route_enemy.free()
	print("DOOR AI CHECKS ", checks, " failures ", failures.size())
	world.free()
	await frames(20)
	quit(0 if failures.is_empty() else 1)
