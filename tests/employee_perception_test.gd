extends SceneTree

## Runtime regression coverage for the Enemy perception contract.
## This test deliberately drives the existing 2D Gameplay Physics world used by
## the 3D random building; it does not create a second AI or a second LOS map.
const WORLD_SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const ENEMY_SCENE := preload("res://scenes/entities/employee_enemy.tscn")
const DOOR_SCENE := preload("res://scenes/dream/3d/PhysicalDoor3D.tscn")
const CONFIG := preload("res://resources/demo_config.tres")

var world: Node3D
var player: CharacterBody2D
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
	for _i in count:
		await physics_frame
		await process_frame


func make_enemy(at_position: Vector2, cfg: DemoConfig = CONFIG) -> EmployeeEnemy:
	var enemy := ENEMY_SCENE.instantiate() as EmployeeEnemy
	world.enemy_root.add_child(enemy)
	enemy.global_position = at_position
	enemy.set_meta(&"dream_room_id", world.spawn_room_id)
	enemy.configure(
		player,
		100.0,
		0.0,
		world._room_bounds_pixels(world.spawn_room_id, 2.0),
		cfg.enemy_separation_strength,
		cfg.enemy_separation_radius,
		cfg
	)
	enemy.set_room_bounds(world._room_bounds_pixels(world.spawn_room_id, 2.0))
	enemy.set_physics_process(false)
	return enemy


func sample(enemy: EmployeeEnemy) -> void:
	enemy._update_visual_target_perception()


func _make_layer4_blocker(at_position: Vector2) -> StaticBody2D:
	var blocker := StaticBody2D.new()
	blocker.name = "PerceptionTestWall"
	blocker.collision_layer = 4
	blocker.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(6.0, 96.0)
	collision.shape = shape
	blocker.add_child(collision)
	blocker.position = at_position
	world.gameplay_world.add_child(blocker)
	return blocker


func _make_test_door(at_position: Vector2) -> PhysicalDoor3D:
	var door := DOOR_SCENE.instantiate() as PhysicalDoor3D
	door.configure(1.84, 3.0, 0.1, "left", 7001)
	door.position = Vector3(at_position.x / 32.0, 0.0, at_position.y / 32.0)
	# The test ray runs horizontally in 2D. Rotate the doorway so its closed
	# leaf crosses that ray; opening is then performed by the real hinge leaf.
	door.rotation.y = PI * 0.5
	world.door_root.add_child(door)
	door.configure_gameplay_collision(world.collision_root, 32.0, 4)
	return door


func _run() -> void:
	world = WORLD_SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	# Keep the test's explicit target coordinates authoritative; the normal
	# elevator entry tween otherwise moves Player during the LOS fixture.
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41002), "3D building generation")
	player = world.player
	player.set_physics_process(false)
	if world.target_highlight != null:
		world.target_highlight.set_physics_process(false)

	var anchor := Vector2(world.rooms[world.spawn_room_id].center_cell) * 32.0
	var enemy := make_enemy(anchor - Vector2(100.0, 0.0))
	enemy.last_facing_direction = Vector2.RIGHT

	# Front/Back: FOV is evaluated before the wall/door ray.
	player.global_position = anchor + Vector2(100.0, 0.0)
	sample(enemy)
	check(enemy.can_see_target, "front target visible")
	check(enemy.has_last_known_target_position, "visible target position cached")
	var remembered_front := enemy.last_known_target_position
	player.global_position = enemy.global_position - Vector2(100.0, 0.0)
	sample(enemy)
	check(not enemy.can_see_target, "back target rejected by FOV")
	check(enemy.last_known_target_position.distance_to(remembered_front) < 0.01, "back sample preserves last known position")

	# Layer-4 wall: only the project's wall/physical-door mask may block this ray.
	player.global_position = anchor + Vector2(100.0, 0.0)
	var blocker := _make_layer4_blocker(anchor)
	await frames(2)
	sample(enemy)
	check(not enemy.can_see_target, "layer-4 wall blocks LOS")
	check(enemy.last_known_target_position.distance_to(remembered_front) < 0.01, "wall loss keeps memory")
	blocker.collision_layer = 0
	await frames(2)
	sample(enemy)
	check(enemy.can_see_target, "LOS reacquired after wall removal")
	blocker.queue_free()
	await frames(2)

	# Physical door: closed and open checks use the synchronized DoorLeafCollision2D
	# body, not an angle threshold in the Enemy perception code.
	var door := _make_test_door(anchor)
	await frames(2)
	# Ensure a deterministic closed leaf before sampling.
	door.door_leaf.rotation.y = 0.0
	door.door_leaf.position = Vector3(0.0, door.door_height * 0.5, 0.0)
	door._sync_gameplay_collision()
	await frames(2)
	sample(enemy)
	check(not enemy.can_see_target, "closed physical door blocks LOS")
	check(door.apply_door_impact(&"kick", door.door_leaf.global_position, Vector3.RIGHT, 700.0), "physical door impact accepted")
	await frames(24)
	# A second kick only advances the same physical leaf; no perception-side
	# angle shortcut is involved.
	door.apply_door_impact(&"kick", door.door_leaf.global_position, Vector3.RIGHT, 700.0)
	await frames(24)
	sample(enemy)
	check(enemy.can_see_target, "open physical door clears LOS by real leaf position")

	# Damage awareness is immediate, but only the event-time Player position is
	# recorded.  Keep the door closed so the perception state itself remains false.
	door.set_gameplay_collision_enabled(true)
	door.door_leaf.freeze = true
	door.door_leaf.rotation = Vector3.ZERO
	door.door_leaf.position = Vector3(0.0, door.door_height * 0.5, 0.0)
	door._sync_gameplay_collision()
	await frames(2)
	player.global_position = anchor + Vector2(100.0, 0.0)
	enemy.can_see_target = false
	enemy.hostile = false
	enemy.state = EmployeeEnemy.State.NEUTRAL_WANDER
	var damage_position := player.global_position
	enemy.take_damage(1.0, enemy.global_position, 1.0, &"player_projectile")
	check(enemy.hostile, "damage awareness immediately hostile")
	check(not enemy.can_see_target, "damage awareness does not bypass LOS")
	check(enemy.last_known_target_position.distance_to(damage_position) < 0.01, "damage stores event-time target position")

	# Gunshot panic uses the sound position, never a live Player transform.
	var panic_config: DemoConfig = CONFIG.duplicate()
	panic_config.employee_panic_counterattack_chance = 1.0
	var panic_enemy := make_enemy(anchor - Vector2(80.0, 50.0), panic_config)
	var sound_position := anchor + Vector2(40.0, 24.0)
	panic_enemy.on_room_gunshot(sound_position, world.spawn_room_id)
	check(panic_enemy.hostile, "gunshot 20-percent counterattack branch hostile")
	check(panic_enemy.last_known_target_position.distance_to(sound_position) < 0.01, "gunshot stores sound position")

	# A small crowd still receives one cheap, staggered sample each.  This is a
	# runtime budget check, not a replacement for the single-ray perception rule.
	var crowd: Array[EmployeeEnemy] = []
	var phase_values: Dictionary = {}
	for i in range(24):
		var crowd_enemy := make_enemy(anchor + Vector2(-100.0 + float(i % 6) * 12.0, -60.0 + float(i / 6) * 12.0))
		crowd_enemy.last_facing_direction = Vector2.RIGHT
		crowd.append(crowd_enemy)
		phase_values[snappedf(crowd_enemy.perception_update_left, 0.001)] = true
	var sample_started := Time.get_ticks_usec()
	for crowd_enemy in crowd:
		sample(crowd_enemy)
	var sample_seconds := float(Time.get_ticks_usec() - sample_started) / 1000000.0
	print("PERCEPTION CROWD samples=", crowd.size(), " elapsed=", sample_seconds, "s phases=", phase_values.size())
	check(phase_values.size() > 1, "perception checks are staggered")
	check(sample_seconds < 0.25, "24 perception samples stay within runtime budget")

	print("EMPLOYEE_PERCEPTION_CHECKS ", checks, " failures ", failures.size())
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
