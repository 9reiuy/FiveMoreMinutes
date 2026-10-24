extends SceneTree
const WEAPON := preload("res://scripts/dream/lucille_weapon.gd")
const SWEEP := preload("res://scripts/dream/melee_sweep.gd")
const CONFIG := preload("res://resources/demo_config.tres")
var checks := 0
var failures: Array[String] = []

class Actor extends CharacterBody2D:
	var dead := false
	var dashing := false
	var kick_active := false
	var vault_active := false
	var airborne_knockback := false
	var movement_enabled := true
	var attacking_enabled := true
	var selected_weapon_id := "lucille"
	var last_aim_direction := Vector2.RIGHT
	var aim := Vector2.RIGHT
	var snapshots: Array[Dictionary] = []
	var finished := 0
	func get_constrained_aim_position() -> Vector2: return global_position + aim * 100.0
	func should_trigger_weapon_attack() -> bool: return false
	func apply_melee_swing_snapshot(snapshot: Dictionary) -> void: snapshots.append(snapshot)
	func finish_melee_swing_snapshot() -> void: finished += 1

class Enemy extends Node2D:
	var dead := false
	var hits := 0
	var health := 1000.0
	func take_damage(amount: float) -> void:
		health -= amount
		hits += 1

class Prop extends StaticBody2D:
	var category := 3
	var hits := 0
	func get_size_category() -> int: return category
	func take_damage(_amount: float, _direction: Vector2, _multiplier: float) -> void: hits += 1

class World extends Node3D:
	var enemies: Array = []
	var _layout_generation := 1
	var door_impacts := 0
	func get_dream_enemies_snapshot() -> Array: return enemies
	func resolve_player_hit(enemy: Node, amount: float, _origin: Vector2, _source: StringName) -> Dictionary:
		enemy.take_damage(amount)
		return {"damage": amount}
	func resolve_door_impact_from_collision(_door: Node, _point: Vector2, _direction: Vector2, _force: float, _source: StringName, _owner: int) -> bool:
		door_impacts += 1
		return true

var world: World
var actor: Actor
var weapon: Node
var feedback_count := 0

func _init() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL ", label)

func enemy_at(point: Vector2) -> Enemy:
	var enemy := Enemy.new()
	world.add_child(enemy)
	enemy.position = point
	world.enemies.append(enemy)
	return enemy

func obstacle(point: Vector2, size: Vector2, category: int = -1) -> StaticBody2D:
	var body: StaticBody2D = Prop.new() if category >= 0 else StaticBody2D.new()
	body.collision_layer = 8 if category >= 0 else 4
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	shape.name = "CollisionShape2D"
	body.add_child(shape)
	world.add_child(body)
	body.position = point
	if category >= 0:
		body.category = category
		body.add_to_group(&"damageable_props")
	return body

func reset(kind := "lucille") -> void:
	weapon.cancel_swing()
	for enemy in world.enemies:
		if is_instance_valid(enemy): enemy.free()
	world.enemies.clear()
	actor.position = Vector2.ZERO
	actor.aim = Vector2.RIGHT
	actor.selected_weapon_id = kind
	actor.dead = false
	actor.dashing = false
	actor.kick_active = false
	actor.vault_active = false
	actor.airborne_knockback = false
	actor.movement_enabled = true
	actor.attacking_enabled = true
	weapon.weapon_id = kind
	weapon.configure_weapon(CONFIG, {})
	weapon.active = true
	feedback_count = 0

func full_swing(delta := 1.0 / 60.0) -> void:
	weapon._perform_swing(false)
	for step in ceili(0.30 / delta): weapon._physics_process(delta)

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	world = World.new()
	root.add_child(world)
	world.add_to_group(&"dream_world")
	actor = Actor.new()
	world.add_child(actor)
	weapon = WEAPON.new()
	actor.add_child(weapon)
	weapon.set_process(false)
	weapon.set_physics_process(false)
	weapon.melee_impact.connect(func(_hit: bool) -> void: feedback_count += 1)
	await physics_frame
	reset()
	check(weapon.attack_range == 80 and is_equal_approx(weapon.attack_arc_radians, deg_to_rad(160)), "bat unified to 80px/160 degrees")
	check(weapon.damage == CONFIG.lucille_damage and weapon.attack_interval == CONFIG.weapon_interval_for_rate(CONFIG.lucille_attack_interval), "bat damage/cadence preserved")
	reset("books")
	check(weapon.attack_range == 80 and is_equal_approx(weapon.attack_arc_radians, deg_to_rad(150)), "books unified to 80px/150 degrees")
	check(weapon.damage == CONFIG.books_damage and weapon.attack_interval == CONFIG.weapon_interval_for_rate(CONFIG.books_attack_interval), "books damage/cadence preserved")
	check(CONFIG.lucille_attack_range == 30 and CONFIG.books_attack_range == 30, "enemy reach remains unchanged")
	check(CONFIG.player_punch_range == 30 and CONFIG.kick_range == 34, "punch and kick unchanged")
	for direction_index in 8:
		reset()
		actor.aim = Vector2.RIGHT.rotated(direction_index * PI / 4.0)
		var front := enemy_at(actor.aim * 79)
		var side := enemy_at(actor.aim.rotated(deg_to_rad(65)) * 78)
		var rear := enemy_at(-actor.aim * 30)
		var far := enemy_at(actor.aim * 81)
		full_swing()
		check(front.hits == 1 and side.hits == 1, "eight-way forward and side swept once %d" % direction_index)
		check(rear.hits == 0 and far.hits == 0, "eight-way rear/out-of-range rejected %d" % direction_index)
		check(feedback_count == 1, "one aggregate feedback for multiple targets %d" % direction_index)
	for delta in [1.0/120.0, 1.0/60.0, 1.0/30.0, 0.20]:
		reset()
		for angle in range(-75, 76, 5): enemy_at(Vector2(78, 0).rotated(deg_to_rad(angle)))
		full_swing(delta)
		check(world.enemies.all(func(enemy: Enemy) -> bool: return enemy.hits == 1), "no skipped angular slices at step %s" % delta)
	reset()
	var early := enemy_at(Vector2(78,0).rotated(deg_to_rad(-60)))
	var late := enemy_at(Vector2(78,0).rotated(deg_to_rad(65)))
	weapon._perform_swing(false)
	weapon._physics_process(.03)
	check(early.hits == 0 and late.hits == 0, "windup does not damage")
	weapon._physics_process(.03)
	check(early.hits == 1 and late.hits == 0, "only traversed part of arc damages")
	actor.aim = Vector2.LEFT
	weapon._physics_process(.08)
	check(weapon.swing_direction.is_equal_approx(Vector2.RIGHT) and late.hits == 1, "strike facing locks despite cursor reversal")
	reset()
	weapon._perform_swing(false)
	actor.aim = Vector2.DOWN
	weapon._physics_process(.02)
	check(weapon.swing_direction.is_equal_approx(Vector2.DOWN), "windup can still correct aim")
	reset()
	var moving := enemy_at(Vector2(100,0))
	weapon._perform_swing(false)
	actor.position = Vector2(22,0)
	weapon._physics_process(.20)
	check(moving.hits == 1 and actor.position == Vector2(22,0), "sweep follows real movement without forcing a lunge")
	for state in ["dashing", "kick_active", "vault_active", "airborne_knockback", "dead"]:
		reset()
		var target := enemy_at(Vector2(45,0))
		weapon._perform_swing(false)
		actor.set(state, true)
		weapon._physics_process(.20)
		check(target.hits == 0 and not weapon.melee_action_active, "cancel on " + state)
	reset()
	var swap_target := enemy_at(Vector2(45,0))
	weapon._perform_swing(false)
	actor.selected_weapon_id = "basic"
	weapon._physics_process(.20)
	check(swap_target.hits == 0 and not weapon.melee_action_active, "switch cancels deferred damage")
	reset()
	var next_floor_target := enemy_at(Vector2(45,0))
	weapon._perform_swing(false)
	world._layout_generation += 1
	weapon._physics_process(.20)
	check(next_floor_target.hits == 0 and not weapon.melee_action_active, "new floor token cancels an old in-flight swing")
	reset()
	var wall := obstacle(Vector2(25,0), Vector2(6,100))
	await physics_frame
	await physics_frame
	var behind := enemy_at(Vector2(45,0))
	full_swing()
	check(behind.hits == 0, "solid wall/closed-door layer blocks enemies")
	check(weapon._trace_reach(actor, Vector2.ZERO, Vector2(80,0)) < 25, "80px visual ray still clips at wall")
	wall.free()
	await physics_frame
	reset()
	var door := obstacle(Vector2(25,0), Vector2(6,100))
	door.set_meta(&"physical_door", true)
	await physics_frame
	await physics_frame
	var through_door := enemy_at(Vector2(45,0))
	full_swing()
	check(world.door_impacts == 1 and through_door.hits == 0, "closed door is struck once while shielding enemy")
	door.free()
	await physics_frame
	for category in [2, 3]:
		reset()
		var prop := obstacle(Vector2(24,0), Vector2(8,100), category)
		await physics_frame
		await physics_frame
		var target := enemy_at(Vector2(45,0))
		full_swing()
		check(prop.hits == 1, "obstructing furniture itself is hit once category %d" % category)
		check(target.hits == (1 if category == 2 else 0), "low cover passes / high cabinet blocks category %d" % category)
		prop.free()
		await physics_frame
	reset("books")
	var near_book := enemy_at(Vector2(79,0))
	var far_book := enemy_at(Vector2(81,0))
	full_swing()
	check(near_book.hits == 1 and far_book.hits == 0, "books use the same exact 80px boundary")
	reset()
	var interval: float = weapon.attack_interval
	weapon.apply_attack_speed_upgrade(2.0)
	check(is_equal_approx(weapon.attack_interval, interval/2) and is_equal_approx(weapon.strike_seconds, .05), "attack-speed upgrade scales damage and visual clock together")
	weapon.apply_range_upgrade(12)
	check(weapon.attack_range == 92, "range upgrades retained")
	check(is_equal_approx(SWEEP.strike_progress(.14,.04,.10),1.0), "shared sweep reaches its exact terminal angle")
	print("MELEE_SWEEP checks=", checks, " failures=", failures.size())
	world.free()
	for index in 4: await process_frame
	quit(0 if failures.is_empty() else 1)
