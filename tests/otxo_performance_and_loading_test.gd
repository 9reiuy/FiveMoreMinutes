extends SceneTree

const DUNGEON_SCENE: PackedScene = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const DEMO_CONFIG_TRES = preload("res://resources/demo_config.tres")
const EMPLOYEE_SCENE: PackedScene = preload("res://scenes/entities/employee_enemy.tscn")
const LOADING_SCENE: PackedScene = preload("res://scenes/ui/loading_overlay.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame


func _run() -> void:
	print("--- Starting OTXO Performance, 2-Hop Activation & Loading Test Suite ---")

	await _test_2hop_dynamic_room_switching()
	await _test_frozen_enemy_damage_and_wakeup()
	await _test_loading_overlay_and_progress_signal()

	print("\n=====================================================================")
	if failures.is_empty():
		print(" ALL OTXO PERFORMANCE & LOADING TESTS PASSED (100%)! ")
	else:
		print(" FAILED (%d errors):" % failures.size())
		for f in failures:
			print("  - " + f)
	print("=====================================================================\n")

	quit(0 if failures.is_empty() else 1)


func _test_2hop_dynamic_room_switching() -> void:
	print("\n[Test 1] 2-Hop Dynamic Room Switching & Optimization...")
	var dungeon = DUNGEON_SCENE.instantiate()
	dungeon.generate_on_ready = false
	dungeon.spawn_content = true
	dungeon.persist_profile = false
	dungeon.config = DEMO_CONFIG_TRES.duplicate()
	dungeon.config.map_generator_type = "otxo_mansion"
	dungeon.config.otxo_mansion_room_count = 14

	root.add_child(dungeon)
	await frames(2)
	dungeon.regenerate(9991)

	var spawn_room_id: int = dungeon.spawn_room_id
	var spawn_2hop: Dictionary = dungeon._get_rooms_within_hops(spawn_room_id, 2)

	# Verify enemies in spawn 2-hop are active, distant ones are inactive
	for child in dungeon.enemy_root.get_children():
		if child is EmployeeEnemy:
			var enemy: EmployeeEnemy = child
			var r_id := int(enemy.get_meta(&"dream_room_id", -1))
			var active: bool = enemy.room_runtime_active
			var expected: bool = spawn_2hop.has(r_id)
			if active != expected:
				failures.append("Spawn init: Enemy in room %d active=%s, expected=%s" % [r_id, active, expected])
				break
	print("PASS: Initial 2-hop activation strictly matches spawn room BFS distance")

	# Find a distant room that is NOT in spawn_2hop
	var distant_room_id := -1
	for room_variant in dungeon.rooms:
		var r_id: int = int((room_variant as Dictionary).get("id", -1))
		if r_id >= 0 and not spawn_2hop.has(r_id):
			distant_room_id = r_id
			break

	if distant_room_id < 0:
		print("INFO: All rooms within 2 hops on this seed (small graph)")
	else:
		# Transition player to distant room
		dungeon._set_active_presentation_room(distant_room_id)
		var distant_2hop: Dictionary = dungeon._get_rooms_within_hops(distant_room_id, 2)

		var switched_correctly := true
		for child in dungeon.enemy_root.get_children():
			if child is EmployeeEnemy:
				var enemy: EmployeeEnemy = child
				var r_id := int(enemy.get_meta(&"dream_room_id", -1))
				var active: bool = enemy.room_runtime_active
				var expected: bool = distant_2hop.has(r_id)
				if active != expected:
					failures.append("Room switch: Enemy in room %d active=%s, expected=%s" % [r_id, active, expected])
					switched_correctly = false
					break
		if switched_correctly:
			print("PASS: Moving to room %d correctly updated 2-hop active window (%d rooms active)" % [distant_room_id, distant_2hop.size()])

	dungeon.queue_free()
	await frames(2)


func _test_frozen_enemy_damage_and_wakeup() -> void:
	print("\n[Test 2] Frozen Enemy Hurtbox Damageability & Wake-Up...")
	var enemy = EMPLOYEE_SCENE.instantiate() as EmployeeEnemy
	root.add_child(enemy)
	await frames(2)

	# Simulate freezing enemy as if in distant room
	enemy.set_room_runtime_active(false)

	if enemy.room_runtime_active:
		failures.append("Enemy should be inactive when frozen")
	else:
		print("PASS: Enemy successfully entered frozen state")

	# Check hurtbox is monitorable and damage runtime is active
	if not enemy.is_damage_runtime_active():
		failures.append("Frozen enemy must have is_damage_runtime_active() == true")
	else:
		print("PASS: Frozen enemy is_damage_runtime_active() is true")

	if enemy.hurtbox != null and not enemy.hurtbox.monitorable:
		failures.append("Frozen enemy hurtbox must remain monitorable")
	else:
		print("PASS: Frozen enemy hurtbox remains monitorable")

	# Apply non-lethal projectile damage
	var hp_before: float = enemy.current_health
	enemy.take_damage(2.0, Vector2.ZERO, 1.0, &"player_projectile")

	if enemy.current_health >= hp_before:
		failures.append("Frozen enemy did not take damage!")
	else:
		print("PASS: Frozen enemy took damage (HP: %.1f -> %.1f)" % [hp_before, enemy.current_health])

	if not enemy.room_runtime_active:
		failures.append("Frozen enemy did not wake up upon taking damage!")
	else:
		print("PASS: Frozen enemy woke up immediately (room_runtime_active = true)")

	if not enemy.hostile:
		failures.append("Woken enemy must become hostile!")
	else:
		print("PASS: Woken enemy is hostile")

	enemy.queue_free()
	await frames(2)


func _test_loading_overlay_and_progress_signal() -> void:
	print("\n[Test 3] LoadingOverlay & Generation Progress Signals...")
	var overlay = LOADING_SCENE.instantiate()
	root.add_child(overlay)
	await frames(2)

	overlay.show_loading("测试加载中...")
	if not overlay.visible:
		failures.append("LoadingOverlay should be visible after show_loading")
	else:
		print("PASS: LoadingOverlay is visible on show_loading")

	overlay.set_progress(0.55, "构建3D墙体与门窗...")
	if absf(overlay.target_ratio - 0.55) > 0.01:
		failures.append("LoadingOverlay target_ratio should be 0.55")
	else:
		print("PASS: LoadingOverlay progress set to 55%")

	if overlay.status_label.text != "构建3D墙体与门窗...":
		failures.append("LoadingOverlay status text did not update")
	else:
		print("PASS: LoadingOverlay status text updated successfully")

	# Test signal capture from dungeon regenerate
	var dungeon = DUNGEON_SCENE.instantiate()
	dungeon.generate_on_ready = false
	dungeon.spawn_content = false
	dungeon.persist_profile = false
	root.add_child(dungeon)
	await frames(2)

	var signals_received: Array[Dictionary] = []
	dungeon.generation_progress.connect(func(ratio: float, msg: String):
		signals_received.append({"ratio": ratio, "msg": msg})
	)

	dungeon.regenerate(1122)

	if signals_received.size() < 3:
		failures.append("Expected at least 3 generation progress signals, got %d" % signals_received.size())
	else:
		print("PASS: Dungeon emitted %d generation progress events" % signals_received.size())

	var last_ratio: float = signals_received[-1]["ratio"]
	if absf(last_ratio - 1.0) > 0.01:
		failures.append("Last generation progress ratio should be 1.0, got %f" % last_ratio)
	else:
		print("PASS: Last generation progress reached 100%% (%s)" % signals_received[-1]["msg"])

	overlay.hide_loading()
	await frames(5)
	if overlay.is_active:
		failures.append("LoadingOverlay is_active should be false after hide_loading")
	else:
		print("PASS: LoadingOverlay is_active is false after hide_loading")

	dungeon.queue_free()
	overlay.queue_free()
	await frames(2)
