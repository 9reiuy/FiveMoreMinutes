extends RefCounted
## Player-only pixel presentation. Never writes input, movement, aim markers,
## damage, cooldowns or attack geometry. Weapon hands share its capture plane.
var actor: Node2D
var grip_root: Node2D
var grip_left: Sprite2D
var grip_right: Sprite2D
const POSE := preload("res://scripts/entities/humanoid_hand_pose.gd")

static func bat_grip(sprite: Sprite2D) -> Vector2:
	return POSE.bat_grip(sprite)

static func align_bat(sprite: Sprite2D, facing_right: bool = true) -> void:
	POSE.align_bat(sprite,facing_right)

func bind(source: Node2D) -> void:
	actor = source
	grip_root = Node2D.new()
	grip_root.name = "PlayerGripHands"
	actor.reload_visual_pivot.add_child(grip_root)
	grip_left = _hand("LeftGrip", actor.left_hand_part.texture)
	grip_right = _hand("RightGrip", actor.right_hand_part.texture)
	apply()

func _hand(label: String, texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = label
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 2
	grip_root.add_child(sprite)
	return sprite

func apply(melee: Node = null, aim_direction := Vector2.RIGHT) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(grip_root): return
	# Exit cleanup can cancel a dash after the world's camera already exited.
	var world: Node = actor._dream_world()
	if world is Node3D:
		var camera: Camera3D = world.get("camera_3d")
		if not is_instance_valid(camera) or not camera.is_inside_tree(): return
	var armed: bool = actor._has_armed_pose()
	grip_root.visible = armed and actor.held_weapon_sprite.visible
	if armed:
		var sprite: Sprite2D = actor.held_weapon_sprite
		var bat_grip_active := POSE.WEAPONS.uses_lucille_motion(actor.selected_weapon_id)
		if bat_grip_active:
			align_bat(sprite, POSE.facing_right(actor.last_aim_direction))
		if melee != null:
			_apply_melee_combo(melee, aim_direction, sprite.rotation)
		if bat_grip_active:
			# This is only the visual sprite; origin/hit markers stay untouched.
			# WeaponRoot's historical firearm height is above the small torso.
			# Lower only bat art/its hands to shoulder height in actor pixels;
			# inverse basis keeps that drop stable while the swing pivot rotates.
			var shoulder_drop := Vector2(0, 18)
			var bridge_ref: Variant = actor.get_meta(&"depth_visual_bridge") if actor.has_meta(&"depth_visual_bridge") else null
			var bridge: Node = bridge_ref.get_ref() if bridge_ref is WeakRef else null
			if is_instance_valid(bridge) and bridge.has_method("compensate_weapon_pixel_offset"):
				shoulder_drop = bridge.compensate_weapon_pixel_offset(shoulder_drop)
			sprite.position = actor.reload_visual_pivot.global_transform.basis_xform_inv(shoulder_drop)
		POSE.apply_grips(sprite,String(actor.selected_weapon_id),grip_left,grip_right)
	else:
		var angle: float = actor.get_aim_direction().angle()
		# A rotated gameplay camera can supply the matching body-screen heading.
		# Weapon/gameplay aim remains in world coordinates.
		var provider: Callable=actor.get_meta(&"presentation_hand_direction",Callable())
		if actor.punch_active:
			angle = actor.punch_screen_direction.angle()
		elif provider.is_valid():
			var heading: Vector2=provider.call()
			if heading.length_squared()>.0001:angle=heading.angle()
		for pair in [[actor.left_hand_part, -0.8, actor.punch_left_hand_offset], [actor.right_hand_part, 0.8, actor.punch_right_hand_offset]]:
			var hand: Sprite2D = pair[0]
			var phase: float = angle + float(pair[1])
			hand.position = POSE.orbit_center(phase) - hand.texture.get_size() * .5 + Vector2(pair[2])
			if actor.punch_active:
				hand.position = hand.position.round()
				var side := -1 if hand == actor.left_hand_part else 1
				if side == actor.PUNCH.HAND[actor.punch_move]:
					phase += side * deg_to_rad(actor.punch_pose.fist.y)
			hand.z_index = POSE.orbit_depth(phase,hand.z_index)
			# Overlay lives in the matching hierarchy; no reparenting is needed.
			var overlay: Sprite2D = actor.heal_overlay.get_node("BodyPivot/" + hand.name)
			overlay.position = hand.position
			overlay.z_index = hand.z_index

func _apply_melee_combo(melee: Node, aim_direction: Vector2, rest_slant: float) -> void:
	var weight: float = melee.pose_weight()
	var motion: Node2D = actor.weapon_motion
	if weight <= 0.0:
		motion.rotation = 0.0
		motion.position = Vector2.ZERO
		return
	# Project the same heading used by the hit slice and the world-space arc.
	# Keep the previous endpoint in the guard pose until the follow-up begins.
	var angle: float = melee._sweep_angle_at(melee.sweep_progress)
	var aim_on_screen: Vector2 = actor.character_screen_direction(aim_direction)
	var edge_on_screen: Vector2 = actor.character_screen_direction(aim_direction.rotated(angle))
	motion.rotation = (aim_on_screen.angle_to(edge_on_screen) - rest_slant) * weight
	var drop: float = melee.grip_drop()
	var offset := Vector2(0.0, drop)
	if not is_zero_approx(drop):
		var reference: Variant = actor.get_meta(&"depth_visual_bridge", Callable())
		var bridge: Node = reference.get_ref() if reference is WeakRef else null
		if is_instance_valid(bridge):
			offset = bridge.compensate_weapon_pixel_offset(offset)
	motion.position = actor.hand_anchor.global_transform.basis_xform_inv(offset)
