extends SceneTree

const BULLET := preload("res://scenes/entities/basic_projectile.tscn")
var failures := 0
var checks := 0

class Victim extends StaticBody2D:
	var hits := 0
	func receive_damage(_damage: float, _kind: StringName, _position: Vector2, _direction: Vector2) -> void:
		hits += 1

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func bullet(position: Vector2 = Vector2.ZERO) -> Node2D:
	var shot: Node2D = BULLET.instantiate()
	root.add_child(shot)
	shot.set_physics_process(false)
	shot.position = position
	shot.setup(Vector2.RIGHT, 10, 2000, 1500, &"enemy")
	shot.enable_office_ballistics()
	return shot

func run() -> void:
	# Formal world registration opts in before _ready creates the shader.
	var newborn: Node2D = BULLET.instantiate()
	newborn.setup(Vector2.RIGHT, 10, 2000, 1500, &"enemy")
	newborn.enable_office_ballistics()
	root.add_child(newborn)
	newborn.set_physics_process(false)
	var newborn_sprite := newborn.get_node("BulletSprite") as Sprite2D
	var head_uv: Vector2 = (-(newborn_sprite.position / newborn_sprite.scale) + Vector2(.5, .5)) / newborn_sprite.texture.get_size()
	check((newborn_sprite.material as ShaderMaterial).get_shader_parameter(&"head_uv").is_equal_approx(head_uv), "birth glow follows the actual dynamic head anchor")
	newborn.queue_free()
	var shot := bullet()
	var sprite := shot.get_node("BulletSprite") as Sprite2D
	check(shot._trail_history.is_empty(), "birth contains no fictitious muzzle travel")
	for index in 10:
		shot._physics_process(0.01)
	check(shot._trail_history.size() <= shot.MAX_TRAIL_SAMPLES, "bounded history")
	check(absf(shot._trail_history[0].time - 0.04) < 0.0001, "exact interpolated time cutoff")
	check(absf(shot.global_position.x - shot._trail_history[0].position.x - 90) < 0.01, "full 90px trail rather than one tick")
	var head_pixel := -sprite.position / sprite.scale
	check(sprite.texture.get_image().get_pixelv(Vector2i(head_pixel)).a > 0.99, "opaque head stays at gameplay root")
	shot.queue_free()
	var slow := bullet(Vector2(0, 100))
	for index in 1500:
		slow._physics_process(0.00005)
	check(slow._trail_history.size() <= slow.MAX_TRAIL_SAMPLES, "extreme slow motion retains bounded memory")
	check(absf(slow._trail_clock - slow._trail_history[0].time - 0.06) < 0.0001, "slow motion preserves full game-time window")
	check(absf(slow.global_position.x - slow._trail_history[0].position.x - 90) < 0.02, "slow motion preserves full spatial trail")
	# Turning does not rotate already recorded world history behind the head.
	var old_point: Vector2 = slow._trail_history[0].position
	slow.direction = Vector2.DOWN
	slow._physics_process(0.001)
	check(slow._trail_history[1].position.y < slow.global_position.y, "turn records earlier world positions")
	check(old_point.y == 100, "history remains in world coordinates")
	slow.queue_free()
	var victim := Victim.new()
	victim.position = Vector2(35, 300)
	victim.collision_layer = 1
	victim.collision_mask = 0
	victim.add_to_group(&"dream_player")
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2, 20)
	shape.shape = rectangle
	victim.add_child(shape)
	root.add_child(victim)
	await physics_frame
	await physics_frame
	var hit := bullet(Vector2(0, 300))
	hit._physics_process(0.04)
	check(hit.consumed and victim.hits == 1, "fast swept bullet stops and hits once")
	var endpoint: Vector2 = hit.global_position
	check(endpoint.x < 35 and endpoint.x > 30, "tail stops at actual blocking contact")
	check(not hit.is_in_group(&"active_basic_projectiles"), "visual remnant leaves gameplay groups")
	check(is_zero_approx(float((hit.get_node("BulletSprite").material as ShaderMaterial).get_shader_parameter(&"glow_strength"))), "hit removes the projectile head halo")
	check(not hit.is_queued_for_deletion(), "terminal trail remains briefly")
	hit._physics_process(0.02)
	hit._handle_collision(victim)
	check(victim.hits == 1 and hit.global_position == endpoint, "terminal fade cannot move or damage")
	check(hit.get_node("BulletSprite").modulate.a < 1, "terminal trail fades")
	hit._physics_process(0.02)
	check(hit.is_queued_for_deletion(), "terminal presentation expires after 40ms")
	print("PROJECTILE HISTORY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
