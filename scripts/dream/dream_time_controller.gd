extends Node

## The single authority for the Dream time scale.
##
## Gameplay remains driven by Engine.time_scale (there is deliberately no
## second "slow motion" simulation).  This node only composes the player
## input/action target, short real-time event boosts, hit-stop and lifecycle /
## pause state before writing the global scale.

const DEFAULT_MIN_TIME_SCALE := 0.005
const DEFAULT_MAX_TIME_SCALE := 1.0
const DEFAULT_RESUME_TAU := 0.035
const DEFAULT_SLOWDOWN_TAU := 0.075
const DEFAULT_SHOT_PULSE_SECONDS := 0.05
const DEFAULT_WAKE_GRACE_SECONDS := 0.12
const DEFAULT_MOVEMENT_RELEASE_GRACE_SECONDS := 0.20
const DEFAULT_MOVEMENT_DEADZONE := 0.05

var mode_enabled := false
var lifecycle_enabled := true
var pause_authority := false

var bound_player: Node
var bound_owner: Node
var runtime_config: DemoConfig

## Public state is intentionally split: callers can inspect the current
## player-activity base independently from the resolved hit-stop override.
var base_player_activity_scale := 1.0
var current_scale := 1.0
var resolved_time_scale := 1.0
var hitstop_active := false
var hitstop_scale := 0.05
var hitstop_remaining_real := 0.0

## RMB throw aim is presentation-only and deliberately has no time override.
## Keep the legacy state/API for older scene callers, but it is not consulted
## by the compositor anymore.
var throw_aim_active := false
## T is only the enable/disable switch for the existing activity-driven
## Superhot time compositor.  It never installs a second time-scale override.
## Dream sessions start in normal time.  T remains the explicit opt-in toggle
## for the existing activity-driven Superhot compositor.
var slow_time_enabled := false

var shot_pulse_remaining_real := 0.0
var movement_wake_remaining_real := 0.0
## Separate real-time grace after movement input is released.  The wake timer
## above handles the rising edge; this timer owns only the falling edge.
var movement_release_remaining_real := 0.0
var last_player_activity := 0.0
var last_locomotion_speed := 0.0

var _last_real_usec := 0
var _real_delta := 1.0 / 60.0
var _last_hit_stop_usec := -1000000000
var _input_was_active := false
var _hitstop_token := 0
var tactical_planning_active := false
var tactical_planning_scale := 0.05
var dive_bullet_time_active := false
var dive_bullet_time_scale := 0.2
var reaction_remaining_real := 0.0
var near_miss_cooldown_real := 0.0

func begin_reaction_time(reason: StringName = &"parry") -> bool:
	if not mode_enabled or not lifecycle_enabled or pause_authority or get_tree().paused: return false
	if not is_instance_valid(bound_player) or bool(bound_player.get("dead")): return false
	if reason==&"near_miss" and near_miss_cooldown_real>0: return false
	reaction_remaining_real = .6
	if reason==&"near_miss": near_miss_cooldown_real=.8
	# The compositor writes Engine.time_scale on its next idle update. Changing
	# it inside a projectile physics callback would mismatch this tick's delta.
	return true

func is_reaction_time_active() -> bool:
	return reaction_remaining_real>0 and mode_enabled and lifecycle_enabled and not pause_authority and not get_tree().paused

func clear_reaction_time() -> void:
	reaction_remaining_real=0.0
	near_miss_cooldown_real=0.0


func _ready() -> void:
	add_to_group(&"dream_time_controller")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_real_clock()
	_apply_engine_scale(DEFAULT_MAX_TIME_SCALE)


func _process(_scaled_delta: float) -> void:
	var real_delta := _consume_real_delta()
	if bound_owner != null and not is_instance_valid(bound_owner):
		exit_dream_time_mode()
		return
	if bound_player != null and not is_instance_valid(bound_player):
		bound_player = null

	_update_manual_bullet_time_input()
	_update_input_edge()
	_update_real_timers(real_delta)

	if not mode_enabled or not lifecycle_enabled:
		_apply_engine_scale(DEFAULT_MAX_TIME_SCALE)
		return

	if is_instance_valid(bound_player) and bool(bound_player.get("dead")): clear_reaction_time()
	if pause_authority or get_tree().paused:
		_apply_engine_scale(DEFAULT_MAX_TIME_SCALE)
		return

	if tactical_planning_active:
		resolved_time_scale = tactical_planning_scale
		_apply_engine_scale(resolved_time_scale)
		return
	if reaction_remaining_real>0:
		resolved_time_scale=minf(.2,hitstop_scale if hitstop_active else 1.0)
		_apply_engine_scale(resolved_time_scale)
		return

	if dive_bullet_time_active:
		resolved_time_scale = dive_bullet_time_scale
		_apply_engine_scale(resolved_time_scale)
		return

	var min_scale := _config_float(&"superhot_min_time_scale", DEFAULT_MIN_TIME_SCALE)
	var max_scale := _config_float(&"superhot_max_time_scale", DEFAULT_MAX_TIME_SCALE)
	min_scale = clampf(min_scale, 0.001, max_scale)
	max_scale = maxf(max_scale, min_scale)
	if not slow_time_enabled:
		# T-off is an explicit normal-time policy. Hit-stop remains the only
		# temporary override that can still lower the resolved scale.
		base_player_activity_scale = DEFAULT_MAX_TIME_SCALE
		current_scale = minf(DEFAULT_MAX_TIME_SCALE, hitstop_scale) if hitstop_active else DEFAULT_MAX_TIME_SCALE
		resolved_time_scale = current_scale
		_apply_engine_scale(resolved_time_scale)
		return

	last_player_activity = _sample_player_activity()
	var desired_base := lerpf(min_scale, max_scale, last_player_activity)
	var event_boost_active := (
		shot_pulse_remaining_real > 0.0
		or movement_wake_remaining_real > 0.0
		or movement_release_remaining_real > 0.0
	)
	if event_boost_active:
		desired_base = max_scale

	var slowdown_tau := maxf(
		_config_float(&"superhot_slowdown_tau", DEFAULT_SLOWDOWN_TAU),
		0.001
	)
	var resume_tau := maxf(
		_config_float(&"superhot_resume_tau", DEFAULT_RESUME_TAU),
		0.001
	)
	var tau := resume_tau if desired_base > base_player_activity_scale else slowdown_tau
	var base_alpha := 1.0 - exp(-real_delta / tau)
	base_player_activity_scale = lerpf(
		base_player_activity_scale,
		desired_base,
		clampf(base_alpha, 0.0, 1.0)
	)

	if hitstop_active:
		# Hit-stop is a temporary override only.  The player-driven base keeps
		# evolving underneath it, so ending hit-stop never restores a stale 1.0.
		current_scale = minf(base_player_activity_scale, hitstop_scale)
	else:
		var resolved_alpha := 1.0 - exp(-real_delta / resume_tau)
		current_scale = lerpf(
			current_scale,
			base_player_activity_scale,
			clampf(resolved_alpha, 0.0, 1.0)
		)
		if event_boost_active:
			# A raw input edge or confirmed projectile wakes the game on this
			# real-time frame; the following frames return through smoothing.
			current_scale = maxf(current_scale, max_scale)

	resolved_time_scale = clampf(current_scale, min_scale, max_scale)
	_apply_engine_scale(resolved_time_scale)


func begin_tactical_planning(scale: float = 0.05) -> void:
	tactical_planning_active = true
	tactical_planning_scale = scale
	_reset_real_clock()
	resolved_time_scale = scale
	_apply_engine_scale(resolved_time_scale)


func end_tactical_planning() -> void:
	tactical_planning_active = false
	_reset_real_clock()
	_apply_engine_scale(DEFAULT_MAX_TIME_SCALE)


func is_tactical_planning_active() -> bool:
	return tactical_planning_active


func begin_dive_time(scale: float = 0.2) -> void:
	dive_bullet_time_active = true
	dive_bullet_time_scale = clampf(scale, 0.001, 1.0)
	_reset_real_clock()
	resolved_time_scale = dive_bullet_time_scale
	_apply_engine_scale(resolved_time_scale)


func end_dive_time() -> void:
	if not dive_bullet_time_active:
		return
	dive_bullet_time_active = false
	_reset_real_clock()
	resolved_time_scale = DEFAULT_MAX_TIME_SCALE
	_apply_engine_scale(DEFAULT_MAX_TIME_SCALE)


func is_dive_time_active() -> bool:
	return dive_bullet_time_active


func begin_throw_aim(scale: float = -1.0) -> void:
	# Deprecated compatibility marker. Throw aim never changes world time.
	throw_aim_active = true
	_reset_real_clock()


func end_throw_aim() -> void:
	throw_aim_active = false
	_reset_real_clock()


func set_throw_aim_active(active: bool, scale: float = -1.0) -> void:
	if active:
		begin_throw_aim(scale)
	else:
		end_throw_aim()


func is_throw_aim_active() -> bool:
	return throw_aim_active


func set_slow_time_enabled(enabled: bool) -> void:
	slow_time_enabled = enabled
	_reset_real_clock()
	if not enabled:
		base_player_activity_scale = DEFAULT_MAX_TIME_SCALE
		# The toggle only disables the activity-driven slow-time layer.  A
		# currently active hit-stop remains authoritative even when T is turned
		# off, so changing the toggle cannot release a confirmed impact early.
		current_scale = minf(DEFAULT_MAX_TIME_SCALE, hitstop_scale) if hitstop_active else DEFAULT_MAX_TIME_SCALE
		resolved_time_scale = current_scale
		_apply_engine_scale(resolved_time_scale)


func toggle_slow_time_enabled() -> bool:
	set_slow_time_enabled(not slow_time_enabled)
	return slow_time_enabled


func is_slow_time_enabled() -> bool:
	return slow_time_enabled


## Compatibility aliases for older callers. They now toggle the existing
## activity compositor instead of creating a manual Bullet Time mode.
func begin_manual_bullet_time(_scale: float = -1.0) -> void:
	set_slow_time_enabled(true)


func end_manual_bullet_time() -> void:
	set_slow_time_enabled(false)


func set_manual_bullet_time_active(active: bool, _scale: float = -1.0) -> void:
	set_slow_time_enabled(active)


func is_manual_bullet_time_active() -> bool:
	return slow_time_enabled


func enter_dream_time_mode(player: Node, config: DemoConfig = null, owner: Node = null) -> void:
	clear_reaction_time()
	if bound_player != null and bound_player != player and is_instance_valid(bound_player):
		_disconnect_player_signal(bound_player)
	bound_player = player if player != null and is_instance_valid(player) else null
	bound_owner = owner if owner != null and is_instance_valid(owner) else null
	runtime_config = config
	mode_enabled = bound_player != null
	lifecycle_enabled = true
	pause_authority = false
	hitstop_active = false
	hitstop_remaining_real = 0.0
	throw_aim_active = false
	# A newly entered Dream always starts at x1.00.  Do not carry the previous
	# session's T state across scene boundaries.
	slow_time_enabled = false
	shot_pulse_remaining_real = 0.0
	movement_wake_remaining_real = 0.0
	movement_release_remaining_real = 0.0
	_last_hit_stop_usec = -1000000000
	base_player_activity_scale = _config_float(&"superhot_max_time_scale", DEFAULT_MAX_TIME_SCALE)
	current_scale = base_player_activity_scale
	resolved_time_scale = current_scale
	_input_was_active = false
	_reset_real_clock()
	_connect_player_signal(bound_player)
	_apply_engine_scale(resolved_time_scale if mode_enabled else DEFAULT_MAX_TIME_SCALE)


func bind_player(player: Node, config: DemoConfig = null, owner: Node = null) -> void:
	enter_dream_time_mode(player, config, owner)


func exit_dream_time_mode(owner: Node = null) -> void:
	# Scene transitions can queue the old Dream for deletion while the next
	# Dream scene is already entering.  An old owner must not tear down the new
	# owner's binding during that overlap; a null owner remains the explicit
	# global reset used by Main/menu lifecycle code.
	if owner != null and bound_owner != null and bound_owner != owner:
		return
	clear_reaction_time()
	if bound_player != null and is_instance_valid(bound_player):
		_disconnect_player_signal(bound_player)
	mode_enabled = false
	lifecycle_enabled = false
	pause_authority = false
	bound_player = null
	bound_owner = null
	runtime_config = null
	hitstop_active = false
	hitstop_remaining_real = 0.0
	throw_aim_active = false
	slow_time_enabled = false
	shot_pulse_remaining_real = 0.0
	movement_wake_remaining_real = 0.0
	movement_release_remaining_real = 0.0
	_last_hit_stop_usec = -1000000000
	base_player_activity_scale = DEFAULT_MAX_TIME_SCALE
	current_scale = DEFAULT_MAX_TIME_SCALE
	resolved_time_scale = DEFAULT_MAX_TIME_SCALE
	_input_was_active = false
	_reset_real_clock()
	_apply_engine_scale(DEFAULT_MAX_TIME_SCALE)


func reset_for_scene_change() -> void:
	exit_dream_time_mode()


func clear() -> void:
	exit_dream_time_mode()


func set_lifecycle_enabled(enabled: bool) -> void:
	lifecycle_enabled = enabled
	if not enabled:
		clear_reaction_time()
		_apply_engine_scale(DEFAULT_MAX_TIME_SCALE)


func set_pause_authority(paused: bool) -> void:
	pause_authority = paused
	_reset_real_clock()
	if paused:
		_apply_engine_scale(DEFAULT_MAX_TIME_SCALE)


func notify_confirmed_shot() -> void:
	if not mode_enabled:
		return
	shot_pulse_remaining_real = maxf(
		shot_pulse_remaining_real,
		_config_float(&"superhot_shot_pulse_seconds", DEFAULT_SHOT_PULSE_SECONDS)
	)
	# Do not wait for a scaled frame to wake the game after a confirmed shot.
	if slow_time_enabled:
		current_scale = maxf(
			current_scale,
			_config_float(&"superhot_max_time_scale", DEFAULT_MAX_TIME_SCALE)
		)
	if not hitstop_active and slow_time_enabled:
		resolved_time_scale = current_scale
		_apply_engine_scale(resolved_time_scale)


func request_hit_stop(
	scale: float = 0.05,
	duration: float = 0.02,
	minimum_interval: float = 0.06
) -> bool:
	if not mode_enabled or lifecycle_enabled == false or pause_authority or get_tree().paused:
		return false
	var now := Time.get_ticks_usec()
	if hitstop_active:
		return false
	if now - _last_hit_stop_usec < int(maxf(minimum_interval, 0.0) * 1000000.0):
		return false
	_last_hit_stop_usec = now
	_hitstop_token += 1
	hitstop_active = true
	hitstop_scale = clampf(scale, 0.001, 1.0)
	hitstop_remaining_real = maxf(duration, 0.0)
	current_scale = minf(current_scale, hitstop_scale)
	resolved_time_scale = current_scale
	_apply_engine_scale(resolved_time_scale)
	return true


func reset_hit_stop() -> void:
	_hitstop_token += 1
	hitstop_active = false
	hitstop_remaining_real = 0.0
	# Keep the current player-driven base.  The normal compositor will blend
	# current_scale back to that base using the real clock.


func get_real_delta() -> float:
	return _real_delta


func get_resolved_time_scale() -> float:
	return resolved_time_scale


func get_base_player_activity_scale() -> float:
	return base_player_activity_scale


func is_dream_time_mode_enabled() -> bool:
	return mode_enabled and lifecycle_enabled


func _connect_player_signal(player: Node) -> void:
	if player == null or not is_instance_valid(player) or not player.has_signal(&"confirmed_projectile_fired"):
		return
	var callback := Callable(self, "_on_confirmed_projectile_fired")
	if not player.is_connected(&"confirmed_projectile_fired", callback):
		player.connect(&"confirmed_projectile_fired", callback)


func _disconnect_player_signal(player: Node) -> void:
	if player == null or not is_instance_valid(player) or not player.has_signal(&"confirmed_projectile_fired"):
		return
	var callback := Callable(self, "_on_confirmed_projectile_fired")
	if player.is_connected(&"confirmed_projectile_fired", callback):
		player.disconnect(&"confirmed_projectile_fired", callback)


func _on_confirmed_projectile_fired() -> void:
	notify_confirmed_shot()


func _consume_real_delta() -> float:
	var now := Time.get_ticks_usec()
	if _last_real_usec <= 0:
		_last_real_usec = now
		_real_delta = 1.0 / 60.0
		return _real_delta
	var delta := clampf(float(now - _last_real_usec) / 1000000.0, 0.0, 0.1)
	_last_real_usec = now
	_real_delta = delta if delta > 0.0 else 1.0 / 60.0
	return _real_delta


func _reset_real_clock() -> void:
	_last_real_usec = Time.get_ticks_usec()
	_real_delta = 1.0 / 60.0


func _update_real_timers(real_delta: float) -> void:
	if lifecycle_enabled and not pause_authority and not get_tree().paused:
		reaction_remaining_real=maxf(0.0,reaction_remaining_real-real_delta)
		near_miss_cooldown_real=maxf(0.0,near_miss_cooldown_real-real_delta)
	shot_pulse_remaining_real = maxf(0.0, shot_pulse_remaining_real - real_delta)
	movement_wake_remaining_real = maxf(0.0, movement_wake_remaining_real - real_delta)
	movement_release_remaining_real = maxf(0.0, movement_release_remaining_real - real_delta)
	if hitstop_active:
		hitstop_remaining_real = maxf(0.0, hitstop_remaining_real - real_delta)
		if hitstop_remaining_real <= 0.0:
			hitstop_active = false


func _update_input_edge() -> void:
	# Edge wake/release follows the Player's formal action-state authority. The
	# authority includes restored WASD locomotion, while DashAim remains a
	# preview-only state and therefore does not wake time by itself.
	var active := false
	if bound_player != null and is_instance_valid(bound_player) and bound_player.has_method("is_time_activity_active"):
		active = bool(bound_player.call("is_time_activity_active"))
	if active and not _input_was_active:
		# A fresh movement edge wakes the world immediately and cancels any
		# release hold left over from a previous input burst.
		movement_release_remaining_real = 0.0
		movement_wake_remaining_real = maxf(
			movement_wake_remaining_real,
			_config_float(&"superhot_movement_wake_grace_seconds", DEFAULT_WAKE_GRACE_SECONDS)
		)
	elif not active and _input_was_active:
		# Keep normal time briefly after the formal action ends.  This is a
		# real-time hold, so a heavily slowed frame cannot shorten the grace.
		movement_release_remaining_real = maxf(
			movement_release_remaining_real,
			_config_float(
				&"superhot_movement_release_grace_seconds",
				DEFAULT_MOVEMENT_RELEASE_GRACE_SECONDS
			)
		)
	_input_was_active = active


func _update_manual_bullet_time_input() -> void:
	# Poll a single just-pressed edge so T is a toggle, not a hold-to-slow mode.
	# `toggle_slow_time` is the preferred name; `bullet_time` remains the
	# existing project action for backwards-compatible T bindings.
	if not mode_enabled or not lifecycle_enabled:
		return
	var action_name := "toggle_slow_time" if InputMap.has_action("toggle_slow_time") else "bullet_time"
	if InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name):
		toggle_slow_time_enabled()


func _read_movement_input_magnitude() -> float:
	# Compatibility helper for older callers. Read the canonical actions, but
	# let the Player remain the final authority when movement is locked.
	if bound_player == null or not is_instance_valid(bound_player):
		return 0.0
	var movement_enabled_variant: Variant = bound_player.get("movement_enabled")
	if movement_enabled_variant is bool and not bool(movement_enabled_variant):
		return 0.0
	return Input.get_vector("move_left", "move_right", "move_up", "move_down").length()


func _sample_player_activity() -> float:
	if bound_player == null or not is_instance_valid(bound_player):
		last_locomotion_speed = 0.0
		return 0.0
	# Activity is formal action/state driven rather than raw keyboard input or
	# displacement driven.  Actions remain active even when their instantaneous
	# velocity is zero.
	if bound_player.has_method("is_time_activity_active"):
		var active: bool = bool(bound_player.call("is_time_activity_active"))
		last_locomotion_speed = 1.0 if active else 0.0
		return last_locomotion_speed
	var speed := 0.0
	if bound_player.has_method("get_time_locomotion_speed"):
		speed = maxf(float(bound_player.call("get_time_locomotion_speed")), 0.0)
	else:
		# This fallback is only for compatible actors that predate the explicit
		# locomotion sample.  DreamPlayer itself always uses the filtered method.
		var velocity_variant: Variant = bound_player.get("velocity")
		if velocity_variant is Vector2:
			speed = velocity_variant.length()
	last_locomotion_speed = speed
	var reference := _config_float(&"player_movement_speed", 200.0)
	if reference <= 0.0:
		reference = maxf(float(bound_player.get("movement_speed")), 1.0)
	return clampf(speed / reference, 0.0, 1.0)


func _config_float(property: StringName, fallback: float) -> float:
	if runtime_config != null:
		var value: Variant = runtime_config.get(property)
		if value is float or value is int:
			return float(value)
	return fallback


func _apply_engine_scale(value: float) -> void:
	var clamped := clampf(value, 0.001, DEFAULT_MAX_TIME_SCALE)
	if not is_equal_approx(Engine.time_scale, clamped):
		Engine.time_scale = clamped
