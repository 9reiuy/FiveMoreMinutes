extends Node3D
## Whitebox adapter. World and player remain the production gameplay authorities.
const GPU := preload("res://scripts/testing/interactive_gas_gpu.gd")
const MATERIAL := preload("res://shaders/testing/interactive_gas_fog.gdshader")
const EXTINGUISHER := preload("res://scripts/testing/interactive_gas_stylized.gd")
const FIXED_STEP := 1.0/30.0
var world: Node3D
var solver: GPU
var bounds := AABB()
var paused := false:
	set(value):
		paused=value
		if is_instance_valid(extinguisher):extinguisher.set_paused(value)
var emitting := true
var shots := 0
var walks := 0
var rolls := 0
var solid_mask := PackedFloat32Array()
var obstacles: Array[AABB]=[]
var _events := PackedFloat32Array()
var _last_player := Vector2.ZERO
var _accumulator := 0.0
var _topology := 0
var _topology_left := 0.0
var _environment: Environment
var fog: MeshInstance3D
var _volume_lights: Array[OmniLight3D]=[]
var extinguisher: Node3D
var extinguisher_style := true

func configure(owner_world: Node3D) -> void:
	world=owner_world
	process_physics_priority=100
	var floor_bounds: Rect2=world._room_bounds_pixels(1,0.0)
	bounds=AABB(Vector3(floor_bounds.position.x/32.0,.02,floor_bounds.position.y/32.0),
		Vector3(floor_bounds.size.x/32.0,2.8,floor_bounds.size.y/32.0))
	_make_obstacle(Vector3(4.6,.85,6.5),Vector3(.7,1.7,1.4))
	_make_obstacle(Vector3(8.5,.55,7.4),Vector3(1.1,1.1,.7))
	_set_environment()
	solid_mask=_make_mask()
	_topology=_topology_signature()
	solver=GPU.new()
	solver.start(bounds,solid_mask)
	await solver.initialized
	if not is_inside_tree(): return
	if not solver.ready:
		push_error(solver.error)
		return
	fog=MeshInstance3D.new()
	fog.name="SimulatedGas"
	var box:=BoxMesh.new()
	box.size=bounds.size
	fog.mesh=box
	fog.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fog.position=bounds.get_center()
	var material:=ShaderMaterial.new()
	material.shader=MATERIAL
	material.set_shader_parameter("gas_density",solver.output)
	material.set_shader_parameter("gas_solids",solver.solid_output)
	material.set_shader_parameter("volume_extent",bounds.size)
	fog.material_override=material
	add_child(fog)
	_sync_volume_lights()
	extinguisher=EXTINGUISHER.new()
	extinguisher.name="InteractiveStylizedSmoke"
	add_child(extinguisher)
	extinguisher.configure_gas(self)
	set_extinguisher_style(true)
	_last_player=world.player.global_position

func set_extinguisher_style(enabled: bool) -> void:
	extinguisher_style=enabled
	if is_instance_valid(fog): fog.visible=not enabled
	if is_instance_valid(extinguisher): extinguisher.visible=enabled

func active_visual() -> Node3D:
	return extinguisher if extinguisher_style else fog

func _set_environment() -> void:
	var environment_node: WorldEnvironment=world.get_node("Lighting/WorldEnvironment")
	_environment=environment_node.environment.duplicate()
	environment_node.environment=_environment
	world.camera_3d.environment=_environment
	# Only the linked mesh particles draw smoke; no native volumetric fog layer.
	_environment.volumetric_fog_enabled=false
	_environment.volumetric_fog_density=0.0
	_environment.volumetric_fog_length=30.0
	_environment.volumetric_fog_temporal_reprojection_enabled=false
	_environment.ambient_light_energy=.28
	_environment.volumetric_fog_albedo=Color(.88,.93,.98)
	_environment.volumetric_fog_anisotropy=.15
	_environment.volumetric_fog_ambient_inject=.55
	_environment.volumetric_fog_gi_inject=0.0
	for item in [[Vector3(3.5,2.4,5.8),Color("afcfff")],[Vector3(9.3,2.2,8.5),Color("f3d5ad")]]:
		var light:=OmniLight3D.new()
		light.name="GasSideLight%d"%get_child_count()
		light.position=item[0]
		light.light_color=item[1]
		light.light_energy=4.0
		light.omni_range=7.0
		light.shadow_enabled=true
		add_child(light)
		_volume_lights.append(light)

func _process(_delta: float) -> void:
	if is_instance_valid(fog) and fog.visible: _sync_volume_lights()

func _sync_volume_lights() -> void:
	var positions:=PackedVector4Array()
	var colors:=PackedVector4Array()
	positions.resize(4)
	colors.resize(4)
	var sources: Array[OmniLight3D]=_volume_lights.duplicate()
	if is_instance_valid(world.night_lighting):
		for pulse: OmniLight3D in world.night_lighting.muzzle_lights:
			if pulse.is_visible_in_tree() and sources.size()<4: sources.append(pulse)
	var count:=0
	for light in sources:
		if not is_instance_valid(light) or not light.is_visible_in_tree() or count>=4: continue
		var local_point:=fog.to_local(light.global_position)
		var color:=light.light_color.srgb_to_linear()
		positions[count]=Vector4(local_point.x,local_point.y,local_point.z,light.omni_range)
		colors[count]=Vector4(color.r,color.g,color.b,light.light_energy)
		count+=1
	var material: ShaderMaterial=fog.material_override
	material.set_shader_parameter("light_positions",positions)
	material.set_shader_parameter("light_colors",colors)
	material.set_shader_parameter("light_count",count)

func _make_obstacle(center: Vector3, size: Vector3) -> void:
	var mesh:=MeshInstance3D.new()
	var box:=BoxMesh.new()
	box.size=size
	mesh.mesh=box
	mesh.position=center
	var paint:=StandardMaterial3D.new()
	paint.albedo_color=Color("6e7d8a")
	paint.roughness=1.0
	mesh.material_override=paint
	add_child(mesh)
	obstacles.append(AABB(center-size*.5,size))
	var body:=StaticBody2D.new()
	body.collision_layer=4
	body.collision_mask=0
	body.position=Vector2(center.x,center.z)*32.0
	var shape:=RectangleShape2D.new()
	shape.size=Vector2(size.x,size.z)*32.0
	var collider:=CollisionShape2D.new()
	collider.shape=shape
	body.add_child(collider)
	world.collision_root.add_child(body)

func _topology_signature() -> int:
	return hash([world.wall_edges,world.glass_wall_edges,world.window_wall_edges,world.floor_cells.size(),world.pit_cells])

func _make_mask() -> PackedFloat32Array:
	var result:=PackedFloat32Array()
	var grid: Vector3i=GPU.GRID
	result.resize(grid.x*grid.y*grid.z)
	var spacing:=bounds.size/Vector3(grid)
	var edges: Dictionary=world.wall_edges.duplicate()
	edges.merge(world.glass_wall_edges,true)
	edges.merge(world.window_wall_edges,true)
	for z in grid.z:
		for x in grid.x:
			var point:=bounds.position+(Vector3(x,0,z)+Vector3(.5,0,.5))*spacing
			var cell:=Vector2i(roundi(point.x),roundi(point.z))
			var exterior: bool=x==0 or z==0 or x==grid.x-1 or z==grid.z-1 or not world.floor_cells.has(cell) or world.pit_cells.has(cell)
			var vx:=roundi(point.x+.5)
			var hz:=roundi(point.z+.5)
			var wall:=edges.has("V:%d:%d"%[vx,cell.y]) and absf(point.x-(vx-.5))<spacing.x*.55+.06
			wall=wall or (edges.has("H:%d:%d"%[cell.x,hz]) and absf(point.z-(hz-.5))<spacing.z*.55+.06)
			for y in grid.y:
				point.y=bounds.position.y+(y+.5)*spacing.y
				var blocked: bool=exterior or wall or y==0 or y==grid.y-1
				for obstacle in obstacles:
					blocked=blocked or obstacle.grow(.06).has_point(point)
				result[x+grid.x*(y+grid.y*z)]=1.0 if blocked else 0.0
	return result

func push_shot(from: Vector2,to: Vector2) -> void:
	if paused: return
	if not bounds.grow(2.0).has_point(Vector3(from.x/32.0,.65,from.y/32.0)) and not bounds.grow(2.0).has_point(Vector3(to.x/32.0,.65,to.y/32.0)): return
	var direction:=from.direction_to(to)
	_queue(Vector3(from.x/32.0,.65,from.y/32.0),Vector3(to.x/32.0,.65,to.y/32.0),
		.55,4.6,Vector3(direction.x,0,direction.y)*2.8,2.0)
	shots+=1

func _queue(from: Vector3,to: Vector3,radius: float,clearing: float,velocity: Vector3,kind: float) -> void:
	if _events.size()>=GPU.MAX_IMPULSES*12: return
	_events.append_array(PackedFloat32Array([from.x,from.y,from.z,radius,to.x,to.y,to.z,clearing,velocity.x,velocity.y,velocity.z,kind]))

func _physics_process(delta: float) -> void:
	if not is_instance_valid(world) or solver==null or not solver.ready: return
	var player: Node2D=world.player
	var current: Vector2=player.global_position
	var distance:=_last_player.distance_to(current)
	if not paused and distance>.02 and distance<96.0:
		var rolling: bool=player.dashing
		var velocity:=Vector3(current.x-_last_player.x,0,current.y-_last_player.y)/32.0/maxf(delta,.001)
		var gain:=.65 if rolling else .28
		var from:=Vector3(_last_player.x/32.0,.55,_last_player.y/32.0)
		var to:=Vector3(current.x/32.0,.55,current.y/32.0)
		_queue(from,to,1.15 if rolling else .8,.42 if rolling else .06,velocity*gain,1.0 if rolling else 0.0)
		if rolling: rolls+=1
		else: walks+=1
	_last_player=current
	if paused: return
	_topology_left-=delta
	if _topology_left<=0.0:
		_topology_left=.25
		var signature:=_topology_signature()
		if signature!=_topology:
			_topology=signature
			solid_mask=_make_mask()
			solver.update_solids(solid_mask)
	_accumulator=minf(_accumulator+delta,FIXED_STEP*2.0)
	if _accumulator>=FIXED_STEP and solver.advance(FIXED_STEP,_events,emitting):
		_accumulator-=FIXED_STEP
		_events=PackedFloat32Array()

func reset() -> void:
	_events=PackedFloat32Array()
	_accumulator=0.0
	_last_player=world.player.global_position
	shots=0
	walks=0
	rolls=0
	solver.reset()
	if is_instance_valid(extinguisher):extinguisher.reset()

func _exit_tree() -> void:
	if solver!=null: solver.stop()
	if is_instance_valid(world) and is_instance_valid(world.camera_3d) and world.camera_3d.environment==_environment:
		world.camera_3d.environment=null
