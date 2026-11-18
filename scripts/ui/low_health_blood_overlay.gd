extends Control
## Screen-edge blood overlay shown when the player drops to <= 1/3 HP.

const LOW_HEALTH_RATIO_THRESHOLD := 1.0 / 3.0
const THRESHOLD_EPSILON := 0.0005

const BASE_ACTIVE_INTENSITY := 0.72
const MAX_ACTIVE_INTENSITY := 1.0
const FADE_IN_SPEED := 5.5
const FADE_OUT_SPEED := 3.6
const SEVERITY_SMOOTH_SPEED := 6.0
const MIN_HEARTBEAT_HZ := 0.85
const MAX_HEARTBEAT_HZ := 1.35

@onready var absorb_rect: ColorRect = get_node_or_null("AbsorbRect") as ColorRect
@onready var overlay_rect: ColorRect = $OverlayRect

var _absorb_material: ShaderMaterial = null
var _shader_material: ShaderMaterial = null
var _target_intensity := 0.0
var _displayed_intensity := 0.0
var _target_severity := 0.0
var _displayed_severity := 0.0
var _pulse_phase := 0.0


static func is_low_health(current: float, maximum: float) -> bool:
	if maximum <= 0.0 or current <= 0.0:
		return false
	return (current / maximum) <= (LOW_HEALTH_RATIO_THRESHOLD + THRESHOLD_EPSILON)


static func compute_severity(current: float, maximum: float) -> float:
	if not is_low_health(current, maximum):
		return 0.0
	var ratio := clampf(current / maximum, 0.0, LOW_HEALTH_RATIO_THRESHOLD)
	return clampf(1.0 - (ratio / LOW_HEALTH_RATIO_THRESHOLD), 0.0, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if is_instance_valid(absorb_rect):
		absorb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		absorb_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_absorb_material = absorb_rect.material as ShaderMaterial
	if is_instance_valid(overlay_rect):
		overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_shader_material = overlay_rect.material as ShaderMaterial
	_apply_shader_state()
	set_process(_target_intensity > 0.0 or _displayed_intensity > 0.0)


func set_health(current: float, maximum: float, immediate: bool = false) -> void:
	if is_low_health(current, maximum):
		_target_severity = compute_severity(current, maximum)
		_target_intensity = lerpf(BASE_ACTIVE_INTENSITY, MAX_ACTIVE_INTENSITY, _target_severity)
	else:
		_target_severity = 0.0
		_target_intensity = 0.0

	if immediate:
		_displayed_intensity = _target_intensity
		_displayed_severity = _target_severity

	set_process(_target_intensity > 0.0 or _displayed_intensity > 0.001)
	_apply_shader_state()


func _process(delta: float) -> void:
	var fade_in := _target_intensity >= _displayed_intensity
	# When fading out during death or bullet-time slow-mo, pace fade in real seconds
	# while still pausing cleanly whenever the SceneTree is paused.
	var fade_delta := delta if fade_in else (delta / maxf(Engine.time_scale, 0.15))
	var fade_speed := FADE_IN_SPEED if fade_in else FADE_OUT_SPEED
	_displayed_intensity = move_toward(_displayed_intensity, _target_intensity, fade_speed * fade_delta)
	_displayed_severity = move_toward(_displayed_severity, _target_severity, SEVERITY_SMOOTH_SPEED * delta)

	if _displayed_intensity > 0.001:
		var pulse_hz := lerpf(MIN_HEARTBEAT_HZ, MAX_HEARTBEAT_HZ, _displayed_severity)
		_pulse_phase = fposmod(_pulse_phase + delta * pulse_hz, 1.0)
	else:
		_displayed_intensity = 0.0
		_pulse_phase = 0.0
		if _target_intensity <= 0.0:
			set_process(false)

	_apply_shader_state()


func _apply_shader_state() -> void:
	var should_show := _displayed_intensity > 0.001
	visible = should_show
	for material in [_absorb_material, _shader_material]:
		if material == null:
			continue
		material.set_shader_parameter(&"intensity", _displayed_intensity)
		material.set_shader_parameter(&"severity", _displayed_severity)
		material.set_shader_parameter(&"pulse_phase", _pulse_phase)


func is_active() -> bool:
	return visible and _displayed_intensity > 0.001


func get_displayed_intensity() -> float:
	return _displayed_intensity


func get_target_intensity() -> float:
	return _target_intensity


func get_severity() -> float:
	return _displayed_severity
