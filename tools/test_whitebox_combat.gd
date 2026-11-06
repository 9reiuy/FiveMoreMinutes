extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== STARTING WHITEBOX COMBAT PROTOTYPE TEST ===")
	var scene: Node = load("res://scenes/testing/MegastructureWhitebox.tscn").instantiate()
	root.add_child(scene)

	for i in range(5):
		await process_frame

	var player = scene.get_node("GameplayCanvas/GameplayWorld/DreamPlayer")
	var world_2d = scene.get_node("GameplayCanvas/GameplayWorld")
	var config = preload("res://resources/demo_config.tres")

	print("[1] Player initial setup...")
	player.configure_weapon("books", config, {})
	print("    Player equipped: ", player.selected_weapon_id)

	print("[2] Spawning standoff enemy...")
	var enemy_scene = load("res://scenes/entities/employee_enemy.tscn")
	var standoff_enemy = enemy_scene.instantiate()
	standoff_enemy.global_position = Vector2(192.0, 1024.0)
	world_2d.add_child(standoff_enemy)
	standoff_enemy.configure(
		player,
		config.base_enemy_health,
		0.0,
		Rect2(0, 0, 384, 1216),
		config.enemy_separation_strength,
		config.enemy_separation_radius,
		config
	)
	standoff_enemy.equip_weapon("basic")
	standoff_enemy.hostile = true
	print("    Enemy successfully configured with weapon: basic")

	print("[3] Simulating player weapon throw...")
	# Simulate player RMB throw
	var throw_data = player.take_active_weapon_for_throw()
	print("    Throw data: ", throw_data)

	# Spawn thrown pickup
	var pickup_scene = load("res://scenes/dream/world_weapon_pickup.tscn")
	var thrown_pickup = pickup_scene.instantiate()
	thrown_pickup.weapon_id = throw_data.get("weapon_id", "books")
	world_2d.add_child(thrown_pickup)
	thrown_pickup.global_position = player.global_position + Vector2.UP * 16.0
	thrown_pickup.set_thrown(Vector2.UP * 800.0, 25.0, 200.0, player.get_instance_id(), 0.5)

	print("[4] Stepping physics to let throw hit enemy...")
	var hit_enemy := false
	for frame in range(60):
		await physics_frame
		if standoff_enemy.current_health < 10.0 or standoff_enemy.state in [standoff_enemy.State.KNOCKED_DOWN, standoff_enemy.State.GETTING_UP]:
			hit_enemy = true
			print("    FRAME %d: Enemy HIT! Health: %f, State: %s" % [frame, standoff_enemy.current_health, standoff_enemy.state])
			break

	if hit_enemy:
		print("    SUCCESS: Thrown newspaper successfully hit and knocked down enemy!")
	else:
		print("    Enemy pos: ", standoff_enemy.global_position, " Pickup pos: ", thrown_pickup.global_position)

	print("=== PROTOTYPE TEST COMPLETED ===")
	quit(0)
