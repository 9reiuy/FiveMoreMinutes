extends Node3D
## Camera-local optics driven by the installed office fixtures and floor circuit.

const NODE_NAME := &"OfficeLightOptics"
const CAMERA_LAYER := preload("res://scripts/dream/render_layer_mask.gd").MAIN_CAMERA_OPTICS
const SURFACE := preload("res://shaders/dream3d/office_fixture_optics.gdshader")
const AIR := preload("res://shaders/dream3d/office_fixture_fog.gdshader")
const DIRT := preload("res://scripts/dream/office_lens_dirt_mask.gd")
const BASE_ENVIRONMENT := &"office_optics_base_environment"
const FIXTURE_LIMIT := 2
const FADE_SECONDS := 0.14
const AUTHORED_SOURCES := &"fixture_optics_sources"

class Emitter:
	var mesh: MeshInstance3D
	var bounds: AABB
	var material: BaseMaterial3D
	var follow_override := false
	func luminous_material() -> BaseMaterial3D:
		return mesh.material_override as BaseMaterial3D if follow_override else material
	func frame() -> Transform3D:
		var extent := bounds.size
		var axis := Vector3.RIGHT if extent.x >= maxf(extent.y, extent.z) else (Vector3.UP if extent.y >= extent.z else Vector3.BACK)
		axis = (mesh.global_basis * axis).normalized()
		var up := Vector3.FORWARD if absf(axis.dot(Vector3.UP)) > .99 else Vector3.UP
		var side := axis.cross(up).normalized()
		var world_bounds: AABB = mesh.global_transform * bounds
		return Transform3D(Basis(axis, side.cross(axis), side), world_bounds.get_center() + Vector3.UP * (world_bounds.size.y * .5 + .022))
	func half_length() -> float:
		var size := bounds.size * mesh.global_basis.get_scale().abs()
		return maxf(.08, maxf(size.x, maxf(size.y, size.z)) * .5)

class Fixture:
	var housing: Node3D
	var key: Light3D
	var emitters: Array[MeshInstance3D] = []
	var sources: Array[Emitter] = []
	var gain := 0.0
	var reference_energy := 1.0

class Slot:
	var root: Node3D
	var air: FogVolume
	var tubes: Array[MeshInstance3D] = []
	var fixture: Fixture
	var weight := 0.0
	var strength := 0.0

var _world: Node3D
var _camera: Camera3D
var _fixtures: Array[Fixture] = []
var _slots: Array[Slot] = []
var _fog_lights: Dictionary = {}
var _camera_environment: Environment
var _fog_source: Environment
var _fog_environment: Environment
var _added_camera_layer := false
var _last_draw_usec := 0
var _authored := false
var _fixtures_dirty := false
var _active_fog_keys: Array[Light3D] = []
var enabled := true


static func install(world: Node3D, authored := false) -> Node3D:
	if world.get_meta(&"test_office_light_optics_disabled", false):
		return null
	if not authored and (not world.has_method("uses_office_night_lighting") or not world.uses_office_night_lighting()):
		return null
	var host: Node3D = world if authored else world.ceiling_light_root
	var existing := host.get_node_or_null(NodePath(NODE_NAME)) as Node3D
	if existing != null:
		return existing
	var optics := new() as Node3D
	optics.name = NODE_NAME
	optics._authored = authored
	host.add_child(optics)
	optics._configure(world)
	return optics


static func uninstall(world: Node3D) -> void:
	for host: Node3D in [world, world.get("ceiling_light_root")]:
		if is_instance_valid(host):
			var optics := host.get_node_or_null(NodePath(NODE_NAME))
			if optics != null: optics.free()


static func mark_fixture(housing: Node3D, light: Light3D, meshes: Array) -> void:
	var sources: Array[Dictionary] = []
	for mesh: MeshInstance3D in meshes:
		var material := mesh.material_override as BaseMaterial3D
		if material != null:
			sources.append({"mesh": weakref(mesh), "bounds": mesh.get_aabb(), "material": material, "follow_override": true})
	mark_sources(housing, light, sources)


static func mark_sources(housing: Node3D, light: Light3D, sources: Array[Dictionary]) -> void:
	light.set_meta(AUTHORED_SOURCES, {"housing": weakref(housing), "sources": sources, "energy": light.light_energy})


func _configure(world: Node3D) -> void:
	_world = world
	_camera = world.camera_3d
	if not _authored:
		_collect_office_fixtures()
		if _fixtures.is_empty(): return
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	for index in FIXTURE_LIMIT:
		_create_slot(quad, index)
	_added_camera_layer = (_camera.cull_mask & CAMERA_LAYER) == 0
	_camera.cull_mask |= CAMERA_LAYER
	_camera_environment = _camera.environment
	for light in world.find_children("*", "Light3D", true, false):
		_register_light(light)
	get_tree().node_added.connect(_register_light)
	get_tree().node_removed.connect(_restore_light)
	# Moving FogVolumes must finish their scene transforms before render begins.
	# The production office fixtures retain their existing draw-time selection.
	if _authored:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = 200
		set_process(true)
	else:
		set_process(false)
		RenderingServer.frame_pre_draw.connect(_before_draw)


func _process(_delta: float) -> void:
	if _authored: _before_draw()


func _collect_office_fixtures() -> void:
	for holder in get_parent().get_children():
		var key := holder.get_node_or_null("RoomLight") as Light3D
		var housing := holder.get_node_or_null("FixtureMesh") as Node3D
		if key == null or housing == null:
			continue
		var fixture := Fixture.new()
		fixture.key = key
		fixture.housing = housing
		for part in housing.get_children():
			# The breaker can leave the restored floor's tubes unpowered.
			if part is MeshInstance3D and part.get_meta(&"ceiling_fixture_emitter", false):
				var emitter := Emitter.new()
				emitter.mesh = part
				emitter.bounds = part.get_aabb()
				emitter.material = part.material_override as BaseMaterial3D
				emitter.follow_override = true
				fixture.sources.append(emitter)
				fixture.emitters.append(part)
		if not fixture.sources.is_empty():
			_fixtures.append(fixture)


func _create_slot(quad: QuadMesh, index: int) -> void:
	var slot := Slot.new()
	slot.root = Node3D.new()
	slot.root.name = "FixtureOptics%d" % index
	slot.root.hide()
	add_child(slot.root)
	for tube_index in 2:
		var tube := MeshInstance3D.new()
		tube.name = "CameraHalo%d" % tube_index
		tube.layers = CAMERA_LAYER
		tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tube.ignore_occlusion_culling = true
		tube.custom_aabb = AABB(Vector3.ONE * -3.0, Vector3.ONE * 6.0)
		tube.mesh = quad
		var material := ShaderMaterial.new()
		material.shader = SURFACE
		material.set_shader_parameter("reveals_dirt", tube_index == 0)
		material.set_shader_parameter("lens_dirt", DIRT.texture())
		tube.material_override = material
		slot.root.add_child(tube)
		slot.tubes.append(tube)
	slot.air = FogVolume.new()
	slot.air.name = "LitAirBelowFixture"
	slot.air.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	slot.air.layers = CAMERA_LAYER
	var fog_material := ShaderMaterial.new()
	fog_material.shader = AIR
	slot.air.material = fog_material
	slot.root.add_child(slot.air)
	_slots.append(slot)


func _register_light(node: Node) -> void:
	if not node is Light3D or not _world.is_ancestor_of(node) or node.get_world_3d() != _camera.get_world_3d():
		return
	if _fog_lights.has(node): return
	# Other sources retain their ordinary lighting and contribute no fog.
	_fog_lights[node] = node.light_volumetric_fog_energy
	node.light_volumetric_fog_energy = 0.0
	if _authored:
		_discover_authored.call_deferred(weakref(node))


func _discover_authored(reference: WeakRef) -> void:
	var light := reference.get_ref() as Light3D
	if not is_instance_valid(light) or not light.has_meta(AUTHORED_SOURCES): return
	for fixture in _fixtures:
		if fixture.key == light: return
	var info: Dictionary = light.get_meta(AUTHORED_SOURCES)
	var fixture := Fixture.new()
	fixture.key = light
	fixture.housing = info.housing.get_ref()
	fixture.reference_energy = maxf(.001, light.light_energy if light.light_energy > 0.0 else float(info.energy))
	for source: Dictionary in info.sources:
		var mesh := source.mesh.get_ref() as MeshInstance3D
		if not is_instance_valid(mesh): continue
		var emitter := Emitter.new()
		emitter.mesh = mesh
		emitter.bounds = mesh.get_aabb() if source.get("follow_override", false) else source.bounds
		emitter.material = source.material
		emitter.follow_override = source.get("follow_override", false)
		fixture.sources.append(emitter)
		fixture.emitters.append(mesh)
	if not fixture.sources.is_empty(): _fixtures.append(fixture)


func _restore_light(node: Node) -> void:
	_fixtures_dirty = true
	if _fog_lights.has(node):
		node.light_volumetric_fog_energy = _fog_lights[node]
		_fog_lights.erase(node)


func _before_draw() -> void:
	if not is_instance_valid(_camera):
		return
	var now := Time.get_ticks_usec()
	var step := clampf((now - _last_draw_usec) / 1000000.0 / FADE_SECONDS, 0.0, 1.0)
	_last_draw_usec = now
	for slot in _slots:
		if slot.fixture != null and (not is_instance_valid(slot.fixture.key)
			or not is_instance_valid(slot.fixture.sources[0].mesh)):
			slot.weight = 0.0
			_clear_slot(slot)
	if _fixtures_dirty:
		_fixtures_dirty = false
		_fixtures = _fixtures.filter(func(fixture: Fixture) -> bool:
			return is_instance_valid(fixture.key) and is_instance_valid(fixture.housing) and is_instance_valid(fixture.sources[0].mesh))
	var active: bool = enabled and is_visible_in_tree() and _camera.is_current() and (_authored or _world.uses_office_night_lighting())
	var selected: Array[Fixture] = []
	if active:
		selected = _visible_fixtures()
	var unassigned := selected.duplicate()
	for slot in _slots:
		unassigned.erase(slot.fixture)
	var has_fog := false
	var fog_keys: Array[Light3D] = []
	for slot in _slots:
		var keeps_fixture := selected.has(slot.fixture)
		if not keeps_fixture:
			slot.weight = move_toward(slot.weight, 0.0, step)
			if slot.fixture != null and (not active or slot.fixture.gain <= 0.0):
				slot.weight = 0.0
			if slot.weight <= 0.0:
				_clear_slot(slot)
				if not unassigned.is_empty():
					_bind_slot(slot, unassigned.pop_front())
					keeps_fixture = true
		if keeps_fixture:
			slot.weight = move_toward(slot.weight, 1.0, step)
		_sync_slot(slot)
		has_fog = has_fog or slot.root.visible
		if slot.root.visible and slot.fixture != null and not fog_keys.has(slot.fixture.key): fog_keys.append(slot.fixture.key)
	for light in _active_fog_keys:
		if is_instance_valid(light) and not fog_keys.has(light): light.light_volumetric_fog_energy = 0.0
	for light in fog_keys:
		if not _active_fog_keys.has(light): light.light_volumetric_fog_energy = 2.5
	_active_fog_keys = fog_keys
	_sync_camera_environment(has_fog)


func _visible_fixtures() -> Array[Fixture]:
	var view := _camera.get_viewport().get_visible_rect()
	var center := view.get_center()
	var fringe := view.grow(view.size.y * 0.10)
	var nearest: Array[Fixture] = []
	var scores: Array[float] = []
	for fixture in _fixtures:
		fixture.gain = 0.0
		if not is_instance_valid(fixture.key) or not fixture.key.is_visible_in_tree() or fixture.key.layers == 0 or fixture.key.light_energy <= 0.0:
			continue
		var emitter := fixture.sources[0]
		if not is_instance_valid(emitter.mesh) or not emitter.mesh.is_visible_in_tree() or (_authored and (emitter.mesh.layers & _camera.cull_mask) == 0):
			continue
		var at := emitter.frame().origin if _authored else emitter.mesh.global_position
		if _camera.is_position_behind(at): continue
		var point := _camera.unproject_position(at)
		if not fringe.has_point(point):
			continue
		var material := emitter.luminous_material()
		if material == null or not material.emission_enabled:
			continue
		var power := fixture.key.light_energy / fixture.reference_energy if _authored else fixture.key.light_energy
		var brightness := material.emission.get_luminance() * material.emission_energy_multiplier * power
		fixture.gain = smoothstep(0.40, 1.06, brightness)
		if fixture.gain <= 0.0:
			continue
		var score := center.distance_squared_to(point)
		# A small preference for a current source avoids oscillation at ties.
		for slot in _slots:
			if slot.fixture == fixture:
				score *= 0.85
				break
		var insert_at := scores.bsearch(score)
		if insert_at < FIXTURE_LIMIT:
			scores.insert(insert_at, score)
			nearest.insert(insert_at, fixture)
			if nearest.size() > FIXTURE_LIMIT:
				nearest.pop_back()
				scores.pop_back()
	return nearest


func _bind_slot(slot: Slot, fixture: Fixture) -> void:
	slot.fixture = fixture
	if not _authored: _sync_pose(slot)


func _sync_pose(slot: Slot) -> void:
	var fixture := slot.fixture
	if _authored:
		var pose := fixture.sources[0].frame()
		var transform := Transform3D(Basis(Vector3.UP, -atan2(pose.basis.x.z, pose.basis.x.x)), pose.origin)
		if not slot.root.global_transform.is_equal_approx(transform): slot.root.global_transform = transform
	else:
		slot.root.global_transform = fixture.housing.global_transform
	for index in slot.tubes.size():
		var mesh := slot.tubes[index]
		mesh.visible = index < fixture.sources.size()
		if not mesh.visible:
			continue
		var emitter := fixture.sources[index]
		mesh.visible = is_instance_valid(emitter.mesh) and emitter.mesh.is_visible_in_tree()
		if not mesh.visible: continue
		if _authored:
			var transform := emitter.frame()
			if not mesh.global_transform.is_equal_approx(transform): mesh.global_transform = transform
		else:
			mesh.transform = emitter.mesh.transform.translated_local(emitter.bounds.get_center() + Vector3.UP * (emitter.bounds.size.y * .5 + .022))
		var half_length := emitter.half_length() if _authored else maxf(.08, emitter.bounds.size.x * .5)
		var tint := emitter.luminous_material().emission
		var material := mesh.material_override as ShaderMaterial
		if material.get_shader_parameter("half_length") != half_length: material.set_shader_parameter("half_length", half_length)
		if material.get_shader_parameter("fixture_tint") != tint: material.set_shader_parameter("fixture_tint", tint)
	var depth := maxf(0.8, slot.root.global_position.y - (_world.global_position.y if _authored else global_position.y) - 0.18)
	var air_y := -depth * 0.5 - 0.10
	var air_size := Vector3(4.0, depth, 3.2)
	if not is_equal_approx(slot.air.position.y, air_y): slot.air.position.y = air_y
	if not slot.air.size.is_equal_approx(air_size): slot.air.size = air_size


func _clear_slot(slot: Slot) -> void:
	slot.fixture = null
	slot.strength = 0.0
	slot.root.hide()


func _sync_slot(slot: Slot) -> void:
	if slot.fixture == null:
		return
	if _authored: _sync_pose(slot)
	var strength := slot.fixture.gain * slot.weight
	if is_equal_approx(strength, slot.strength):
		return
	slot.strength = strength
	slot.root.visible = strength > 0.001
	slot.air.material.set_shader_parameter("density", 0.050 * strength)
	for mesh in slot.tubes:
		mesh.material_override.set_shader_parameter("luminous_gain", strength)


func _sync_camera_environment(active: bool) -> void:
	if not is_instance_valid(_camera):
		return
	if not active:
		if _fog_environment != null and _camera.environment == _fog_environment:
			_camera.environment = _camera_environment
		return
	if _camera.environment != _fog_environment:
		_camera_environment = _camera.environment
	var source := _camera_environment if _camera_environment != null else _camera.get_world_3d().environment
	if source == null:
		return
	if _fog_source != source:
		_fog_source = source
		_fog_environment = source.duplicate()
		_fog_environment.set_meta(BASE_ENVIRONMENT, source)
		_fog_environment.volumetric_fog_enabled = true
		_fog_environment.volumetric_fog_density = 0.0
		_fog_environment.volumetric_fog_length = 35.0
		_fog_environment.volumetric_fog_anisotropy = 0.16
		_fog_environment.volumetric_fog_emission_energy = 0.0
		_fog_environment.volumetric_fog_ambient_inject = 0.0
		_fog_environment.volumetric_fog_gi_inject = 0.0
		_fog_environment.volumetric_fog_temporal_reprojection_amount = 0.62
	if _camera.environment != _fog_environment:
		_camera.environment = _fog_environment
	if _authored:
		# Connected regions adjust the same Environment in place.
		_fog_environment.ambient_light_color = source.ambient_light_color
		_fog_environment.ambient_light_energy = source.ambient_light_energy


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_before_draw):
		RenderingServer.frame_pre_draw.disconnect(_before_draw)
	var tree := get_tree()
	if tree.node_added.is_connected(_register_light):
		tree.node_added.disconnect(_register_light)
	if tree.node_removed.is_connected(_restore_light):
		tree.node_removed.disconnect(_restore_light)
	for light in _fog_lights.keys():
		if is_instance_valid(light):
			_restore_light(light)
	_fog_lights.clear()
	if is_instance_valid(_camera) and _camera.environment == _fog_environment:
		_camera.environment = _camera_environment
	if _added_camera_layer and is_instance_valid(_camera):
		_camera.cull_mask &= ~CAMERA_LAYER
