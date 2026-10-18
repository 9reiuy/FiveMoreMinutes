extends "res://tests/firearm_shared_rules_test.gd"

class InputShooter extends Node2D:
	var dead := false
	var pressed := true
	var ammo := 30
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

func _run() -> void:
	seed(31415)
	var world := ShotWorld.new()
	root.add_child(world)
	world.add_to_group(&"dream_world")
	var shooter := InputShooter.new()
	world.add_child(shooter)
	var weapon := RIFLE.new()
	shooter.add_child(weapon)
	weapon.configure_weapon(CONFIG, {})
	weapon.set_process(false)
	weapon.active = true
	var widest_first_shot := 0.0
	for index in 64:
		weapon.active = false
		weapon.active = true
		weapon._fire(Vector2.RIGHT, false)
		var offset := absf(rad_to_deg(world.shots.back().direction.angle()))
		widest_first_shot = maxf(widest_first_shot, offset)
		check(offset <= 1.0001, "first shot stays within the 2-degree cone")
		check(is_equal_approx(weapon.current_spread_degrees, 3.0), "real shot adds one degree")
		world.clear_shots()
	check(widest_first_shot > .5, "real projectiles use random spread rather than perfect aim")
	weapon.active = false
	weapon.active = true
	for index in 8:
		var spread_before: float = weapon.current_spread_degrees
		weapon._fire(Vector2.RIGHT, false)
		var offset := absf(rad_to_deg(world.shots.back().direction.angle()))
		check(offset <= spread_before * .5 + .0001, "burst projectile respects its current cone")
		check(is_equal_approx(weapon.current_spread_degrees, minf(6.0, spread_before + 1.0)), "burst reaches and stays at 6 degrees")
	weapon.cooldown_left = 10.0
	weapon._process(.125)
	check(is_equal_approx(weapon.current_spread_degrees, 6.0), "held trigger retains burst spread during cooldown")
	shooter.pressed = false
	weapon._process(.125)
	check(is_equal_approx(weapon.current_spread_degrees, 4.0), "half recovery after 0.125 seconds")
	weapon._process(.125)
	check(is_equal_approx(weapon.current_spread_degrees, 2.0), "full recovery after 0.25 seconds")
	weapon._process(1.0)
	check(is_equal_approx(weapon.current_spread_degrees, 2.0), "recovery does not undershoot base spread")
	world.clear_shots()
	shooter.ammo = 0
	shooter.pressed = true
	weapon.cooldown_left = 0.0
	weapon._process(.001)
	check(world.shots.is_empty() and is_equal_approx(weapon.current_spread_degrees, 2.0), "empty rifle creates no projectile or spread growth")
	weapon.set_extra_attack(1.0, .001)
	weapon._fire(Vector2.RIGHT, true)
	await create_timer(.03).timeout
	check(world.shots.size() == 2, "extra attack emits two real projectiles")
	check(is_equal_approx(weapon.current_spread_degrees, 4.0), "extra attack also contributes spread")
	check(absf(rad_to_deg(world.shots.back().direction.angle())) <= 1.5001, "extra attack uses the next bounded cone")
	world.clear_shots()
	weapon.active = false
	check(is_equal_approx(weapon.current_spread_degrees, 2.0), "weapon deactivation resets spread")
	weapon.active = true
	weapon._fire(Vector2.RIGHT, true)
	weapon.active = false
	await create_timer(.03).timeout
	check(world.shots.size() == 1, "deactivated rifle cancels delayed extra attack")
	weapon.current_spread_degrees = 6.0
	weapon.configure_weapon(CONFIG, {})
	check(is_equal_approx(weapon.current_spread_degrees, 2.0), "configuration resets spread")
	world.queue_free()
	await process_frame
	print("Player rifle spread: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
