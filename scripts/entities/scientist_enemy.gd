extends EmployeeEnemy

const POTIONS := preload("res://scripts/dream/scientist_potions.gd")
const SECOND_ATLAS := preload("res://art/Dream/enemy/Scientist2.png")
const POCKET := "scientist_potion"
const THROW_RANGE := 215.0
const THROW_RECOVERY := .29
# Pixel at the belt where the combined head/coat meets the two planted legs.
const THROW_HIP := Vector2(-2, 10)
# On both sheets the coat hem spans x=9..19 in front and x=12..22 on the back.
const BACK_UPPER_OFFSET := Vector2(-3, 0)
@onready var flask: Sprite2D = $CharacterVisual/BodyPivot/CarriedFlask
@onready var exhale_mouth: Polygon2D = $CharacterVisual/BodyPivot/Head/ExhaleMouth
var large_flask := false
var throw_age := -1.0
var released := false
var throw_aim := Vector2.ZERO
var throw_direction := Vector2.LEFT
var pool_field: Node3D
var _appearance_atlas: Texture2D = POTIONS.ATLAS

func _ready() -> void:
	enemy_archetype = &"scientist"
	held_weapon_id = POCKET
	var world := _get_world()
	if is_instance_valid(world):
		var appearance_seed: int = world.active_seed
		# A chapter retry rebuilds the world with a fresh layout seed.
		if world.get_meta(&"chapter_one", false):
			var chapter: Dictionary = world.profile_state.get("chapter_one", {})
			appearance_seed = int(chapter.get("seed", appearance_seed))
		if (hash([appearance_seed, Vector2i(position.round())]) & 1) != 0:
			_appearance_atlas = SECOND_ATLAS
	flask.texture = POTIONS.ATLAS
	flask.region_enabled = true
	super._ready()
	if is_instance_valid(world) and is_instance_valid(world.get("floor_root")):
		pool_field = POTIONS.ensure(world)

func configure_archetype(_archetype: StringName) -> void:
	enemy_archetype = &"scientist"

func _character_atlas() -> Texture2D:
	return _appearance_atlas

func _back_atlas_region() -> Rect2:
	return Rect2(64, 0, 32, 32)

func _set_back_facing(back: bool) -> void:
	if not dead and back != facing_back:
		var draw_offset := BACK_UPPER_OFFSET if back else Vector2.ZERO
		head.offset = draw_offset
		body.offset = draw_offset # The ragdoll splits the same drawing at the neck.
	super._set_back_facing(back)

func _setup_character_parts() -> void:
	super._setup_character_parts()
	# The flask is a body attachment. This rig sets its own screen side.
	set_meta(&"character_authored_facing_x", 0.0)
	left_leg.texture = _make_employee_atlas_texture(Rect2(108,44,4,9))
	right_leg.texture = _make_employee_atlas_texture(Rect2(113,44,4,9))
	left_hand.texture = _make_employee_atlas_texture(Rect2(102,79,5,4))
	right_hand.texture = _make_employee_atlas_texture(Rect2(117,79,5,4))
	# Column one shows the two feet at (10,26)/(15,26) relative to the upper cell.
	left_leg.position = body_pivot.position + head.position + Vector2(10,26)
	right_leg.position = body_pivot.position + head.position + Vector2(15,26)

func _weapon_max_range() -> float:
	return THROW_RANGE

func equip_weapon(_weapon_id: String, _skin_index: int = -1) -> void:
	held_weapon_id = POCKET

func _drop_held_weapon(_impulse: Vector2) -> void:
	_cancel_throw()

func set_room_runtime_active(active: bool) -> void:
	if not active:
		_cancel_throw()
	super.set_room_runtime_active(active)

func _update_enemy_blink(delta: float) -> void:
	if throw_age < 0.0 or dead:
		super._update_enemy_blink(delta)

func _sync_enemy_hands_visibility() -> void:
	if not dead:
		left_hand.show()
		right_hand.show()
	if hand_presentation != null:
		hand_presentation.refresh_visibility()

func _apply_live_facing(direction: Vector2) -> void:
	if dead or direction.length_squared() < .001:
		return
	last_facing_direction = direction.normalized()
	if throw_age >= 0.0:
		# The wrist follows the ballistic aim. The planted body keeps its pre-throw pose.
		return
	_set_back_facing(last_facing_direction.y < -.2)
	var horizontal := last_facing_direction.x
	if hand_presentation != null:
		horizontal = hand_presentation._screen_direction().x
	if absf(horizontal) > .001:
		character_visual.scale.x = -signf(horizontal) * absf(base_visual_scale.x)

func _update_weapon_aim() -> void:
	weapon_root.hide()
	var direction := last_facing_direction
	if throw_age >= 0.0:
		direction = throw_direction
	elif hostile and _has_known_target():
		direction = global_position.direction_to(_get_known_target_position())
	elif velocity.length_squared() > 1.0:
		direction = velocity.normalized()
	if direction.length_squared() > .01:
		weapon_root.rotation = direction.angle()
		_apply_live_facing(direction)
	_sync_enemy_hands_visibility()

func _physics_process_profiled(delta: float) -> void:
	if throw_age >= 0.0 and (dead or burning_panic or sky_drop_active or not room_runtime_active or not is_instance_valid(target) or target.get("dead") == true or state != State.ATTACK_PLAYER or not can_see_target or knockback_left > 0.0):
		_cancel_throw()
	super._physics_process_profiled(delta)

func _engage_visible_target(target_position: Vector2, distance: float, delta: float) -> void:
	if throw_age >= 0.0:
		velocity = Vector2.ZERO
		throw_age += delta
		if not released and throw_age >= _release_time():
			var world := _get_world()
			# Recheck on release; a door closing or smoke entering the sightline cancels the throw.
			if not _has_target_line_of_sight(target_position) or _smoke_blocks_target():
				_cancel_throw()
				return
			_apply_throw_presentation(_release_time())
			var start := global_position + throw_direction * 7.0
			var origin: Vector3 = world.get_gameplay_world_position(start,.7)
			var link: WeakRef = get_meta(&"depth_visual_bridge") if has_meta(&"depth_visual_bridge") else null
			if link != null and is_instance_valid(link.get_ref()):
				origin = link.get_ref().get_attached_part_world_position(flask)
			pool_field = POTIONS.ensure(world)
			pool_field.launch(large_flask, start, origin, throw_aim)
			released = true
			flask.hide()
		if throw_age >= _release_time() + THROW_RECOVERY:
			_cancel_throw()
			attack_cooldown_left = 1.65
		return
	if distance > THROW_RANGE:
		attack_movement_intent = true
		velocity = _steer_toward(target_position)
		return
	velocity = Vector2.ZERO
	if reaction_left <= 0.0 and attack_cooldown_left <= 0.0:
		_apply_live_facing(global_position.direction_to(target_position))
		large_flask = random.randi_range(0,1) == 0
		throw_aim = target_position + (target.body_collision.global_position - target.global_position)
		throw_direction = global_position.direction_to(throw_aim)
		if throw_direction == Vector2.ZERO:
			throw_direction = last_facing_direction
		throw_age = 0.0
		released = false
		flask.region_rect = POTIONS.LARGE_REGION if large_flask else POTIONS.SMALL_REGION
		flask.show()
		_update_weapon_aim()
		_update_hand_presentation()
	elif distance < 52.0:
		velocity = _steer_toward(global_position + target_position.direction_to(global_position) * 40.0)

func _release_time() -> float:
	return .48 if large_flask else .32

func _cancel_throw() -> void:
	if throw_age < 0.0:
		return
	throw_age = -1.0
	released = false
	flask.hide()
	exhale_mouth.hide()
	body_pivot.transform = Transform2D(0.0, body_pivot_base_position)
	if not dead:
		enemy_blink_phase = 0
		enemy_blink_phase_left = 0.0
		enemy_blink_time_left = maxf(enemy_blink_time_left, .40)
		_update_weapon_aim()
		_set_enemy_head_frame(0)
		super._update_hand_presentation()

func _update_hand_presentation() -> void:
	if throw_age < 0.0:
		super._update_hand_presentation()
		return
	_apply_throw_presentation(throw_age)

func _apply_throw_presentation(at_age: float) -> void:
	super._update_hand_presentation()
	var heading: Vector2 = hand_presentation._screen_direction()
	heading.x *= signf(character_visual.scale.x)
	var phase := clampf(at_age / _release_time(), 0.0, 1.0)
	var follow := clampf((at_age - _release_time()) / THROW_RECOVERY, 0.0, 1.0)
	_pose_throw_body(heading, phase, follow)
	_pose_throw_face(phase, follow)
	_pose_throw_hands(heading, phase, follow)

func _pose_throw_body(heading: Vector2, phase: float, follow: float) -> void:
	var windup := smoothstep(0.0, .48, phase) * (1.0 - smoothstep(.60, 1.0, phase))
	var drive := smoothstep(.60, 1.0, phase) * (1.0 - smoothstep(.14, 1.0, follow))
	var lean := heading.x * ((27.0 if large_flask else 16.0) * drive - (19.0 if large_flask else 10.0) * windup)
	# Seen end-on, one shoulder leads and the coat foreshortens towards the viewer.
	lean += absf(heading.y) * (windup - drive) * (6.0 if large_flask else 3.0)
	var height := 1.0 - .035 * windup - heading.y * drive * (.11 if large_flask else .07)
	var pose := Transform2D(deg_to_rad(lean), Vector2(1.0, height), 0.0, Vector2.ZERO)
	pose.origin = body_pivot_base_position + THROW_HIP - pose * THROW_HIP
	body_pivot.transform = pose

func _pose_throw_face(phase: float, follow: float) -> void:
	var eye_frame := 0
	if large_flask:
		if phase >= .84 and follow < .22:
			eye_frame = 2
		elif phase >= .27 and follow < .52:
			eye_frame = 1
	elif phase >= .27 and phase < .91:
		eye_frame = 1
	if enemy_head_frame_index != eye_frame:
		_set_enemy_head_frame(eye_frame)
	exhale_mouth.visible = large_flask and phase >= .84 and follow < .39 and not facing_back

func _pose_throw_hands(heading: Vector2, phase: float, follow: float) -> void:
	var rest := right_hand.position
	var off_rest := left_hand.position
	# Cock the flask outside the cheek so the eyes remain readable through the windup.
	var gather := Vector2(16.0, -11.0) if large_flask else Vector2(10.0, 2.0)
	var reach := rest + heading * (12.0 if large_flask else 15.0) + Vector2.UP * 4.0
	if phase < .65:
		right_hand.position = rest.lerp(gather, smoothstep(0.0,.65,phase))
	else:
		right_hand.position = gather.lerp(reach, smoothstep(.65,1.0,phase))
	right_hand.position = right_hand.position.lerp(rest, smoothstep(0,1,follow))
	var brace := right_hand.position + Vector2(-4,2) if large_flask else off_rest - heading * 4.0
	left_hand.position = off_rest.lerp(brace, sin(phase * PI * .7) * (1.0 - follow))
	right_hand.z_index = 4
	flask.position = right_hand.position + Vector2(2, -3 if large_flask else -4)
	flask.rotation = heading.x * lerpf(-.45,.62,smoothstep(.65,1.0,phase))

func _avoid_ground_hazards(proposed: Vector2) -> Vector2:
	if dead or state in [State.KNOCKED_DOWN, State.GETTING_UP, State.ROOM_TRANSIT]:
		return proposed
	var world := _get_world()
	if not is_instance_valid(pool_field):
		pool_field = world.floor_root.get_node_or_null("ScientistPotions") if is_instance_valid(world) else null
	if not is_instance_valid(pool_field) or pool_field.puddles.is_empty():
		return proposed
	var feet := body_collision.global_position
	var forward := proposed.normalized()
	var inside: bool = pool_field.contains(feet)
	if not inside and not pool_field.contains(feet + forward * 12.0) and not pool_field.contains(feet + forward * 26.0):
		return proposed
	if throw_age >= 0.0:
		_cancel_throw()
		attack_cooldown_left = maxf(attack_cooldown_left, .35)
	var point := feet
	var nearest := INF
	for pool in pool_field.puddles:
		var d: float = feet.distance_squared_to(pool.center)
		if d < nearest:
			nearest = d
			point = pool.center
	var away := point.direction_to(feet)
	if away == Vector2.ZERO:
		away = -last_facing_direction
	var course := away if inside or forward == Vector2.ZERO else forward
	var best := Vector2.ZERO
	var best_score := -INF
	for angle in [0.0,.55,-.55,1.05,-1.05,1.57,-1.57,2.25,-2.25,PI]:
		var candidate := course.rotated(angle)
		if not _steering_point_clear(global_position + candidate * 22.0, world):
			continue
		if not inside and (pool_field.contains(feet + candidate * 12.0) or pool_field.contains(feet + candidate * 26.0)):
			continue
		var score := course.dot(candidate) + away.dot(candidate) * .32
		if inside and not pool_field.contains(feet + candidate * 30.0):
			score += 2.0
		if score > best_score:
			best_score = score
			best = candidate
	return best * _get_current_move_speed()
