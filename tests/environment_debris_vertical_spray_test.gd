extends SceneTree
## Real debris scene and native 2D wall collision; stationary planar motion must
## keep integrating height and ground safety without issuing zero-length rays.
const DEBRIS_SCENE := preload("res://scenes/entities/environment_debris.tscn")
class World extends Node2D:
	var config: Resource
	var room_queries := 0
	var safety_queries := 0
	var exterior_queries := 0
	var reassignments := 0
	var next_room := 7
	var allowed := true
	func resolve_environment_debris_room_id(_point: Vector2, _fallback: int) -> int:
		room_queries += 1
		return next_room
	func is_environment_debris_position_allowed(_point: Vector2, _room: int, _source: Node2D) -> bool:
		safety_queries += 1
		return allowed
	func can_fall_through_exterior(_from: Vector2, _to: Vector2) -> bool:
		exterior_queries += 1
		return false
	func reassign_environment_debris_room(_debris: Node2D) -> void:
		reassignments += 1
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func make_debris(world: World, velocity: Vector2, up: float) -> EnvironmentDebris:
	var debris: EnvironmentDebris = DEBRIS_SCENE.instantiate()
	world.add_child(debris)
	debris.setup(0,world,3,Vector2.ZERO,velocity,up)
	debris.set_physics_process(false)
	return debris
func land(debris: EnvironmentDebris) -> float:
	var peak := debris.fake_height
	for tick in 300:
		if debris.settled: break
		debris._physics_process(1.0/120)
		peak = maxf(peak,debris.fake_height)
	return peak
func run() -> void:
	var world := World.new()
	root.add_child(world)
	var upward := make_debris(world,Vector2.ZERO,60)
	check(not upward.settled,"vertical-only production debris starts airborne")
	upward._physics_process(0)
	check(upward._sweep_query == null and not upward.settled,"zero-delta airborne tick creates no degenerate ray")
	var peak := land(upward)
	check(peak > 3 and upward.settled and upward.fake_height == 0 and upward.sprite.position.y == 0,"zero horizontal velocity still rises and lands")
	check(upward.global_position == Vector2.ZERO and upward._sweep_query == null,"vertical-only spray never allocates or calls a planar ray")
	check(world.room_queries > 1 and world.safety_queries > 1 and world.exterior_queries > 1 and upward.room_id == 7,"stationary planar motion still runs room, ground and exterior validation")
	check(world.reassignments == 1 and not upward.is_physics_processing(),"vertical landing reassigns once and stops physics")
	upward.free()
	var dragged := make_debris(world,Vector2(5,0),60)
	dragged._physics_process(1.0/60)
	check(dragged.spray_velocity == Vector2.ZERO and dragged.fake_height > 0 and not dragged.settled,"drag stops planar motion before vertical flight ends")
	var ray_from: Vector2 = dragged._sweep_query.from
	var ray_to: Vector2 = dragged._sweep_query.to
	var dragged_point := dragged.global_position
	land(dragged)
	check(dragged.settled and dragged.global_position == dragged_point,"drag-stopped debris continues landing at its last ground point")
	check(ray_from != ray_to and dragged._sweep_query.from == ray_from and dragged._sweep_query.to == ray_to,"drag-stopped vertical frames never overwrite the last ray with a zero-length ray")
	dragged.free()
	var wall := StaticBody2D.new()
	wall.position = Vector2(20,0)
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2,100)
	shape.shape = rectangle
	wall.add_child(shape)
	world.add_child(wall)
	await physics_frame
	var moving := make_debris(world,Vector2(120,0),100)
	moving._physics_process(.25)
	check(is_equal_approx(moving.global_position.x,17) and moving.spray_velocity == Vector2.ZERO,"normal horizontal spray still hits the real wall and stops two pixels before it")
	check(moving.fake_height > 0 and not moving.settled,"wall contact does not cancel remaining vertical motion")
	ray_from = moving._sweep_query.from
	ray_to = moving._sweep_query.to
	land(moving)
	check(moving.settled and is_equal_approx(moving.global_position.x,17),"wall-stopped fragment finishes landing without crossing the wall")
	check(moving._sweep_query.from == ray_from and moving._sweep_query.to == ray_to and ray_from != ray_to,"post-wall vertical flight never submits a zero-length ray")
	moving.free()
	var unsafe := make_debris(world,Vector2.ZERO,60)
	unsafe._physics_process(1.0/60)
	world.allowed = false
	unsafe._physics_process(1.0/60)
	check(unsafe.settled and unsafe.fake_height == 0 and unsafe._sweep_query == null,"stationary airborne fragment still obeys changed floor safety")
	unsafe.free()
	world.allowed = true
	var no_room := make_debris(world,Vector2.ZERO,60)
	world.next_room = -1
	no_room._physics_process(1.0/60)
	check(no_room.settled and no_room._sweep_query == null,"stationary airborne fragment still rejects invalid room membership")
	world.free()
	await process_frame
	print("ENVIRONMENT_DEBRIS_VERTICAL_SPRAY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
