extends RefCounted

enum Strike { JAB, CROSS, WRIST, UPPERCUT }
const ORDER := [Strike.JAB, Strike.WRIST, Strike.CROSS, Strike.UPPERCUT]
const SOURCES: Array[StringName] = [&"player_punch_jab", &"player_punch_cross", &"player_punch_wrist", &"player_punch_uppercut"]
const CONTACT: Array[int] = [4, 6, 8, 9]
const END: Array[int] = [12, 16, 17, 18]
const FPS := 60.0
const BASE_CONTACT_TIME := 0.04 + 0.05 * 0.5
const BASE_RECOVERY_TIME := 0.12 + 0.05 * 0.5
const ASSIST_RANGE := 48.0
const STANDOFF := 25.0
const STAGGER := 32.0 / FPS
const LAUNCH_FORCE := 536.0
const LAUNCH_RISE := 148.0
# The cross slides a standing opponent about eight pixels under normal ground drag.
const HIT_FORCE: Array[float] = [24.0, 112.0, 24.0, LAUNCH_FORCE]
const HAND_POSE := preload("res://scripts/entities/humanoid_hand_pose.gd")
const LEAD := -1
const REAR := 1
const HAND: Array[int] = [LEAD, REAR, REAR, LEAD]

class Pose:
	var tick: int
	# Offsets from the game's unarmed grip: forward pixels, outward arc in degrees, lift in pixels.
	var fist: Vector3
	# The entire original upper-body cell moves forward and down together.
	var body: Vector2
	# Leading shoe travel and trailing shoe lift, both in source pixels.
	var feet: Vector2

	func _init(at: int, hand_delta: Vector3, body_delta: Vector2, foot_delta: Vector2) -> void:
		tick = at
		fist = hand_delta
		body = body_delta
		feet = foot_delta


static func key(t: int, fist := Vector3.ZERO, body := Vector2.ZERO, feet := Vector2.ZERO) -> Pose:
	return Pose.new(t, fist, body, feet)


static func build() -> Array:
	var jab := [
		key(0),
		key(2, Vector3(-2, 0, 0)),
		key(4, Vector3(6, 0, 2), Vector2(1, 0)),
		key(5, Vector3(5, 0, 2), Vector2(1, 0)),
		key(8, Vector3(1, 0, 1)),
		key(12)
	]
	var cross := [
		key(0),
		key(3, Vector3(-2, 10, 1), Vector2(-1, 1), Vector2(1, 0)),
		key(5, Vector3(3, -14, 3), Vector2(1, 1), Vector2(2, 0)),
		key(6, Vector3(7, -30, 5), Vector2(3, 0), Vector2(3, 1)),
		key(8, Vector3(6, -28, 5), Vector2(3, 0), Vector2(3, 1)),
		key(10, Vector3(2, -12, 2), Vector2(1, 1), Vector2(2, 0)),
		key(16)
	]
	var hook := [
		key(0),
		key(3, Vector3(-1, 22, 0), Vector2(-1, 1)),
		key(5, Vector3(1, 43, 3), Vector2(-1, 1)),
		key(7, Vector3(4, 10, 4), Vector2(1, 0), Vector2(0, 1)),
		key(8, Vector3(5, -35, 4), Vector2(2, 0), Vector2(0, 1)),
		key(10, Vector3(2, -61, 3), Vector2(2, 1), Vector2(0, 1)),
		key(13, Vector3(0, -22, 2), Vector2(0, 1)),
		key(17)
	]
	var uppercut := [
		key(0),
		key(3, Vector3(-1, 4, -2), Vector2(-1, 2)),
		key(5, Vector3(-2, 9, -3), Vector2(-1, 3)),
		key(7, Vector3(1, 6, 1), Vector2(0, 1)),
		key(9, Vector3(3, -3, 9), Vector2(1, -1), Vector2(0, 1)),
		key(10, Vector3(3, -3, 8), Vector2(1, -1), Vector2(0, 1)),
		key(12, Vector3(1, 2, 4), Vector2(0, 0)),
		key(18)
	]
	return [jab, cross, hook, uppercut]


static var tracks: Array = build()


static func sample(move: int, frame: float, pose: Pose) -> void:
	var keys: Array = tracks[move]
	frame = clampf(frame, 0.0, END[move])
	for i in range(1, keys.size()):
		var last: Pose = keys[i - 1]
		var next: Pose = keys[i]
		if frame <= next.tick:
			var t := clampf((frame - last.tick) / float(next.tick - last.tick), 0.0, 1.0)
			pose.fist = last.fist.lerp(next.fist, t)
			pose.body = last.body.lerp(next.body, t)
			pose.feet = last.feet.lerp(next.feet, t)
			return


static func hand_travel(side: int, facing: Vector2, delta: Vector3) -> Vector2:
	var rest_phase := facing.angle() + side * 0.8
	var center := HAND_POSE.orbit_center(rest_phase + side * deg_to_rad(delta.y))
	center += Vector2(facing.x, facing.y * 0.56) * delta.x - Vector2(0, delta.z)
	if absf(facing.x) > 0.9 and delta.z > 5.0:
		center.x = lerpf(center.x, signf(facing.x) * 16.0, clampf((delta.z - 5.0) / 4.0, 0.0, 1.0))
	var back := clampf((-facing.y - 0.4) / 0.6, 0.0, 1.0)
	var extension := clampf(maxf(delta.x / 6.0, delta.z / 9.0), 0.0, 1.0)
	var flank := signf(facing.x) if absf(facing.x) > 0.4 else float(side)
	center.x = lerpf(center.x, flank * 14.0, back * extension)
	return center - HAND_POSE.orbit_center(rest_phase)
