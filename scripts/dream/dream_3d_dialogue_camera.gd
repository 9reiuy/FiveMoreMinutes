class_name Dream3DDialogueCamera
extends Node

## Shared dialogue-camera modifier for the 3D Random Dream and Tutorial scenes.
## The helper never writes Camera3D transforms.  The owning scene remains the
## single camera authority and only consumes the focus/weight values below.

const FALLBACK_CELL_PIXELS := 32.0

@export_category("Dialogue camera timing")
@export_range(0.0, 2.0, 0.01) var dialogue_enter_duration := 0.45
@export_range(0.0, 2.0, 0.01) var dialogue_exit_duration := 0.55
@export_range(0.0, 1.0, 0.01) var speaker_switch_duration := 0.30
@export_range(0.01, 1.0, 0.01) var speaker_follow_time := 0.15
@export_range(0.1, 1.0, 0.01) var dialogue_zoom_factor := 0.80

enum FocusMode {
	CONVERSATION,
	SPEAKER_FOCUS,
}

enum FocusState {
	INACTIVE,
	ENTERING,
	ACTIVE,
	EXITING,
}

var focus_mode := FocusMode.CONVERSATION
var state := FocusState.INACTIVE
var dialogue_weight := 0.0

var conversation_partner: Node2D
var current_speaker: Node2D
var focus_current := Vector3.ZERO
var focus_target := Vector3.ZERO
var last_valid_focus := Vector3.ZERO
var exit_focus := Vector3.ZERO

var _player: Node2D
var _ground_mapper: Callable
var _dialogue_active := false
var _has_focus := false
var _has_last_valid_focus := false
var _weight_tween: Tween
var _weight_transition_token := 0

var _focus_transition_active := false
var _focus_transition_elapsed := 0.0
var _focus_transition_from := Vector3.ZERO


func _ready() -> void:
	# Dialogue UI is process-always; the modifier must finish its transition even
	# when a pause/menu briefly pauses the gameplay tree.
	process_mode = Node.PROCESS_MODE_ALWAYS


func configure(player_node: Node2D, ground_mapper: Callable = Callable()) -> void:
	_player = player_node
	_ground_mapper = ground_mapper


func begin_dialogue_focus(
	speaker: Node2D = null,
	mode: int = FocusMode.CONVERSATION
) -> void:
	# A null speaker is deliberately not promoted to an origin or to Player.  A
	# narrator/system line can therefore leave the normal camera untouched.
	if speaker == null or not _is_valid_actor(speaker):
		return
	var was_exiting := state == FocusState.EXITING
	var was_active := _dialogue_active and not was_exiting
	var previous_mode := focus_mode
	_dialogue_active = true
	focus_mode = clampi(mode, int(FocusMode.CONVERSATION), int(FocusMode.SPEAKER_FOCUS))
	if was_active:
		# A coordinator may repeat begin() while a session is already active.  Do
		# not restart the 0.45s weight transition (or make the camera breathe on
		# every line); treat it as a speaker/mode update instead.
		_set_speaker_internal(speaker, true)
		if previous_mode != focus_mode and _has_focus:
			_focus_transition_from = focus_current
			_focus_transition_elapsed = 0.0
			_focus_transition_active = true
		if state == FocusState.INACTIVE:
			state = FocusState.ACTIVE if dialogue_weight >= 0.999 else FocusState.ENTERING
		return
	state = FocusState.ENTERING
	_set_speaker_internal(speaker, false)
	# Re-entering while EXITING cancels only the weight transition.  The current
	# visual focus is retained and the new speaker is followed from there.
	_start_weight_tween(1.0, dialogue_enter_duration)
	if was_exiting and _has_focus:
		_focus_transition_from = focus_current
		_focus_transition_elapsed = 0.0
		_focus_transition_active = true


func set_dialogue_speaker(speaker: Node2D = null, mode_override: int = -1) -> void:
	# Resolver failures must be safe: keep the current/last valid focus rather
	# than guessing a different actor or jumping to the world origin.
	if speaker == null or not _is_valid_actor(speaker):
		return
	var previous_mode := focus_mode
	if mode_override >= int(FocusMode.CONVERSATION) and mode_override <= int(FocusMode.SPEAKER_FOCUS):
		focus_mode = mode_override
	if not _dialogue_active:
		begin_dialogue_focus(speaker, focus_mode)
		return
	_set_speaker_internal(speaker, true)
	if previous_mode != focus_mode and _has_focus:
		# A mode change can alter the resolved position even when the Node identity
		# stays the same (for example, partner midpoint -> speaker-only focus).
		_focus_transition_from = focus_current
		_focus_transition_elapsed = 0.0
		_focus_transition_active = true


func end_dialogue_focus() -> void:
	if not _dialogue_active and state != FocusState.ENTERING and state != FocusState.ACTIVE:
		return
	# Freeze the exact composition at the end of the session.  From this point
	# on, a moving or freed Speaker cannot pull the pull-out camera away.
	if _has_focus:
		exit_focus = focus_current
	elif _has_last_valid_focus:
		exit_focus = last_valid_focus
	else:
		_weight_transition_token += 1
		if _weight_tween != null and _weight_tween.is_valid():
			_weight_tween.kill()
			_weight_tween = null
		_dialogue_active = false
		state = FocusState.INACTIVE
		dialogue_weight = 0.0
		return
	focus_current = exit_focus
	focus_target = exit_focus
	_has_focus = true
	_dialogue_active = false
	state = FocusState.EXITING
	_focus_transition_active = false
	# Do not keep a freed node alive through the EXITING transition.
	conversation_partner = null
	current_speaker = null
	_start_weight_tween(0.0, dialogue_exit_duration)


func clear_dialogue_focus() -> void:
	_weight_transition_token += 1
	if _weight_tween != null and _weight_tween.is_valid():
		_weight_tween.kill()
	_weight_tween = null
	_dialogue_active = false
	state = FocusState.INACTIVE
	dialogue_weight = 0.0
	conversation_partner = null
	current_speaker = null
	focus_current = Vector3.ZERO
	focus_target = Vector3.ZERO
	last_valid_focus = Vector3.ZERO
	exit_focus = Vector3.ZERO
	_has_focus = false
	_has_last_valid_focus = false
	_focus_transition_active = false
	_focus_transition_elapsed = 0.0


## Called by the owning scene's existing final camera writer once per frame.
## `player_ground_world` is already mapped by that scene, so the helper never
## changes the authoritative 2D->3D ground convention.
func advance(delta: float, player_ground_world: Vector3) -> void:
	if state == FocusState.EXITING:
		# EXITING is intentionally frozen; only dialogue_weight changes.
		focus_current = exit_focus
		focus_target = exit_focus
		return
	if not _dialogue_active:
		return
	var resolved := _resolve_live_focus(player_ground_world)
	if bool(resolved.get("valid", false)):
		var next_target: Vector3 = resolved.get("position", player_ground_world)
		focus_target = next_target
		last_valid_focus = next_target
		_has_last_valid_focus = true
		if not _has_focus:
			# The entry weight blends from the current Player camera to this target;
			# initializing here avoids an origin flash on the first frame.
			focus_current = next_target
			_has_focus = true
			_focus_transition_active = false
		else:
			_update_focus_smoothing(delta)
	elif _has_last_valid_focus:
		focus_target = last_valid_focus
		_update_focus_smoothing(delta)
	if state == FocusState.ENTERING and dialogue_weight >= 0.999:
		state = FocusState.ACTIVE


func get_focus_world(fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if _has_focus:
		return focus_current
	if _has_last_valid_focus:
		return last_valid_focus
	return fallback


func get_dialogue_weight() -> float:
	return clampf(dialogue_weight, 0.0, 1.0)


func is_dialogue_active() -> bool:
	return _dialogue_active or state == FocusState.EXITING


func _set_speaker_internal(speaker: Node2D, start_transition: bool) -> void:
	if speaker == null or not _is_valid_actor(speaker):
		return
	var changed := current_speaker == null or current_speaker != speaker
	var should_transition := changed
	current_speaker = speaker
	if focus_mode == FocusMode.CONVERSATION:
		# Player lines do not replace the established conversation partner.  A
		# coordinator can explicitly pass another NPC to change the partner.
		if speaker != _player:
			conversation_partner = speaker
		elif conversation_partner == null or not _is_valid_actor(conversation_partner):
			conversation_partner = speaker
		# Changing only the text speaker from the partner to Player does not alter
		# the midpoint composition, so it must not start a needless camera blend.
		if speaker == _player:
			should_transition = false
	if start_transition and should_transition and _has_focus:
		_focus_transition_from = focus_current
		_focus_transition_elapsed = 0.0
		_focus_transition_active = true


func _resolve_live_focus(player_ground_world: Vector3) -> Dictionary:
	if focus_mode == FocusMode.CONVERSATION:
		if not _is_valid_actor(conversation_partner):
			return {"valid": false}
		var partner_world := _map_actor_to_ground(conversation_partner)
		return {"valid": true, "position": player_ground_world.lerp(partner_world, 0.5)}
	if not _is_valid_actor(current_speaker):
		return {"valid": false}
	return {"valid": true, "position": _map_actor_to_ground(current_speaker)}


func _map_actor_to_ground(actor: Node2D) -> Vector3:
	if _ground_mapper.is_valid():
		var mapped: Variant = _ground_mapper.call(actor.global_position)
		if mapped is Vector3:
			return mapped
	# Both current 3D scenes use this formal pixel-to-cell mapping.  The callback
	# supplied by each owner remains authoritative; this is only a safe fallback
	# for isolated helper tests.
	return Vector3(actor.global_position.x / FALLBACK_CELL_PIXELS, 0.0, actor.global_position.y / FALLBACK_CELL_PIXELS)


func _update_focus_smoothing(delta: float) -> void:
	if delta <= 0.0:
		return
	if _focus_transition_active:
		_focus_transition_elapsed += delta
		var duration := maxf(speaker_switch_duration, 0.001)
		var progress := clampf(_focus_transition_elapsed / duration, 0.0, 1.0)
		var eased := progress * progress * (3.0 - 2.0 * progress)
		focus_current = _focus_transition_from.lerp(focus_target, eased)
		if progress >= 1.0:
			_focus_transition_active = false
		return
	# Exponential smoothing is stable across frame rates and is not restarted
	# when the same Speaker moves.
	var alpha := 1.0 - exp(-delta / maxf(speaker_follow_time, 0.001))
	focus_current = focus_current.lerp(focus_target, alpha)


func _start_weight_tween(target: float, duration: float) -> void:
	_weight_transition_token += 1
	var transition_token := _weight_transition_token
	if _weight_tween != null and _weight_tween.is_valid():
		_weight_tween.kill()
	_weight_tween = null
	var clamped_target := clampf(target, 0.0, 1.0)
	var clamped_duration := maxf(duration, 0.0)
	if clamped_duration <= 0.0:
		dialogue_weight = clamped_target
		_on_weight_tween_finished(clamped_target, transition_token)
		return
	_weight_tween = create_tween()
	_weight_tween.tween_property(self, "dialogue_weight", clamped_target, clamped_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_weight_tween.tween_callback(_on_weight_tween_finished.bind(clamped_target, transition_token))


func _on_weight_tween_finished(target: float, transition_token: int) -> void:
	if transition_token != _weight_transition_token:
		return
	if is_zero_approx(target):
		dialogue_weight = 0.0
		state = FocusState.INACTIVE
		_weight_tween = null
		_has_focus = false
		_has_last_valid_focus = false
		last_valid_focus = Vector3.ZERO
		exit_focus = Vector3.ZERO
		return
	if is_equal_approx(target, 1.0) and _dialogue_active:
		dialogue_weight = 1.0
		state = FocusState.ACTIVE
	_weight_tween = null


func _is_valid_actor(actor: Node2D) -> bool:
	return actor != null and is_instance_valid(actor) and actor.is_inside_tree()
