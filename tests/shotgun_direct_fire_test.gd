extends SceneTree

const WEAPON := preload("res://scripts/dream/shotgun_weapon.gd")
const PLAYER := preload("res://scenes/entities/dream_player.tscn")
const CONFIG := preload("res://resources/demo_config.tres")

class ShotWorld extends Node2D:
	var shots: Array[Node2D] = []
	var shells := 0
	var muzzles := 0
	func add_projectile(projectile: Node2D, _shooter: Node2D) -> void:
		add_child(projectile)
		projectile.set_physics_process(false)
		shots.append(projectile)
	func spawn_weapon_muzzle(_origin: Vector2, _direction: Vector2, _kind: StringName, _shooter: Node2D) -> void:
		muzzles += 1
	func spawn_shell_ejection(_origin: Vector2, _direction: Vector2, _kind: StringName) -> void:
		shells += 1

class Shooter extends Node2D:
	var dead := false
	var pressed := false
	var ammo := 20
	func should_trigger_weapon_attack() -> bool:
		return pressed
	func is_weapon_empty_for_attack() -> bool:
		return ammo <= 0
	func try_consume_ammo_for_attack() -> bool:
		if ammo <= 0:
			return false
		ammo -= 1
		return true
	func get_projectile_origin() -> Vector2:
		return global_position
	func get_aim_direction() -> Vector2:
		return Vector2.RIGHT

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
	var world := ShotWorld.new()
	root.add_child(world)
	world.add_to_group(&"dream_world")
	var shooter := Shooter.new()
	world.add_child(shooter)
	var weapon := WEAPON.new()
	shooter.add_child(weapon)
	weapon.set_process(false)
	weapon.configure_weapon(CONFIG, {})
	weapon.active = true
	var fired := [0]
	weapon.weapon_fired.connect(func(_recoil: float): fired[0] += 1)
	shooter.pressed = true
	weapon._process(0.0)
	check(fired[0] == 1, "first press fires without a charge or initial wait")
	check(world.shots.size() == CONFIG.shotgun_pellet_count, "one normal volley on press")
	check(shooter.ammo == 19 and world.shells == 1 and world.muzzles == 1, "one ammo, shell and muzzle per volley")
	weapon._process(weapon.attack_interval * .5)
	check(fired[0] == 1, "held fire respects cooldown")
	weapon._process(weapon.attack_interval * .5 + .0001)
	check(fired[0] == 2, "held fire repeats at authored cadence")
	check(shooter.ammo == 18, "continuous fire consumes one ammo per shot")
	shooter.pressed = false
	weapon._process(weapon.attack_interval * 2.0)
	check(fired[0] == 2, "release does not produce a charged or queued shot")
	shooter.pressed = true
	weapon._process(0.0)
	check(fired[0] == 3, "ready weapon fires on next press")
	weapon.active = false
	weapon._process(weapon.attack_interval * 2.0)
	check(fired[0] == 3, "disabled weapon cannot fire")
	weapon.active = true
	weapon.cooldown_left = 0.0
	shooter.ammo = 0
	weapon._process(0.0)
	check(fired[0] == 3, "empty shotgun has no volley or recoil signal")
	check(not weapon.has_method("cancel_charge"), "charge API completely removed")
	var charge_state: Array[String] = []
	for property in weapon.get_property_list():
		if "charge" in String(property.name):
			charge_state.append(String(property.name))
	check(charge_state.is_empty(), "no charge state remains")
	var charge_settings: Array[String] = []
	for property in CONFIG.get_property_list():
		var property_name := String(property.name)
		if property_name.begins_with("shotgun_") and "charg" in property_name:
			charge_settings.append(property_name)
	check(charge_settings.is_empty(), "no shotgun charge tuning remains")
	var player := PLAYER.instantiate()
	check(player.get_node_or_null("WeaponRoot/HandAnchor/WeaponMotion/ShotgunChargeVisual") == null, "player scene has no charge visual")
	player.free()
	world.queue_free()
	await process_frame
	print("Shotgun direct fire: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
