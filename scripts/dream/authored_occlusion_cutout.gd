extends RefCounted
## Authored blockers share the game's screen-space cutout slots and fragment mask.

const PBR := preload("res://shaders/dream3d/authored_cutout_pbr.gdshader")
const BLACK := preload("res://shaders/dream3d/authored_cutout_unshaded.gdshader")
const SLOT_COUNT := 8
const RADIUS_HEIGHT_SCALE := .58
const AIM_DOWN_SCALE := .20
const BIN_SIZE := 4.0
const SHADER_HEADER := "shader_type spatial;\n#include \"res://shaders/dream3d/occlusion_cutout.gdshaderinc\"\nvarying flat float cutout_camera_pass;\n"
const CAMERA_PASS := "\n\tcutout_camera_pass = float(all(equal(INV_VIEW_MATRIX[3], MAIN_CAM_INV_VIEW_MATRIX[3])));\n"
const DISCARD := "\n\tif (main_camera_cutout(SCREEN_UV, cutout_camera_pass)) { discard; }\n"
const TEXTURE_FILTERS := ["filter_nearest", "filter_linear", "filter_nearest_mipmap", "filter_linear_mipmap",
	"filter_nearest_mipmap_anisotropic", "filter_linear_mipmap_anisotropic"]
const PBR_PROPERTIES := [
	&"roughness", &"metallic", &"metallic_specular", &"emission",
	&"roughness_texture", &"metallic_texture", &"normal_texture", &"normal_scale", &"ao_enabled", &"ao_texture",
	&"ao_light_affect", &"clearcoat_enabled", &"clearcoat_texture", &"clearcoat", &"clearcoat_roughness",
]

class Blocker:
	var visual: MeshInstance3D
	var local_bounds: AABB
	var world_bounds: AABB
	var inverse: Transform3D
	var faces: PackedVector3Array
	var last_query := -1

	func refresh() -> void:
		var transform := visual.global_transform
		local_bounds = visual.get_aabb().grow(.015)
		world_bounds = transform * local_bounds
		inverse = transform.affine_inverse()

	func intersects(eye: Vector3, target: Vector3) -> bool:
		if world_bounds.intersects_segment(eye, target) == null or not is_instance_valid(visual) or not visual.is_visible_in_tree():
			return false
		var start := inverse * eye
		var end := inverse * target
		if local_bounds.intersects_segment(start, end) == null:
			return false
		if faces.is_empty():
			return true
		for i in range(0, faces.size(), 3):
			if Geometry3D.segment_intersects_triangle(start, end, faces[i], faces[i + 1], faces[i + 2]) != null:
				return true
		return false


var top_black := ShaderMaterial.new()
var _bounds: Array[AABB] = []
var _blockers: Array[Blocker] = []
var _moving: Array[Blocker] = []
var _static_bins: Dictionary[Vector2i, Array] = {}
var _query_id := 0
var _registered: Dictionary = {}
var _moving_frame := -1
var _materials: Dictionary[Material, Material] = {}
var _shaders: Dictionary[Shader, Shader] = {}
var _pbr_shaders: Dictionary[Vector3i, Shader] = {}
var _actors: Dictionary[Node2D, Node3D] = {}
var _slots: Array[Vector4] = []
var _viewport_size := Vector2.ZERO


func _init() -> void:
	top_black.resource_name = "Top_Black"
	top_black.shader = BLACK


func add_bounds(bounds: AABB) -> void:
	_bounds.append(bounds.grow(.015))


func blocks_view(camera: Camera3D, target: Vector3) -> bool:
	if camera.is_position_behind(target):
		return false
	var eye := camera.project_ray_origin(camera.unproject_position(target))
	for bounds in _bounds:
		if bounds.intersects_segment(eye, target) != null:
			return true
	var frame := Engine.get_process_frames()
	if frame != _moving_frame:
		_moving_frame = frame
		for entry in _moving:
			if is_instance_valid(entry.visual):
				entry.refresh()
	if _blockers.size() < 16:
		for entry in _blockers:
			if entry.intersects(eye, target):
				return true
		return false
	for entry in _moving:
		if entry.intersects(eye, target):
			return true
	# Long walls occupy every bin their bounds cross. Check each one only once
	# as the camera-to-actor segment can span several bins.
	_query_id += 1
	var first := _bin(eye.min(target))
	var last := _bin(eye.max(target))
	for z in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, z)
			if not _static_bins.has(cell):
				continue
			for entry: Blocker in _static_bins[cell]:
				if entry.last_query == _query_id:
					continue
				entry.last_query = _query_id
				if entry.intersects(eye, target):
					return true
	return false


func _bin(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / BIN_SIZE), floori(point.z / BIN_SIZE))


func register_tree(root: Node, moving := false, excluded: Array[StringName] = []) -> void:
	if root is MeshInstance3D and root.name not in excluded:
		register_mesh(root, moving)
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.name not in excluded:
			register_mesh(mesh, moving)


func register_mesh(visual: MeshInstance3D, moving := false, precise := false) -> void:
	if visual.mesh == null or visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		return
	var id := visual.get_instance_id()
	if _registered.has(id):
		return
	_registered[id] = true
	var entry := Blocker.new()
	entry.visual = visual
	entry.refresh()
	if precise:
		entry.faces = visual.mesh.get_faces()
	_blockers.append(entry)
	if moving:
		_moving.append(entry)
	else:
		var first := _bin(entry.world_bounds.position)
		var last := _bin(entry.world_bounds.end)
		for z in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var cell := Vector2i(x, z)
				if not _static_bins.has(cell):
					_static_bins[cell] = []
				_static_bins[cell].append(entry)
	if visual.material_override != null:
		visual.material_override = material_for(visual.material_override)
	else:
		for surface in visual.mesh.get_surface_count():
			var original := visual.get_active_material(surface)
			var cutout := material_for(original)
			if cutout != original:
				visual.set_surface_override_material(surface, cutout)


func material_for(original: Material) -> Material:
	if original == null or original == top_black:
		return original
	if _materials.has(original):
		return _materials[original]
	var material := original
	if original is StandardMaterial3D and original.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		material = pbr_material(original)
	elif original is ShaderMaterial and original.shader != null:
		material = _shader_material(original)
	_materials[original] = material
	return material


func include_variants_in(materials: Array[ShaderMaterial]) -> void:
	for original in materials.duplicate():
		var variant := _materials.get(original) as ShaderMaterial
		if variant != null and variant not in materials:
			materials.append(variant)


func _shader_material(original: ShaderMaterial) -> ShaderMaterial:
	var shader := original.shader
	var code := shader.code
	if shader == PBR or shader == BLACK:
		return original
	var has_switch := code.contains("uniform bool occlusion_cutout_enabled")
	if has_switch and original.get_shader_parameter(&"occlusion_cutout_enabled") == true:
		return original
	if not has_switch:
		# Native office and door shaders already consume the shared slots.
		if code.contains("combined_cutout(") or code.contains("main_camera_cutout(") or code.contains("global uniform vec4 occlusion_cutout_0"):
			return original
		if not code.contains("shader_type spatial;") or not code.contains("void fragment("):
			return original
		if not _shaders.has(shader):
			var variant := Shader.new()
			code = code.replace("shader_type spatial;", SHADER_HEADER)
			var fragment := code.find("{", code.find("void fragment(")) + 1
			code = code.insert(fragment, DISCARD)
			var vertex := code.find("void vertex(")
			if vertex == -1:
				code += "\nvoid vertex() {" + CAMERA_PASS + "}\n"
			else:
				code = code.insert(code.find("{", vertex) + 1, CAMERA_PASS)
			variant.code = code
			_shaders[shader] = variant
		shader = _shaders[shader]
	var material := original.duplicate() as ShaderMaterial
	material.shader = shader
	for field in original.shader.get_shader_uniform_list():
		var value: Variant = original.get_shader_parameter(field.name)
		if value != null:
			material.set_shader_parameter(field.name, value)
	if has_switch:
		material.set_shader_parameter(&"occlusion_cutout_enabled", true)
	return material


func pbr_material(original: StandardMaterial3D) -> ShaderMaterial:
	if _materials.has(original):
		return _materials[original] as ShaderMaterial
	var material := ShaderMaterial.new()
	material.resource_name = original.resource_name
	var unshaded := original.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	material.shader = _standard_shader(original, unshaded)
	material.render_priority = original.render_priority
	material.next_pass = original.next_pass
	material.set_shader_parameter(&"albedo_color", original.albedo_color)
	material.set_shader_parameter(&"albedo_texture", original.albedo_texture)
	material.set_shader_parameter(&"textured", original.albedo_texture != null)
	material.set_shader_parameter(&"uv1_scale", original.uv1_scale)
	material.set_shader_parameter(&"uv1_offset", original.uv1_offset)
	if unshaded:
		_materials[original] = material
		return material
	for field: StringName in PBR_PROPERTIES:
		var value: Variant = original.get(field)
		if value != null:
			material.set_shader_parameter(field, value)
	material.set_shader_parameter(&"normal_enabled", original.normal_enabled)
	material.set_shader_parameter(&"metallic_channel", _channel(original.metallic_texture_channel))
	material.set_shader_parameter(&"roughness_channel", _channel(original.roughness_texture_channel))
	material.set_shader_parameter(&"ao_channel", _channel(original.ao_texture_channel))
	if original.emission_enabled:
		material.set_shader_parameter(&"emission_energy_multiplier", original.emission_energy_multiplier)
	_materials[original] = material
	return material


func _standard_shader(original: StandardMaterial3D, unshaded: bool) -> Shader:
	var prototype := BLACK if unshaded else PBR
	var key := Vector3i(int(unshaded), original.cull_mode, original.texture_filter)
	if original.cull_mode == BaseMaterial3D.CULL_BACK and original.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC:
		return prototype
	if not _pbr_shaders.has(key):
		var shader := Shader.new()
		var code := prototype.code.replace("filter_nearest_mipmap_anisotropic", TEXTURE_FILTERS[original.texture_filter])
		if original.cull_mode != BaseMaterial3D.CULL_BACK:
			var cull := "cull_front" if original.cull_mode == BaseMaterial3D.CULL_FRONT else "cull_disabled"
			code = code.replace("render_mode ", "render_mode %s, " % cull)
		shader.code = code
		_pbr_shaders[key] = shader
	return _pbr_shaders[key]


func _channel(index: int) -> Vector4:
	var weights := Vector4(.333333, .333333, .333333, 0.0)
	if index < 4:
		weights = Vector4.ZERO
		weights[index] = 1.0
	return weights


func watch_actor(actor: Node2D, bridge: Node3D) -> void:
	_actors[actor] = bridge


func update_slots(camera: Camera3D, projectiles: Array[Node] = [], projectile_radius := .20, primary_sprite: Sprite3D = null, lower_body_probe := false) -> void:
	var size := camera.get_viewport().get_visible_rect().size
	if size != _viewport_size:
		_viewport_size = size
		RenderingServer.global_shader_parameter_set(&"occlusion_viewport_size", size)
	if _slots.is_empty():
		_slots.resize(SLOT_COUNT)
		_slots.fill(Vector4(-1, -1, -1, -1))
	var index := _actor_slot(camera, primary_sprite, 0, lower_body_probe)
	for actor in _actors:
		if not is_instance_valid(actor) or not actor.visible or actor.get("dead") == true:
			continue
		var bridge: Node3D = _actors[actor]
		if is_instance_valid(bridge):
			index = _actor_slot(camera, bridge.get(&"actor_sprite") as Sprite3D, index)
			if index == SLOT_COUNT:
				return
	for projectile in projectiles:
		if not is_instance_valid(projectile) or not projectile is Node2D or projectile.is_queued_for_deletion() or projectile.get("consumed") == true:
			continue
		var sprite := _actor_sprite(projectile as Node2D)
		if sprite == null or not blocks_view(camera, sprite.global_position):
			continue
		var slot := project(camera, sprite.global_position, projectile_radius)
		if slot.w > .5:
			_write_slot(index, slot)
			index += 1
			if index == SLOT_COUNT:
				return
	for i in range(index, SLOT_COUNT):
		_write_slot(i, Vector4.ZERO)


func _actor_slot(camera: Camera3D, sprite: Sprite3D, index: int, lower_body_probe := false) -> int:
	# The capture can hide the gameplay CanvasLayer while its 3D actor is visible.
	if not is_instance_valid(sprite) or not sprite.is_visible_in_tree():
		return index
	var point := sprite_center(sprite, camera)
	var radius := sprite_radius(sprite)
	if not blocks_view(camera, point):
		if not lower_body_probe:
			return index
		# Low coast dressing can cover the lower half while the torso stays visible.
		var lower_point := point - camera.global_basis.y.normalized() * (radius * .60)
		if not blocks_view(camera, lower_point):
			return index
		point = lower_point
		radius *= .70
	var slot := project(camera, point, radius)
	if slot.w < .5:
		return index
	_write_slot(index, slot)
	return index + 1


func clear_slots() -> void:
	for i in SLOT_COUNT:
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	_slots.clear()
	_viewport_size = Vector2.ZERO


func _write_slot(index: int, slot: Vector4) -> void:
	if _slots[index] != slot:
		_slots[index] = slot
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % index, slot)


func _actor_sprite(actor: Node2D) -> Sprite3D:
	var reference: WeakRef = actor.get_meta(&"depth_visual_bridge", null)
	var bridge: Node3D = reference.get_ref() if reference != null else null
	return bridge.get(&"actor_sprite") as Sprite3D if is_instance_valid(bridge) else null


static func sprite_center(sprite: Sprite3D, camera: Camera3D) -> Vector3:
	var center := sprite.global_position
	if is_instance_valid(camera) and sprite.texture != null:
		var half_height := sprite.pixel_size * float(sprite.texture.get_height()) * .5
		center -= camera.global_transform.basis.y.normalized() * (half_height * AIM_DOWN_SCALE)
	return center


static func sprite_radius(sprite: Sprite3D) -> float:
	if sprite.texture == null:
		return .24
	var half_height := sprite.pixel_size * float(sprite.texture.get_height()) * .5
	return maxf(.24, half_height * RADIUS_HEIGHT_SCALE + .04)


static func project(camera: Camera3D, center: Vector3, world_radius: float, screen_override: Variant = null) -> Vector4:
	if not is_instance_valid(camera) or camera.is_position_behind(center):
		return Vector4.ZERO
	var viewport := camera.get_viewport()
	if viewport == null:
		return Vector4.ZERO
	var size := viewport.get_visible_rect().size
	if size.x <= 1.0 or size.y <= 1.0:
		return Vector4.ZERO
	var screen: Vector2 = screen_override if screen_override is Vector2 else camera.unproject_position(center)
	var radius := maxf(world_radius, .01)
	var right := camera.global_transform.basis.x.normalized()
	var up := camera.global_transform.basis.y.normalized()
	var edge_x := camera.unproject_position(center + right * radius)
	var edge_y := camera.unproject_position(center + up * radius)
	var pixels := maxf(screen.distance_to(edge_x), screen.distance_to(edge_y)) + 2.0
	if not Rect2(Vector2.ZERO, size).grow(pixels).has_point(screen):
		return Vector4.ZERO
	return Vector4(screen.x / size.x, screen.y / size.y, pixels, 1.0)
