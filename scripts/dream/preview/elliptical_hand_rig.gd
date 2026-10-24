extends RefCounted
## Preview-only presentation solver. No hitboxes, weapon timers, damage or input.
const ORBIT := Vector2(12.0, 6.0)
const FOLLOW_RATE := 18.0
const HAND_ART := preload("res://scripts/entities/player_hand_presentation.gd")
var actor: Node2D
var weapon: Sprite2D
var initialized := false
var mode := 1
var snapshot: Dictionary = {}
var left_position := Vector2.ZERO
var right_position := Vector2.ZERO

static func orbit(angle: float, radius: Vector2 = ORBIT) -> Vector2:
	return Vector2(cos(angle) * radius.x, sin(angle) * radius.y)

func bind(source: Node2D) -> void:
	actor = source
	weapon = Sprite2D.new()
	weapon.name = "PreviewHeldWeapon"
	weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.visual.add_child(weapon)
	for hand: Sprite2D in [actor.left_hand_part, actor.right_hand_part]:
		hand.reparent(actor.visual, false)
		hand.centered = true
	actor.weapon_root.visible = false
	# Formal player now owns grip-hand copies. This lab still renders its own
	# comparison solver, so keep the formal copies hidden with WeaponRoot.
	actor.heal_overlay.visible = false
	actor.get_node("PlayerHPBar").visible = false
	set_mode(1)

func set_mode(value: int) -> void:
	mode = clampi(value, 0, 3)
	var ids: Array[String] = ["", "basic", "assault_rifle", "lucille"]
	weapon.texture = DreamGunAtlas.get_held(ids[mode])
	weapon.visible = mode != 0
	weapon.flip_h = false # Bat handle is left; wire-wrapped striking end is right.
	# Grip is at the back of each existing texture, not at its centre.
	weapon.offset = Vector2(weapon.texture.get_width() * 0.32, 0) if weapon.texture != null else Vector2.ZERO
	if mode == 3: HAND_ART.align_bat(weapon)
	initialized = false

func step(delta: float, aim: Vector2, motion: Vector2, attack: float = -1.0,
		dash: float = 0.0, comparison: bool = false) -> void:
	var angle := aim.angle() if aim.length_squared() > 0.0001 else 0.0
	var swing := 0.0
	var extension := 0.0
	if attack >= 0.0:
		if mode == 3:
			# Short anticipation, fast cut, readable recovery. Visual-only timing.
			var phase := clampf((attack - 0.18) / 0.48, 0.0, 1.0)
			swing = lerpf(-1.4, 1.4, smoothstep(0.0, 1.0, phase))
			extension = sin(attack * PI) * 4.0
		elif mode == 0:
			extension = sin(attack * PI) * 8.0
		else:
			extension = -pow(1.0 - attack, 3.0) * 3.0
	var held_angle := angle + swing
	var forward := orbit(held_angle, Vector2(1.0, 0.5))
	var screen_angle := forward.angle()
	if mode == 3:
		screen_angle += -PI / 3.0 if aim.x >= 0.0 else PI / 3.0
	var bob := -absf(sin(float(actor.walk_animation_time))) * minf(motion.length() / 290.0, 1.0)
	var chest := Vector2(0, float(actor.body_pivot.position.y) + bob + 8.0)
	var grip := chest + orbit(held_angle, ORBIT + Vector2.ONE * extension)
	var left := chest + orbit(angle - 0.8, Vector2(12, 6))
	var right := chest + orbit(angle + 0.8, Vector2(12, 6))
	var left_depth := sin(angle - 0.8)
	var right_depth := sin(angle + 0.8)
	if mode != 0:
		right = grip
		left = grip + forward * (7.0 if mode == 2 else 2.0)
		left_depth = sin(held_angle)
		right_depth = left_depth
	else:
		right += forward * extension
	# Running/dashing pulls the hands back without moving the collision owner.
	var lag := Vector2(motion.x, motion.y * 0.5).limit_length(290.0) / 290.0 * (2.0 + dash * 3.0)
	left -= lag
	right -= lag
	grip -= lag
	if comparison:
		left = Vector2(-8.5, -6.0) + Vector2(0, bob)
		right = Vector2(6.5, -6.0) + Vector2(0, bob)
		grip = chest + orbit(angle, Vector2(14, 9))
		screen_angle = angle
		left_depth = 1.0
		right_depth = 1.0
	var blend := 1.0 - exp(-FOLLOW_RATE * maxf(delta, 0.0)) if initialized else 1.0
	# Existing gait resets the original hand nodes every tick. Retain solver
	# state here instead of interpolating from that reset pose indefinitely.
	left_position = left_position.lerp(left, blend)
	right_position = right_position.lerp(right, blend)
	actor.left_hand_part.position = left_position
	actor.right_hand_part.position = right_position
	weapon.position = weapon.position.lerp(grip, blend)
	weapon.rotation = lerp_angle(weapon.rotation, screen_angle, blend)
	weapon.flip_v = cos(held_angle) < 0.0
	if mode == 3:
		weapon.offset = -HAND_ART.bat_grip(weapon)
		# Both hand centres lie on the handle, never on the barrel or empty UVs.
		actor.right_hand_part.position = weapon.position
		actor.left_hand_part.position = weapon.position + Vector2(3, 0).rotated(weapon.rotation)
	actor.left_hand_part.visible = true
	actor.right_hand_part.visible = true
	actor.left_hand_part.rotation = screen_angle * 0.25
	actor.right_hand_part.rotation = screen_angle * 0.25
	# A dead band prevents flicker exactly side-on. Sort using ground depth,
	# never elevated screen Y (which would put every hand behind the torso).
	if absf(left_depth) > 0.08 or not initialized:
		actor.left_hand_part.z_index = -1 if left_depth < 0.0 else 1
	if absf(right_depth) > 0.08 or not initialized:
		actor.right_hand_part.z_index = -1 if right_depth < 0.0 else 1
	weapon.z_index = -1 if sin(held_angle) < -0.08 else 1
	weapon.show_behind_parent = true
	initialized = true
	snapshot = {"left": actor.left_hand_part.position, "right": actor.right_hand_part.position,
		"grip": weapon.position, "left_depth": actor.left_hand_part.z_index,
		"right_depth": actor.right_hand_part.z_index, "angle": weapon.rotation, "mode": mode}
