extends CharacterBody2D

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const OUTLINE_CONTROLLER := preload("res://scripts/entities/enemy_outline_controller.gd")

signal defeated(at_position: Vector2, experience_drop_count: int)

@export var movement_speed := 42.0

var target: Node2D
var arena_bounds := Rect2(24, 44, 592, 282)
var current_health := 18.0
var contact_damage := 8.0
var contact_cooldown := 0.0
var dead := false
var experience_drop_count := 1
var separation_strength := 24.0
var separation_radius := 30.0
var movement_speed_multiplier := 1.0
var feedback_config: DemoConfig
var hit_flash_left := 0.0
var hit_scale_left := 0.0
var hit_visual_offset := Vector2.ZERO
var visual_state_offset := Vector2.ZERO
var visual_base_scale := Vector2.ONE
var auto_aim_locked := false
var outline_controller: EnemyOutlineController
@onready var visual: AnimatedSprite2D = get_node_or_null("Visual")


func _ready() -> void:
	if visual == null:
		return
	visual_base_scale = visual.scale
	outline_controller = OUTLINE_CONTROLLER.new()
	outline_controller.name = "EnemyOutlineController"
	add_child(outline_controller)
	outline_controller.configure(visual)
	_configure_visual_animation_speeds()
	_play_visual_animation(&"move_down" if visual.sprite_frames.has_animation(&"move_down") else &"walk")


func configure(new_target: Node2D, health: float, damage: float, bounds: Rect2, new_separation_strength: float, new_separation_radius: float, config: DemoConfig = null) -> void:
	target = new_target
	current_health = health
	contact_damage = damage
	movement_speed = config.base_enemy_movement_speed if config != null else movement_speed
	arena_bounds = bounds
	separation_strength = new_separation_strength
	separation_radius = new_separation_radius
	feedback_config = config
	if visual != null:
		visual_base_scale = Vector2.ONE * config.basic_enemy_sprite_scale if config != null and visual.sprite_frames.has_animation(&"move_down") else visual.scale
		visual.scale = visual_base_scale
		_configure_visual_animation_speeds()


func _process(delta: float) -> void:
	if dead or feedback_config == null:
		return
	hit_flash_left = maxf(0.0, hit_flash_left - delta)
	hit_scale_left = maxf(0.0, hit_scale_left - delta)
	if visual == null:
		return
	visual.modulate = feedback_config.enemy_hit_flash_color if hit_flash_left > 0.0 else Color.WHITE
	hit_visual_offset = hit_visual_offset.move_toward(Vector2.ZERO, feedback_config.enemy_hit_visual_knockback_pixels * 12.0 * delta)
	visual.position = visual_state_offset + hit_visual_offset
	if hit_scale_left > 0.0:
		var ratio := hit_scale_left / maxf(feedback_config.enemy_hit_scale_seconds, 0.001)
		var amount := feedback_config.enemy_hit_scale_amount * ratio
		visual.scale = visual_base_scale * Vector2(1.0 + amount, 1.0 - amount)
	else:
		visual.scale = visual_base_scale


func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(target):
		return
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	var effective_speed := movement_speed * movement_speed_multiplier
	var chase_velocity := global_position.direction_to(target.global_position) * effective_speed
	var separation_velocity := _get_separation_velocity()
	velocity = (chase_velocity + separation_velocity).limit_length(effective_speed + separation_strength * 0.5)
	move_and_slide()
	update_direction_animation()
	global_position.x = clampf(global_position.x, arena_bounds.position.x, arena_bounds.end.x)
	global_position.y = clampf(global_position.y, arena_bounds.position.y, arena_bounds.end.y)
	if global_position.distance_to(target.global_position) < 22.0 and contact_cooldown <= 0.0:
		contact_cooldown = 0.8
		target.receive_damage(contact_damage)


func update_direction_animation() -> void:
	if visual == null:
		return
	if visual.sprite_frames.has_animation(&"move_down"):
		var motion := velocity
		if motion.length_squared() <= 0.01 and is_instance_valid(target):
			motion = global_position.direction_to(target.global_position)
		var animation_name := &"move_down"
		if absf(motion.x) > absf(motion.y):
			animation_name = &"move_right" if motion.x > 0.0 else &"move_left"
		elif motion.y < 0.0:
			animation_name = &"move_up"
		visual.flip_h = false
		_play_visual_animation(animation_name)
	elif visual.sprite_frames.has_animation(&"walk"):
		_play_visual_animation(&"walk")
		if absf(velocity.x) > 0.1:
			visual.flip_h = velocity.x < 0.0


func _get_separation_velocity() -> Vector2:
	var result := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("dream_enemies"):
		if other == self or not is_instance_valid(other) or other.dead:
			continue
		var offset: Vector2 = global_position - other.global_position
		var distance := offset.length()
		if distance >= separation_radius:
			continue
		if distance < 0.001:
			offset = Vector2.RIGHT.rotated(float(get_instance_id() % 360) * PI / 180.0)
			distance = 0.001
		result += offset.normalized() * (1.0 - distance / separation_radius) * separation_strength
	return result.limit_length(separation_strength)


func take_damage(amount: float, _hit_origin: Vector2 = Vector2.INF) -> void:
	if dead:
		return
	var hit_direction := _resolve_hit_direction(_hit_origin)
	current_health -= amount
	if current_health <= 0.0:
		dead = true
		set_auto_aim_locked(false)
		_spawn_combat_feedback(hit_direction, true)
		SFX.play_event(&"enemy_kill")
		defeated.emit(global_position, experience_drop_count)
		queue_free()
		return
	if feedback_config != null:
		hit_flash_left = feedback_config.enemy_hit_flash_seconds
		hit_scale_left = feedback_config.enemy_hit_scale_seconds
		hit_visual_offset = hit_direction * feedback_config.enemy_hit_visual_knockback_pixels
		_spawn_combat_feedback(hit_direction, false)


func _resolve_hit_direction(hit_origin: Vector2) -> Vector2:
	if is_finite(hit_origin.x) and is_finite(hit_origin.y):
		var direction := hit_origin.direction_to(global_position)
		if direction.length_squared() > 0.0001:
			return direction
	if is_instance_valid(target):
		return target.global_position.direction_to(global_position)
	return Vector2.RIGHT


func _spawn_combat_feedback(direction: Vector2, is_kill: bool) -> void:
	var world := get_tree().get_first_node_in_group("dream_world")
	if world == null:
		return
	world.spawn_combat_feedback(global_position, direction, is_kill)
	world.request_hit_stop()


func set_visual_state_offset(offset: Vector2) -> void:
	visual_state_offset = offset


func _play_visual_animation(animation_name: StringName) -> void:
	if visual == null or not visual.sprite_frames.has_animation(animation_name):
		return
	if visual.animation != animation_name or not visual.is_playing():
		visual.play(animation_name)


func _configure_visual_animation_speeds() -> void:
	if feedback_config == null or visual == null:
		return
	var walk_fps := feedback_config.basic_enemy_walk_animation_fps
	if name.contains("LargeCorrection"):
		walk_fps = feedback_config.large_correction_enemy_walk_animation_fps
	elif name.contains("Correction"):
		walk_fps = feedback_config.correction_enemy_walk_animation_fps
	elif name.contains("Stapler"):
		walk_fps = feedback_config.stapler_enemy_walk_animation_fps
	elif name.contains("AlarmClock"):
		walk_fps = feedback_config.alarm_enemy_walk_fps
	elif name.contains("Mailbox"):
		walk_fps = feedback_config.mailbox_enemy_walk_fps
	if visual.sprite_frames.has_animation(&"walk"):
		visual.sprite_frames.set_animation_speed(&"walk", walk_fps)
	for animation_name in [&"move_down", &"move_left", &"move_right", &"move_up"]:
		if visual.sprite_frames.has_animation(animation_name):
			visual.sprite_frames.set_animation_speed(animation_name, walk_fps)
	if visual.sprite_frames.has_animation(&"charge"):
		var charge_fps := feedback_config.large_correction_charge_animation_fps if name.contains("LargeCorrection") else feedback_config.correction_charge_animation_fps
		visual.sprite_frames.set_animation_speed(&"charge", charge_fps)
	if visual.sprite_frames.has_animation(&"attack_prepare"):
		visual.sprite_frames.set_animation_speed(&"attack_prepare", feedback_config.stapler_attack_animation_fps)


func set_movement_speed_multiplier(multiplier: float) -> void:
	movement_speed_multiplier = maxf(0.0, multiplier)


func set_auto_aim_locked(locked: bool) -> void:
	auto_aim_locked = locked
	if outline_controller != null:
		outline_controller.set_locked(locked)


func _draw() -> void:
	pass
