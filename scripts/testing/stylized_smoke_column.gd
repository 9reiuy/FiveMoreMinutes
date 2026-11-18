extends Node3D
## Visual-study column. It is deliberately separate from the room's gas adapter.
const ASSETS:=preload("res://scripts/dream/stylized_cloud_assets.gd")
const SHADER:=ASSETS.SHADER
const LIGHT_GAIN:=1.25
var reference_mode:=true
var reference_paused:=false:
	set(value):
		reference_paused=value
		if is_instance_valid(particles):particles.speed_scale=0.0 if value else 1.0
var material:ShaderMaterial
var mesh:ArrayMesh
var particles:GPUParticles3D

func configure_reference()->void:
	mesh=ASSETS.MESH
	material=ASSETS.make_material()
	particles=GPUParticles3D.new()
	particles.amount=18
	particles.lifetime=5.0
	particles.preprocess=5.0
	particles.fixed_fps=30
	particles.local_coords=false
	particles.visibility_aabb=AABB(Vector3(-6,-1,-6),Vector3(12,12,12))
	particles.draw_pass_1=mesh
	particles.material_override=material
	particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	particles.use_fixed_seed=true
	particles.seed=28711
	var process:=ParticleProcessMaterial.new()
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius=.1
	process.direction=Vector3(0,1,0)
	process.spread=8.0
	process.initial_velocity_min=.9
	process.initial_velocity_max=1.1
	process.gravity=Vector3(-.1,.16,0)
	# The reconstructed mesh is normalized to radius 0.58 m. This range
	# restores the intended visible cloud size without changing its UVs.
	process.scale_min=1.4
	process.scale_max=1.68
	process.angle_min=0.0
	process.angle_max=360.0
	process.angular_velocity_min=-10.0
	process.angular_velocity_max=10.0
	process.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_ROTATE_Y,true)
	process.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY,true)
	var curve:=Curve.new()
	curve.max_value=2.5
	for point in [Vector2(0,.2),Vector2(.15,.65),Vector2(.4,1.2),Vector2(.7,1.8),Vector2(1,2.2)]:curve.add_point(point)
	var curve_texture:=CurveTexture.new()
	curve_texture.curve=curve
	process.scale_curve=curve_texture
	particles.process_material=process
	add_child(particles)
	particles.position=Vector3(0,.7,0)

static func palette_input(color:Color)->Color:
	# Calibrate the two ramp colors against the preview's single real light.
	# This keeps the photographed paper/ink colors while the floor is lit.
	var linear:=color.srgb_to_linear()
	return Color(linear.r/LIGHT_GAIN,linear.g/LIGHT_GAIN,linear.b/LIGHT_GAIN,1.0).linear_to_srgb()
