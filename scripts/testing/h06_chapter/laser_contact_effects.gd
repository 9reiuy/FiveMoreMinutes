extends MultiMeshInstance3D
## World-space hot smoke and sparks outlive the moving wall contact briefly.

const CONTACT_SHADER := preload("res://shaders/dream3d/h06_laser_contacts.gdshader")
const RAY_LIMIT := 6
const FLARE_COUNT := RAY_LIMIT * 2
const PARTICLE_LIMIT := 72

class ContactParticle:
	var origin: Vector3
	var velocity: Vector3
	var dimensions: Vector2
	var age := 0.0
	var life: float
	var seed: float
	var strength: float
	var smoke: bool
	var wall: bool

var _lift: Node3D
var _rng := RandomNumberGenerator.new()
var _flares: Array[Transform3D] = []
var _style := PackedColorArray()
var _next_strike := PackedFloat32Array()
var _particles: Array[ContactParticle] = []

func _ready() -> void:
	name = "LaserContactEffects"
	_flares.resize(FLARE_COUNT)
	_style.resize(FLARE_COUNT)
	_next_strike.resize(RAY_LIMIT)
	_style.fill(Color.TRANSPARENT)
	_rng.seed = 603078
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true
	batch.mesh = quad
	batch.instance_count = FLARE_COUNT + PARTICLE_LIMIT
	batch.visible_instance_count = 0
	multimesh = batch
	var finish := ShaderMaterial.new()
	finish.shader = CONTACT_SHADER
	material_override = finish
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 2.0
	set_process(false)

func set_ray(index: int, start: Vector3, direction: Vector3, end: Vector3,
		normal: Vector3, time: float, radial: bool, wall: bool) -> void:
	var weight := 0.65 if radial else 1.0
	var port_size := 0.73 if radial else 1.02
	_set_flare(index, start, direction, Vector2.ONE * port_size, Color(time, index * 0.173, 0.0, weight))
	var strike_slot := index + RAY_LIMIT
	if normal == Vector3.ZERO:
		_style[strike_slot] = Color.TRANSPARENT
		_next_strike[index] = 0.0
	else:
		var point := end + normal * 0.13
		var radius := 0.84 if radial else 1.09
		_set_flare(strike_slot, point, normal, Vector2(radius, radius * 1.10), Color(time, index * 0.139, 1.0, weight))
		if time >= _next_strike[index]:
			_next_strike[index] = time + (0.086 if radial else 0.056)
			_emit_strike(point, normal, weight, radial, wall)
	set_process(true)

func hide_ray(index: int) -> void:
	_style[index] = Color.TRANSPARENT
	_style[index + RAY_LIMIT] = Color.TRANSPARENT
	_next_strike[index] = 0.0

func hide_flares() -> void:
	_style.fill(Color.TRANSPARENT)
	_next_strike.fill(0.0)
	_publish()
	set_process(not _particles.is_empty())

func clear() -> void:
	_particles.clear()
	hide_flares()

func _set_flare(index: int, at: Vector3, axis: Vector3, size: Vector2, style: Color) -> void:
	_flares[index] = _transform(at, axis, size)
	_style[index] = style

func _emit_strike(at: Vector3, normal: Vector3, strength: float, radial: bool, wall: bool) -> void:
	var tangent := Vector3.UP.cross(normal).normalized()
	var origin := at - _shaft_offset() if wall else at
	for index in (3 if radial else 5):
		var motion := normal * _rng.randf_range(0.75, 3.6) + tangent * _rng.randf_range(-3.8, 3.8) \
			+ Vector3.UP * _rng.randf_range(-0.9, 3.2)
		var dimensions := Vector2(_rng.randf_range(0.11, 0.25), _rng.randf_range(0.025, 0.061))
		_add_particle(origin, motion, dimensions, _rng.randf_range(0.13, 0.24), strength * 0.83, false, wall)
	for index in (1 if radial else 2):
		var motion := normal * _rng.randf_range(0.26, 1.25) + tangent * _rng.randf_range(-0.96, 0.96) \
			+ Vector3.UP * _rng.randf_range(0.66, 1.82)
		var size := _rng.randf_range(0.75, 1.25)
		_add_particle(origin, motion, Vector2(size, size * _rng.randf_range(0.80, 1.23)),
			_rng.randf_range(0.29, 0.45), strength * 0.57, true, wall)

func _add_particle(at: Vector3, motion: Vector3, size: Vector2, life: float, strength: float, smoke: bool, wall: bool) -> void:
	if _particles.size() == PARTICLE_LIMIT: _particles.pop_front()
	var particle := ContactParticle.new()
	particle.origin = at
	particle.velocity = motion
	particle.dimensions = size
	particle.life = life
	particle.strength = strength
	particle.seed = _rng.randf()
	particle.smoke = smoke
	particle.wall = wall
	_particles.append(particle)

func _process(delta: float) -> void:
	var active := 0
	for particle in _particles:
		particle.age += delta
		if particle.age < particle.life:
			_particles[active] = particle
			active += 1
	_particles.resize(active)
	_publish()
	if multimesh.visible_instance_count == 0: set_process(false)

func _publish() -> void:
	var slot := 0
	for index in FLARE_COUNT:
		if _style[index].a <= 0.0: continue
		multimesh.set_instance_transform(slot, _flares[index])
		multimesh.set_instance_custom_data(slot, _style[index])
		slot += 1
	var shaft_offset := _shaft_offset()
	for particle in _particles:
		var progress := particle.age / particle.life
		var at := particle.origin + particle.velocity * (particle.age / (1.0 + 2.4 * particle.age))
		if particle.wall: at += shaft_offset
		var size := particle.dimensions
		var axis := particle.velocity.normalized()
		if particle.smoke:
			size *= lerpf(0.52, 1.48, progress)
		else:
			at.y -= 3.8 * particle.age * particle.age
			axis = (particle.velocity - Vector3.UP * 7.6 * particle.age).normalized()
			size.x *= lerpf(1.0, 0.42, progress)
		multimesh.set_instance_transform(slot, _transform(at, axis, size))
		multimesh.set_instance_custom_data(slot, Color(progress, particle.seed, 2.0 if particle.smoke else 3.0, particle.strength))
		slot += 1
	multimesh.visible_instance_count = slot

func _shaft_offset() -> Vector3:
	if not is_instance_valid(_lift): return Vector3.ZERO
	var distance: float = _lift.distance
	return Vector3(0.0, -distance * _lift.GUIDE_GRADE - _lift.deck_vertical_offset, distance)

func _transform(at: Vector3, axis: Vector3, size: Vector2) -> Transform3D:
	var sideways := axis.cross(Vector3.UP).normalized()
	var across := sideways.cross(axis)
	return Transform3D(Basis(axis * size.x, across * size.y, sideways), at)
