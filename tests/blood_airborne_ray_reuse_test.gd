extends SceneTree
const BLOOD = preload("res://scripts/entities/black_blood_effect.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4, 100)
	shape.shape = rectangle
	wall.add_child(shape)
	root.add_child(wall)
	wall.position = Vector2(50, 0)
	var blood := BLOOD.new()
	root.add_child(blood)
	blood.set_process(false)
	await physics_frame
	await physics_frame
	for position_index in 2:
		wall.position = Vector2(50 + 40 * position_index, 0)
		await physics_frame
		await physics_frame
		for mask in [1, 2, 3]:
			blood.wall_collision_mask = mask
			for offset in [Vector2.ZERO, Vector2(7, -12)]:
				blood.position = offset
				for endpoint in [Vector2(100, 0), Vector2(20, 0), Vector2(100, 80), Vector2.ZERO]:
					blood.set_meta(&"test_legacy_airborne_ray_query", true)
					var baseline: Dictionary = blood._raycast_environment(Vector2.ZERO, endpoint)
					blood.set_meta(&"test_legacy_airborne_ray_query", false)
					var current: Dictionary = blood._raycast_environment(Vector2.ZERO, endpoint)
					check(current == baseline, "Ray hit, geometry and mask parity %d %d %s %s" % [position_index, mask, offset, endpoint])
	var reused_query: PhysicsRayQueryParameters2D = blood._airborne_wall_query
	blood._raycast_environment(Vector2.ZERO, Vector2(100, 0))
	check(reused_query == blood._airborne_wall_query, "Droplet calls retain one per-effect query")
	wall.free()
	blood.free()
	print("Airborne ray reuse: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
