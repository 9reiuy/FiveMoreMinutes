extends Node
## The phase controller owns travel and combat. This node only poses Rei.
const ART := preload("res://scripts/entities/player_dive_roll_art.gd")
const POSE_END_TICKS := [1, 3, 5, 7, 8, 9, 11, 12, 14, 16, 18, 20, 22, 24]
const TOTAL_TICKS := 24.0
const ROLL_DURATION := TOTAL_TICKS / 60.0 - 0.000001
const PALM_BOTTOM := Vector2(0.0, 2.0)
# Time, distance and speed at push-off, palm plant, transfer and recovery.
const PACE := [Vector3(0.0, 0.0, 0.25), Vector3(3.0 / TOTAL_TICKS, 0.075, 0.90),
	Vector3(9.0 / TOTAL_TICKS, 0.50, 1.20), Vector3(11.0 / TOTAL_TICKS, 0.565, 0.74),
	Vector3(16.0 / TOTAL_TICKS, 0.86, 0.90), Vector3(1.0, 1.0, 0.12)]
static var _texture: ImageTexture
static var _hand_offsets: Array[PackedVector2Array]
var player: Node2D
var cel: Sprite2D
var hands: Array[Sprite2D] = []
var frame := -1
var facing := 0
var _original_parts: Array[CanvasItem] = []
var _original_visibility: Array[bool] = []
var _was_rolling := false
var _palm_floor := PackedVector3Array()
var _release_offsets := PackedVector2Array()

func bind(actor: Node2D) -> void:
	player = actor
	if _texture == null:
		var roll_art := ART.build()
		_texture = ImageTexture.create_from_image(roll_art.image)
		_hand_offsets = roll_art.hands
	process_physics_priority = 20
	cel = Sprite2D.new()
	cel.name = "ReiRollCel"
	cel.texture = _texture
	cel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cel.centered = false
	cel.position = -Vector2(ART.ANCHOR)
	cel.region_enabled = true
	cel.region_filter_clip_enabled = true
	cel.hide()
	player.visual.add_child(cel)
	for index in 2:
		var hand := Sprite2D.new()
		hand.name = "RollLeftHand" if index == 0 else "RollRightHand"
		hand.texture = ART.ATLAS.texture(ART.ATLAS.LEFT_HAND_REGION if index == 0 else ART.ATLAS.RIGHT_HAND_REGION)
		hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hand.z_index = -1
		hand.hide()
		player.visual.add_child(hand)
		hands.append(hand)
	_original_parts.assign([player.left_leg, player.right_leg, player.body_pivot, player.weapon_root])
	set_physics_process(false)

static func travel_progress(progress: float) -> float:
	for index in range(1, PACE.size()):
		var next: Vector3 = PACE[index]
		if progress <= next.x:
			var previous: Vector3 = PACE[index - 1]
			var t := inverse_lerp(previous.x, next.x, progress)
			var tangent := t * (1.0 - t) * lerpf(previous.z, -next.z, t)
			return lerpf(previous.y, next.y, smoothstep(0.0, 1.0, t)) + (next.x - previous.x) * tangent
	return 1.0

func begin(direction: Vector2) -> void:
	facing = ART.ATLAS.facing(player.character_screen_direction(direction))
	_palm_floor.clear()
	_release_offsets.clear()
	_was_rolling = true
	set_physics_process(true)
	_apply_timeline(0.0)

func _physics_process(_delta: float) -> void:
	var phase: Node = player.phase_dash
	if (not is_instance_valid(phase) or not phase.dive_roll or player.dead or not player.movement_enabled or not player.attacking_enabled
		or player.vault_active or player.airborne_knockback or player.kick_active or player.is_throw_aim_active()):
		restore()
		return
	if phase.active:
		_apply_timeline(float(phase.elapsed) / maxf(player.active_dash_duration, 0.001))
		return
	# Normal landing and the final pose share the physics tick. An interrupted
	# roll hands the pose back immediately at its safe stopping point.
	if (_was_rolling and phase.landed
		and phase.elapsed >= player.active_dash_duration and not player.should_trigger_weapon_attack()):
		_was_rolling = false
		_apply_timeline(1.0)
		return
	restore()

func _apply_timeline(progress: float) -> void:
	var tick := clampf(progress, 0.0, 1.0) * TOTAL_TICKS
	for index in POSE_END_TICKS.size():
		if tick <= float(POSE_END_TICKS[index]) + 0.0001:
			_apply_frame(index)
			break
	var rise_start := float(POSE_END_TICKS[ART.Cel.HIP])
	var return_progress := clampf(inverse_lerp(rise_start, TOTAL_TICKS, tick), 0.0, 1.0)
	if frame >= ART.Cel.FEET:
		_apply_return_hands(return_progress)
	else:
		_apply_roll_hands(tick)

func _apply_frame(index: int) -> void:
	if not cel.visible:
		_original_visibility.clear()
		for part in _original_parts:
			_original_visibility.append(part.visible)
		cel.show()
		for hand in hands:
			hand.show()
	var region := Rect2(Vector2(Vector2i(index, facing) * ART.CELL), Vector2(ART.CELL))
	if cel.region_rect != region:
		cel.region_rect = region
	for part in _original_parts:
		if part.visible:
			part.hide()
	frame = index

func _apply_roll_hands(tick: float) -> void:
	var offsets := _hand_offsets[facing * ART.FRAME_COUNT + frame].duplicate()
	if frame == ART.Cel.PALMS or frame == ART.Cel.TRANSFER:
		_lock_palms(offsets)
		_release_offsets = offsets.duplicate()
	elif not _release_offsets.is_empty() and frame <= ART.Cel.BACK:
		var blend := smoothstep(float(POSE_END_TICKS[ART.Cel.TRANSFER]), float(POSE_END_TICKS[ART.Cel.BACK]), tick)
		for index in hands.size():
			offsets[index] = _release_offsets[index].lerp(offsets[index], blend)
	for index in hands.size():
		hands[index].position = offsets[index]
		hands[index].rotation = 0.0
		hands[index].scale = Vector2.ONE
		hands[index].z_index = -1 if index == 0 else 1

func _lock_palms(offsets: PackedVector2Array) -> void:
	var bridge := _depth_bridge()
	if bridge == null:
		return
	var camera: Camera3D = bridge._active_world_camera()
	if camera == null:
		return
	var basis := camera.global_basis.orthonormalized()
	var plane_origin: Vector3 = bridge._character_colour_origin(camera, 0.0)
	var capture_origin: Vector2 = bridge.viewport_offset - Vector2(bridge.render_viewport.size) * 0.5
	var pixel_size: float = bridge.actor_sprite.pixel_size
	if _palm_floor.is_empty():
		var ground: Vector3 = bridge._character_ground()
		for offset in offsets:
			var pixel: Vector2 = player.visual.to_global(offset + PALM_BOTTOM) - player.global_position + capture_origin
			var screen := camera.unproject_position(plane_origin + basis * Vector3(pixel.x, -pixel.y, 0.0) * pixel_size)
			var ray_start := camera.project_ray_origin(screen)
			var ray := camera.project_ray_normal(screen)
			if absf(ray.y) < 0.0001:
				_palm_floor.clear()
				return
			_palm_floor.append(ray_start + ray * ((ground.y - ray_start.y) / ray.y))
	for index in offsets.size():
		var screen := camera.unproject_position(_palm_floor[index])
		var ray_start := camera.project_ray_origin(screen)
		var ray := camera.project_ray_normal(screen)
		var intersection := ray_start + ray * (basis.z.dot(plane_origin - ray_start) / basis.z.dot(ray))
		var pixel := basis.transposed() * (intersection - plane_origin) / pixel_size
		offsets[index] = player.visual.to_local(player.global_position + Vector2(pixel.x, -pixel.y) - capture_origin) - PALM_BOTTOM

func _depth_bridge() -> Node3D:
	var reference: Variant = player.get_meta(&"depth_visual_bridge", null)
	return reference.get_ref() as Node3D if reference is WeakRef else null

func _apply_return_hands(progress: float) -> void:
	var weight := smoothstep(0.0, 1.0, progress)
	var start_offsets := _hand_offsets[facing * ART.FRAME_COUNT + ART.Cel.HIP]
	var armed: bool = not player.selected_weapon_id.is_empty() and player.held_weapon_sprite.visible
	var capture_turn := 0.0
	if armed:
		var bridge := _depth_bridge()
		if bridge != null:
			var unrotated: Vector2 = bridge.compensate_weapon_pixel_offset(Vector2.RIGHT)
			capture_turn = -unrotated.angle()
	var targets: Array = ([player.hand_presentation.grip_left, player.hand_presentation.grip_right] if armed
		else [player.left_hand_part, player.right_hand_part])
	for index in hands.size():
		var sprite := hands[index]
		var target: Sprite2D = targets[index]
		var center := target.global_position if target.centered else target.to_global(target.texture.get_size() * 0.5)
		if armed:
			var weapon_origin: Vector2 = player.weapon_root.global_position
			center = weapon_origin + (center - weapon_origin).rotated(capture_turn)
		var destination: Vector2 = player.visual.to_local(center)
		var start := start_offsets[index]
		var lift := sin(weight * PI) * minf(start.distance_to(destination) * 0.16, 2.5)
		sprite.position = start.lerp(destination, weight) - Vector2(0.0, lift)
		sprite.rotation = lerp_angle(0.0, target.global_rotation - player.visual.global_rotation + capture_turn, weight)
		sprite.scale = Vector2.ONE.lerp(target.global_scale / player.visual.global_scale, weight)
		sprite.z_index = target.z_index if progress >= 0.55 else (-1 if index == 0 else 1)

func restore() -> void:
	set_physics_process(false)
	_was_rolling = false
	_palm_floor.clear()
	_release_offsets.clear()
	frame = -1
	if not is_instance_valid(cel) or not cel.visible:
		return
	cel.hide()
	for hand in hands:
		if is_instance_valid(hand):
			hand.hide()
	for index in _original_parts.size():
		if is_instance_valid(_original_parts[index]):
			_original_parts[index].visible = _original_visibility[index]

func _exit_tree() -> void:
	# The sprites belong to CharacterVisual and share the player's lifetime.
	# A temporary detach must keep them available when the actor re-enters.
	restore()
