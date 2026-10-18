extends SceneTree

## Runtime regression for the macro Room -> Corridor -> Room enemy transit.
## The actor is placed at the authored approach point so this test isolates
## doorway arbitration and the multi-cell corridor traversal itself.

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const ENEMY_SCENE := preload("res://scenes/entities/employee_enemy.tscn")
const CONFIG := preload("res://resources/demo_config.tres")
const SEEDS := [41001, 41002, 41003, 41004, 41005]

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	call_deferred("_run")


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL ", label)


func frames(count: int) -> void:
	for _index in count:
		await physics_frame
		await process_frame


func _run() -> void:
	for test_seed in SEEDS:
		var world := SCENE.instantiate()
		world.generate_on_ready = false
		world.spawn_content = false
		world.persist_profile = false
		root.add_child(world)
		await frames(2)
		check(world.regenerate(test_seed), "seed %d generation" % test_seed)
		var chosen: Dictionary = {}
		for connection_variant in world.connections:
			var connection: Dictionary = connection_variant
			var a := int(connection.get("a", -1))
			var b := int(connection.get("b", -1))
			if a >= 0 and b >= 0 and a != world.boss_room_id and b != world.boss_room_id:
				chosen = connection
				break
		check(not chosen.is_empty(), "seed %d has a non-boss graph connection" % test_seed)
		if chosen.is_empty():
			world.free()
			await frames(1)
			continue
		var from_room := int(chosen.get("a", -1))
		var target_room := int(chosen.get("b", -1))
		var enemy := ENEMY_SCENE.instantiate() as EmployeeEnemy
		world.enemy_root.add_child(enemy)
		enemy.set_meta(&"dream_room_id", from_room)
		enemy.configure(
			world.player,
			100.0,
			0.0,
			world._room_bounds_pixels(from_room, 2.0),
			CONFIG.enemy_separation_strength,
			CONFIG.enemy_separation_radius,
			CONFIG
		)
		enemy.set_room_bounds(world._room_bounds_pixels(from_room, 2.0))
		enemy.set_player_vision_visible(true)
		enemy.set_physics_process(false)
		world._spawn_actor_physics_proxy(enemy, true)
		var plan: Dictionary = world.get_employee_door_plan(enemy, target_room)
		check(not plan.is_empty(), "seed %d has an enemy door plan" % test_seed)
		if plan.is_empty():
			enemy.free()
			world.free()
			await frames(1)
			continue
		enemy.global_position = plan.get("approach", enemy.global_position)
		# A discovered player across an open doorway can be fired at briefly,
		# but the enemy must subsequently enter the connected room.
		enemy.equip_weapon("assault_rifle", 0)
		enemy.hostile = true
		enemy.state = EmployeeEnemy.State.ATTACK_PLAYER
		enemy.can_see_target = true
		enemy.last_known_room = target_room
		enemy.last_known_target_position = plan.get("transit", enemy.global_position)
		enemy.has_last_known_target_position = true
		enemy._update_attack_player(0.20)
		check(enemy.state == EmployeeEnemy.State.ATTACK_PLAYER, "seed %d allows a short doorway engagement" % test_seed)
		enemy._update_attack_player(0.50)
		check(enemy.state == EmployeeEnemy.State.MOVE_TO_DOOR, "seed %d commits to cross-room pursuit" % test_seed)
		check(not enemy.door_hold_active, "seed %d does not wait at door during pursuit" % test_seed)
		enemy.set_physics_process(true)
		var start_position := enemy.global_position
		var max_step := 0.0
		var previous := start_position
		var reached := false
		for _frame in 1800:
			await frames(1)
			max_step = maxf(max_step, enemy.global_position.distance_to(previous))
			previous = enemy.global_position
			if int(enemy.get_meta(&"dream_room_id", -1)) == target_room and enemy.state != EmployeeEnemy.State.ROOM_TRANSIT:
				reached = true
				break
		check(reached, "seed %d enemy traverses corridor to Room %d" % [test_seed, target_room])
		# Hostile pursuit uses the configured run multiplier, unlike the old
		# neutral-travel fixture; a frame may cover a little over 10 pixels.
		check(max_step < 16.0, "seed %d corridor transit has no teleport (max step %.2f)" % [test_seed, max_step])
		check(enemy.global_position.distance_to(start_position) > 32.0, "seed %d enemy moved through corridor" % test_seed)
		enemy.free()
		world.free()
		await frames(1)

	print("CORRIDOR ENEMY checks=", checks, " failures=", failures.size())
	if failures.is_empty():
		print("PASS: Enemy traversed authored macro corridors without teleport.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
