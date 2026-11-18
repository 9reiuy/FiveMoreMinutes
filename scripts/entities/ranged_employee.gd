extends EmployeeEnemy
## Sight, turning and fire discipline for ordinary armed employees.
## EmployeeEnemy owns movement, weapon handling and projectile creation.

const TURN_RATE := 300.0 * PI / 180.0
const RAISE_ANGLE := 15.0 * PI / 180.0
const BREAK_AIM_ANGLE := 45.0 * PI / 180.0
const SEARCH_SECONDS := 2.0
const FOLLOW_SECONDS := 0.70
const FIRST_AIM := 0.70
const REAIM := 0.45
const RIFLE_BURST := 3
const BURST_GAP := 0.85
# Rounding after repeated frame deltas must not add a whole tick to a deadline.
const TIMER_EPSILON := 1.0e-8

var turning := false
var look_angle := 0.0
var searching := false
var observed_velocity := Vector2.ZERO
var search_focus := Vector2.ZERO
var sweep_sign := 1.0
var short_warning := false
var rounds_in_burst := 0
var last_visual_frame := -1

func _init() -> void:
	ranged_aim_lock_seconds = 0.20

func _update_visual_target_perception() -> void:
	var had_sight := can_see_target
	var previous := last_known_target_position
	super._update_visual_target_perception()
	last_visual_frame = Engine.get_physics_frames()
	if not _weapon_requires_ranged_windup():
		return
	if not can_see_target:
		if had_sight:
			_begin_search(true)
		return
	searching = false
	lkp_search_time_left = 0.0
	if not turning:
		look_angle = weapon_root.rotation
		turning = true
	observed_velocity = last_known_target_velocity
	if had_sight:
		var travel := last_known_target_position - previous
		if travel.length_squared() > 1.0:
			# Dives can move the body directly without exposing that movement
			# through CharacterBody2D.velocity. Only compare visible samples.
			if observed_velocity.length_squared() < 1.0:
				observed_velocity = travel / _perception_update_interval()
			var change := (previous - global_position).angle_to(last_known_target_position - global_position)
			if absf(change) > 0.02:
				sweep_sign = signf(change)
	var locked := ranged_attack_fire_locked or (ranged_attack_windup_pending and ranged_attack_windup_left <= ranged_aim_lock_seconds)
	if ranged_attack_session_active and not locked and _aim_error() > BREAK_AIM_ANGLE:
		_cancel_ranged_attack_windup()

func _lose_target_in_smoke() -> void:
	if can_see_target and _weapon_requires_ranged_windup():
		_begin_search(true)
	super._lose_target_in_smoke()

func _begin_search(lost_sight := false) -> void:
	if searching or not hostile or not _has_known_target():
		return
	searching = true
	lkp_search_time_left = SEARCH_SECONDS
	search_focus = last_known_target_position + observed_velocity.limit_length(500.0) * 0.28
	_cancel_ranged_attack_windup()
	# A scripted alert can supply a search point before the first sighting.
	if lost_sight:
		short_warning = true

func _update_target_perception_clock(delta: float) -> void:
	super._update_target_perception_clock(delta)
	if not hostile or not _has_known_target() or not _weapon_requires_ranged_windup() or state in [State.KNOCKED_DOWN, State.GETTING_UP]:
		turning = false
		return
	if not turning:
		look_angle = weapon_root.rotation
		turning = true
	var focus := last_known_target_position
	if not can_see_target:
		_begin_search()
		lkp_search_time_left = maxf(0.0, lkp_search_time_left - delta)
		if lkp_search_time_left < TIMER_EPSILON:
			if state in [State.MOVE_TO_DOOR, State.ROOM_TRANSIT]:
				# Finish the reserved passage; its existing exit handles neutral patrol.
				has_last_known_target_position = false
				hostile = false
				lkp_search_time_left = 0.0
			else:
				_finish_target_search()
			searching = false
			turning = false
			short_warning = false
			observed_velocity = Vector2.ZERO
			return
		if lkp_search_time_left < SEARCH_SECONDS - FOLLOW_SECONDS:
			look_angle = wrapf(look_angle + sweep_sign * TURN_RATE * delta, -PI, PI)
			return
		focus = search_focus
	elif ranged_attack_windup_pending and ranged_attack_windup_left <= ranged_aim_lock_seconds:
		focus = ranged_attack_target_snapshot
	var offset := focus - global_position
	if offset.length_squared() > 0.01:
		look_angle = rotate_toward(look_angle, offset.angle(), TURN_RATE * delta)

func _get_gameplay_facing_direction() -> Vector2:
	return Vector2.from_angle(look_angle) if turning else super._get_gameplay_facing_direction()

func _weapon_aim_direction() -> Vector2:
	return Vector2.from_angle(look_angle) if turning else super._weapon_aim_direction()

func _search_last_known_position(target_position: Vector2, delta: float) -> void:
	if not _weapon_requires_ranged_windup():
		super._search_last_known_position(target_position, delta)
		return
	if not searching:
		_begin_search()
	attack_movement_intent = global_position.distance_squared_to(target_position) > 100.0
	velocity = _steer_toward(target_position) if attack_movement_intent else Vector2.ZERO

func _aim_error() -> float:
	return absf(angle_difference(look_angle, (last_known_target_position - global_position).angle()))

func _tracked_aim_point(target_position: Vector2) -> Vector2:
	if not turning:
		return target_position
	# At contact range the muzzle can extend past the player's feet.
	var distance := maxf(global_position.distance_to(target_position), global_position.distance_to(projectile_origin.global_position) + 2.0)
	return global_position + Vector2.from_angle(look_angle) * distance

func _begin_ranged_attack_windup() -> void:
	if ranged_attack_windup_pending or not turning or not can_see_target or _aim_error() > RAISE_ANGLE:
		return
	ranged_warning_seconds = REAIM if short_warning else FIRST_AIM
	super._begin_ranged_attack_windup()
	if ranged_attack_windup_pending:
		ranged_attack_windup_left = ranged_warning_seconds - TIMER_EPSILON

func _cancel_ranged_attack_windup() -> void:
	if ranged_attack_session_active or ranged_attack_magazine_primed:
		short_warning = true
	ranged_attack_magazine_primed = false
	rounds_in_burst = 0
	super._cancel_ranged_attack_windup()

func _try_fire_ranged_attack() -> void:
	# A closing door or a roll between sight samples must also be respected
	# on the release frame. The final locked shot still goes to its old point.
	if last_visual_frame != Engine.get_physics_frames():
		_update_visual_target_perception()
	if not can_see_target or not ranged_attack_session_active:
		return
	if not ranged_attack_fire_locked and _aim_error() > RAISE_ANGLE:
		_cancel_ranged_attack_windup()
		return
	var shot_point := ranged_attack_target_snapshot if ranged_attack_fire_locked else _tracked_aim_point(last_known_target_position)
	var world := _get_world()
	if not _has_target_line_of_sight(shot_point) or (world != null and world.has_method("is_furniture_shot_path_clear") and not world.is_furniture_shot_path_clear(get_projectile_origin(), shot_point, self)):
		_cancel_ranged_attack_windup()
		return
	var previous_serial := ranged_attack_shot_serial
	_fire_held_weapon()
	if previous_serial == ranged_attack_shot_serial or reload_left > 0.0 or held_weapon_id != "assault_rifle":
		return
	rounds_in_burst += 1
	if rounds_in_burst == RIFLE_BURST:
		_cancel_ranged_attack_windup()
		attack_cooldown_left = maxf(attack_cooldown_left, BURST_GAP - REAIM - TIMER_EPSILON)

func equip_weapon(weapon_id: String, skin_index: int = -1) -> void:
	super.equip_weapon(weapon_id, skin_index)
	short_warning = false
	if not _weapon_requires_ranged_windup():
		turning = false
		searching = false

func _start_reload() -> void:
	super._start_reload()
	short_warning = false

func set_room_runtime_active(active: bool) -> void:
	super.set_room_runtime_active(active)
	if not active:
		searching = false
		turning = false
		if _weapon_requires_ranged_windup():
			can_see_target = false
		observed_velocity = Vector2.ZERO
