extends Node
## One component per 3D Dream world, sharing compiled variants but not materials.
const GRID_STEP := 1.0 / 32.0
const INCLUDE := "res://shaders/dream3d/office_dither_lighting.gdshaderinc"
const OUTLINE_SHADER_PATH := "res://shaders/dream3d/furniture_pixel_outline.gdshader"
static var shader_cache: Dictionary = {}
## Shared outline material -> its cutout-enabled copy (occluder furniture only).
static var cutout_outline_cache: Dictionary = {}
## Shader RID/instance_id -> whether its source declares occlusion_cutout_enabled.
## Avoids scanning shader.code (multi-KB string) up to 24 meshes/frame in _apply.
static var _shader_has_cutout_uniform: Dictionary = {}
## Shader RID/instance_id -> whether code contains sample_capture_pass (wall cutaway etc.).
static var _shader_has_sample_capture_pass: Dictionary = {}
var materials: Dictionary = {}
var meshes: Array[WeakRef] = []
var cursor := 0
var world: Node

func _ready() -> void:
	world = get_parent()
	add_to_group(&"office_dither_lighting")
	for mesh in world.find_children("*", "MeshInstance3D", true, false):
		_register_mesh(mesh)
	get_tree().node_added.connect(_on_node_added)
	if world.has_signal("generation_progress"):
		world.connect("generation_progress", _on_generation_progress)
	if world.has_signal("elevator_floor_transition_completed"):
		world.connect("elevator_floor_transition_completed", _on_floor_completed)

func _on_generation_progress(ratio: float, _message: String) -> void:
	if ratio <= 0.10:
		materials.clear()

func _on_floor_completed(_floor: int) -> void:
	materials.clear()
	meshes = meshes.filter(func(reference: WeakRef) -> bool: return is_instance_valid(reference.get_ref()))
	cursor = 0

func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D and world.is_ancestor_of(node):
		# A floor can be freed before the deferred callback is dispatched.
		# Never send a raw Node through deferred typed argument conversion.
		_register_deferred_mesh.call_deferred(weakref(node))

func _register_deferred_mesh(reference: WeakRef) -> void:
	var mesh: Node = reference.get_ref()
	if is_instance_valid(mesh) and is_instance_valid(world) and world.is_ancestor_of(mesh):
		_register_mesh(mesh)

func _register_mesh(mesh: Node) -> void:
	if not is_instance_valid(mesh) or mesh.is_queued_for_deletion():
		return
	meshes.append(weakref(mesh))
	_apply(mesh)

func _process(_delta: float) -> void:
	# Bounded refresh catches late material assignment without a whole-floor scan.
	for slot in mini(24, meshes.size()):
		if cursor >= meshes.size():
			cursor = 0
		var mesh: MeshInstance3D = meshes[cursor].get_ref()
		if not is_instance_valid(mesh):
			meshes.remove_at(cursor)
			if meshes.is_empty():
				break
		else:
			_apply(mesh)
			cursor += 1

func _apply(mesh: MeshInstance3D) -> void:
	if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		return
	var furniture := _is_furniture_occluder(mesh)
	if furniture:
		# Furniture keeps its own render layers: the cutout is single-pass (the
		# body discards its hole core in the transparent list) and needs no
		# separate behind-camera layer.
		_enable_outline_cutout(mesh)
	# Write occlusion_cutout_enabled only AFTER dither material replacement so
	# the live ShaderMaterial (not the discarded pre-dither source) gets the flag.
	if mesh.material_override != null:
		var replacement := _material(mesh.material_override)
		if replacement != mesh.material_override:
			mesh.material_override = replacement
		if furniture and mesh.material_override is ShaderMaterial:
			var live_shader: Shader = (mesh.material_override as ShaderMaterial).shader
			if live_shader != null and _shader_supports_cutout(live_shader):
				(mesh.material_override as ShaderMaterial).set_shader_parameter("occlusion_cutout_enabled", true)
	elif mesh.mesh != null:
		for index in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(index)
			var replacement := _material(original)
			if replacement != original:
				mesh.set_surface_override_material(index, replacement)
			# GLB/catalogue furniture carries its pixel material on SURFACES, not
			# in material_override.  Flag the live (dithered) surface material as
			# well or the furniture body never opens its hole.  The dither copy
			# is per-source and these sources are furniture-only, so the write
			# cannot leak into walls or floors.
			if furniture:
				var live_surface := mesh.get_active_material(index) as ShaderMaterial
				if live_surface != null and live_surface.shader != null and _shader_supports_cutout(live_surface.shader):
					live_surface.set_shader_parameter("occlusion_cutout_enabled", true)


## The black inverted-hull outline (Furniture3DVisual) is drawn after the body.
## Inside a cutout hole the body is discarded, so the hull must discard there
## too or its back faces paint the hole black.  Swap the shared outline for a
## shared cutout-enabled copy; other overlays (damage/interaction) are untouched.
func _enable_outline_cutout(mesh: MeshInstance3D) -> void:
	var overlay := mesh.material_overlay as ShaderMaterial
	if overlay == null or overlay.shader == null or overlay.shader.resource_path != OUTLINE_SHADER_PATH:
		return
	if overlay.get_shader_parameter("occlusion_cutout_enabled") == true:
		return
	if not cutout_outline_cache.has(overlay):
		var copy: ShaderMaterial = overlay.duplicate()
		copy.set_shader_parameter("occlusion_cutout_enabled", true)
		cutout_outline_cache[overlay] = copy
	mesh.material_overlay = cutout_outline_cache[overlay]


## A mesh counts as furniture when one of its ancestors carries the marker set by
## office_low_pixel_art.make_visual(), or owns a damageable_props source actor.
func _is_furniture_occluder(mesh: Node) -> bool:
	var cursor: Node = mesh
	while cursor != null:
		if cursor.has_meta(&"occlusion_cutout_occluder"):
			return bool(cursor.get_meta(&"occlusion_cutout_occluder"))
		var source: Variant = cursor.get("source_actor")
		if source is Node2D:
			return (source as Node2D).is_in_group(&"damageable_props")
		cursor = cursor.get_parent()
	return false


func _material(source: Material) -> Material:
	if not source is ShaderMaterial or source.shader == null:
		return source
	# Retain the live material used by wall cutaway, doors and furniture.
	if _shader_has_capture_pass(source.shader):
		return source
	var res_path: String = source.shader.resource_path
	if res_path.is_empty():
		return source
	var filename: String = res_path.get_file()
	# Actor/blood/glass/emission/outline shaders are deliberately outside scope.
	if not (filename in ["office_pixel_surface.gdshader", "office_low_pixel.gdshader", "office_low_pixel_refined.gdshader", "office_detail_atlas.gdshader"] or filename.begins_with("interiors_a_floor_") or filename in ["interiors_a_wall_pixel_light.gdshader", "interiors_a_wall_vertical_fade.gdshader", "interiors_a_door_pixel_light.gdshader"]):
		return source
	if not materials.has(source):
		var copy: ShaderMaterial = source.duplicate()
		copy.shader = _shader(source.shader)
		for uniform in source.shader.get_shader_uniform_list():
			var value: Variant = source.get_shader_parameter(uniform.name)
			if value != null:
				copy.set_shader_parameter(uniform.name, value)
		copy.set_shader_parameter("office_dither_step", GRID_STEP)
		copy.set_shader_parameter("office_dither_enabled", true)
		materials[source] = copy
	return materials[source]


static func _shader_supports_cutout(shader: Shader) -> bool:
	var id := shader.get_instance_id()
	if _shader_has_cutout_uniform.has(id):
		return bool(_shader_has_cutout_uniform[id])
	var has := shader.code.contains("occlusion_cutout_enabled")
	_shader_has_cutout_uniform[id] = has
	return has


static func _shader_has_capture_pass(shader: Shader) -> bool:
	var id := shader.get_instance_id()
	if _shader_has_sample_capture_pass.has(id):
		return bool(_shader_has_sample_capture_pass[id])
	var has := shader.code.contains("sample_capture_pass")
	_shader_has_sample_capture_pass[id] = has
	return has


static func _shader(source: Shader) -> Shader:
	if shader_cache.has(source):
		return shader_cache[source]
	var code := source.code
	var start := code.find("void light()")
	var original := "DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * max(dot(NORMAL, LIGHT), 0.0) / PI;"
	if start >= 0:
		# Find the balanced body instead of assuming light() is the last function.
		var open := code.find("{", start)
		var end := open + 1
		var depth := 1
		while depth > 0 and end < code.length():
			if code[end] == "{": depth += 1
			elif code[end] == "}": depth -= 1
			end += 1
		original = code.substr(open + 1, end - open - 2)
		code = code.substr(0, start) + code.substr(end)
	code = code.replace("shader_type spatial;", "shader_type spatial;\n#include \"" + INCLUDE + "\"")
	var vertex := "office_dither_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; office_dither_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);"
	if code.contains("void vertex() {"):
		code = code.replace("void vertex() {", "void vertex() {\n" + vertex)
	else:
		code += "\nvoid vertex() {" + vertex + "}\n"
	code += "\nvoid light() { if (!office_dither_enabled) {" + original + "} else { float shade = office_dither_response(ATTENUATION * max(dot(NORMAL, LIGHT), 0.0)); DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * shade / PI; }}"
	var shader := Shader.new()
	shader.code = code
	shader_cache[source] = shader
	return shader

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if is_instance_valid(world):
		if world.has_signal("generation_progress") and world.is_connected("generation_progress", _on_generation_progress):
			world.disconnect("generation_progress", _on_generation_progress)
		if world.has_signal("elevator_floor_transition_completed") and world.is_connected("elevator_floor_transition_completed", _on_floor_completed):
			world.disconnect("elevator_floor_transition_completed", _on_floor_completed)
