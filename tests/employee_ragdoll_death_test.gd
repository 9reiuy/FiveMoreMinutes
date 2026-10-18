extends SceneTree

const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const ENEMY = preload("res://scenes/entities/employee_enemy.tscn")
const CONFIG = preload("res://resources/demo_config.tres")

var world: Node3D
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, msg: String) -> void:
	if not condition:
		failures.append(msg)
		print("FAIL: ", msg)
	else:
		print("PASS: ", msg)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	print("--- Starting Employee Ragdoll Death Test ---")
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41002), "World dungeon generated")

	var player: Node2D = world.player
	var anchor := Vector2.ZERO

	var e: EmployeeEnemy = ENEMY.instantiate()
	world.enemy_root.add_child(e)
	e.global_position = anchor
	e.set_meta("dream_room_id", world.spawn_room_id)
	var cfg: DemoConfig = CONFIG.duplicate()
	e.configure(player, 100, 0, world._room_bounds_pixels(world.spawn_room_id, 2), CONFIG.enemy_separation_strength, CONFIG.enemy_separation_radius, cfg)
	e.set_room_bounds(world._room_bounds_pixels(world.spawn_room_id, 2))
	e.defeated.connect(world._on_enemy_defeated)
	e.weapon_drop_requested.connect(world._on_employee_weapon_drop_requested.bind(e))
	e.set_physics_process(false)
	e.set_player_vision_visible(true)
	world.register_depth_visual(e, [^"Shadow", ^"CharacterVisual", ^"WeaponRoot"])
	e.equip_weapon("basic")
	await frames(3)

	check(e.held_weapon_id == "basic", "Enemy has basic weapon equipped initially")

	var hit_origin := anchor - Vector2(25, 0)
	var lethal_force := 450.0
	e.take_damage(120, hit_origin, lethal_force, &"shotgun")

	check(e.dead, "Enemy marked dead")
	check(e.death_presentation_left > 14.5, "Normal corpse keeps its existing ~15s lifetime")
	check(e.ragdoll_active, "Ragdoll physics is active")
	check(e.left_hand.visible, "Left hand remains visible after death")
	check(e.right_hand.visible, "Right hand remains visible after death")
	check(e.head.visible, "Head remains visible on body")
	check(e.left_leg.visible, "Left leg remains visible on body")
	check(e.right_leg.visible, "Right leg remains visible on body")
	check(e.character_visual.visible, "Character visual remains intact (not hidden)")

	check(e.ragdoll_left_hand_vel.length() > 20.0, "Left hand has initial impulse velocity")
	check(e.ragdoll_right_hand_vel.length() > 20.0, "Right hand has initial impulse velocity")
	check(e.ragdoll_head_vel.length() > 10.0, "Head has initial impulse velocity")

	await frames(10)
	check(is_instance_valid(e), "Enemy corpse is actively playing presentation")
	check(e.ragdoll_left_hand_pos.length() > 0.5, "Left hand swung away from base socket")
	check(e.ragdoll_right_hand_pos.length() > 0.5, "Right hand swung away from base socket")
	check(absf(e.ragdoll_head_rot) > 0.05, "Head has tilted/rotated from impact shock")
	check(e.ragdoll_left_hand_pos.length() <= 16.01, "Left hand clamped within socket limit")
	check(e.ragdoll_right_hand_pos.length() <= 16.01, "Right hand clamped within socket limit")
	check(e.ragdoll_head_pos.length() <= 9.01, "Head clamped within neck limit")

	await frames(45)
	if is_instance_valid(e):
		check(e.death_landed, "Enemy corpse hit ground and triggered landing")
		check(e.death_pool_spawned, "Blood pool spawned beneath corpse")

	await frames(60)
	check(is_instance_valid(e), "Normal corpse remains after its short landing animation")
	if is_instance_valid(e):
		e.set_process(false)
		while e.death_presentation_left > 0.0:
			e._update_death_presentation(1.0/60.0)
	await frames(3)
	check(not is_instance_valid(e), "Enemy corpse freed after its existing presentation lifetime")
	world.queue_free()
	await frames(4)

	if failures.is_empty():
		print("--- ALL Employee Ragdoll Death Tests PASSED! ---")
		quit(0)
	else:
		print("--- Failures detected: %d ---" % failures.size())
		quit(1)
