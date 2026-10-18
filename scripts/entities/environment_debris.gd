extends Area2D
class_name EnvironmentDebris

## Lightweight 2D ground debris.  The sprite stays in the room's
## GroundDebrisRoot; only spray debris runs physics until it settles.

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var owner_world: Node
var room_id := -1
var source_prop: Node2D
var spray_velocity := Vector2.ZERO
var vertical_velocity := 0.0
var fake_height := 0.0
var debris_gravity := 240.0
var drag := 420.0
var settled := true
var breaking := false
var _sweep_query: PhysicsRayQueryParameters2D


func _ready() -> void:
	add_to_group(&"environment_debris")
	body_entered.connect(_on_body_entered)
	set_physics_process(false)


## Called by DreamWorld after the instance has been added to the room's ground
## debris root.  All 42 atlas cells are kept in one texture; each instance
## stores only its frame index.
func setup(
	frame_index: int,
	world: Node,
	initial_room_id: int,
	ground_position: Vector2,
	initial_velocity: Vector2 = Vector2.ZERO,
	initial_up_velocity: float = 0.0,
	initial_source_prop: Node2D = null
) -> void:
	owner_world = world
	room_id = initial_room_id
	source_prop = initial_source_prop
	global_position = ground_position
	sprite.frame = clampi(frame_index, 0, 41)
	sprite.rotation = [0.0, PI * 0.5, PI, PI * 1.5][randi_range(0, 3)]
	debris_gravity = _world_float_config(&"environment_debris_spray_gravity", debris_gravity)
	drag = _world_float_config(&"environment_debris_spray_drag", drag)
	spray_velocity = initial_velocity
	vertical_velocity = maxf(initial_up_velocity, 0.0)
	fake_height = 0.0
	settled = spray_velocity.length_squared() < 0.01 and vertical_velocity <= 0.01
	sprite.position.y = 0.0
	set_physics_process(not settled)


func _physics_process(delta: float) -> void:
	if breaking or settled:
		return

	var next_ground := global_position + spray_velocity * delta
	if _sweep_query == null:
		_sweep_query = PhysicsRayQueryParameters2D.new()
		_sweep_query.collision_mask = 1 | 4
		_sweep_query.collide_with_bodies = true
		_sweep_query.collide_with_areas = false
	_sweep_query.from = global_position
	_sweep_query.to = next_ground
	var hit := get_world_2d().direct_space_state.intersect_ray(_sweep_query)
	if not hit.is_empty():
		next_ground = Vector2(hit.position) + Vector2(hit.normal) * 2.0
		spray_velocity = Vector2.ZERO
	if not is_instance_valid(source_prop):
		source_prop = null
	var next_room := room_id
	if owner_world != null and owner_world.has_method("resolve_environment_debris_room_id"):
		next_room = int(owner_world.call("resolve_environment_debris_room_id", next_ground, room_id))
	if next_room < 0 or (
		owner_world != null
		and owner_world.has_method("is_environment_debris_position_allowed")
		and not bool(owner_world.call("is_environment_debris_position_allowed", next_ground, next_room, source_prop))
	):
		# The last valid point is the settled point.  This keeps spray from
		# crossing a wall/closed door while still allowing an open-door path.
		spray_velocity = Vector2.ZERO
		vertical_velocity = 0.0
		fake_height = 0.0
		_settle()
		return

	room_id = next_room
	global_position = next_ground
	spray_velocity = spray_velocity.move_toward(Vector2.ZERO, drag * delta)
	vertical_velocity -= debris_gravity * delta
	fake_height += vertical_velocity * delta
	sprite.position.y = -maxf(fake_height, 0.0)
	sprite.rotation += spray_velocity.length() * delta * 0.02

	if fake_height <= 0.0 and vertical_velocity <= 0.0:
		fake_height = 0.0
		_settle()


func _settle() -> void:
	if settled:
		return
	settled = true
	spray_velocity = Vector2.ZERO
	vertical_velocity = 0.0
	fake_height = 0.0
	sprite.position.y = 0.0
	set_physics_process(false)
	if owner_world != null and owner_world.has_method("reassign_environment_debris_room"):
		owner_world.call("reassign_environment_debris_room", self)


func _on_body_entered(body: Node) -> void:
	if breaking or body == null or not body.is_in_group(&"dream_player"):
		return
	break_debris()


func break_debris() -> void:
	if breaking:
		return
	breaking = true
	settled = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	var duration := _world_float_config(&"environment_debris_break_duration", 0.12)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.35, 0.35), duration)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, duration)
	tween.tween_callback(queue_free)


func _world_float_config(property_name: StringName, fallback: float) -> float:
	if owner_world == null:
		return fallback
	var config_variant: Variant = owner_world.get("config")
	if config_variant != null:
		var value: Variant = config_variant.get(property_name)
		if value != null:
			return float(value)
	return fallback
