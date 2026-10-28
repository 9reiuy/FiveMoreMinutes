extends SceneTree

const CONFIG := preload("res://resources/demo_config.tres")

var checks: int = 0
var failures: Array[String] = []

class World extends Node3D:
	var floor_root: Node3D = Node3D.new()
	var floor_cells: Dictionary = {}
	var pit_cells: Dictionary = {}
	var _layout_generation: int = 1
	var aim: Vector2 = Vector2(300, 0)
	var player: CharacterBody2D
	var enemies: Array = []

	func _ready() -> void:
		add_child(floor_root)
		add_to_group(&"dream_world")
		for x in range(-25, 26):
			for y in range(-25, 26):
				floor_cells[Vector2i(x, y)] = true

	func _cell_for_gameplay_position(point: Vector2) -> Vector2i:
		return Vector2i(roundi(point.x / 32.0), roundi(point.y / 32.0))

	func get_gameplay_aim_position() -> Vector2:
		return aim

	func get_dream_enemies_snapshot() -> Array:
		return enemies

	func resolve_phase_dash_attack(start: Vector2, end: Vector2, radius: float, damage: float, source: StringName, handled: Variant = null, _feedback: bool = true) -> Dictionary:
		return preload("res://scripts/dream/phase_dash_combat.gd").resolve(self, player, start, end, radius, damage, source, handled)


var world: World
var player: CharacterBody2D


func _init() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
		print("FAIL: ", label)
	else:
		print("PASS: ", label)


func reset_player() -> void:
	if is_instance_valid(player.phase_dash):
		player.phase_dash.cancel()
	player.cancel_dash()
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player._time_locomotion_velocity = Vector2.ZERO
	player.dead = false
	player.movement_enabled = true
	player.set_attacking_enabled(true)
	player.dash_charges = 1
	player.dash_cooldown_left = 0.0
	player.invulnerability_left = 0.0
	player.last_move_direction = Vector2.RIGHT


func run() -> void:
	AudioServer.set_bus_mute(0, true)
	preload("res://scripts/app/game_input_actions.gd").configure()

	world = World.new()
	root.add_child(world)
	player = load("res://scenes/entities/dream_player.tscn").instantiate()
	world.add_child(player)
	world.player = player
	player.configure_weapon("lucille", CONFIG, {})
	player.set_physics_process(false)
	await physics_frame

	print("\n--- Test 1: Direct target_direction in try_start_phase_dash ---")
	var directions: Dictionary = {
		"W (Up)": Vector2.UP,
		"S (Down)": Vector2.DOWN,
		"A (Left)": Vector2.LEFT,
		"D (Right)": Vector2.RIGHT,
		"W+D (Up-Right Diagonal)": Vector2(1, -1).normalized(),
		"W+A (Up-Left Diagonal)": Vector2(-1, -1).normalized(),
		"S+D (Down-Right Diagonal)": Vector2(1, 1).normalized(),
		"S+A (Down-Left Diagonal)": Vector2(-1, 1).normalized(),
	}

	for name in directions.keys():
		reset_player()
		var dir: Vector2 = directions[name]
		var started: bool = bool(player.try_start_phase_dash(dir))
		check(started, "Dash started for direction: " + str(name))
		check(player.dash_roll_direction.is_equal_approx(dir), "dash_roll_direction matches " + str(name))
		var expected_endpoint: Vector2 = dir * player.dash_distance
		check(player.dash_end.is_equal_approx(expected_endpoint), "dash_end matches expected endpoint for " + str(name))
		player._update_dash(player.dash_duration)
		check(player.global_position.is_equal_approx(expected_endpoint), "player reached endpoint for " + str(name))

	print("\n--- Test 2: Input actions simulation for 4 cardinal and 4 diagonal directions ---")
	var input_cases: Array[Dictionary] = [
		{"name": "W alone", "actions": ["move_up"], "expected": Vector2(0, -1).normalized()},
		{"name": "S alone", "actions": ["move_down"], "expected": Vector2(0, 1).normalized()},
		{"name": "A alone", "actions": ["move_left"], "expected": Vector2(-1, 0).normalized()},
		{"name": "D alone", "actions": ["move_right"], "expected": Vector2(1, 0).normalized()},
		{"name": "W + D diagonal", "actions": ["move_up", "move_right"], "expected": Vector2(1, -1).normalized()},
		{"name": "W + A diagonal", "actions": ["move_up", "move_left"], "expected": Vector2(-1, -1).normalized()},
		{"name": "S + D diagonal", "actions": ["move_down", "move_right"], "expected": Vector2(1, 1).normalized()},
		{"name": "S + A diagonal", "actions": ["move_down", "move_left"], "expected": Vector2(-1, 1).normalized()},
	]

	for c in input_cases:
		reset_player()
		# Release all movement actions first
		for act in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(act)
		# Press the specified actions
		for act in c["actions"]:
			Input.action_press(act, 1.0)

		# Read movement input from player
		var move_input: Vector2 = player._read_gameplay_movement_input()
		var expected_dir: Vector2 = c["expected"]
		check(move_input.normalized().is_equal_approx(expected_dir), "Input vector normalized matches expected for " + str(c["name"]))
		check(is_equal_approx(move_input.length(), 1.0), "Input vector length is 1.0 for " + str(c["name"]))

		# Now simulate pressing dash with no explicit argument
		var started: bool = bool(player.try_start_phase_dash())
		check(started, "Dash started via input for: " + str(c["name"]))
		check(player.dash_roll_direction.is_equal_approx(expected_dir), "Dash direction matches expected for " + str(c["name"]))
		var expected_landing: Vector2 = expected_dir * player.dash_distance
		check(player.dash_end.is_equal_approx(expected_landing), "Dash endpoint matches for " + str(c["name"]))

		# Release keys
		for act in c["actions"]:
			Input.action_release(act)

	print("\n--- Test 3: Mouse aim direction when no WASD is pressed ---")
	var mouse_aim_cases: Array[Dictionary] = [
		{"name": "Mouse Up", "aim": Vector2(0, -300), "expected": Vector2.UP},
		{"name": "Mouse Down", "aim": Vector2(0, 300), "expected": Vector2.DOWN},
		{"name": "Mouse Left", "aim": Vector2(-300, 0), "expected": Vector2.LEFT},
		{"name": "Mouse Right", "aim": Vector2(300, 0), "expected": Vector2.RIGHT},
		{"name": "Mouse Up-Right", "aim": Vector2(200, -200), "expected": Vector2(1, -1).normalized()},
	]

	for mc in mouse_aim_cases:
		reset_player()
		for act in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(act)
		world.aim = mc["aim"]
		# Even if last_move_direction was opposite, lack of WASD input must dash towards mouse
		player.last_move_direction = -mc["expected"]
		var started: bool = bool(player.try_start_phase_dash())
		check(started, "Dash started when stationary for " + str(mc["name"]))
		check(player.dash_roll_direction.is_equal_approx(mc["expected"]), "Dash directed to mouse aim for " + str(mc["name"]))
		var expected_end: Vector2 = (mc["expected"] as Vector2) * player.dash_distance
		check(player.dash_end.is_equal_approx(expected_end), "Dash endpoint matches mouse aim for " + str(mc["name"]))

	print("\n--- Test 4: Simulated input_vector in _physics_process with no WASD pressed ---")
	reset_player()
	for act in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(act)
	world.aim = Vector2(-250, -250)
	var expected_diag: Vector2 = Vector2(-1, -1).normalized()
	# Simulate the physics process dash trigger calculation
	var input_vec: Vector2 = player._read_gameplay_movement_input()
	check(input_vec.is_zero_approx(), "input_vector is zero when no keys pressed")
	var dash_dir: Vector2 = input_vec
	if dash_dir.length_squared() <= 0.0001:
		var mouse_pos: Vector2 = player.get_constrained_aim_position()
		var mouse_dir: Vector2 = player.global_position.direction_to(mouse_pos)
		if mouse_dir.length_squared() > 0.0001:
			dash_dir = mouse_dir
		else:
			dash_dir = player.get_aim_direction().normalized()
	check(dash_dir.normalized().is_equal_approx(expected_diag), "dash_dir falls back to mouse aim diagonal")
	var started_proc: bool = bool(player.try_start_phase_dash(dash_dir))
	check(started_proc, "Dash started via computed dash_dir")
	check(player.dash_roll_direction.is_equal_approx(expected_diag), "Dash roll direction matches mouse aim")

	print("\n==========================================")
	print("PHASE_DASH_WASD_INPUT checks=", checks, " failures=", failures.size())
	print("==========================================")
	world.free()
	quit(0 if failures.is_empty() else 1)
