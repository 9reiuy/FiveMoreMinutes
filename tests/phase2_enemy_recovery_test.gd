extends Node

## Phase 2 regression tests for the living EmployeeEnemy recovery state machine.
## These tests use the formal 2D Enemy and only exercise the existing gameplay
## owner; no Enemy3D substitute or alternate knockdown implementation is used.

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const ENEMY_SCENE := preload("res://scenes/entities/employee_enemy.tscn")
const CONFIG := preload("res://resources/demo_config.tres")

var world: Node3D
var player: Node2D
var failures: Array[String] = []
var checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	get_tree().root.add_child(world)
	await _frames(2)
	_check(world.regenerate(41007), "layout generation")
	if failures.size() > 0:
		_finish()
		return

	player = world.player
	player.set_process(false)
	player.set_physics_process(false)
	world.set_process(false)
	if world.target_highlight != null:
		world.target_highlight.set_physics_process(false)
	var anchor: Vector2 = Vector2(world.rooms[world.spawn_room_id].center_cell) * 32.0
	player.global_position = anchor + Vector2(-180.0, 0.0)

	await _test_single_recovery(anchor)
	await _test_target_invalid_recovery(anchor)
	await _test_inactive_room_recovery(anchor)
	await _test_repeated_impacts(anchor)
	await _test_getting_up_reentry(anchor)
	await _test_fifty_nonlethal_recoveries(anchor)
	await _test_dead_stays_dead(anchor)

	print("PHASE2 ENEMY RECOVERY checks=", checks, " failures=", failures.size())
	_finish()


func _make_enemy(
	anchor: Vector2,
	health: float = 100.0,
	knockdown_duration: float = 0.1,
	get_up_duration: float = 0.1
) -> EmployeeEnemy:
	var enemy := ENEMY_SCENE.instantiate() as EmployeeEnemy
	world.enemy_root.add_child(enemy)
	enemy.global_position = anchor
	enemy.set_meta("dream_room_id", world.spawn_room_id)
	var test_config := CONFIG.duplicate(true) as DemoConfig
	# Keep the pressure run short while preserving the actual airborne, landing,
	# settled and Tween stages of the production state machine.
	test_config.employee_knockdown_duration = knockdown_duration
	test_config.employee_get_up_duration = get_up_duration
	enemy.configure(
		player,
		health,
		0.0,
		world._room_bounds_pixels(world.spawn_room_id, 2),
		world.config.enemy_separation_strength,
		world.config.enemy_separation_radius,
		test_config
	)
	enemy.set_room_bounds(world._room_bounds_pixels(world.spawn_room_id, 2))
	enemy.set_physics_process(true)
	enemy.set_process(true)
	return enemy


func _test_single_recovery(anchor: Vector2) -> void:
	var enemy := _make_enemy(anchor)
	var seen: Dictionary = {}
	var first_seen_msec: Dictionary = {}
	var started := Time.get_ticks_msec()
	enemy.start_knockdown(Vector2.RIGHT, &"phase2_single", 90.0)
	_check(enemy.state == EmployeeEnemy.State.KNOCKED_DOWN, "single knockdown enters KNOCKED_DOWN")
	for _frame in 300:
		await _frames(1)
		var state_id := int(enemy.state)
		seen[state_id] = true
		if not first_seen_msec.has(state_id):
			first_seen_msec[state_id] = Time.get_ticks_msec() - started
		if enemy.state != EmployeeEnemy.State.KNOCKED_DOWN and enemy.state != EmployeeEnemy.State.GETTING_UP and not enemy.knockdown_inertia_active:
			break
	var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
	print("PHASE2 SINGLE timeline_ms=", first_seen_msec, " total_ms=", int(elapsed * 1000.0))
	_check(seen.has(EmployeeEnemy.State.KNOCKED_DOWN), "single recovery observed KNOCKED_DOWN")
	_check(seen.has(EmployeeEnemy.State.GETTING_UP), "single recovery observed GETTING_UP")
	_check(enemy.state != EmployeeEnemy.State.KNOCKED_DOWN and not enemy.dead, "single recovery returns to alive active state")
	_check(elapsed < 6.0, "single recovery completes within legal bound")
	enemy.free()


func _test_target_invalid_recovery(anchor: Vector2) -> void:
	var enemy := _make_enemy(anchor + Vector2(30.0, 0.0))
	enemy.start_knockdown(Vector2.RIGHT, &"phase2_target_invalid", 90.0)
	# Simulate Player teardown after the impact.  Recovery must continue while
	# target-dependent perception/AI is skipped.
	enemy.set("target", null)
	var got_up := false
	for _frame in 360:
		await _frames(1)
		if enemy.state == EmployeeEnemy.State.GETTING_UP:
			got_up = true
		if got_up and enemy.state != EmployeeEnemy.State.GETTING_UP:
			break
	_check(got_up, "invalid target still reaches GETTING_UP")
	_check(enemy.state != EmployeeEnemy.State.KNOCKED_DOWN and not enemy.dead, "invalid target still completes alive recovery")
	enemy.free()


func _test_inactive_room_recovery(anchor: Vector2) -> void:
	var enemy := _make_enemy(anchor + Vector2(45.0, 24.0))
	enemy.start_knockdown(Vector2.RIGHT, &"phase2_inactive_room", 90.0)
	# Room streaming may pause ordinary AI.  It must not pause the physical
	# recovery episode or leave the get-up tween without a process owner.
	enemy.set_room_runtime_active(false)
	var got_up := false
	for _frame in 360:
		await _frames(1)
		if enemy.state == EmployeeEnemy.State.GETTING_UP:
			got_up = true
		if got_up and enemy.state != EmployeeEnemy.State.GETTING_UP:
			break
	_check(got_up, "inactive room recovery still reaches GETTING_UP")
	_check(enemy.state != EmployeeEnemy.State.KNOCKED_DOWN and not enemy.dead, "inactive room recovery completes alive")
	_check(not enemy.is_processing() and not enemy.is_physics_processing(), "inactive room disables processing after recovery")
	enemy.free()


func _test_repeated_impacts(anchor: Vector2) -> void:
	# Keep the authored recovery duration here so the five impact sources are
	# sampled while the same settled knockdown episode is still active.
	var enemy := _make_enemy(anchor + Vector2(60.0, 0.0), 100.0, 1.2, 0.4)
	enemy.start_knockdown(Vector2.RIGHT, &"phase2_repeat", 90.0)
	for _frame in 240:
		await _frames(1)
		if enemy.knockdown_settled:
			break
	_check(enemy.knockdown_settled, "repeated-impact fixture reaches settled state")
	var timer_before: float = enemy.knockdown_left
	for source in [&"door_impact", &"enemy_collision", &"furniture_impact", &"kick", &"lucille"]:
		enemy.start_knockdown(Vector2.LEFT, source, 900.0)
		await _frames(2)
		_check(enemy.state == EmployeeEnemy.State.KNOCKED_DOWN, "repeated %s keeps knockdown state" % source)
		_check(enemy.knockdown_left <= timer_before, "repeated %s does not refresh full timer" % source)
		_check(enemy.knockdown_settled, "repeated %s does not clear settled state" % source)
		_check(enemy.knockdown_visual_tween == null or not enemy.knockdown_visual_tween.is_valid(), "repeated %s does not start a get-up tween" % source)
	await _wait_until_active(enemy)
	_check(not enemy.dead, "repeated impacts still recover alive")
	enemy.free()


func _test_getting_up_reentry(anchor: Vector2) -> void:
	var enemy := _make_enemy(anchor + Vector2(90.0, 0.0))
	enemy.start_knockdown(Vector2.RIGHT, &"phase2_getup", 90.0)
	for _frame in 300:
		await _frames(1)
		if enemy.state == EmployeeEnemy.State.GETTING_UP:
			break
	_check(enemy.state == EmployeeEnemy.State.GETTING_UP, "get-up reentry fixture reaches GETTING_UP")
	var tween_before := enemy.knockdown_visual_tween
	enemy.start_knockdown(Vector2.LEFT, &"door_impact", 1200.0)
	_check(enemy.state == EmployeeEnemy.State.GETTING_UP, "ordinary impact does not re-enter knockdown during GETTING_UP")
	_check(enemy.knockdown_visual_tween == tween_before, "ordinary impact keeps the existing get-up tween")
	await _wait_until_active(enemy)
	_check(not enemy.dead, "GETTING_UP reentry still finishes alive")
	enemy.free()


func _test_fifty_nonlethal_recoveries(anchor: Vector2) -> void:
	var enemy := _make_enemy(anchor + Vector2(120.0, 0.0))
	var stuck_count := 0
	for cycle in 50:
		enemy.global_position = anchor + Vector2(120.0 + float(cycle % 4) * 4.0, 0.0)
		enemy.state = EmployeeEnemy.State.NEUTRAL_WANDER
		enemy.dead = false
		enemy.current_health = enemy.maximum_health
		enemy.start_knockdown(Vector2.RIGHT, &"phase2_pressure", 90.0)
		await _wait_until_active(enemy, 360)
		if enemy.dead or enemy.state == EmployeeEnemy.State.KNOCKED_DOWN or enemy.state == EmployeeEnemy.State.GETTING_UP:
			stuck_count += 1
	_check(stuck_count == 0, "50 nonlethal knockdowns all recover")
	enemy.free()


func _test_dead_stays_dead(anchor: Vector2) -> void:
	var enemy := _make_enemy(anchor + Vector2(150.0, 0.0), 1.0)
	enemy.take_damage(10.0, enemy.global_position - Vector2(10.0, 0.0), 90.0, &"player_projectile")
	_check(enemy.dead, "lethal hit enters dead state")
	await _frames(60)
	_check(not is_instance_valid(enemy) or enemy.dead, "dead Enemy does not enter alive recovery")
	if is_instance_valid(enemy):
		enemy.free()


func _wait_until_active(enemy: EmployeeEnemy, max_frames: int = 360) -> void:
	for _frame in max_frames:
		await _frames(1)
		if enemy.state != EmployeeEnemy.State.KNOCKED_DOWN and enemy.state != EmployeeEnemy.State.GETTING_UP and not enemy.knockdown_inertia_active:
			return


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL ", label)


func _finish() -> void:
	if is_instance_valid(world):
		world.free()
	await get_tree().process_frame
	get_tree().quit(1 if not failures.is_empty() else 0)
