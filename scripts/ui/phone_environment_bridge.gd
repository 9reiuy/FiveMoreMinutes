class_name PhoneEnvironmentBridge
extends Node

## A presentation bridge between the real gameplay room and the isolated phone.
## The phone never enters the capture world. Only one 64px face renders per frame.
## Direct lights retain source colour/energy/type and are mapped about the player;
## this is local illumination approximation, not copied world shadow geometry.
const BODY_SHADER := preload("res://shaders/ui/phone_body_surface.gdshader")
const LCD_SHADER := preload("res://shaders/ui/phone_lcd_surface.gdshader")
const FACE_SIZE := Vector2i(64, 64)
const LIGHT_SCALE := 20.0
const MAX_LIGHTS := 4
const FACE_NAMES := ["xp", "xn", "yp", "yn", "zp", "zn"]
const FACE_DIRECTIONS := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
const FACE_UP := [Vector3.UP, Vector3.UP, Vector3.BACK, Vector3.FORWARD, Vector3.UP, Vector3.UP]

var _source: WeakRef
var _source_camera: WeakRef
var _phone_camera: WeakRef
var _target: WeakRef
var _source_environment: Environment
var _target_environment: WorldEnvironment
var _original_environment: Environment
var _original_lights: Array[Dictionary] = []
var _mirrored_root: Node3D
var _mirrored_lights: Dictionary = {}
var _source_lights: Array[WeakRef] = []
var _faces: Array[SubViewport] = []
var _face_cameras: Array[Camera3D] = []
var _body_materials: Dictionary = {}
var _lcd_material: ShaderMaterial
var _fallback: Texture2D
var _active := false
var _source_is_3d := false
var _capture_requested := false
var _capture_in_progress := false
var _next_face := 0
var _pending_face := -1
var _face_update_count: Array[int] = [0, 0, 0, 0, 0, 0]
var _capture_count := 0
var _lights_count := 0
var _last_sync_usec := -1000000
var _last_inventory_usec := -1000000
var _signature := 0
var _has_signature := false
var _diagnostic_source_world_id := 0
var _diagnostic_own_world_id := 0
var _capture_anchor := Vector3.ZERO
var _face_ready := false
var _reflection_enabled := true
var _published_direction_basis := Basis.IDENTITY
var _has_direction_basis := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(_active)


func _resolve(reference: WeakRef) -> Object:
	return reference.get_ref() if reference != null else null


func configure(source_world: Node3D, source_camera: Camera3D, phone_camera: Camera3D, target_root: Node3D, ui_texture: Texture2D, fallback: Texture2D = null) -> void:
	stop()
	_source = weakref(source_world) if is_instance_valid(source_world) else null
	_source_camera = weakref(source_camera) if is_instance_valid(source_camera) else null
	_phone_camera = weakref(phone_camera) if is_instance_valid(phone_camera) else null
	_target = weakref(target_root) if is_instance_valid(target_root) else null
	_fallback = fallback
	_source_is_3d = is_instance_valid(source_world) and is_instance_valid(source_camera)
	_face_update_count = [0, 0, 0, 0, 0, 0]
	_capture_count = 0
	_lights_count = 0
	_has_signature = false
	_has_direction_basis = false
	_last_sync_usec = -1000000
	_last_inventory_usec = -1000000
	_diagnostic_source_world_id = source_world.get_world_3d().get_instance_id() if _source_is_3d else 0
	_diagnostic_own_world_id = target_root.get_world_3d().get_instance_id() if is_instance_valid(target_root) else 0
	if _lcd_material == null:
		_lcd_material = ShaderMaterial.new()
		_lcd_material.shader = LCD_SHADER
	_lcd_material.set_shader_parameter("lcd_texture", ui_texture)
	if is_instance_valid(target_root):
		for node in target_root.find_children("*", "Light3D", true, false):
			_original_lights.append({"node": weakref(node), "visible": node.visible})
		for node in target_root.find_children("*", "WorldEnvironment", true, false):
			_target_environment = node as WorldEnvironment
			_original_environment = _target_environment.environment
			if _original_environment != null:
				_target_environment.environment = _original_environment.duplicate()
			break
	_source_environment = _find_source_environment()
	_publish_textures()


func start() -> void:
	if _active:
		return
	if not is_instance_valid(_resolve(_target)):
		return
	_active = true
	set_process(true)
	if not RenderingServer.frame_post_draw.is_connected(_after_draw):
		RenderingServer.frame_post_draw.connect(_after_draw)
	if _source_is_3d:
		if _diagnostic_source_world_id == _diagnostic_own_world_id:
			# Sharing a world would create phone-in-phone feedback and is rejected.
			_source_is_3d = false
		else:
			for record in _original_lights:
				var light := _resolve(record.node) as Light3D
				if is_instance_valid(light):
					light.visible = false
			_create_capture_faces()
			_sync_environment_and_lights()
			request_capture()
	_publish_textures()


func stop() -> void:
	_active = false
	set_process(false)
	if RenderingServer.frame_post_draw.is_connected(_after_draw):
		RenderingServer.frame_post_draw.disconnect(_after_draw)
	for face in _faces:
		if is_instance_valid(face):
			face.render_target_update_mode = SubViewport.UPDATE_DISABLED
			face.world_3d = null
			face.queue_free()
	_faces.clear()
	_face_cameras.clear()
	if is_instance_valid(_mirrored_root):
		_mirrored_root.visible = false
		_mirrored_root.queue_free()
	_mirrored_root = null
	_mirrored_lights.clear()
	_source_lights.clear()
	for record in _original_lights:
		var light := _resolve(record.node) as Light3D
		if is_instance_valid(light):
			light.visible = bool(record.visible)
	_original_lights.clear()
	if is_instance_valid(_target_environment):
		_target_environment.environment = _original_environment
	_target_environment = null
	_original_environment = null
	_source_environment = null
	_fallback = null
	_capture_requested = false
	_capture_in_progress = false
	_pending_face = -1
	_face_ready = false
	_publish_textures()


func request_capture() -> void:
	if _active and _source_is_3d:
		_capture_requested = true


func set_reflection_enabled(enabled: bool) -> void:
	_reflection_enabled = enabled
	_publish_textures()


func get_body_material(source: StandardMaterial3D) -> ShaderMaterial:
	if source == null:
		return null
	var key := source.get_instance_id()
	if _body_materials.has(key):
		return _body_materials[key]
	var material := ShaderMaterial.new()
	material.shader = BODY_SHADER
	material.set_shader_parameter("body_colour", source.albedo_color)
	material.set_shader_parameter("body_roughness", source.roughness)
	material.set_shader_parameter("body_metallic", source.metallic)
	material.set_shader_parameter("body_specular", source.metallic_specular)
	material.set_shader_parameter("body_has_texture", source.albedo_texture != null)
	material.set_shader_parameter("body_texture", source.albedo_texture)
	_body_materials[key] = material
	_publish_material(material)
	return material


func get_lcd_material() -> ShaderMaterial:
	return _lcd_material


func get_diagnostics() -> Dictionary:
	return {"active": _active, "source_type": "source_3d" if _source_is_3d else "fallback_2d", "lighting_mode": "mapped_real_lights_local_approximation" if _source_is_3d else "fallback_soft_lights", "capture_count": _capture_count, "light_count": _lights_count, "source_world_id": _diagnostic_source_world_id, "own_world_id": _diagnostic_own_world_id, "face_update_count": _face_update_count.duplicate(), "face_size": FACE_SIZE, "capture_ready": _face_ready, "capture_anchor": _capture_anchor, "fallback_ready": _fallback != null, "capture_in_progress": _capture_in_progress, "pending_face": _pending_face, "source_shadow_geometry_copied": false, "reflection_enabled": _reflection_enabled, "phone_units_per_world_unit": LIGHT_SCALE}


func _find_source_environment() -> Environment:
	var camera := _resolve(_source_camera) as Camera3D
	if is_instance_valid(camera) and camera.environment != null:
		return camera.environment
	var world := _resolve(_source) as Node3D
	if not is_instance_valid(world):
		return null
	var node := world.get_node_or_null("Lighting/WorldEnvironment") as WorldEnvironment
	return node.environment if node != null else world.get_world_3d().environment


func _create_capture_faces() -> void:
	var world := _resolve(_source) as Node3D
	var main_camera := _resolve(_source_camera) as Camera3D
	if not is_instance_valid(world) or not is_instance_valid(main_camera):
		return
	for index in 6:
		var face := SubViewport.new()
		face.name = "PhoneEnvironment_" + FACE_NAMES[index]
		face.size = FACE_SIZE
		face.world_3d = world.get_world_3d()
		face.msaa_3d = Viewport.MSAA_DISABLED
		# Blurry environment colour uses geometry depth and real scene lighting;
		# it deliberately adds no second positional-shadow atlas to the floor.
		face.positional_shadow_atlas_size = 0
		face.render_target_update_mode = SubViewport.UPDATE_DISABLED
		face.handle_input_locally = false
		face.gui_disable_input = true
		add_child(face)
		var camera := Camera3D.new()
		camera.fov = 90.0
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.near = 0.05
		camera.far = minf(main_camera.far, 24.0)
		# Existing floor reflection installs capture-aware physical actor planes.
		# Keep main's floor layer while enabling those existing capture branches.
		camera.cull_mask = main_camera.cull_mask | (1 << 18)
		camera.environment = _source_environment
		face.add_child(camera)
		camera.current = true
		_faces.append(face)
		_face_cameras.append(camera)
	_publish_textures()


func _anchor() -> Vector3:
	var world := _resolve(_source) as Node3D
	var camera := _resolve(_source_camera) as Camera3D
	if not is_instance_valid(world):
		return Vector3.ZERO
	var player := world.get("player") as Node2D
	var result := world.global_position + Vector3.UP
	if is_instance_valid(player) and world.has_method("get_gameplay_world_position"):
		result = world.call("get_gameplay_world_position", player.global_position, 1.05)
	if is_instance_valid(camera):
		# Clear the camera-facing actor sheet instead of capturing inside its head.
		result += camera.global_basis.z * 0.35
	return result


func _process(_delta: float) -> void:
	if not _active:
		return
	if _source_is_3d:
		var source := _resolve(_source) as Node3D
		var camera := _resolve(_source_camera) as Camera3D
		if not is_instance_valid(source) or not is_instance_valid(camera) or not source.is_inside_tree() or not camera.is_inside_tree():
			stop()
			return
	var now := Time.get_ticks_usec()
	if _source_is_3d and now - _last_sync_usec >= 100000:
		_last_sync_usec = now
		_sync_environment_and_lights()
	if _capture_requested and not _capture_in_progress and _faces.size() == 6:
		_capture_requested = false
		_capture_in_progress = true
		_next_face = 0
		_capture_anchor = _anchor()
		for index in 6:
			_face_cameras[index].global_transform = Transform3D(Basis.looking_at(FACE_DIRECTIONS[index], FACE_UP[index]), _capture_anchor)
	if _capture_in_progress and _pending_face < 0 and _next_face < 6:
		_pending_face = _next_face
		_next_face += 1
		_faces[_pending_face].render_target_update_mode = SubViewport.UPDATE_ONCE
	_update_direction_basis()


func _after_draw() -> void:
	if not _active or _pending_face < 0:
		return
	_face_update_count[_pending_face] += 1
	_pending_face = -1
	if _next_face >= 6:
		_capture_in_progress = false
		_capture_count += 1
		_face_ready = true
		_publish_textures()


func _refresh_light_inventory() -> void:
	_source_lights.clear()
	var world := _resolve(_source) as Node3D
	if is_instance_valid(world):
		for light in world.find_children("*", "Light3D", true, false):
			_source_lights.append(weakref(light))


func _light_score(light: Light3D, anchor: Vector3) -> float:
	if not light.is_visible_in_tree() or light.light_energy <= 0 or (light.light_cull_mask & 3) == 0:
		return -1.0
	var energy := light.light_energy * light.light_color.get_luminance()
	if light is DirectionalLight3D:
		return energy
	var offset := anchor - light.global_position
	var distance := offset.length()
	var range_value: float = light.omni_range if light is OmniLight3D else light.spot_range if light is SpotLight3D else 0.0
	if distance >= range_value or range_value <= 0:
		return -1.0
	if light is SpotLight3D and distance > 0.001:
		var alignment := (-light.global_basis.z).dot(offset / distance)
		if alignment < cos(deg_to_rad(light.spot_angle)):
			return -1.0
	return energy * pow(1.0 - distance / range_value, 2.0)


func _sync_environment_and_lights() -> void:
	var world := _resolve(_source) as Node3D
	var camera := _resolve(_source_camera) as Camera3D
	var phone_camera := _resolve(_phone_camera) as Camera3D
	var target := _resolve(_target) as Node3D
	if not is_instance_valid(world) or not is_instance_valid(camera) or not is_instance_valid(phone_camera) or not is_instance_valid(target):
		return
	var now := Time.get_ticks_usec()
	if now - _last_inventory_usec >= 1000000:
		_last_inventory_usec = now
		_refresh_light_inventory()
	var anchor := _anchor()
	var rotation_basis := phone_camera.global_basis * camera.global_basis.inverse()
	var selected: Array[Dictionary] = []
	for reference in _source_lights:
		var source := _resolve(reference) as Light3D
		if not is_instance_valid(source):
			continue
		var score := _light_score(source, anchor)
		if score > 0.0001:
			selected.append({"source": source, "score": score})
	selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
	if selected.size() > MAX_LIGHTS:
		selected.resize(MAX_LIGHTS)
	if not is_instance_valid(_mirrored_root):
		_mirrored_root = Node3D.new()
		_mirrored_root.name = "MappedGameplayLights"
		target.add_child(_mirrored_root)
	var active_ids: Array[int] = []
	var signature_values: Array = [anchor, camera.global_basis]
	for record in selected:
		var source: Light3D = record.source
		var id := source.get_instance_id()
		active_ids.append(id)
		var clone := _mirrored_lights.get(id) as Light3D
		if not is_instance_valid(clone):
			clone = DirectionalLight3D.new() if source is DirectionalLight3D else OmniLight3D.new() if source is OmniLight3D else SpotLight3D.new()
			clone.name = "Mapped_" + str(id)
			_mirrored_root.add_child(clone)
			_mirrored_lights[id] = clone
		clone.global_transform = Transform3D(rotation_basis * source.global_basis, rotation_basis * (source.global_position - anchor) * LIGHT_SCALE)
		clone.light_color = source.light_color
		clone.light_energy = source.light_energy
		clone.light_negative = source.light_negative
		clone.light_specular = source.light_specular
		clone.light_cull_mask = 1
		clone.shadow_enabled = false
		signature_values.append([id, source.global_transform, source.light_color, source.light_energy, source.light_specular])
		if source is OmniLight3D:
			clone.omni_range = source.omni_range * LIGHT_SCALE
			clone.omni_attenuation = source.omni_attenuation
			signature_values.append([source.omni_range, source.omni_attenuation])
		elif source is SpotLight3D:
			clone.spot_range = source.spot_range * LIGHT_SCALE
			clone.spot_attenuation = source.spot_attenuation
			clone.spot_angle = source.spot_angle
			clone.spot_angle_attenuation = source.spot_angle_attenuation
			signature_values.append([source.spot_range, source.spot_attenuation, source.spot_angle, source.spot_angle_attenuation])
	for id in _mirrored_lights.keys():
		if not active_ids.has(id):
			var light := _mirrored_lights[id] as Light3D
			if is_instance_valid(light):
				light.queue_free()
			_mirrored_lights.erase(id)
	_lights_count = active_ids.size()
	_source_environment = _find_source_environment()
	if _source_environment != null and is_instance_valid(_target_environment) and _target_environment.environment != null:
		var env := _target_environment.environment
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = _source_environment.ambient_light_color
		env.ambient_light_energy = _source_environment.ambient_light_energy
		signature_values.append([env.ambient_light_color, env.ambient_light_energy])
	var current_signature := hash(signature_values)
	if not _has_signature or current_signature != _signature:
		_signature = current_signature
		_has_signature = true
		request_capture()


func _update_direction_basis() -> void:
	var source_camera := _resolve(_source_camera) as Camera3D
	var phone_camera := _resolve(_phone_camera) as Camera3D
	var cameras_in_tree:=is_instance_valid(source_camera) and source_camera.is_inside_tree() and is_instance_valid(phone_camera) and phone_camera.is_inside_tree()
	var basis := source_camera.global_basis * phone_camera.global_basis.inverse() if cameras_in_tree else Basis.IDENTITY
	if _has_direction_basis and _published_direction_basis.is_equal_approx(basis):
		return
	_published_direction_basis = basis
	_has_direction_basis = true
	for material: ShaderMaterial in _body_materials.values():
		material.set_shader_parameter("environment_direction_basis", basis)
	if _lcd_material != null:
		_lcd_material.set_shader_parameter("environment_direction_basis", basis)


func _publish_material(material: ShaderMaterial) -> void:
	material.set_shader_parameter("environment_direction_basis", _published_direction_basis)
	material.set_shader_parameter("environment_ready", (_face_ready if _source_is_3d else _fallback != null) and _reflection_enabled)
	material.set_shader_parameter("environment_is_3d", _source_is_3d)
	material.set_shader_parameter("environment_fallback", _fallback)
	for index in 6:
		material.set_shader_parameter("environment_" + FACE_NAMES[index], _faces[index].get_texture() if _faces.size() == 6 else null)


func _publish_textures() -> void:
	for material: ShaderMaterial in _body_materials.values():
		_publish_material(material)
	if _lcd_material != null:
		_publish_material(_lcd_material)
	_update_direction_basis()


func _exit_tree() -> void:
	stop()
