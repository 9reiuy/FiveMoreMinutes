extends SceneTree

const WORLD := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const ENEMY := preload("res://scenes/entities/employee_enemy.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func active_emitters(world: Node) -> Array:
	return get_nodes_in_group(&"corpse_blood_emitters").filter(func(n: Node) -> bool:
		return n.active and not n.is_queued_for_deletion() and int(n.get_meta(&"blood_world_instance_id", -1)) == world.get_instance_id())

func run() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	var world := WORLD.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	check(world.regenerate(42001), "formal floor generated")
	var origin: Vector2 = world.player.global_position
	var room_id: int = world.current_room_id
	world.player.set_physics_process(false)
	var enemy := ENEMY.instantiate() as EmployeeEnemy
	world.enemy_root.add_child(enemy)
	enemy.global_position = origin
	enemy.set_meta(&"dream_room_id", room_id)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.take_damage(999.0, Vector2.RIGHT, 50.0, &"rifle")
	check(enemy.dead and not enemy.death_landed, "lethal hit starts airborne corpse")
	check(active_emitters(world).is_empty(), "airborne corpse does not seep onto floor")
	for i in 120:
		if enemy.death_landed:
			break
		enemy._update_death_presentation(1.0 / 60.0)
	check(enemy.death_landed and enemy.corpse_bleed_spawned, "landing enters formal follow bleed path")
	var emitters := active_emitters(world)
	check(emitters.size() == 1, "one scheduler per corpse")
	if not emitters.is_empty():
		var emitter := emitters[0] as CorpseBloodEmitter
		emitter.set_process(false)
		check(emitter.follow_source.get_ref() == enemy, "formal source is weakly bound to corpse")
		enemy._start_corpse_follow_bleed()
		check(active_emitters(world).size() == 1, "repeated landing request does not duplicate bleed")
		enemy.global_position += Vector2(2, 0)
		emitter._process(0.24)
		check(emitter.origin_gameplay_position == enemy.global_position, "formal seep follows moving ground root")
	for i in 14:
		world.spawn_corpse_blood_emitter(origin, room_id, Vector2.RIGHT, 0.5)
	check(active_emitters(world).size() <= world.EMPLOYEE_CONFIG.max_active_corpse_blood_emitters, "simultaneous corpse schedulers obey authored budget")
	var previous := active_emitters(world).map(func(n: Node) -> WeakRef: return weakref(n))
	check(world.regenerate(42002), "next floor generated")
	for i in 4:
		await process_frame
	check(active_emitters(world).is_empty(), "floor regeneration clears old corpse schedulers")
	for reference in previous:
		check(reference.get_ref() == null, "old scheduler released")
	world.free()
	for i in 3:
		await process_frame
	print("CORPSE_FOLLOW_WORLD_CHECKS=", checks, " FAILURES=", failures)
	quit(0 if failures == 0 else 1)
