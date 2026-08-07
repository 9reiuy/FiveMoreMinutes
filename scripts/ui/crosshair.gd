extends Control
@export var config: DemoConfig
var player: Node
var recoil_offset := Vector2.ZERO
var current_color := Color.GRAY
var recoil_recovery_left := 0.0


func configure(target: Node) -> void:
	player = target
	target.weapon_fired.connect(_on_weapon_fired)


func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	var progress: float = player.get_weapon_cooldown_progress()
	var target_color := config.crosshair_cooldown_color.lerp(config.crosshair_ready_color, progress)
	current_color = current_color.lerp(target_color, clampf(delta * config.crosshair_color_lerp_speed,0,1))
	if recoil_recovery_left > 0.0:
		var step := clampf(delta / recoil_recovery_left, 0.0, 1.0)
		recoil_offset = recoil_offset.lerp(Vector2.ZERO, step)
		recoil_recovery_left = maxf(0.0, recoil_recovery_left - delta)
	else:
		recoil_offset = Vector2.ZERO
	queue_redraw()


func _on_weapon_fired(multiplier: float) -> void:
	var angle := randf() * TAU
	recoil_offset = Vector2.RIGHT.rotated(angle) * config.crosshair_recoil_pixels * multiplier
	recoil_recovery_left = maxf(config.crosshair_recoil_recovery_seconds, 0.01)


func _draw() -> void:
	if not is_instance_valid(player):
		return
	var p: Vector2 = player.get_constrained_aim_position() + recoil_offset
	draw_line(p+Vector2(-9,0),p+Vector2(-3,0),current_color,2)
	draw_line(p+Vector2(3,0),p+Vector2(9,0),current_color,2)
	draw_line(p+Vector2(0,-9),p+Vector2(0,-3),current_color,2)
	draw_line(p+Vector2(0,3),p+Vector2(0,9),current_color,2)
	draw_circle(p,2,current_color,false,1)
