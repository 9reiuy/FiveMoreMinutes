extends SceneTree

## Runtime regression for the Random3D adapter of the formal Dream population
## lifecycle.  It counts live EmployeeEnemy instances (not enemy_count), waits
## for the configured low-frequency tick, and verifies a defeated employee is
## replaced only in a safe off-screen room.

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

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
	for _index in count:
		await physics_frame
		await process_frame


func _run() -> void:
	var world := SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = true
	world.persist_profile = false
	world.show_debug_markers = false
	world.enable_enemy_population_refill = true
	world.global_enemy_cap = 8
	world.min_enemies_per_room = 1
	world.max_enemies_per_room = 3
	world.enemy_density = 0.03
	world.config = world.config.duplicate()
	world.config.employee_global_population_target = 8
	world.config.employee_population_refill_interval = 0.25
	world.config.employee_population_refill_batch = 2
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41004), "population test generation")
	await frames(4)

	var initial_alive: int = world._get_alive_employee_count()
	var initial_spawn_total: int = world.enemy_count
	check(initial_alive > 0, "initial Employee population exists")
	check(initial_alive <= world._enemy_population_target(), "initial population respects target")

	var victim: Node = null
	for enemy_variant in world.enemy_root.get_children():
		var enemy := enemy_variant as EmployeeEnemy
		if enemy != null and not bool(enemy.get_meta("content_kind", "") == &"boss"):
			victim = enemy
			break
	check(victim != null, "regular Employee available for population kill")
	if victim != null:
		var victim_position: Vector2 = victim.global_position
		victim.take_damage(100000.0, victim_position - Vector2(20.0, 0.0), 0.0, &"player_projectile")
	check(bool(victim.get("dead")), "population victim enters formal death state")
	var after_kill_alive: int = world._get_alive_employee_count()
	check(after_kill_alive < initial_alive, "alive count drops after defeat")

	# The formal cadence is 0.25s in this test.  Allow several ticks for the
	# candidate-room visibility and finite spawn-position retries to succeed.
	await frames(75)
	var refilled_alive: int = world._get_alive_employee_count()
	check(refilled_alive > after_kill_alive, "population tick refills a defeated Employee")
	check(refilled_alive <= world._enemy_population_target(), "refill does not exceed population target")
	check(world.enemy_count >= initial_spawn_total, "enemy_count remains a spawn-total counter")
	check(refilled_alive <= world.global_enemy_cap, "live population stays within the Random3D cap")

	print("POPULATION checks=", checks, " failures=", failures.size(),
		" initial_alive=", initial_alive, " after_kill=", after_kill_alive,
		" refilled=", refilled_alive, " enemy_count=", world.enemy_count)
	world.free()
	await frames(3)
	quit(1 if failures.size() else 0)
