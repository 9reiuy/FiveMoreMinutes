class_name DreamShellEffect
extends Node2D

var ground_velocity := Vector2.ZERO
var height := 0.0
var vertical_velocity := 0.0
var rotation_velocity := 0.0
var fake_gravity := 180.0
var lifetime := 2.2
var _presentation_frozen := false

@onready var shell_sprite: Sprite2D = $ShellSprite


func setup(texture: Texture2D, fire_direction: Vector2, random: RandomNumberGenerator, duration: float, gravity: float) -> void:
	shell_sprite.texture = texture
	shell_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var forward := fire_direction.normalized() if fire_direction.length_squared() > 0.001 else Vector2.RIGHT
	var eject_direction := -forward.orthogonal().rotated(random.randf_range(-0.22, 0.22))
	ground_velocity = eject_direction * random.randf_range(42.0, 72.0) - forward * random.randf_range(4.0, 14.0)
	vertical_velocity = random.randf_range(46.0, 72.0)
	rotation_velocity = random.randf_range(-12.0, 12.0)
	lifetime = maxf(duration, 0.1)
	fake_gravity = maxf(gravity, 1.0)


func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	if _presentation_frozen:
		return
	global_position += ground_velocity * delta
	ground_velocity = ground_velocity.move_toward(Vector2.ZERO, 54.0 * delta)
	height = maxf(0.0, height + vertical_velocity * delta)
	vertical_velocity -= fake_gravity * delta
	if height <= 0.0 and vertical_velocity < 0.0:
		height = 0.0
		vertical_velocity = 0.0
		ground_velocity = ground_velocity.move_toward(Vector2.ZERO, 150.0 * delta)
	shell_sprite.position.y = -height
	shell_sprite.rotation += rotation_velocity * delta
	if height <= 0.0 and ground_velocity.length_squared() < 0.25 and absf(rotation_velocity) < 0.35:
		_presentation_frozen = true
		ground_velocity = Vector2.ZERO
		rotation_velocity = 0.0
		if has_meta(&"depth_visual_bridge"):
			var bridge_ref: Variant = get_meta(&"depth_visual_bridge")
			if bridge_ref is WeakRef:
				var bridge: Variant = bridge_ref.get_ref()
				if bridge != null and is_instance_valid(bridge) and bridge.has_method("freeze_static_visual"):
					bridge.call("freeze_static_visual")

