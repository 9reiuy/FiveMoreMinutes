extends Control
## Presentation only: three equal portions of the supplied health pool.
const LIQUID := preload("res://shaders/ui/liquid_health_meter.gdshader")
const DAMAGE_HOLD := 0.085
const DAMAGE_DRAIN := 0.38
const GLOW_PADDING := 4.0
var current_fill := Vector3.ONE
var damage_fill := Vector3.ONE
var motion_energy := 0.0
var wave_activity := 0.0
var liquid_tilt := 0.0
var _tilt_velocity := 0.0
var _phase := 0.0
var _foreground_phase := 1.4
var _previous_velocity := Vector2.ZERO
var _motion_source: WeakRef
var _material: ShaderMaterial
var _initialized := false
var _maximum := 1.0
var _current := 1.0
var _damage_age := DAMAGE_HOLD + DAMAGE_DRAIN
var _current_ratio := 1.0
var _damage_ratio := 1.0
var _damage_start_ratio := 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = LIQUID
	var surface := ColorRect.new()
	surface.name = "ThreeLiquidCells"
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.offset_left = -GLOW_PADDING
	surface.offset_top = -GLOW_PADDING
	surface.offset_right = GLOW_PADDING
	surface.offset_bottom = GLOW_PADDING
	surface.material = _material
	add_child(surface)
	_sync_material()

func set_motion_source(actor: Node) -> void:
	_motion_source = weakref(actor) if is_instance_valid(actor) else null
	_initialized = false
	_damage_age = DAMAGE_HOLD + DAMAGE_DRAIN
	_previous_velocity = Vector2.ZERO
	motion_energy = 0.0
	wave_activity = 0.0
	liquid_tilt = 0.0
	_tilt_velocity = 0.0

func set_health(current: float, maximum: float) -> void:
	var safe_max := maxf(maximum, 0.001)
	var safe_current := clampf(current, 0.0, safe_max)
	if _initialized and is_equal_approx(safe_current, _current) and is_equal_approx(safe_max, _maximum):
		return
	var next_ratio := safe_current / safe_max
	var next_fill := _split_fill(next_ratio)
	if not _initialized or not is_equal_approx(safe_max, _maximum) or safe_current >= _current:
		damage_fill = next_fill
		_damage_ratio = next_ratio
		_damage_start_ratio = next_ratio
		_damage_age = DAMAGE_HOLD + DAMAGE_DRAIN
	else:
		_damage_start_ratio = maxf(_damage_ratio, _current_ratio)
		_damage_ratio = _damage_start_ratio
		damage_fill = _split_fill(_damage_ratio)
		_damage_age = 0.0
	current_fill = next_fill
	_current_ratio = next_ratio
	_current = safe_current
	_maximum = safe_max
	_initialized = true
	_sync_material()

func _split_fill(ratio: float) -> Vector3:
	var thirds := clampf(ratio, 0.0, 1.0) * 3.0
	return Vector3(clampf(thirds, 0.0, 1.0), clampf(thirds - 1.0, 0.0, 1.0), clampf(thirds - 2.0, 0.0, 1.0))

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var seconds := minf(delta / maxf(Engine.time_scale, 0.001), 0.05)
	_damage_age += seconds
	var drain := smoothstep(DAMAGE_HOLD, DAMAGE_HOLD + DAMAGE_DRAIN, _damage_age)
	_damage_ratio = lerpf(_damage_start_ratio, _current_ratio, drain)
	damage_fill = _split_fill(_damage_ratio)
	var velocity := Vector2.ZERO
	var actor: Node = _motion_source.get_ref() if _motion_source != null else null
	if is_instance_valid(actor) and not bool(actor.get("dead")):
		var supplied: Variant = actor.get("velocity")
		if supplied is Vector2:
			velocity = supplied
	var speed := clampf(velocity.length() / 200.0, 0.0, 1.5)
	var response := 6.0 if speed > motion_energy else 4.5
	motion_energy = lerpf(motion_energy, speed, 1.0 - exp(-seconds * response))
	var velocity_change := (velocity - _previous_velocity) / 200.0
	_previous_velocity = velocity
	var impulse := clampf((velocity_change.x - velocity_change.y * 0.65) * -26.0, -34.0, 34.0)
	_tilt_velocity += impulse
	# Substeps keep the damped liquid spring stable through a long render frame.
	for step in 3:
		var dt := seconds / 3.0
		_tilt_velocity += (-liquid_tilt * 56.0 - _tilt_velocity * 4.2) * dt
		liquid_tilt += _tilt_velocity * dt
	liquid_tilt = clampf(liquid_tilt, -1.8, 1.8)
	if speed < 0.005 and motion_energy < 0.02 and absf(liquid_tilt) < 0.08 and absf(_tilt_velocity) < 0.5:
		motion_energy = 0.0
		liquid_tilt = 0.0
		_tilt_velocity = 0.0
	wave_activity = smoothstep(0.0, 0.18, motion_energy + absf(liquid_tilt) * 0.30)
	if wave_activity > 0.0:
		_phase = fmod(_phase + seconds * (0.65 + motion_energy * 4.5), TAU * 100.0)
		_foreground_phase = fposmod(_foreground_phase - seconds * (0.45 + motion_energy * 2.8), TAU * 100.0)
	_sync_material()

func _sync_material() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("health_fill", current_fill)
	_material.set_shader_parameter("damage_fill", damage_fill)
	_material.set_shader_parameter("wave_phase", _phase)
	_material.set_shader_parameter("foreground_phase", _foreground_phase)
	_material.set_shader_parameter("wave_energy", motion_energy)
	_material.set_shader_parameter("wave_activity", wave_activity)
	_material.set_shader_parameter("liquid_tilt", liquid_tilt)
	_material.set_shader_parameter("panel_size", size)
	_material.set_shader_parameter("glow_padding", GLOW_PADDING)
	_material.set_shader_parameter("damage_glow", 1.0 - smoothstep(DAMAGE_HOLD, DAMAGE_HOLD + DAMAGE_DRAIN, _damage_age))
