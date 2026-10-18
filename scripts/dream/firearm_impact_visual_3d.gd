extends Node3D

## One bounded, presentation-only carrier per firearm hit. The gameplay world
## supplies the exact collision point and maps the 2D normal into its current
## 3D floor basis. No particle has collision or owns a light.
const MAX_PARTICLES := 6
const MAX_LIFETIME := 0.34
## Immutable geometry/material only. Particle color, trajectory and lifetime
## stay on each emitter; this resource never owns a hit or a floor node.
static var _shared_particle_mesh: QuadMesh

var _impact_normal := Vector3.UP
var _surface_kind: StringName = &"solid"
var _elapsed := 0.0
var _configured := false
var _emitter: CPUParticles3D


func _ready() -> void:
	_emitter = CPUParticles3D.new()
	_emitter.name = "ImpactPixels"
	_emitter.emitting = false
	_emitter.one_shot = true
	_emitter.explosiveness = 1.0
	_emitter.local_coords = true
	_emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_emitter.mesh = _get_particle_mesh()
	add_child(_emitter)
	set_process(false)
	if _configured:
		_start_particles()


func _get_particle_mesh() -> QuadMesh:
	if _shared_particle_mesh == null:
		_shared_particle_mesh = _create_particle_mesh()
	return _shared_particle_mesh


static func _create_particle_mesh() -> QuadMesh:
	var particle_quad := QuadMesh.new()
	particle_quad.size = Vector2(0.09, 0.09)
	var particle_material := StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particle_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	particle_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	particle_material.vertex_color_use_as_albedo = true
	particle_quad.material = particle_material
	return particle_quad


func setup(normal_world: Vector3, surface_kind: StringName) -> void:
	_impact_normal = normal_world.normalized() if normal_world.length_squared() > 0.0001 else Vector3.UP
	_surface_kind = surface_kind
	_configured = true
	if is_inside_tree() and _emitter != null:
		_start_particles()


func _start_particles() -> void:
	# Glass has its own cool glint; low/soft props emit neutral dust rather than
	# metal sparks. Character impacts are deliberately not classified as metal.
	match _surface_kind:
		&"metal":
			_emitter.amount = MAX_PARTICLES
			_emitter.color = Color(1.0, 0.69, 0.27, 1.0)
			_emitter.initial_velocity_min = 2.0
			_emitter.initial_velocity_max = 3.8
		&"glass":
			_emitter.amount = 5
			_emitter.color = Color(0.74, 0.92, 1.0, 0.92)
			_emitter.initial_velocity_min = 1.6
			_emitter.initial_velocity_max = 3.2
		&"soft":
			_emitter.amount = 2
			_emitter.color = Color(0.63, 0.62, 0.58, 0.72)
			_emitter.initial_velocity_min = 0.65
			_emitter.initial_velocity_max = 1.2
		_:
			_emitter.amount = 4
			_emitter.color = Color(1.0, 0.76, 0.42, 1.0)
			_emitter.initial_velocity_min = 1.3
			_emitter.initial_velocity_max = 2.6
	_emitter.lifetime = 0.19 if _surface_kind == &"soft" else 0.15
	_emitter.direction = _impact_normal
	_emitter.spread = 58.0
	_emitter.gravity = Vector3(0.0, -3.4, 0.0)
	_emitter.emitting = true
	_elapsed = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= MAX_LIFETIME:
		queue_free()
