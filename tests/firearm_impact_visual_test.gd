extends SceneTree

const BULLET := preload("res://scenes/entities/basic_projectile.tscn")
const IMPACT := preload("res://scenes/dream/3d/FirearmImpactVisual3D.tscn")

class ImpactWorld3D extends Node3D:
	var calls := 0
	var captured_position := Vector2.ZERO
	var captured_normal := Vector2.ZERO
	var captured_collider: Node
	var captured_height := -1.0

	func _ready() -> void:
		add_to_group(&"dream_world")

	func spawn_firearm_impact_visual(position_2d: Vector2, normal_2d: Vector2, collider: Node, height: float) -> void:
		calls += 1
		captured_position = position_2d
		captured_normal = normal_2d
		captured_collider = collider
		captured_height = height


class LegacyWorld2D extends Node2D:
	var calls := 0

	func _ready() -> void:
		add_to_group(&"dream_world")

	func spawn_firearm_impact_visual(_position_2d: Vector2, _normal_2d: Vector2, _collider: Node, _height: float) -> void:
		calls += 1


var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL ", label)


func _run() -> void:
	for kind: StringName in [&"metal", &"glass", &"solid", &"soft"]:
		var effect := IMPACT.instantiate() as Node3D
		root.add_child(effect)
		effect.call("setup", Vector3.LEFT, kind)
		var particles := effect.get_node("ImpactPixels") as CPUParticles3D
		# One-shot particles may turn `emitting` off in the same render tick.
		_check(particles != null and particles.one_shot, "%s uses one-shot emitter" % kind)
		_check(particles.amount > 0 and particles.amount <= 6, "%s bounded particle count" % kind)
		_check(particles.direction.is_equal_approx(Vector3.LEFT), "%s normal retained" % kind)
		_check(not particles.mesh.surface_get_material(0).no_depth_test, "%s depth test retained" % kind)
		effect.call("_process", 0.35)
		_check(effect.is_queued_for_deletion(), "%s cleans up" % kind)
		await process_frame
	var world := ImpactWorld3D.new()
	root.add_child(world)
	var collider := StaticBody2D.new()
	collider.set_meta(&"physical_door", true)
	world.add_child(collider)
	var bullet := BULLET.instantiate() as Node2D
	world.add_child(bullet)
	bullet.set_physics_process(false)
	bullet.global_position = Vector2(12.0, 34.0)
	bullet.set_meta(&"shot_height_pixels", 28.0)
	bullet.call("_handle_collision", collider, Vector2.LEFT)
	_check(world.calls == 1, "3D hit emits exactly one callback")
	_check(world.captured_position.is_equal_approx(Vector2(12.0, 34.0)), "2D collision point preserved")
	_check(world.captured_normal.is_equal_approx(Vector2.LEFT), "2D hit normal preserved")
	_check(world.captured_collider == collider, "collider identity preserved")
	_check(is_equal_approx(world.captured_height, 28.0), "shot-height snapshot preserved")
	_check(bullet.consumed, "existing door terminal collision remains")
	world.free()
	var legacy := LegacyWorld2D.new()
	root.add_child(legacy)
	var legacy_collider := StaticBody2D.new()
	legacy_collider.set_meta(&"physical_door", true)
	legacy.add_child(legacy_collider)
	var legacy_bullet := BULLET.instantiate() as Node2D
	legacy.add_child(legacy_bullet)
	legacy_bullet.set_physics_process(false)
	legacy_bullet.call("_handle_collision", legacy_collider, Vector2.RIGHT)
	_check(legacy.calls == 0, "legacy 2D world never gets 3D impact callback")
	_check(legacy_bullet.consumed, "legacy 2D collision remains terminal")
	legacy.free()
	print("Firearm impact checks: ", checks, " failures: ", failures.size())
	for failure in failures:
		print("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)
