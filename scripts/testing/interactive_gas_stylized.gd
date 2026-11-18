extends "res://scripts/testing/stylized_smoke_column.gd"
## Persistent cloud parcels following the room's GPU fluid field.
const PROCESS_SHADER:=preload("res://shaders/testing/interactive_gas_particles.gdshader")
const GRID:=preload("res://scripts/testing/interactive_gas_gpu.gd").GRID
const SMOKE_LAYER:=1<<11
const PUFF_COUNT:=256
var gas:Node3D
var field_material:ShaderMaterial
var _reset_generation:=1.0
var _masked_lights:Array[Dictionary]=[]
var _camera:Camera3D
var _camera_had_layer:=false
var style_light:DirectionalLight3D
var _shared_lighting:Node3D
var materials:Array[ShaderMaterial]=[]
var silhouette_strategy:="whole_native_mesh"

func configure_gas(owner_gas:Node3D)->void:
	gas=owner_gas
	super.configure_reference()
	reference_mode=false
	particles.emitting=false
	particles.layers=SMOKE_LAYER
	particles.position=Vector3.ZERO
	particles.amount=PUFF_COUNT
	particles.preprocess=0.0
	particles.explosiveness=1.0
	particles.visibility_aabb=gas.bounds.grow(1.3)
	field_material=ShaderMaterial.new()
	field_material.shader=PROCESS_SHADER
	field_material.set_shader_parameter("gas_density",gas.solver.output)
	field_material.set_shader_parameter("gas_velocity",gas.solver.velocity_output)
	field_material.set_shader_parameter("gas_solids",gas.solver.solid_output)
	field_material.set_shader_parameter("reset_generation",_reset_generation)
	field_material.set_shader_parameter("gas_to_world",gas.global_transform)
	field_material.set_shader_parameter("world_to_gas",gas.global_transform.affine_inverse())
	field_material.set_shader_parameter("gas_minimum",gas.bounds.position)
	field_material.set_shader_parameter("gas_extent",gas.bounds.size)
	field_material.set_shader_parameter("gas_cell_size",gas.bounds.size/Vector3(GRID))
	var center:Vector3=gas.bounds.get_center()
	center.y=gas.bounds.position.y+.95
	field_material.set_shader_parameter("spawn_center",center)
	field_material.set_shader_parameter("spawn_half_extent",Vector3(minf(4.5,gas.bounds.size.x*.34),.4,minf(4.3,gas.bounds.size.z*.32)))
	particles.process_material=field_material
	material.set_shader_parameter("gas_field_enabled",true)
	material.set_shader_parameter("gas_solids",gas.solver.solid_output)
	material.set_shader_parameter("world_to_gas",gas.global_transform.affine_inverse())
	material.set_shader_parameter("gas_minimum",gas.bounds.position)
	material.set_shader_parameter("gas_extent",gas.bounds.size)
	materials.append(material)
	_setup_light_layers()
	particles.emitting=true
	particles.restart(true)

func _setup_light_layers()->void:
	_shared_lighting=preload("res://scripts/dream/stylized_cloud_lighting.gd").acquire(gas.world,self)
	style_light=_shared_lighting.key

func set_paused(value:bool)->void:
	reference_paused=value

func reset()->void:
	_reset_generation+=1.0
	if is_instance_valid(field_material):field_material.set_shader_parameter("reset_generation",_reset_generation)
	if is_instance_valid(particles):particles.restart(true)

func _exit_tree()->void:
	if is_instance_valid(particles):
		particles.emitting=false
		particles.speed_scale=0.0
		particles.process_material=null
	if is_instance_valid(field_material):
		for uniform_name in ["gas_density","gas_velocity","gas_solids"]:field_material.set_shader_parameter(uniform_name,null)
	if is_instance_valid(material):
		material.set_shader_parameter("gas_field_enabled",false)
		material.set_shader_parameter("gas_solids",null)
	if is_instance_valid(_shared_lighting):_shared_lighting.release(self)
