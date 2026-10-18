extends SceneTree
const GENERATOR = preload("res://scripts/dream/preview/office_flank_generator.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL ", label)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	for value in GENERATOR.SEEDS:
		var world = load("res://scenes/dream/preview/OfficeFlankPreview.tscn").instantiate()
		world.generate_on_ready = false
		world.enable_game_start_cab_exit = false
		root.add_child(world)
		check(world.regenerate(value), "generation %d" % value)
		world.player.invulnerability_left = 10000
		await frames(8)
		var start: Vector2 = world.player.global_position
		Input.action_press("move_right")
		await frames(20)
		Input.action_release("move_right")
		check(world.player.global_position.distance_to(start) > 5, "player input moves %d" % value)
		var budget := 0
		for encounter in world.room_encounters.values():
			budget += int(encounter.get("planned_enemy_count", 0))
		check(world.enemy_root.get_child_count() == budget and budget > 0, "enemy budget spawned %d" % value)
		for other in world.enemy_root.get_children():
			other.process_mode = Node.PROCESS_MODE_DISABLED
		var connection: Dictionary = {}
		for candidate in world.connections:
			if String(candidate.door_style) == "double" and int(candidate.a) != world.spawn_room_id and int(candidate.b) != world.spawn_room_id:
				connection = candidate
				break
		check(not connection.is_empty(), "physical doorway available %d" % value)
		if not connection.is_empty():
			var from_room := int(connection.a)
			var to_room := int(connection.b)
			var enemy = load("res://scenes/entities/employee_enemy.tscn").instantiate()
			world.enemy_root.add_child(enemy)
			enemy.set_meta(&"dream_room_id", from_room)
			enemy.configure(world.player, 100.0, 0.0, world._room_bounds_pixels(from_room, 2), world.config.enemy_separation_strength, world.config.enemy_separation_radius, world.config)
			enemy.set_room_bounds(world._room_bounds_pixels(from_room, 2))
			enemy.set_player_vision_visible(true)
			enemy.set_physics_process(false)
			world._spawn_actor_physics_proxy(enemy, true)
			var plan: Dictionary = world.get_employee_door_plan(enemy, to_room)
			check(not plan.is_empty(), "enemy route found %d" % value)
			if not plan.is_empty():
				enemy.global_position = plan.approach
				enemy.equip_weapon("assault_rifle", 0)
				enemy.hostile = true
				enemy.state = EmployeeEnemy.State.ATTACK_PLAYER
				enemy.can_see_target = true
				enemy.last_known_room = to_room
				enemy.last_known_target_position = plan.transit
				enemy.has_last_known_target_position = true
				enemy._update_attack_player(0.2)
				enemy._update_attack_player(0.5)
				enemy.set_physics_process(true)
				var reached := false
				var previous: Vector2 = enemy.global_position
				var max_step := 0.0
				for frame in 600:
					await frames(1)
					max_step = maxf(max_step, enemy.global_position.distance_to(previous))
					previous = enemy.global_position
					if int(enemy.get_meta(&"dream_room_id", -1)) == to_room and enemy.state != EmployeeEnemy.State.ROOM_TRANSIT:
						reached = true
						break
				check(reached, "enemy crosses physical door %d" % value)
				if not reached:
					print("FLANK TRANSIT DEBUG state=", enemy.state, " room=", enemy.get_meta(&"dream_room_id"), " pos=", enemy.global_position, " plan=", plan)
				check(max_step < 16, "enemy has no teleport %d" % value)
		print("FLANK RUNTIME seed=", value, " checks=", checks, " failures=", failures.size())
		world.queue_free()
		await frames(3)
	print("FLANK RUNTIME checks=", checks, " failures=", failures)
	quit(1 if not failures.is_empty() else 0)
