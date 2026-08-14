class_name PickupAttraction
extends RefCounted

enum Phase { IDLE, LIFTING, SUCTION }

var phase := Phase.IDLE
var elapsed := 0.0
var start_position := Vector2.ZERO
var lift_position := Vector2.ZERO


func update(pickup: Node2D, target: Node2D, delta: float, config: DemoConfig) -> bool:
	if not is_instance_valid(pickup) or not is_instance_valid(target):
		return false
	if phase == Phase.IDLE:
		if pickup.global_position.distance_to(target.global_position) >= config.pickup_magnet_radius:
			return false
		phase = Phase.LIFTING
		elapsed = 0.0
		start_position = pickup.global_position
		lift_position = start_position + Vector2.UP * config.pickup_lift_height
	if phase == Phase.LIFTING:
		elapsed += delta
		var progress := clampf(elapsed / maxf(config.pickup_lift_duration, 0.001), 0.0, 1.0)
		var ease_out := 1.0 - pow(1.0 - progress, 3.0)
		pickup.global_position = start_position.lerp(lift_position, ease_out)
		if progress >= 1.0:
			phase = Phase.SUCTION
			elapsed = 0.0
	else:
		elapsed += delta
		var progress := clampf(elapsed / maxf(config.pickup_suction_duration, 0.001), 0.0, 1.0)
		var curved := config.pickup_suction_curve.sample_baked(progress) if config.pickup_suction_curve != null else progress * progress * progress
		# P2每帧读取玩家当前位置；二次Bezier从抬升点弯入，不锁死旧坐标。
		var p0 := lift_position
		var p1 := lift_position + Vector2.UP * config.pickup_lift_height * 0.5
		var p2 := target.global_position
		var inverse := 1.0 - curved
		pickup.global_position = inverse * inverse * p0 + 2.0 * inverse * curved * p1 + curved * curved * p2
		if progress >= 1.0:
			pickup.global_position = p2
	return pickup.global_position.distance_to(target.global_position) <= config.pickup_snap_distance
