extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("==================================================")
	print("=== STARTING FORMAL COMBAT & ENEMY AI TEST     ===")
	print("==================================================")

	var packed: PackedScene = load("res://scenes/testing/MegastructureWhitebox.tscn")
	assert(packed != null, "MegastructureWhitebox scene must exist!")
	var scene = packed.instantiate()
	root.add_child(scene)

	# Process 2 frames to let ready hooks run
	await process_frame
	await process_frame

	var player = scene.get_node("GameplayCanvas/GameplayWorld/DreamPlayer")
	var enemy_root = scene.get_node("GameplayCanvas/GameplayWorld/EnemyRoot")
	var world_effects = scene.get_node("GameplayCanvas/GameplayWorld/WorldEffectsRoot")
	var hud_layer = scene.get_node("HUD")
	var native_damage_numbers_root = scene.get_node("HUD/DamageNumbers")
	var standoff_enemy = scene.get("standoff_enemy")
	var corridor_shooter = scene.get("corridor_shooter")

	assert(player != null, "Player must exist!")
	assert(enemy_root != null, "EnemyRoot must exist!")
	assert(world_effects != null, "WorldEffects must exist!")
	assert(hud_layer != null, "HUD layer must exist!")
	assert(native_damage_numbers_root != null, "HUD/DamageNumbers must exist!")
	assert(standoff_enemy != null, "Standoff enemy must exist!")
	assert(corridor_shooter != null, "Corridor shooter must exist!")

	print("[TEST 1] Verifying Formal 3D Movement Speeds & Pacing...")
	print("  Player movement_speed: ", player.movement_speed)
	assert(player.movement_speed == 290.0, "Player movement speed must be 290.0 (3D formal profile)!")
	var runtime_cfg = scene.get("runtime_config")
	assert(runtime_cfg != null, "Runtime config must exist!")
	print("  Runtime config employee_movement_speed: ", runtime_cfg.employee_movement_speed)
	assert(runtime_cfg.employee_movement_speed == 150.0, "Enemy movement speed must be 150.0!")

	print("\n[TEST 2] Verifying Superhot Slow-motion Standoff & Bullet Buffer Margin...")
	print("  Engine.time_scale at start: ", Engine.time_scale)
	assert(Engine.time_scale <= 0.1, "Engine time scale must be in slow motion (<= 0.1) from frame 0!")
	print("  Player HP at spawn: ", player.current_health, " / ", player.maximum_health)
	assert(player.current_health == player.maximum_health, "Player must not be hit at spawn!")
	print("  Player has shield / grace: ", player.has_shield)
	assert(player.has_shield == true, "Player must have initial shield grace buffer!")

	# Distance between bullet and player
	var initial_bullet: Node2D = null
	for child in world_effects.get_children():
		if child.is_in_group(&"dream_projectiles"):
			initial_bullet = child
			break
	assert(initial_bullet != null, "Pre-fired bullet must exist in world!")
	var dist: float = initial_bullet.global_position.distance_to(player.global_position)
	print("  Distance between bullet and player: ", dist, "px (buffer margin > 100px)")
	assert(dist >= 100.0, "Bullet must have ample distance buffer (> 100px) from player!")

	print("\n[TEST 3] Verifying Enemy Can Be Shot By Bullets (resolve_player_hit)...")
	var patrol_enemy = enemy_root.get_child(1) # first corridor enemy
	assert(patrol_enemy != null, "Patrol enemy must exist!")
	var enemy_initial_hp: float = patrol_enemy.current_health
	print("  Corridor Enemy initial HP: ", enemy_initial_hp)

	# Fire a player projectile and resolve hit through world.resolve_player_hit
	# Deal 4.0 non-lethal bullet damage to verify EnemyHPBar pops up
	var hit_result: Dictionary = scene.resolve_player_hit(
		patrol_enemy,
		4.0,
		patrol_enemy.global_position,
		&"player_projectile_basic"
	)
	await process_frame

	print("  resolve_player_hit result: ", hit_result)
	print("  Corridor Enemy HP after bullet hit: ", patrol_enemy.current_health)
	assert(patrol_enemy.current_health == enemy_initial_hp - 4.0, "Enemy HP must be 6.0 after 4 bullet damage!")

	# Check Enemy HP bar and damage number
	var enemy_hp_bar = patrol_enemy.get_node_or_null("EnemyHPBar")
	assert(enemy_hp_bar != null and enemy_hp_bar.visible == true, "EnemyHPBar must be visible after non-lethal bullet damage!")
	assert(native_damage_numbers_root.get_child_count() > 0, "Damage number must spawn on bullet hit!")

	# Now deal lethal bullet damage to verify death transition
	scene.resolve_player_hit(patrol_enemy, 10.0, patrol_enemy.global_position, &"player_projectile_basic")
	await process_frame
	print("  Corridor Enemy HP after lethal hit: ", patrol_enemy.current_health)
	assert(patrol_enemy.current_health == 0.0, "Enemy HP must be 0.0 after lethal hit!")
	assert(bool(patrol_enemy.get("dead")) == true, "Enemy must be marked dead!")
	assert(enemy_hp_bar.visible == false, "EnemyHPBar must hide immediately on death (formal behavior)!")

	print("\n[TEST 4] Verifying Formal Enemy AI, Targeting & Runtime Activation...")
	print("  Standoff Enemy room_runtime_active: ", standoff_enemy.get("room_runtime_active"))
	print("  Standoff Enemy hostile: ", standoff_enemy.get("hostile"))
	assert(bool(standoff_enemy.get("room_runtime_active")) == true, "Standoff enemy must be runtime active!")
	assert(bool(standoff_enemy.get("hostile")) == true, "Standoff enemy must be hostile!")

	for enemy in enemy_root.get_children():
		if not bool(enemy.get("dead")):
			assert(bool(enemy.get("room_runtime_active")) == true, "All living enemies must be runtime active!")
			print("  Living enemy at ", enemy.global_position, " weapon: ", enemy.get("held_weapon_id"), " active: ", enemy.get("room_runtime_active"))
		else:
			print("  Corpse at ", enemy.global_position, " correctly deactivated: active = ", enemy.get("room_runtime_active"))

	print("\n[TEST 5] Verifying Player Formal HUD, Crosshair & Death CRT...")
	var hud = scene.get("hud")
	var crosshair = scene.get("crosshair")
	assert(hud != null, "Formal DreamHUD must be instantiated!")
	assert(crosshair != null, "Formal Crosshair must be instantiated!")

	# Lethal damage to player
	player.has_shield = false
	player.invulnerability_left = 0.0
	player.receive_damage(player.current_health, &"lethal_hit", player.global_position, Vector2.DOWN)
	await process_frame

	print("  Player dead: ", player.get("dead"))
	assert(bool(player.get("dead")) == true, "Player must be dead!")

	var found_death_crt = false
	for child in scene.get_children():
		if child is DeathCrtEffect or child.name.begins_with("DeathCrt"):
			found_death_crt = true
			break
	print("  Formal Death CRT Effect spawned: ", found_death_crt)
	assert(found_death_crt, "Formal DeathCrtEffect must be instantiated on player death!")

	print("\n==================================================")
	print("=== ALL COMBAT, SPEED & MARGIN TESTS PASS!     ===")
	print("==================================================")
	quit(0)
