extends Node3D
## Floor-owned, depth-tested firearm particles. Two bounded draw batches,
## with their own RNG so visuals never consume combat randomness.

const HOT_LIMIT := 128
const SMOKE_LIMIT := 80
const FLASH := 0.0
const SPARK := 1.0
const HOT_SHADER := preload("res://shaders/dream3d/firearm_flash_fx.gdshader")
const SMOKE_SHADER := preload("res://shaders/dream3d/firearm_smoke_fx.gdshader")


class Particle:
	var origin: Vector3
	var velocity: Vector3
	var size: Vector2
	var lifetime: float
	var drag: float
	var acceleration: float
	var style: float
	var seed: float
	var strength: float
	var age := 0.0
	var birth_frame := Engine.get_frames_drawn()

	func _init(point: Vector3, motion: Vector3, dimensions: Vector2, duration: float,
			resistance: float, vertical: float, variant: float, noise_seed: float, opacity: float) -> void:
		origin = point
		velocity = motion
		size = dimensions
		lifetime = duration
		drag = resistance
		acceleration = vertical
		style = variant
		seed = noise_seed
		strength = opacity


var _rng := RandomNumberGenerator.new()
var _hot: MultiMeshInstance3D
var _smoke: MultiMeshInstance3D
var _hot_particles: Array[Particle] = []
var _smoke_particles: Array[Particle] = []


func _ready() -> void:
	# Keep positions in the same world coordinates as the rendered muzzle and
	# contact. The floor still owns the lifetime of this emitter.
	top_level = true
	global_transform = Transform3D.IDENTITY
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_smoke = _make_batch("Smoke", quad, SMOKE_SHADER, SMOKE_LIMIT, 0)
	_hot = _make_batch("FlashAndSparks", quad, HOT_SHADER, HOT_LIMIT, 2)
	set_process(false)


func configure(camera: Camera3D, main_only_layer: int) -> void:
	if is_instance_valid(camera) and camera.cull_mask & main_only_layer:
		_hot.layers = main_only_layer
		_smoke.layers = main_only_layer


func muzzle(point: Vector3, forward: Vector3, weapon: StringName) -> void:
	if not visible or forward.length_squared() < 0.0001:
		return
	var axis := forward.normalized()
	var side := Vector3.UP.cross(axis).normalized()
	var count := 14
	var cone := 0.34
	var speed := 14.5
	var flash_size := Vector2(1.46, 1.30)
	var smoke_size := 1.06
	match weapon:
		&"assault_rifle", &"mp5":
			count = 20
			cone = 0.31
			speed = 20.5
			flash_size = Vector2(1.91, 1.57)
			smoke_size = 1.28
		&"shotgun":
			count = 25
			cone = 0.56
			speed = 17.5
			flash_size = Vector2(2.09, 1.79)
			smoke_size = 1.52
	_push(_hot_particles, HOT_LIMIT, Particle.new(point, axis * 0.8, flash_size,
		0.085, 2.0, 0.0, FLASH, _rng.randf(), 1.0))
	for index in count:
		var direction := (axis + side * _rng.randfn(0.0, cone * 0.56)
			+ Vector3.UP * _rng.randf_range(-cone * 0.38, cone * 0.65)).normalized()
		var start := point + axis * _rng.randf_range(0.12, 0.47)
		var motion := direction * speed * _rng.randf_range(0.53, 1.15)
		var size := Vector2(_rng.randf_range(0.19, 0.44), _rng.randf_range(0.042, 0.078))
		_push(_hot_particles, HOT_LIMIT, Particle.new(start, motion, size,
			_rng.randf_range(0.14, 0.26), 4.55, -12.0, SPARK, _rng.randf(), _rng.randf_range(0.67, 1.0)))
	for index in (6 if weapon == &"shotgun" else 5):
		var start := point + axis * _rng.randf_range(0.03, 0.28) + side * _rng.randf_range(-0.14, 0.14)
		var motion := (axis * _rng.randf_range(0.85, 4.95)
			+ side * _rng.randf_range(-1.2, 1.2) + Vector3.UP * _rng.randf_range(0.07, 0.72))
		_add_smoke(start, motion, smoke_size, _rng.randf_range(0.41, 0.64), 0.0, 0.62)
	_present()


func impact(point: Vector3, normal: Vector3, surface: StringName) -> void:
	if not visible:
		return
	var side := Vector3.UP.cross(normal).normalized()
	var count := 8
	var smoke_size := 1.04
	var smoke_strength := 0.84
	match surface:
		&"metal":
			count = 16
			smoke_size = 1.06
		&"soft":
			count = 4
			smoke_size = 1.12
		&"glass":
			count = 6
			smoke_size = 0.78
			smoke_strength = 0.63
	var start := point + normal * 0.055
	var flash_size := Vector2(0.55, 0.48) if surface == &"metal" else Vector2(0.30, 0.25)
	if surface != &"soft":
		_push(_hot_particles, HOT_LIMIT, Particle.new(start, normal * 0.55, flash_size,
			0.058, 2.5, 0.0, FLASH, _rng.randf(), 0.80 if surface == &"metal" else 0.58))
	for index in count:
		var direction := (normal * _rng.randf_range(0.30, 1.0) + side * _rng.randf_range(-1.1, 1.1)
			+ Vector3.UP * _rng.randf_range(-0.10, 0.74)).normalized()
		var motion := direction * _rng.randf_range(3.1, 9.5)
		var size := Vector2(_rng.randf_range(0.12, 0.34), _rng.randf_range(0.036, 0.063))
		var strength := 0.87 if surface == &"metal" else (0.34 if surface == &"soft" else 0.65)
		_push(_hot_particles, HOT_LIMIT, Particle.new(start, motion, size,
			_rng.randf_range(0.10, 0.21), 5.3, -13.0, SPARK, _rng.randf(), strength))
	for index in 4:
		var motion := (normal * _rng.randf_range(0.6, 2.25) + side * _rng.randf_range(-1.1, 1.1)
			+ Vector3.UP * _rng.randf_range(0.27, 1.32))
		var smoke_tint := 1.0 if surface == &"glass" else 0.54
		_add_smoke(start, motion, smoke_size, _rng.randf_range(0.38, 0.63), smoke_tint, smoke_strength)
	_present()


func _add_smoke(point: Vector3, motion: Vector3, size: float, duration: float, tint: float, strength: float) -> void:
	var width := size * _rng.randf_range(0.74, 1.20)
	_push(_smoke_particles, SMOKE_LIMIT, Particle.new(point, motion, Vector2(width, width * _rng.randf_range(0.57, 0.87)),
		duration, 3.6, 1.4, tint, _rng.randf(), strength * _rng.randf_range(0.73, 1.0)))


func _push(particles: Array[Particle], limit: int, particle: Particle) -> void:
	if particles.size() == limit:
		particles.pop_front()
	particles.append(particle)


func _process(delta: float) -> void:
	_advance(_hot_particles, delta)
	_advance(_smoke_particles, delta)
	_present()


func _advance(particles: Array[Particle], delta: float) -> void:
	var drawn := Engine.get_frames_drawn()
	var live := 0
	for particle in particles:
		# A late first frame must still show the bright birth of each shot.
		# Headless never draws, so there we age the effects on the normal tick.
		if particle.birth_frame != drawn or drawn == 0:
			particle.age += delta
		if particle.age < particle.lifetime:
			particles[live] = particle
			live += 1
	particles.resize(live)


func _present() -> void:
	_draw_batch(_hot.multimesh, _hot_particles, false)
	_draw_batch(_smoke.multimesh, _smoke_particles, true)
	set_process(not _hot_particles.is_empty() or not _smoke_particles.is_empty())


func _draw_batch(batch: MultiMesh, particles: Array[Particle], smoke: bool) -> void:
	for index in particles.size():
		var particle := particles[index]
		var phase := particle.age / particle.lifetime
		var braking := exp(-particle.drag * particle.age)
		var travel := (1.0 - braking) / particle.drag
		var lift := Vector3.UP * particle.acceleration
		var position := particle.origin + particle.velocity * travel + lift * (0.5 * particle.age * particle.age)
		var size := particle.size
		var axes := Basis.IDENTITY
		if smoke:
			size *= lerpf(0.45, 1.52, phase)
		else:
			var axis := (particle.velocity * braking + lift * particle.age).normalized()
			var side := axis.cross(Vector3.UP).normalized()
			axes = Basis(axis, side.cross(axis), side)
			if particle.style == SPARK:
				size.x *= lerpf(1.0, 0.49, phase)
			else:
				size *= lerpf(0.86, 1.18, phase)
		axes.x *= size.x
		axes.y *= size.y
		batch.set_instance_transform(index, Transform3D(axes, position))
		batch.set_instance_custom_data(index, Color(phase, particle.seed, particle.style, particle.strength))
	batch.visible_instance_count = particles.size()


func _make_batch(label: String, quad: QuadMesh, shader: Shader, limit: int, priority: int) -> MultiMeshInstance3D:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true
	batch.mesh = quad
	batch.instance_count = limit
	batch.visible_instance_count = 0
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = priority
	var mesh := MultiMeshInstance3D.new()
	mesh.name = label
	mesh.multimesh = batch
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader faces the view and the flash extends ahead of its pivot.
	mesh.extra_cull_margin = 2.2
	add_child(mesh)
	return mesh


func clear() -> void:
	_hot_particles.clear()
	_smoke_particles.clear()
	_present()


func set_effects_visible(shown: bool) -> void:
	visible = shown
	if not shown:
		clear()
