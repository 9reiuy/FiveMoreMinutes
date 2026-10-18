extends SceneTree

const DUNGEON_SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const ENEMY_SCENE = preload("res://scenes/entities/employee_enemy.tscn")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)
	else:
		print("PASS: ", message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== STARTING ENEMY CORPSE PRESENTATION TEST (15s LINGER, 3s 50% DARKEN) ===")
	var world = DUNGEON_SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	root.add_child(world)
	world.regenerate(42001)
	for i in range(5):
		await process_frame

	var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
	enemy.global_position = Vector2(0.0, 0.0)
	world.enemy_root.add_child(enemy)
	enemy.configure(world.player, 100.0, 0.0, Rect2(-500, -500, 1000, 1000), 10.0, 20.0, world.config)
	for i in range(3):
		await process_frame

	# Kill the enemy
	enemy.take_damage(200.0, Vector2(-20.0, 0.0), 300.0, &"shotgun")
	await process_frame

	check(enemy.dead, "Enemy marked dead")
	check(enemy.death_presentation_left >= 14.5, "Corpse presentation timer initialized to ~15s (got %s s)" % [enemy.death_presentation_left])
	check(absf(enemy.modulate.r - 1.0) < 0.05, "Corpse starts at 100%% brightness (modulate.r = %s)" % [enemy.modulate.r])

	# Simulate 1.5 seconds of process frames (90 frames at 60fps)
	var dt := 1.0 / 60.0
	for f in range(90):
		enemy._update_death_presentation(dt)

	check(is_instance_valid(enemy), "Corpse still on ground at 1.5s")
	check(enemy.modulate.r > 0.65 and enemy.modulate.r < 0.85, "Corpse brightness at 1.5s is around 75%% (got %s)" % [enemy.modulate.r])

	# Simulate another 1.5 seconds (reaching 3.0 seconds total)
	for f in range(90):
		enemy._update_death_presentation(dt)

	check(is_instance_valid(enemy), "Corpse still on ground at 3.0s")
	check(absf(enemy.modulate.r - 0.5) < 0.03, "Corpse brightness at 3.0s decreased to 50%% (got %s)" % [enemy.modulate.r])
	check(absf(enemy.modulate.g - 0.5) < 0.03, "Corpse green channel at 3.0s is 50%% (got %s)" % [enemy.modulate.g])
	check(absf(enemy.modulate.b - 0.5) < 0.03, "Corpse blue channel at 3.0s is 50%% (got %s)" % [enemy.modulate.b])

	# Simulate another 7.0 seconds (reaching 10.0 seconds total)
	for f in range(420):
		enemy._update_death_presentation(dt)

	check(is_instance_valid(enemy), "Corpse still on ground at 10.0s")
	check(absf(enemy.modulate.r - 0.5) < 0.03, "Corpse brightness remains at 50%% at 10.0s (got %s)" % [enemy.modulate.r])

	# Fast forward to 14.8 seconds (fading out)
	while enemy.death_presentation_left > 0.2:
		enemy._update_death_presentation(dt)

	check(is_instance_valid(enemy), "Corpse still valid at 14.8s during fade-out")
	check(enemy.modulate.a < 0.9, "Corpse alpha is fading out near end of 15s (alpha = %.2f)" % enemy.modulate.a)

	# Advance past 15.0 seconds
	for f in range(30):
		if is_instance_valid(enemy):
			enemy._update_death_presentation(dt)
		await process_frame

	check(not is_instance_valid(enemy) or enemy.is_queued_for_deletion(), "Corpse despawned after 15s")

	print("\n=== CORPSE PRESENTATION SUMMARY: %d FAILURES ===" % failures.size())
	if not failures.is_empty():
		for f in failures:
			print("  - ", f)
	quit()
