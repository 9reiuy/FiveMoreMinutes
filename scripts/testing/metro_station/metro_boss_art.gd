extends RefCounted

const ATLAS: Texture2D = preload("res://art/Dream/enemy/boss1.png")


static func apply(actor: EmployeeEnemy) -> void:
	# The assembled reference in the first column ends at row 40. Its leg
	# pieces overlap the torso and leave four pixels visible in the rest pose.
	for frame in actor.enemy_head_frames.size():
		actor.enemy_head_frames[frame] = _texture(Rect2(32, frame * 32, 32, 32))
	actor.employee_back_frame = null
	actor.combined_upper_body = false
	actor.set_meta(&"character_combined_upper_body", false)
	actor.head_base_position = Vector2(-16, -24)
	actor.head.position = actor.head_base_position
	actor.body_base_position = Vector2(-7, 4)
	actor.body.position = actor.body_base_position
	actor.body.texture = _texture(Rect2(9, 28, 10, 8))
	actor.body.show()
	actor.left_leg.texture = _texture(EmployeeEnemy.EMPLOYEE_LEFT_FOOT_REGION)
	actor.right_leg.texture = _texture(EmployeeEnemy.EMPLOYEE_RIGHT_FOOT_REGION)
	actor.right_leg_base_position = Vector2(-1, -9)
	actor.right_leg.position = actor.right_leg_base_position
	actor.left_hand.texture = _texture(EmployeeEnemy.EMPLOYEE_LEFT_HAND_REGION)
	actor.right_hand.texture = _texture(EmployeeEnemy.EMPLOYEE_RIGHT_HAND_REGION)
	actor.left_hand_base_position = Vector2(-12, 7)
	actor.right_hand_base_position = Vector2(3, 7)
	actor.left_hand.position = actor.left_hand_base_position
	actor.right_hand.position = actor.right_hand_base_position
	actor._apply_live_facing(Vector2.DOWN)
	actor.refresh_hurtbox_from_visuals()


static func _texture(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = ATLAS
	texture.region = region
	texture.filter_clip = true
	return texture
