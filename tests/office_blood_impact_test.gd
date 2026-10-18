extends SceneTree

const WORLD := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const BLOOD := preload("res://scripts/entities/black_blood_effect.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _run() -> void:
	var master_bus := AudioServer.get_bus_index(&"Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, true)
	var world := WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	_check(world.regenerate(42001), "Office floor generated")
	var impact_position: Vector2 = world.player.global_position
	var room_id: int = int(world.get_current_room_id())
	for room in world.rooms:
		if String(room.get("archetype", "")) == "open_office":
			room_id = int(room.get("id", -1))
			impact_position = Vector2(room.get("center_cell", Vector2i.ZERO)) * 32.0
			break
	_check(room_id >= 0, "Blood target room exists")
	_check(world.spawn_black_blood(impact_position, Vector2.RIGHT, false, room_id, 0.82), "Office impact accepted")
	var impact: Node = world.world_effects_root.get_child(world.world_effects_root.get_child_count() - 1)
	_check(impact is BlackBloodEffect, "Impact uses shared blood simulation")
	if impact is BlackBloodEffect:
		_check(impact.ground_pixels.size() >= 40, "Hit immediately places a substantial floor splash")
		_check(impact.airborne_pixels.size() >= 13, "Hit emits a fast droplet burst")
		_check(impact.settle_seconds <= 0.12, "Office burst lands within 120 ms")
		var peak_speed := 0.0
		for droplet in impact.airborne_pixels:
			peak_speed = maxf(peak_speed, (droplet.get("velocity", Vector2.ZERO) as Vector2).length())
		_check(peak_speed >= 300.0, "Impact droplets leave fast enough to read at game zoom")
	world.spawn_death_blood_pool(impact_position + Vector2(16.0, 0.0), room_id, 1.0)
	var pool: Node = world.world_effects_root.get_child(world.world_effects_root.get_child_count() - 1)
	_check(pool is BlackBloodEffect, "Death pool uses shared blood simulation")
	if pool is BlackBloodEffect:
		# User-approved OTXO morphology also changes footprint and growth timing.
		_check(is_equal_approx(pool.pool_growth_duration, 0.55), "Independent deposits finish within 550ms")
		_check(is_equal_approx(pool.pool_max_scale, 2.05), "Approved final footprint uses 2.05 radius scale")
		_check(not pool._pool_cell_arrivals.is_empty(), "Death pool uses independent arrival times")
		_check(is_equal_approx(pool.ground_visual_scale, 1.0), "Growth reveals fixed cells without magnifying pixels")
		var bridge_ref: Variant = pool.get_meta(&"depth_visual_bridge", null)
		var bridge: Node = bridge_ref.get_ref() if bridge_ref is WeakRef else null
		var capture: SubViewport = bridge.get_node_or_null("ActorDepthViewport") as SubViewport if bridge != null else null
		_check(capture != null and capture.size.x >= 192, "Expanded death pool capture does not crop its edge")
	var enemy: EmployeeEnemy = null
	for actor in world.enemy_root.get_children():
		if actor is EmployeeEnemy:
			enemy = actor
			break
	_check(enemy != null, "Office floor contains a damageable employee")
	if enemy != null:
		var stains_before: int = world.world_effects_root.get_child_count()
		enemy.take_damage(1.0, enemy.global_position, 0.0, &"player_projectile")
		_check(world.world_effects_root.get_child_count() > stains_before, "Accepted projectile hit enters the impact blood path")
	var old_dream_effect := BLOOD.new() as BlackBloodEffect
	root.add_child(old_dream_effect)
	_check(is_equal_approx(old_dream_effect.settle_seconds, 0.22), "Shared unconfigured blood API keeps default timing")
	_check(not old_dream_effect.office_impact_blot, "Office presentation remains an explicit opt-in")
	old_dream_effect.free()
	world.free()
	print("OFFICE_BLOOD_IMPACT_CHECKS=", checks, " FAILURES=", failures.size())
	quit(1 if not failures.is_empty() else 0)
