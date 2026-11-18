extends SceneTree
## Run the production input, contact and pickup paths against the isolated lab's collision world.
const STEP := 1.0 / 60.0
const MOVES := preload("res://scripts/entities/player_punch_motion.gd")
var player
var lab
var enemy
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func tick(count: int) -> void:
	for i in count:
		player._update_punch(STEP)

func tap() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	player._unhandled_input(event)
	event.pressed = false
	player._unhandled_input(event)

func run() -> void:
	var settings := root.get_node("SettingsManager")
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/") or settings.get_volume(&"master_volume") != 0:
		AudioServer.set_bus_mute(0, true)
		quit(2)
		return
	lab = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	root.add_child(lab)
	while not lab.ready_world: await process_frame
	lab.enemies.value = 0
	lab.checks.furniture.button_pressed = false
	lab.weapon.select(0)
	lab.rebuild()
	while not lab.ready_world: await process_frame
	lab.panel.hide()
	var world = lab.world
	player = world.player
	player.set_physics_process(false)
	player.set_meta(&"presentation_pointer_gate", func(): return true)
	player.set_meta(&"aim_direction_override", Vector2.LEFT)
	var home: Vector2 = Vector2(world.rooms[1].center_cell) * 32.0
	player.global_position = home
	enemy = world._spawn_regular_employee(world.rooms[1].id, home + Vector2(45,0), &"employee", false, "basic")
	enemy.set_room_runtime_active(true)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.current_health = 100.0
	enemy.maximum_health = 100.0
	enemy.equip_weapon("basic")
	await physics_frame
	enemy.ranged_attack_windup_pending = true
	enemy.ranged_attack_windup_left = 1.0
	tap()
	tick(1)
	check(player.punch_active and player.punch_move == MOVES.Strike.JAB, "Released short tap starts exactly the jab")
	check(player.punch_direction.is_equal_approx(Vector2.RIGHT), "Near enemy captures the swing even with cursor facing away")
	check(player.global_position.is_equal_approx(home), "Acquiring a target never teleports the player")
	tick(1)
	check(player.position.x > home.x and player.position.x < home.x + 20.0, "Startup moves only part of the approach")
	tick(3)
	check(absf(player.global_position.distance_to(enemy.global_position) - 25.0) < 0.5, "Real player reaches the contact standoff")
	check(enemy.current_health < 100 and not enemy.ranged_attack_windup_pending and enemy.held_weapon_id == "basic", "Jab interrupts the live warning and leaves the gun held")
	var first_hp: float = enemy.current_health
	tick(40)
	check(not player.punch_active and player.punch_next == 1 and enemy.current_health == first_hp, "One tap cannot repeat")
	var pickups_before: int = world.world_weapon_root.get_child_count()
	tap()
	tick(1)
	tap()
	tap()
	check(player.punch_taps == 2, "Two released taps during a swing are buffered")
	tick(8)
	check(player.punch_move == MOVES.Strike.WRIST and enemy.held_weapon_id.is_empty(), "Second punch disarms")
	await process_frame
	await process_frame
	check(world.world_weapon_root.get_child_count() == pickups_before + 1, "Exactly one real weapon pickup appears")
	tick(16)
	check(player.punch_move == MOVES.Strike.CROSS and enemy.knockback_velocity.x > 100, "Third punch gives short forward recoil")
	tick(22)
	check(player.punch_move == MOVES.Strike.UPPERCUT and enemy.knockdown_airborne and enemy.knockback_velocity.x > 100, "Fourth punch launches the enemy forward and up")
	enemy._update_knockdown_state(STEP)
	check(enemy.knockdown_height > 0 and enemy.knockdown_vertical_velocity > 0, "Knockdown produces real height above the ground")
	tick(40)
	check(not player.punch_active and player.punch_next == 0 and player.punch_taps == 0, "Buffered sequence finishes once and wraps")
	Input.action_press(&"attack")
	var starts: Array[int] = []
	for i in 81:
		var last_next: int = player.punch_next
		tick(1)
		if last_next != player.punch_next: starts.append(player.punch_move)
	check(starts == [0,2,1,3,0], "One hold continuously loops all four motions")
	check(player.punch_assist_target == null, "Downed enemy cannot pull the player")
	Input.action_release(&"attack")
	tick(60)
	check(not player.punch_active and player.punch_next == 1, "Release finishes only the ongoing strike")
	enemy.queue_free()
	await process_frame
	await physics_frame
	player.global_position = home
	var hidden_enemy = world._spawn_regular_employee(world.rooms[1].id, home + Vector2(35,0), &"employee", false, "basic")
	hidden_enemy.set_room_runtime_active(true)
	hidden_enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4,80)
	shape.shape = box
	wall.add_child(shape)
	world.collision_root.add_child(wall)
	wall.global_position = home + Vector2(17,0)
	player.set_meta(&"aim_direction_override", Vector2.RIGHT)
	await physics_frame
	await physics_frame
	var wall_hp: float = hidden_enemy.current_health
	tap()
	tick(24)
	check(player.global_position.distance_to(home) < 0.01 and hidden_enemy.current_health == wall_hp, "Solid wall blocks both adhesion and damage")
	tap()
	tap()
	player.equip_weapon("basic", world.config)
	check(player.punch_taps == 0 and not player.punch_active, "Equipping a gun clears every queued blow")
	Input.action_press(&"attack")
	tick(25)
	check(player.should_trigger_weapon_attack() and not player.punch_active, "Equipped LMB belongs to the firearm")
	player.take_active_weapon_for_throw()
	tick(25)
	check(not player.punch_active, "Dropping a gun during held fire does not generate a stray punch")
	Input.action_release(&"attack")
	tick(1)
	tap()
	tick(1)
	check(player.punch_move == MOVES.Strike.JAB and player.punch_active, "A fresh tap after dropping the gun resumes fists")
	var ground_gun = world.world_weapon_root.get_child(-1)
	ground_gun.place_after_swap(player.global_position,Vector2.ZERO)
	ground_gun.set_room_runtime_active(true)
	for i in 3: await physics_frame
	check(ground_gun.is_available_for(player) and world.interaction_resolver.update_target() == ground_gun, "Disarmed pistol has landed within pickup reach")
	world.current_world_weapon_target = ground_gun
	world._update_world_weapon_interaction()
	check(player.selected_weapon_id.is_empty() and player.is_using_fists(), "Automatic pickup waits for an ongoing combo")
	Input.action_press(&"pickup_weapon")
	await process_frame
	world._update_world_weapon_interaction()
	await physics_frame
	Input.action_release(&"pickup_weapon")
	check(player.selected_weapon_id == "basic" and not player.punch_active, "Explicit pickup takes precedence while punching")
	player.equip_weapon("",world.config)
	tap()
	tick(1)
	player.set_attacking_enabled(false)
	check(not player.punch_active and player.punch_next == 0 and player.punch_taps == 0, "Disabling combat clears the sequence")
	var robot_origin := home + Vector2(0, 64)
	var visuals: Node3D = world._hotel_robot_visual_container()
	check(world._spawn_hotel_robot(world.rooms[1].id,robot_origin,visuals), "Ground robot spawns on the same collision map")
	var robot = world.enemy_root.get_children().filter(func(n): return n.get_script() == load("res://scripts/entities/hotel_robot_unit.gd")).front()
	robot.set_physics_process(false)
	robot._aiming = true
	robot._magazine_primed = true
	world.resolve_player_hit(robot,2.0,robot_origin-Vector2(25,0),MOVES.SOURCES[MOVES.Strike.UPPERCUT])
	check(not robot._aiming and not robot._magazine_primed and not player._punch_target_standing(robot), "Robot's burst is interrupted and airborne target is released")
	for i in 12: robot._physics_process(STEP)
	robot.visual._sync_transform()
	check(robot.position.x > robot_origin.x+10.0 and robot.punch_height>12.0 and world.to_local(robot.visual.global_position).y>0.35, "Ground robot's real model rises and recoils")
	for i in 45: robot._physics_process(STEP)
	check(robot.is_standing_for_punch() and is_zero_approx(robot.punch_height), "Robot lands and becomes eligible again")
	world.resolve_player_hit(hidden_enemy,hidden_enemy.current_health * 2.0,player.global_position,MOVES.SOURCES[MOVES.Strike.UPPERCUT])
	check(hidden_enemy.dead and hidden_enemy.death_vertical_speed > 60.0 and hidden_enemy.death_ground_velocity.length() > 100.0, "Lethal uppercut carries the impulse into ordinary death physics")
	player.set_attacking_enabled(true)
	tap()
	tick(1)
	var previous_player: WeakRef = weakref(player)
	lab.rebuild()
	while not lab.ready_world: await process_frame
	check(not is_instance_valid(previous_player.get_ref()) and lab.world.player.punch_next == 0 and not lab.world.player.punch_active, "Floor rebuild frees the previous attacker and starts the new one in guard")
	lab.queue_free()
	await create_timer(1.2, true, false, true).timeout
	print("FIST_COMBO checks=", checks, " failures=", failures, " pid=", OS.get_process_id())
	quit(0 if failures.is_empty() else 1)
