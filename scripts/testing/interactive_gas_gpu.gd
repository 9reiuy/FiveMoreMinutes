extends RefCounted
## Room-local Stable Fluids state. All RIDs belong to the main render device.
signal initialized
signal field_sampled(state: Dictionary)
const SHADER_PATH := "res://shaders/testing/interactive_gas.glsl"
const GRID := Vector3i(64,24,64)
const MAX_IMPULSES := 64
const PRESSURE_ITERATIONS := 24
var output := Texture3DRD.new()
var solid_output := Texture3DRD.new()
var velocity_output := Texture3DRD.new()
var ready := false
var error := ""
var origin := Vector3.ZERO
var extent := Vector3.ONE
var steps := 0
var clock := 0.0
var ambient_curl := .018
var buoyancy := 0.0
var _device: RenderingDevice
var _shader := RID()
var _pipeline := RID()
var _linear := RID()
var _nearest := RID()
var _events := RID()
var _solid := RID()
var _visible := RID()
var _divergence := RID()
var _velocity: Array[RID] = []
var _density: Array[RID] = []
var _pressure: Array[RID] = []
var _owned: Array[RID] = []
var _sets: Dictionary = {}
var _density_index := 1
var _pressure_index := 0
var _mutex := Mutex.new()
var _pending := false
var _running := true

func start(bounds: AABB, solids: PackedFloat32Array) -> void:
	origin=bounds.position
	extent=bounds.size
	var keep_alive: RefCounted=self
	RenderingServer.call_on_render_thread(func(): keep_alive._create(solids))

func _create(solids: PackedFloat32Array) -> void:
	_device=RenderingServer.get_rendering_device()
	if _device==null:
		call_deferred("_created","This gas sample requires the native Forward+ renderer.")
		return
	var source:=RDShaderSource.new()
	source.source_compute=FileAccess.get_file_as_string(SHADER_PATH).replace("#[compute]","")
	var spirv:=_device.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty():
		call_deferred("_created",spirv.compile_error_compute)
		return
	_shader=_own(_device.shader_create_from_spirv(spirv))
	_pipeline=_own(_device.compute_pipeline_create(_shader))
	var sampler:=RDSamplerState.new()
	sampler.mag_filter=RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler.min_filter=RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler.repeat_u=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler.repeat_v=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler.repeat_w=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_linear=_own(_device.sampler_create(sampler))
	sampler.mag_filter=RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler.min_filter=RenderingDevice.SAMPLER_FILTER_NEAREST
	_nearest=_own(_device.sampler_create(sampler))
	for i in 2:
		_velocity.append(_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT))
		_density.append(_texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT))
		_pressure.append(_texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT))
	_divergence=_texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT)
	_visible=_texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT)
	_solid=_texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT,solids.to_byte_array())
	var empty:=PackedByteArray()
	empty.resize(MAX_IMPULSES*48)
	_events=_own(_device.storage_buffer_create(empty.size(),empty))
	for v in 2:
		for d in 2:
			for p in 2:
				var uniforms: Array[RDUniform]=[
					_sample(0,_velocity[v],_linear),_image(1,_velocity[1-v]),
					_sample(2,_density[d],_linear),_image(3,_density[1-d]),
					_sample(4,_pressure[p],_nearest),_image(5,_pressure[1-p]),
					_image(6,_divergence),_sample(7,_solid,_nearest),
					_buffer(8,_events),_image(9,_visible),_sample(10,_divergence,_nearest)]
				_sets[Vector3i(v,d,p)]=_own(_device.uniform_set_create(uniforms,_shader,0))
	_reset_gpu()
	output.texture_rd_rid=_visible
	solid_output.texture_rd_rid=_solid
	velocity_output.texture_rd_rid=_velocity[0]
	call_deferred("_created","")

func _created(message: String) -> void:
	error=message
	ready=message.is_empty() and _running
	initialized.emit()

func _own(handle: RID) -> RID:
	_owned.append(handle)
	return handle

func _texture(format: int, data: PackedByteArray=PackedByteArray()) -> RID:
	var spec:=RDTextureFormat.new()
	spec.texture_type=RenderingDevice.TEXTURE_TYPE_3D
	spec.width=GRID.x
	spec.height=GRID.y
	spec.depth=GRID.z
	spec.format=format
	spec.usage_bits=RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	var handle:=_own(_device.texture_create(spec,RDTextureView.new(),[data] if not data.is_empty() else []))
	if data.is_empty(): _device.texture_clear(handle,Color(0,0,0,0),0,1,0,1)
	return handle

func _sample(binding: int, texture: RID, sampler: RID) -> RDUniform:
	var value:=RDUniform.new()
	value.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	value.binding=binding
	value.add_id(sampler)
	value.add_id(texture)
	return value

func _image(binding: int, texture: RID) -> RDUniform:
	var value:=RDUniform.new()
	value.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE
	value.binding=binding
	value.add_id(texture)
	return value

func _buffer(binding: int, buffer: RID) -> RDUniform:
	var value:=RDUniform.new()
	value.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	value.binding=binding
	value.add_id(buffer)
	return value

func advance(dt: float, events: PackedFloat32Array, emitting: bool) -> bool:
	_mutex.lock()
	if not ready or not _running or _pending:
		_mutex.unlock()
		return false
	_pending=true
	_mutex.unlock()
	var keep_alive: RefCounted=self
	RenderingServer.call_on_render_thread(func(): keep_alive._advance_gpu(dt,events,emitting))
	return true

func _advance_gpu(dt: float, events: PackedFloat32Array, emitting: bool) -> void:
	_mutex.lock()
	var running:=_running
	_mutex.unlock()
	if running:
		if not events.is_empty():
			var bytes:=events.to_byte_array()
			_device.buffer_update(_events,0,bytes.size(),bytes)
		var count:=events.size()/12
		var commands:=_device.compute_list_begin()
		_dispatch(commands,1,0,_density_index,_pressure_index,dt,count,emitting)
		_dispatch(commands,2,1,_density_index,_pressure_index,dt,count,emitting)
		for i in PRESSURE_ITERATIONS:
			_dispatch(commands,3,1,_density_index,_pressure_index,dt,count,emitting)
			_pressure_index=1-_pressure_index
		_dispatch(commands,4,1,_density_index,_pressure_index,dt,count,emitting)
		_dispatch(commands,5,0,_density_index,_pressure_index,dt,count,emitting)
		_device.compute_list_end()
		_density_index=1-_density_index
		clock+=dt
		steps+=1
	_mutex.lock()
	_pending=false
	_mutex.unlock()

func _dispatch(commands: int, stage: int, v: int, d: int, p: int, dt: float, count: int, emitting: bool) -> void:
	var push:=PackedFloat32Array([origin.x,origin.y,origin.z,dt,extent.x,extent.y,extent.z,clock,
		float(GRID.x),float(GRID.y),float(GRID.z),float(stage),float(count),float(emitting),ambient_curl,buoyancy]).to_byte_array()
	_device.compute_list_bind_compute_pipeline(commands,_pipeline)
	_device.compute_list_bind_uniform_set(commands,_sets[Vector3i(v,d,p)],0)
	_device.compute_list_set_push_constant(commands,push,push.size())
	_device.compute_list_dispatch(commands,GRID.x/4,GRID.y/4,GRID.z/4)
	_device.compute_list_add_barrier(commands)

func reset() -> void:
	var keep_alive: RefCounted=self
	RenderingServer.call_on_render_thread(func(): keep_alive._reset_gpu())

func _reset_gpu() -> void:
	if _device==null or not _running: return
	for field in _velocity+_pressure+_density+[_divergence,_visible]:
		_device.texture_clear(field,Color(0,0,0,0),0,1,0,1)
	_density_index=1
	_pressure_index=0
	clock=0.0
	steps=0
	var commands:=_device.compute_list_begin()
	_dispatch(commands,0,0,0,0,0.0,0,false)
	_device.compute_list_end()

func update_solids(data: PackedFloat32Array) -> void:
	var keep_alive: RefCounted=self
	RenderingServer.call_on_render_thread(func():
		if keep_alive._device!=null and keep_alive._running:
			keep_alive._device.texture_update(keep_alive._solid,0,data.to_byte_array()))

func sample_field() -> void:
	var keep_alive: RefCounted=self
	RenderingServer.call_on_render_thread(func():
		if keep_alive._device==null or not keep_alive._running: return
		# Diagnostic readback only. The normal simulation never waits for CPU pixels.
		var result: Dictionary={"density":keep_alive._device.texture_get_data(keep_alive._visible,0).to_float32_array(),
			"velocity":keep_alive._device.texture_get_data(keep_alive._velocity[0],0).to_float32_array(),
			"divergence":keep_alive._device.texture_get_data(keep_alive._divergence,0).to_float32_array(),
			"solid":keep_alive._device.texture_get_data(keep_alive._solid,0).to_float32_array(),
			"steps":keep_alive.steps}
		keep_alive.call_deferred("_sampled",result))

func _sampled(state: Dictionary) -> void:
	field_sampled.emit(state)

func stop() -> void:
	_mutex.lock()
	_running=false
	ready=false
	_mutex.unlock()
	var keep_alive: RefCounted=self
	RenderingServer.call_on_render_thread(func(): keep_alive._free_gpu())

func _free_gpu() -> void:
	output.texture_rd_rid=RID()
	solid_output.texture_rd_rid=RID()
	velocity_output.texture_rd_rid=RID()
	if _device!=null:
		_owned.reverse()
		for handle in _owned:
			if handle.is_valid(): _device.free_rid(handle)
	_owned.clear()
	_sets.clear()
