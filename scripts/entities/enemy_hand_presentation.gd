extends RefCounted
## Employee/Waitress/Boss adapter. Hands remain inside the existing captures.
const POSE := preload("res://scripts/entities/humanoid_hand_pose.gd")
var actor: Node2D
var grip_root: Node2D
var grip_left: Sprite2D
var grip_right: Sprite2D
var _weapon_id := ""

func bind(source: Node2D) -> void:
	actor = source
	grip_root = Node2D.new()
	grip_root.name = "EnemyGripHands"
	actor.reload_visual_pivot.add_child(grip_root)
	grip_left = _hand("LeftGrip",actor.left_hand)
	grip_right = _hand("RightGrip",actor.right_hand)
	refresh_visibility()

func _hand(label: String, original: Sprite2D) -> Sprite2D:
	var hand := Sprite2D.new()
	hand.name = label
	hand.texture = original.texture
	hand.material = original.material
	hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hand.z_index = 2
	grip_root.add_child(hand)
	return hand

func refresh_visibility() -> void:
	if not is_instance_valid(actor) or not is_instance_valid(grip_root): return
	grip_root.visible = not actor.dead and not String(actor.held_weapon_id).is_empty() and actor.held_weapon_sprite.visible and actor.held_weapon_sprite.texture != null and actor.weapon_root.visible and not actor.has_meta(&"training_model_source")

func apply(movement_blocked: bool = false) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(grip_root) or not actor.is_inside_tree(): return
	var weapon_id := String(actor.held_weapon_id)
	var sprite: Sprite2D = actor.held_weapon_sprite
	if weapon_id != _weapon_id:
		if POSE.WEAPONS.uses_lucille_motion(_weapon_id) and not POSE.WEAPONS.uses_lucille_motion(weapon_id):
			sprite.position = Vector2(actor._cfg("held_weapon_distance",11.0),0)
			sprite.offset = Vector2.ZERO
			sprite.rotation = 0.0
			sprite.flip_h = false
		_weapon_id = weapon_id
	for pair in [[grip_left,actor.left_hand],[grip_right,actor.right_hand]]:
		var hand: Sprite2D = pair[0]
		var original: Sprite2D = pair[1]
		if hand.texture != original.texture: hand.texture = original.texture
		if hand.material != original.material: hand.material = original.material
	refresh_visibility()
	if actor.dead or actor.has_meta(&"training_model_source"): return
	if grip_root.visible:
		if POSE.WEAPONS.uses_lucille_motion(weapon_id):
			POSE.align_bat(sprite,POSE.facing_right(actor.last_facing_direction))
			var drop := Vector2(0,18)
			var reference: Variant = actor.get_meta(&"depth_visual_bridge") if actor.has_meta(&"depth_visual_bridge") else null
			var bridge: Node = reference.get_ref() if reference is WeakRef else null
			if is_instance_valid(bridge) and bridge.has_method("compensate_weapon_pixel_offset"):
				drop = bridge.compensate_weapon_pixel_offset(drop)
			sprite.position = actor.reload_visual_pivot.global_transform.basis_xform_inv(drop)
		POSE.apply_grips(sprite,weapon_id,grip_left,grip_right)
		return
	if movement_blocked or actor.burning_panic: return
	var angle := _screen_direction().angle()
	var mirror := -1.0 if actor.character_visual.scale.x < 0.0 else 1.0
	var left_offset := Vector2.ZERO
	var right_offset := Vector2.ZERO
	if actor.unarmed_attack_active and actor.unarmed_attack_kind == &"employee_punch":
		var strike := sin(clampf(actor.unarmed_attack_elapsed/.24,0.0,1.0)*PI)
		var direction := Vector2(cos(angle),sin(angle)*.5)
		left_offset = direction * (10.0 if actor.unarmed_attack_left else -2.0) * strike
		right_offset = direction * (-2.0 if actor.unarmed_attack_left else 10.0) * strike
	for pair in [[actor.left_hand,-.8,left_offset],[actor.right_hand,.8,right_offset]]:
		var hand: Sprite2D = pair[0]
		if hand.texture == null: continue
		var phase: float = angle + float(pair[1])
		var center := POSE.orbit_center(phase) + Vector2(pair[2])
		center.x *= mirror
		hand.position = center - hand.texture.get_size() * .5
		hand.z_index = POSE.orbit_depth(phase,hand.z_index)

func _screen_direction() -> Vector2:
	var direction: Vector2 = actor.last_facing_direction
	if direction.length_squared()<.0001: direction = Vector2.RIGHT
	var world: Node = actor._get_world()
	if world is Node3D and world.has_method("get_gameplay_world_position"):
		var camera: Camera3D = world.get("camera_3d")
		if is_instance_valid(camera) and camera.is_inside_tree():
			var origin: Vector3 = world.get_gameplay_world_position(actor.global_position,.65)
			var along: Vector3 = world.get_gameplay_world_position(actor.global_position+direction.normalized()*32.0,.65)
			var projected := camera.unproject_position(along)-camera.unproject_position(origin)
			if projected.length_squared()>.0001: return projected.normalized()
	return direction.normalized()
