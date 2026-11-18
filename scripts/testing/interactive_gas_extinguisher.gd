extends "res://scripts/dream/fire_extinguisher_system.gd"
## Reuse production cloud banks, fusion, pixel silhouette, shade and ordering.
## GPU density remains the authority; this adapter creates no tank or AI rules.
const FILL:=preload("res://shaders/testing/interactive_gas_extinguisher.gdshader")
const OUTLINE:=preload("res://shaders/testing/interactive_gas_extinguisher_outline.gdshader")
var gas: Node3D
var anchors: Array[Dictionary]=[]

func spawn_wall_tanks() -> void:
	pass

func _physics_process(_delta: float) -> void:
	pass

func configure_gas(owner_gas: Node3D) -> void:
	gas=owner_gas
	configure(gas.world)
	for index in materials.size():
		var material:=materials[index]
		material.shader=FILL if index==0 else OUTLINE
		material.set_shader_parameter("gas_density",gas.solver.output)
		material.set_shader_parameter("gas_velocity",gas.solver.velocity_output)
		material.set_shader_parameter("gas_minimum",gas.bounds.position)
		material.set_shader_parameter("gas_extent",gas.bounds.size)
		material.set_shader_parameter("gas_world_to_local",gas.global_transform.affine_inverse())
		# Keep each complete multi-lobed silhouette. Cross-card fusion and
		# fragment density masks previously turned the group into one soft blob.
		material.set_shader_parameter("collective_fusion",false)
		material.set_shader_parameter("clip_at_floor",false)
	var fixed:=RandomNumberGenerator.new()
	fixed.seed=0xF1E1D
	for z in 6:
		for x in 7:
			anchors.append({"point":Vector3(3.2+x*1.05+fixed.randf_range(-.12,.12),fixed.randf_range(.85,1.25),4.1+z*1.1+fixed.randf_range(-.12,.12)),
				"size":fixed.randf_range(2.05,2.6),"seed":fixed.randf()})
	_refresh_clouds()

func _process(_delta: float) -> void:
	if is_instance_valid(gas) and gas.solver!=null and gas.solver.ready and is_visible_in_tree():
		_refresh_clouds()

func _refresh_clouds() -> void:
	clock=gas.solver.clock
	for material in materials: material.set_shader_parameter("smoke_clock",clock*.5)
	var rendered: Array[Dictionary]=[]
	for anchor in anchors:
		var point: Vector3=anchor.point
		point+=Vector3(sin(clock*.4+float(anchor.seed)*6.28)*.06,0,cos(clock*.33+float(anchor.seed)*6.28)*.06)
		var cell:=Vector2i(roundi(point.x),roundi(point.z))
		rendered.append({"at":gas.to_global(point),"cell":cell,"size":float(anchor.size),
			"alpha":1.0,"seed":float(anchor.seed),"field_row":rendered.size()})
	var camera: Camera3D=world.camera_3d
	_commit_puffs(rendered,true,camera.global_position,camera.global_basis)
