extends SceneTree

const RULES := preload("res://scripts/dream/dream_firearm_rules.gd")
const ENEMY := preload("res://scenes/entities/employee_enemy.tscn")
const PISTOL := preload("res://scripts/dream/auto_weapon.gd")
const SHOTGUN := preload("res://scripts/dream/shotgun_weapon.gd")
const RIFLE := preload("res://scripts/dream/assault_rifle_weapon.gd")
const CONFIG := preload("res://resources/demo_config.tres")

class ShotWorld extends Node2D:
	var shots: Array[Node2D] = []
	func spawn_weapon_muzzle(_origin: Vector2, _direction: Vector2, _weapon: StringName, _source: Node2D) -> void:
		pass
	func spawn_shell_ejection(_origin: Vector2, _direction: Vector2, _weapon: StringName) -> void:
		pass
	func add_projectile(projectile: Node2D, _source: Node2D) -> void:
		add_child(projectile)
		projectile.set_physics_process(false)
		shots.append(projectile)
	func clear_shots() -> void:
		for projectile in shots:
			projectile.free()
		shots.clear()

class Shooter extends Node2D:
	var dead := false
	var pressed := false
	var ammo := 100
	func _init() -> void:
		var weapon_root := Node2D.new()
		weapon_root.name = "WeaponRoot"
		add_child(weapon_root)
		var hand := Node2D.new()
		hand.name = "HandAnchor"
		weapon_root.add_child(hand)
		var motion := Node2D.new()
		motion.name = "WeaponMotion"
		hand.add_child(motion)
	func get_projectile_origin() -> Vector2:
		return global_position
	func get_aim_direction() -> Vector2:
		return Vector2.RIGHT
	func should_trigger_weapon_attack() -> bool:
		return pressed
	func is_weapon_empty_for_attack() -> bool:
		return ammo <= 0
	func try_consume_ammo_for_attack() -> bool:
		if ammo <= 0:
			return false
		ammo -= 1
		return true

var checks := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _run() -> void:
	var config := CONFIG.duplicate(true) as DemoConfig
	config.employee_attack_cadence_jitter_ratio = 0.0
	config.employee_weapon_spread_degrees = 0.0
	config.employee_movement_spread_degrees = 0.0
	config.employee_burst_spread_step_degrees = 0.0
	config.weapon_fire_rate_multiplier = 1.7
	var world := ShotWorld.new()
	root.add_child(world)
	world.add_to_group("dream_world")
	var shooter := Shooter.new()
	world.add_child(shooter)
	var enemy := ENEMY.instantiate()
	world.add_child(enemy)
	enemy.configure(shooter, 100.0, 0.0, Rect2(-1000, -1000, 2000, 2000), 0.0, 0.0, config)
	enemy.set_physics_process(false)
	enemy.set_process(false)
	enemy.can_see_target = true
	enemy.has_last_known_target_position = true
	enemy.last_known_target_position = Vector2(500, 0)
	for entry in [[&"basic", PISTOL], [&"shotgun", SHOTGUN], [&"assault_rifle", RIFLE]]:
		var weapon_id: StringName = entry[0]
		var weapon: Node = entry[1].new()
		shooter.add_child(weapon)
		weapon.configure_weapon(config, {})
		weapon.set_process(false)
		var parameters := RULES.parameters(config, weapon_id)
		if weapon_id == &"shotgun":
			weapon._fire_full_volley(Vector2.RIGHT, false)
		else:
			weapon._fire(Vector2.RIGHT, false)
		check(world.shots.size() == int(parameters.pellets), String(weapon_id) + " player pellet count")
		var player_data: Array[float] = []
		for shot in world.shots:
			check(shot.source_faction == &"player", "player projectile faction")
			player_data = [shot.damage, shot.max_distance, shot.speed]
		world.clear_shots()
		enemy.equip_weapon(String(weapon_id))
		enemy.pickup_pause_left = 0.0
		enemy.reload_left = 0.0
		var ammo_before: int = enemy.current_ammo
		enemy._fire_held_weapon()
		check(enemy.current_ammo == ammo_before - 1, String(weapon_id) + " enemy consumes one round per volley")
		check(world.shots.size() == int(parameters.pellets), String(weapon_id) + " enemy pellet count")
		check(is_equal_approx(enemy.attack_cooldown_left, weapon.attack_interval), String(weapon_id) + " enemy and unupgraded player cadence agree")
		for shot in world.shots:
			check(shot.source_faction == &"enemy", "enemy projectile faction")
			check([shot.damage, shot.max_distance, shot.speed] == player_data, String(weapon_id) + " enemy/player damage, range and speed agree")
		world.clear_shots()
		weapon.free()
	var shotgun := SHOTGUN.new()
	shooter.add_child(shotgun)
	shotgun.configure_weapon(config, {})
	shotgun.set_process(false)
	shotgun.active = true
	shotgun.cooldown_left = 0.0
	shooter.pressed = true
	shotgun._process(0.001)
	check(world.shots.size() == shotgun.pellet_count and shooter.ammo == 99, "shotgun fires on press without waiting for release")
	shotgun._process(0.01)
	check(shooter.ammo == 99, "shotgun respects fire interval while held")
	shotgun._process(shotgun.attack_interval)
	check(world.shots.size() == 2 * shotgun.pellet_count and shooter.ammo == 98, "held shotgun repeats at existing cadence")
	shooter.pressed = false
	shotgun._process(shotgun.attack_interval)
	check(shooter.ammo == 98, "release does not queue an extra shotgun volley")
	shooter.pressed = true
	shooter.ammo = 0
	shotgun._process(0.01)
	check(world.shots.size() == 2 * shotgun.pellet_count and shooter.ammo == 0, "empty shotgun cannot create projectiles")
	check(not shotgun.has_method("cancel_charge") and shotgun.get_node_or_null("ShotgunChargeVisual") == null, "shotgun charge API removed")
	world.clear_shots()
	shotgun.free()
	# Seeded volleys must cover every sector without escaping the total cone.
	var random := RandomNumberGenerator.new()
	random.seed = 1973
	for volley in range(20):
		var rays := RULES.directions(Vector2.RIGHT, 9, 30.0, random)
		for index in range(rays.size()):
			var degrees := rad_to_deg(rays[index].angle())
			check(degrees >= -15.0 + index * (30.0 / 9.0) - 0.001 and degrees <= -15.0 + (index + 1) * (30.0 / 9.0) + 0.001, "shotgun sector coverage")
	world.free()
	preload("res://scripts/audio/sfx_manager.gd").stop_event(&"gunshot")
	preload("res://scripts/audio/sfx_manager.gd").stop_event(&"weapon_dry_fire")
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	print("Shared firearm rules: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
