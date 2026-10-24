extends RefCounted
## Player-only pixel presentation. Never writes input, movement, aim markers,
## damage, cooldowns or attack geometry. Weapon hands share its capture plane.
var actor: Node2D
var grip_root: Node2D
var grip_left: Sprite2D
var grip_right: Sprite2D
static var _bat_rects: Dictionary = {}

static func bat_grip(sprite: Sprite2D) -> Vector2:
	if not _bat_rects.has(sprite.texture):
		_bat_rects[sprite.texture] = sprite.texture.get_image().get_used_rect()
	var rect: Rect2i = _bat_rects[sprite.texture]
	var size := sprite.texture.get_size()
	# Original 3.png: narrow plain wooden grip is LEFT; wire-wrapped striking
	# head is RIGHT. Grip the wood, never the wire. Keep the authored direction.
	var point := Vector2(rect.position.x + 2.0, rect.get_center().y)
	if sprite.flip_h: point.x = size.x - point.x
	if sprite.flip_v: point.y = size.y - point.y
	return point - size * 0.5

static func align_bat(sprite: Sprite2D, facing_right: bool = true) -> void:
	sprite.flip_h = false
	sprite.offset = -bat_grip(sprite)
	sprite.rotation = -PI / 3.0 if facing_right else PI / 3.0

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

func apply() -> void:
	if not is_instance_valid(actor) or not is_instance_valid(grip_root): return
	var armed := not String(actor.selected_weapon_id).is_empty() and not bool(actor.dead)
	grip_root.visible = armed and actor.held_weapon_sprite.visible
	if armed:
		var sprite: Sprite2D = actor.held_weapon_sprite
		if actor.selected_weapon_id == "lucille":
			align_bat(sprite, actor.last_aim_direction.x >= 0.0)
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
			grip_right.position = sprite.transform * (bat_grip(sprite) + sprite.offset)
			grip_left.position = sprite.transform * (bat_grip(sprite) + sprite.offset + Vector2(3, 0))
		else:
			var size := sprite.texture.get_size()
			var point := Vector2(-size.x * 0.22, size.y * 0.12)
			if sprite.flip_v: point.y = -point.y
			grip_right.position = sprite.transform * (point + sprite.offset)
			var spacing := 7.0 if actor.selected_weapon_id in ["assault_rifle", "shotgun"] else 2.0
			grip_left.position = sprite.transform * (point + sprite.offset + Vector2(spacing, 0))
		grip_left.rotation = sprite.rotation * 0.25
		grip_right.rotation = sprite.rotation * 0.25
	else:
		var angle: float = actor.get_aim_direction().angle()
		for pair in [[actor.left_hand_part, -0.8, actor.punch_left_hand_offset], [actor.right_hand_part, 0.8, actor.punch_right_hand_offset]]:
			var hand: Sprite2D = pair[0]
			var phase: float = angle + float(pair[1])
			hand.position = Vector2(cos(phase) * 12, 8 + sin(phase) * 6) - hand.texture.get_size() * 0.5 + Vector2(pair[2])
			if absf(sin(phase)) > 0.08:
				hand.z_index = -1 if sin(phase) < 0.0 else 1
			# Overlay lives in the matching hierarchy; no reparenting is needed.
			var overlay: Sprite2D = actor.heal_overlay.get_node("BodyPivot/" + hand.name)
			overlay.position = hand.position
			overlay.z_index = hand.z_index
