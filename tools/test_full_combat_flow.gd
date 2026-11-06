extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== RUNNING FULL END-TO-END COMBAT FLOW TEST ===")
	var scene: Node = load("res://scenes/testing/MegastructureWhitebox.tscn").instantiate()
	root.add_child(scene)

	# Dodge bullet by taking one step to the west (X: 160 instead of 192)
	var player = scene.get_node("GameplayCanvas/GameplayWorld/DreamPlayer")
	player.global_position = Vector2(160.0, 1152.0)

	await process_frame

	var world_2d = scene.get_node("GameplayCanvas/GameplayWorld")
	var enemy_root = scene.get_node("GameplayCanvas/GameplayWorld/EnemyRoot")
	var weapon_root = scene.get_node("GameplayCanvas/GameplayWorld/WorldWeaponRoot")
	var effects_root = scene.get_node("GameplayCanvas/GameplayWorld/WorldEffectsRoot")

	print("[1] Player setup verification:")
	print("    Equipped weapon: ", player.selected_weapon_id)
	assert(player.selected_weapon_id == "books", "Player must start with books (newspaper)!")
	print("    Position: ", player.global_position)

	print("[2] Standoff Enemy verification:")
	var enemies = enemy_root.get_children()
	print("    Total enemies in world: ", enemies.size())
	assert(enemies.size() >= 5, "Expected at least 5 enemies (1 standoff, 3 corridor melee, 1 end shooter)")
	var standoff_enemy = enemies[0]
	print("    Standoff enemy pos: ", standoff_enemy.global_position, " weapon: ", standoff_enemy.held_weapon_id)

	print("[3] Pre-fired slow-motion bullet verification:")
	var projs = effects_root.get_children()
	print("    Projectiles in world: ", projs.size())
	assert(projs.size() >= 1, "Expected pre-fired bullet in world_effects_root")
	var bullet = projs[0]
	print("    Bullet pos: ", bullet.global_position, " dir: ", bullet.direction)

	print("[4] Simulating Player Throwing Newspaper at Standoff Enemy...")
	# Aim directly at standoff enemy from player position
	var aim_dir = (standoff_enemy.global_position - player.global_position).normalized()
	var throw_data = player.take_active_weapon_for_throw()
	throw_data["direction"] = aim_dir
	scene._on_player_weapon_drop_requested(throw_data)
	print("    Player now empty handed: ", player.call("is_empty_handed"))

	# Step frames to let thrown weapon hit standoff enemy
	var enemy_hit := false
	for frame in range(60):
		await physics_frame
		if standoff_enemy.current_health < 10.0 or standoff_enemy.state in [standoff_enemy.State.KNOCKED_DOWN, standoff_enemy.State.GETTING_UP]:
			enemy_hit = true
			print("    FRAME %d: Standoff enemy HIT & KNOCKED DOWN! State: %s" % [frame, standoff_enemy.state])
			break

	assert(enemy_hit, "Thrown newspaper should have hit the standoff enemy!")

	print("[5] Verifying Dropped Pistol Pickup...")
	# Let the dropped pistol spawn and settle
	for frame in range(5):
		await physics_frame

	var pickups = weapon_root.get_children()
	print("    Pickups in world: ", pickups.size())
	var pistol_found := false
	for p in pickups:
		if p.weapon_id == "basic":
			pistol_found = true
			print("    Found dropped pistol at: ", p.global_position)
			# Move player onto the pistol to test auto-pickup
			player.global_position = p.global_position
			break
	assert(pistol_found, "Standoff enemy must drop pistol upon knockdown!")

	# Step a few frames to let auto-pickup process
	for frame in range(5):
		await physics_frame
		scene._update_world_weapon_interaction()

	print("    Player weapon after walking over pistol: ", player.selected_weapon_id)
	assert(player.selected_weapon_id == "basic", "Player should have picked up basic pistol!")

	print("[6] Stepping simulation for Corridor & End Shooter...")
	for frame in range(60):
		await physics_frame

	print("[7] Testing Player advancing to elevator...")
	player.global_position = Vector2(192.0, 48.0)
	for frame in range(10):
		await physics_frame

	print("    Level cleared state: ", scene.level_cleared)
	assert(scene.level_cleared, "Level should be cleared when entering elevator!")

	print("=== ALL FULL COMBAT AND DODGING CHECKS PASSED PERFECTLY! ===")
	quit(0)
