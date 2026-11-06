extends Node
## Preview-only world-space LOS on the existing surfaces. No extra actor layer,
## depth reconstruction, source-shader edits, or changes to transparent coverage.

const PIXELS_PER_CELL := 32.0
const SWATCHES = preload("res://scripts/dream/office_pixel_materials.gd")
const ATLAS_ART = preload("res://scripts/dream/office_low_pixel_art.gd")
const WALL_SCRIPT := "res://scripts/dream/wall_segment_3d.gd"
const DOOR_SCRIPT := "res://scripts/dream/physical_door_3d.gd"
const MARKER := "woo_visibility_material_variant"
const HEADER := """
// woo_visibility_material_variant
uniform bool woo_enabled = false;
uniform sampler2D woo_ray_distances : filter_nearest, repeat_enable;
uniform vec2 woo_origin = vec2(0.0);
uniform float woo_range = 1024.0;
uniform float woo_surface_margin = 2.0;
uniform mat4 woo_world_to_map;
uniform float woo_wall_padding = 0.0;
uniform float woo_wall_half_depth = 0.0;
uniform vec3 woo_wall_axis = vec3(0.0, 0.0, 1.0);
uniform vec3 woo_wall_center = vec3(0.0);
uniform bool woo_door_leaf = false;
uniform vec2 woo_leaf_center = vec2(0.0);
uniform vec2 woo_leaf_tangent = vec2(1.0, 0.0);
uniform vec2 woo_leaf_normal = vec2(0.0, 1.0);
uniform vec2 woo_leaf_half_size = vec2(1.0);
varying vec3 woo_position;
varying vec3 woo_normal;
varying float woo_occluded;
float woo_surface_occlusion(vec3 point, vec3 surface_normal) {
	if (!woo_enabled) { return 0.0; }
	if (woo_wall_padding > 0.0) {
		vec3 normal = normalize(surface_normal);
		if (abs(normal.y) > 0.5) {
			// A thin wall's cap is inside its wider gameplay blocker. Test its
			// near physical face, retaining the same along-wall coordinate.
			vec3 eye = (inverse(woo_world_to_map) * vec4(woo_origin.x / 32.0, 0.0, woo_origin.y / 32.0, 1.0)).xyz;
			float side = dot(eye - point, woo_wall_axis) >= 0.0 ? 1.0 : -1.0;
			float offset = dot(point - woo_wall_center, woo_wall_axis);
			point += woo_wall_axis * (side * (woo_wall_half_depth + 0.005) - offset);
		} else if (abs(dot(normal, woo_wall_axis)) > 0.5) {
			// Only recognized wall faces get this geometric compensation.
			// Floor/furniture keep their actual surface point and original bias.
			point += normal * (woo_wall_padding + 0.005);
		}
	}
	vec2 map_point = (woo_world_to_map * vec4(point, 1.0)).xz * 32.0;
	if (woo_door_leaf) {
		// The Camera may see the opposite panel face from the player's ground
		// anchor. A normal-selected face then lies behind this leaf's own box.
		// Intersect the PLAYER-to-fragment segment with this exact rotating 2D
		// leaf and test just before its first entry. Only this leaf's material
		// gets that sample; the field and all pixels behind the door stay intact.
		vec2 origin_offset = woo_origin - woo_leaf_center;
		vec2 target_offset = map_point - woo_leaf_center;
		vec2 local_origin = vec2(dot(origin_offset, woo_leaf_tangent), dot(origin_offset, woo_leaf_normal));
		vec2 local_target = vec2(dot(target_offset, woo_leaf_tangent), dot(target_offset, woo_leaf_normal));
		vec2 direction = local_target - local_origin;
		vec2 safe_direction = vec2(abs(direction.x) > 0.00001 ? direction.x : 0.00001,
			abs(direction.y) > 0.00001 ? direction.y : 0.00001);
		vec2 a = (-woo_leaf_half_size - local_origin) / safe_direction;
		vec2 b = (woo_leaf_half_size - local_origin) / safe_direction;
		float enter = max(min(a.x, b.x), min(a.y, b.y));
		float leave = min(max(a.x, b.x), max(a.y, b.y));
		bool parallel_outside = (abs(direction.x) <= 0.00001 && abs(local_origin.x) > woo_leaf_half_size.x)
			|| (abs(direction.y) <= 0.00001 && abs(local_origin.y) > woo_leaf_half_size.y);
		if (!parallel_outside && enter >= 0.0 && enter <= 1.0 && leave >= enter) {
			vec2 sight_ray = map_point - woo_origin;
			float safe_enter = max(0.0, enter - 0.16 / max(length(sight_ray), 0.001));
			map_point = woo_origin + sight_ray * safe_enter;
		}
	}
	vec2 delta = map_point - woo_origin;
	float distance_to_origin = length(delta);
	if (distance_to_origin < 0.001) { return 0.0; }
	float radius = max(woo_range, 0.001);
	if (distance_to_origin > radius) { return 1.0; }
	float angle_u = fract((atan(delta.y, delta.x) + 3.14159265359) / 6.28318530718);
	float count = float(textureSize(woo_ray_distances, 0).x);
	float left = floor(angle_u * count - 0.5);
	float a = texture(woo_ray_distances, vec2(fract((left + 0.5) / count), 0.5)).r;
	float b = texture(woo_ray_distances, vec2(fract((left + 1.5) / count), 0.5)).r;
	float limit = min(a, b) * radius;
	return distance_to_origin > limit + woo_surface_margin ? 1.0 : 0.0;
}
"""
const VERTEX_TAIL := "\nwoo_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\nwoo_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);\n"
const FRAGMENT_TAIL := """
woo_occluded = woo_surface_occlusion(woo_position, woo_normal);
if (woo_occluded > 0.5) {
	ALBEDO = vec3(0.0);
	EMISSION = vec3(0.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
}
"""
const LIGHT_TAIL := """
if (woo_occluded > 0.5) {
	DIFFUSE_LIGHT = vec3(0.0);
	SPECULAR_LIGHT = vec3(0.0);
}
"""

var world: Node3D
var field: Object
var enabled := false
var scan_interval_seconds := 0.2
var surface_margin_pixels := 2.0
var managed_count := 0
var binding_count := 0
var unsupported_count := 0
var unsupported_names: Array[String] = []
var shader_rejections: Dictionary = {}
var last_scan_usec := 0
var last_update_usec := 0

var _next_scan_usec := 0
var _records: Dictionary = {}
var _copies: Dictionary = {}
var _wall_copies: Dictionary = {}
var _door_copies: Dictionary = {}
var _bindings: Dictionary = {}
var _variants: Dictionary = {}
var _known_local: Dictionary = {}
var _shared: Dictionary = {}
var _protected: Dictionary = {}
var _excluded_roots: Array[Node] = []
var _seen: Dictionary = {}


func configure(owner_world: Node3D, visibility_field: Object) -> void:
	restore()
	world = owner_world
	field = visibility_field
	enabled = is_instance_valid(world) and is_instance_valid(field)
	_next_scan_usec = 0
	if enabled:
		update_now()


func set_enabled(value: bool) -> void:
	enabled = value and is_instance_valid(world) and is_instance_valid(field)
	for material: ShaderMaterial in _records:
		material.set_shader_parameter("woo_enabled", enabled)
	if enabled:
		_next_scan_usec = 0
		update_now()


func update_now() -> void:
	var started := Time.get_ticks_usec()
	if not is_instance_valid(world) or not is_instance_valid(field):
		restore()
		return
	if enabled:
		# Wall cutaway owners may rebind an unchanged original material between
		# scans. Keep these known slots decorated immediately; a genuinely new
		# material schedules a fresh ownership/geometry scan instead.
		for binding: Dictionary in _bindings.values():
			var node := binding.node.get_ref() as GeometryInstance3D
			if not is_instance_valid(node): continue
			var current := _slot_material(node, binding.slot)
			if current == binding.original:
				_set_slot(node, binding.slot, binding.installed)
			elif current != binding.installed:
				_next_scan_usec = 0
	if enabled and started >= _next_scan_usec:
		_scan()
		_next_scan_usec = started + int(maxf(scan_interval_seconds, 0.0) * 1000000.0)
	var transform := world.global_transform.affine_inverse()
	var ray_texture: Texture2D = field.get("texture") as Texture2D
	var origin: Vector2 = field.get("origin_pixels")
	var radius: float = float(field.get("range_pixels"))
	for material: ShaderMaterial in _records:
		var record: Dictionary = _records[material]
		var source := record.source as ShaderMaterial
		if source != material:
			# Unowned materials are isolated on the instance, while their original
			# animation/cutout/reflection owner remains authoritative for uniforms.
			_copy_parameters(source, material, record.uniforms)
		material.set_shader_parameter("woo_ray_distances", ray_texture)
		material.set_shader_parameter("woo_origin", origin)
		material.set_shader_parameter("woo_range", radius)
		material.set_shader_parameter("woo_world_to_map", transform)
		material.set_shader_parameter("woo_surface_margin", maxf(surface_margin_pixels, 0.0))
		material.set_shader_parameter("woo_wall_padding", float(record.get("wall_padding", 0.0)))
		if record.has("wall_owner"):
			var wall := record.wall_owner.get_ref() as Node3D
			if is_instance_valid(wall):
				material.set_shader_parameter("woo_wall_axis", wall.global_basis.z.normalized())
				material.set_shader_parameter("woo_wall_center", wall.global_position)
				material.set_shader_parameter("woo_wall_half_depth", float(wall.get("wall_thickness")) * 0.5 * wall.global_basis.z.length())
		var door_shape: CollisionShape2D = record.door_shape.get_ref() as CollisionShape2D if record.has("door_shape") else null
		var leaf_rect := door_shape.shape as RectangleShape2D if is_instance_valid(door_shape) else null
		material.set_shader_parameter("woo_door_leaf", leaf_rect != null)
		if leaf_rect != null:
			# Read the actual synchronized 2D blocker every frame, including its
			# leaf rotation and any local shape transform. Never move that blocker.
			var shape_transform := door_shape.global_transform
			material.set_shader_parameter("woo_leaf_center", shape_transform.origin)
			material.set_shader_parameter("woo_leaf_tangent", shape_transform.x.normalized())
			material.set_shader_parameter("woo_leaf_normal", shape_transform.y.normalized())
			material.set_shader_parameter("woo_leaf_half_size", leaf_rect.size * Vector2(shape_transform.x.length(), shape_transform.y.length()) * 0.5)
		material.set_shader_parameter("woo_enabled", enabled and ray_texture != null)
	last_update_usec = Time.get_ticks_usec() - started


func restore() -> void:
	enabled = false
	for material: ShaderMaterial in _records:
		material.set_shader_parameter("woo_enabled", false)
	for record: Dictionary in _bindings.values():
		var node := record.node.get_ref() as GeometryInstance3D
		if is_instance_valid(node) and _slot_material(node, record.slot) == record.installed:
			_set_slot(node, record.slot, record.original)
	for material: ShaderMaterial in _records:
		var record: Dictionary = _records[material]
		if material == record.source and material.shader == record.installed_shader:
			_replace_shader(material, record.original_shader)
	_records.clear()
	_copies.clear()
	_wall_copies.clear()
	_door_copies.clear()
	_bindings.clear()
	_variants.clear()
	shader_rejections.clear()
	_known_local.clear()
	_shared.clear()
	_protected.clear()
	_excluded_roots.clear()
	_seen.clear()
	managed_count = 0
	binding_count = 0
	world = null
	field = null


func _exit_tree() -> void:
	restore()


func _scan() -> void:
	var started := Time.get_ticks_usec()
	_collect_ownership()
	# A pooled player attachment can acquire a formerly world-only material.
	# Restore that identity first; any non-player binding will get a copy below.
	for material: ShaderMaterial in _records.keys():
		var record: Dictionary = _records[material]
		if material == record.source and (_protected.has(material) or _shared.has(material)):
			if material.shader == record.installed_shader:
				_replace_shader(material, record.original_shader)
			_records.erase(material)
	_seen.clear()
	unsupported_count = 0
	unsupported_names.clear()
	binding_count = 0
	var pending: Array[Node] = [world]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		if not is_instance_valid(node) or node.is_queued_for_deletion() or node in _excluded_roots:
			continue
		for child in node.get_children():
			pending.append(child)
		if not node is MeshInstance3D and not node is Sprite3D \
			and not node is MultiMeshInstance3D and not node is GPUParticles3D:
			continue
		var geometry := node as GeometryInstance3D
		if geometry.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		if geometry.material_override != null:
			_scan_slot(geometry, -1, geometry.material_override)
		elif geometry is MeshInstance3D and geometry.mesh != null:
			for index in geometry.mesh.get_surface_count():
				_scan_slot(geometry, index, geometry.get_active_material(index))
		elif geometry is MultiMeshInstance3D and geometry.multimesh != null \
			and geometry.multimesh.mesh != null and geometry.multimesh.mesh.get_surface_count() == 1:
			# One draw surface can use an instance override without changing the
			# shared MultiMesh/mesh or its INSTANCE_CUSTOM/particle animation.
			_scan_slot(geometry, -1, geometry.multimesh.mesh.surface_get_material(0))
		else:
			_unsupported(geometry, "implicit/draw-pass material without shader override")
		if geometry.material_overlay != null:
			_scan_slot(geometry, -2, geometry.material_overlay)
	# Released/deleted effects must not retain their runtime material forever.
	for material: ShaderMaterial in _records.keys():
		if _seen.has(material):
			continue
		var record: Dictionary = _records[material]
		material.set_shader_parameter("woo_enabled", false)
		if material == record.source and material.shader == record.installed_shader:
			_replace_shader(material, record.original_shader)
		if _copies.get(record.source) == material:
			_copies.erase(record.source)
		if record.has("wall_copy_key"):
			_wall_copies.erase(record.wall_copy_key)
		if record.has("door_copy_key"):
			_door_copies.erase(record.door_copy_key)
		_records.erase(material)
	for key in _bindings.keys():
		var record: Dictionary = _bindings[key]
		var node := record.node.get_ref() as GeometryInstance3D
		if not is_instance_valid(node) or _slot_material(node, record.slot) != record.installed:
			_bindings.erase(key)
	managed_count = _records.size()
	last_scan_usec = Time.get_ticks_usec() - started


func _scan_slot(node: GeometryInstance3D, slot: int, source: Material) -> void:
	if not source is ShaderMaterial or source.shader == null:
		_unsupported(node, "non-shader material")
		return
	var material := source as ShaderMaterial
	var door_context := _door_context(node)
	if not door_context.is_empty() and slot != -2:
		_scan_door_slot(node, slot, material, door_context)
		return
	var wall := _wall_owner(node)
	if wall != null and slot != -2:
		_scan_wall_slot(node, slot, material, wall)
		return
	if _records.has(material):
		var record: Dictionary = _records[material]
		var original := record.source as ShaderMaterial
		if original != material and original.shader != record.source_shader:
			if not _install_shader(material, original, original.shader):
				_unsupported(node, "source replaced copied shader")
				return
		elif material.shader != record.installed_shader:
			# Another owner replaced the shader: treat its latest shader as the
			# new baseline, instead of restoring an obsolete shader on exit.
			if not _install_shader(material, record.source):
				_unsupported(node, "owner replaced shader")
				return
		_seen[material] = true
		binding_count += 1
		if node is MultiMeshInstance3D and node.material_override == null:
			_bind_slot(node, slot, material)
		if material.next_pass != null:
			_unsupported(node, "next_pass is not decorated")
		return
	var installed: ShaderMaterial = _copies.get(material)
	if installed == null:
		installed = material if _can_preserve_identity(material) else material.duplicate() as ShaderMaterial
		if not _install_shader(installed, material):
			_unsupported(node, "unsupported spatial shader: " + material.shader.resource_path)
			return
		if installed != material:
			_copies[material] = installed
	if installed != material:
		_bind_slot(node, slot, installed)
	elif node is MultiMeshInstance3D and node.material_override == null:
		# Even a known local material gets an explicit instance override here;
		# restore() records the original null slot.
		_bind_slot(node, slot, installed)
	_seen[installed] = true
	binding_count += 1
	if installed.next_pass != null:
		_unsupported(node, "next_pass is not decorated")


func _wall_owner(node: GeometryInstance3D) -> Node3D:
	if not node is MeshInstance3D or node.mesh == null:
		return null
	var wall := node.get_parent() as Node3D
	if wall == null:
		return null
	var script := wall.get_script() as Script
	if script == null or script.resource_path != WALL_SCRIPT or wall.get("wall_mesh") != node:
		return null
	return wall


func _door_context(node: GeometryInstance3D) -> Dictionary:
	if not node is MeshInstance3D:
		return {}
	var leaf := node.get_parent() as Node3D
	while leaf != null and leaf != world and not leaf is RigidBody3D:
		leaf = leaf.get_parent() as Node3D
	if leaf == null or not leaf is RigidBody3D:
		return {}
	var door := leaf.get_parent() as Node3D
	if door == null:
		return {}
	var script := door.get_script() as Script
	if script == null or script.resource_path != DOOR_SCRIPT:
		return {}
	var leaves: Array = door.get("_leaves")
	var index := leaves.find(leaf)
	var visuals: Array = door.get("_visuals")
	var handles: Array = door.get("_handle_visuals")
	var shapes: Array = door.get("_collision_shapes")
	if index < 0 or index >= shapes.size() or index >= visuals.size():
		return {}
	var panel := visuals[index] as Node3D
	var is_panel := node == panel or (is_instance_valid(panel) and panel.is_ancestor_of(node))
	var is_handle: bool = index < handles.size() and node == handles[index]
	var is_cap := node.get_parent() == leaf and node.name == &"ArchitecturalCutSurface"
	if not is_panel and not is_handle and not is_cap:
		return {} # Never decorate a frame/jamb as a moving leaf.
	var shape := shapes[index] as CollisionShape2D
	if not is_instance_valid(shape) or not shape.shape is RectangleShape2D:
		return {}
	return {"leaf": leaf, "shape": shape, "panel_owned": is_panel or is_handle}


func _scan_door_slot(node: GeometryInstance3D, slot: int, shown: ShaderMaterial, context: Dictionary) -> void:
	var source := shown
	if _records.has(shown): source = _records[shown].source as ShaderMaterial
	var baseline: Shader = source.shader
	if _records.has(source) and source.shader == _records[source].installed_shader:
		baseline = _records[source].original_shader as Shader
	# PhysicalDoor3D creates a fresh, scene-local material per leaf and updates
	# the active visual's material directly. Keep that identity for door owners.
	var keep_identity := bool(context.panel_owned) and source.resource_local_to_scene \
		and not _shared.has(source) and not _protected.has(source)
	var key := "%s:%s" % [context.leaf.get_instance_id(), source.get_instance_id()]
	var installed := source if keep_identity else _door_copies.get(key) as ShaderMaterial
	if installed == null:
		installed = source.duplicate() as ShaderMaterial
	if not _records.has(installed):
		if not _install_shader(installed, source, baseline):
			_unsupported(node, "unsupported door leaf shader")
			return
	elif installed.shader != _records[installed].installed_shader \
		or (installed != source and source.shader != _records[installed].source_shader):
		if not _install_shader(installed, source, baseline):
			_unsupported(node, "door leaf owner replaced shader")
			return
	var record: Dictionary = _records[installed]
	record.door_shape = weakref(context.shape)
	if installed != source:
		_door_copies[key] = installed
		record.door_copy_key = key
	if installed != shown: _bind_slot(node, slot, installed)
	_seen[installed] = true
	binding_count += 1


func _scan_wall_slot(node: GeometryInstance3D, slot: int, shown: ShaderMaterial, wall: Node3D) -> void:
	var physical_depth := float(wall.get("wall_thickness"))
	var full_mesh := wall.get("office_full_mesh") as Mesh
	var visual_depth := full_mesh.get_aabb().size.z if full_mesh != null else (node as MeshInstance3D).mesh.get_aabb().size.z
	var padding := maxf(physical_depth - visual_depth, 0.0) * 0.5 * wall.global_basis.z.length()
	var source := shown
	if _records.has(shown):
		source = _records[shown].source as ShaderMaterial
	var key := "%s:%s" % [wall.get_instance_id(), source.get_instance_id()]
	var installed := _wall_copies.get(key) as ShaderMaterial
	var baseline: Shader = source.shader
	if _records.has(source) and source.shader == _records[source].installed_shader:
		baseline = _records[source].original_shader as Shader
	if installed == null:
		# The same room material may also be used by floors or props. Bind a
		# private wall variant and mirror the true owner's live uniforms below.
		installed = source.duplicate() as ShaderMaterial
		if not _install_shader(installed, source, baseline):
			_unsupported(node, "unsupported wall shader")
			return
		_wall_copies[key] = installed
	elif installed.shader != _records[installed].installed_shader or source.shader != _records[installed].source_shader:
		if not _install_shader(installed, source, baseline):
			_unsupported(node, "wall owner replaced shader")
			return
	var record: Dictionary = _records[installed]
	record.wall_owner = weakref(wall)
	record.wall_padding = padding
	record.wall_copy_key = key
	if installed != shown:
		_bind_slot(node, slot, installed)
	_seen[installed] = true
	binding_count += 1


func _bind_slot(node: GeometryInstance3D, slot: int, installed: ShaderMaterial) -> void:
	var key := "%s:%s" % [node.get_instance_id(), slot]
	# Preserve null surface overrides and the earliest original if a generic
	# preview variant is replaced with a private wall variant during a rescan.
	var original := _slot_material(node, slot)
	if _bindings.has(key) and original == _bindings[key].installed:
		original = _bindings[key].original as Material
	_bindings[key] = {"node": weakref(node), "slot": slot,
		"original": original, "installed": installed}
	_set_slot(node, slot, installed)


func _install_shader(material: ShaderMaterial, source: ShaderMaterial, baseline: Shader = null) -> bool:
	if baseline == null: baseline = material.shader
	if baseline == null or baseline.code.contains(MARKER):
		return false
	var variant := _variant_for(baseline)
	if variant == null:
		return false
	var names: Array[StringName] = []
	for uniform in source.shader.get_shader_uniform_list():
		if not String(uniform.name).begins_with("woo_"):
			names.append(StringName(uniform.name))
	_records[material] = {"source": source, "original_shader": baseline,
		"installed_shader": variant, "source_shader": source.shader, "uniforms": names}
	_replace_shader(material, variant)
	return true


func _variant_for(shader: Shader) -> Shader:
	if _variants.has(shader):
		return _variants[shader] as Shader
	# Some particle shaders put their actual vertex()/fragment() in an include.
	# Expand only this private runtime string, leaving the authored source and
	# every #define/#if/#endif intact for Godot's normal preprocessor.
	var expanded := _expand_includes(shader.code, shader.resource_path, {}, 0)
	if not bool(expanded.ok):
		shader_rejections[shader.resource_path if not shader.resource_path.is_empty() else str(shader.get_instance_id())] = expanded.reason
		return null
	var code: String = expanded.code
	var skeleton := _skeleton(code)
	var type_regex := RegEx.new()
	type_regex.compile("\\bshader_type\\s+spatial\\s*;")
	var type_match := type_regex.search(skeleton)
	if type_match == null or skeleton.contains("skip_vertex_transform"):
		return null
	# Explicit-position outlines still use their original VERTEX for ground LOS.
	var vertex_tail := VERTEX_TAIL
	if skeleton.contains("world_vertex_coords"):
		vertex_tail = "\nwoo_position = VERTEX;\nwoo_normal = normalize(NORMAL);\n"
	code = code.insert(type_match.get_end(), HEADER)
	code = _append_stage(code, "vertex", vertex_tail, true)
	code = _append_stage(code, "fragment", FRAGMENT_TAIL, true)
	# Do not introduce a custom light() into a default-lit material.
	code = _append_stage(code, "light", LIGHT_TAIL, false)
	if code.is_empty():
		return null
	var variant := Shader.new()
	variant.code = code
	_variants[shader] = variant
	return variant


func _expand_includes(code: String, source_path: String, active: Dictionary, depth: int) -> Dictionary:
	if depth > 32:
		return {"ok": false, "reason": "include depth exceeds 32: " + source_path}
	if not source_path.is_empty() and active.has(source_path):
		return {"ok": false, "reason": "cyclic shader include: " + source_path}
	var next_active := active.duplicate()
	if not source_path.is_empty(): next_active[source_path] = true
	var regex := RegEx.new()
	regex.compile("(?m)^[ \\t]*#[ \\t]*include[ \\t]+\"([^\"\\r\\n]+)\"")
	var matches: Array[RegExMatch] = regex.search_all(code)
	var skeleton := _skeleton(code)
	# Descending insertions keep offsets into the untouched source valid.
	matches.reverse()
	for found: RegExMatch in matches:
		if not skeleton.substr(found.get_start(), found.get_end() - found.get_start()).strip_edges().begins_with("#"):
			continue # An apparent include inside a block comment is not a directive.
		var requested := found.get_string(1)
		var include_path: String
		if requested.begins_with("res://"):
			include_path = requested.simplify_path()
		elif not requested.is_absolute_path() and source_path.begins_with("res://"):
			include_path = source_path.get_base_dir().path_join(requested).simplify_path()
		else:
			return {"ok": false, "reason": "unresolved local shader include: " + requested}
		if not include_path.begins_with("res://") or not FileAccess.file_exists(include_path):
			return {"ok": false, "reason": "missing local shader include: " + include_path}
		var included_text := FileAccess.get_file_as_string(include_path)
		var child := _expand_includes(included_text, include_path, next_active, depth + 1)
		if not bool(child.ok): return child
		var replacement := "\n// begin expanded include: " + include_path + "\n" + String(child.code) \
			+ "\n// end expanded include: " + include_path + "\n"
		code = code.substr(0, found.get_start()) + replacement + code.substr(found.get_end())
	return {"ok": true, "code": code}


func _append_stage(code: String, stage: String, tail: String, create: bool) -> String:
	if code.is_empty():
		return ""
	var skeleton := _skeleton(code)
	var regex := RegEx.new()
	regex.compile("\\bvoid\\s+" + stage + "\\s*\\(\\s*\\)\\s*\\{")
	var matches: Array[RegExMatch] = regex.search_all(skeleton)
	if matches.is_empty():
		return code + "\nvoid " + stage + "() {\n" + tail + "\n}\n" if create else code
	# Includes may contain alternate stage definitions behind #if/#else. Inject
	# each definition without choosing, deleting, or evaluating those macros.
	matches.reverse()
	for found: RegExMatch in matches:
		var cursor := found.get_end()
		var depth := 1
		while cursor < skeleton.length() and depth > 0:
			if skeleton[cursor] == "{": depth += 1
			elif skeleton[cursor] == "}": depth -= 1
			cursor += 1
		if depth != 0:
			return ""
		# A stage return would bypass the tail. Refuse it rather than leaving
		# a silently unmasked path (current source stages all fall through).
		var body := skeleton.substr(found.get_end(), cursor - found.get_end() - 1)
		var return_regex := RegEx.new()
		return_regex.compile("\\breturn\\b")
		if return_regex.search(body) != null:
			return ""
		code = code.insert(cursor - 1, "\n" + tail + "\n")
	return code


## Preserve character offsets while removing comments/strings for brace matching.
func _skeleton(code: String) -> String:
	var output := PackedStringArray()
	var state := 0 # 0 code, 1 line comment, 2 block comment, 3 quoted string
	var index := 0
	while index < code.length():
		var current := code[index]
		var following := code[index + 1] if index + 1 < code.length() else ""
		if state == 0:
			if current == "/" and following == "/":
				state = 1; output.append("  "); index += 2; continue
			if current == "/" and following == "*":
				state = 2; output.append("  "); index += 2; continue
			if current == "\"":
				state = 3; output.append(" ")
			else:
				output.append(current)
		elif state == 1:
			output.append("\n" if current == "\n" else " ")
			if current == "\n": state = 0
		elif state == 2:
			if current == "*" and following == "/":
				state = 0; output.append("  "); index += 2; continue
			output.append("\n" if current == "\n" else " ")
		else:
			if current == "\\" and following != "":
				output.append("  "); index += 2; continue
			output.append(" ")
			if current == "\"": state = 0
		index += 1
	return "".join(output)


func _collect_ownership() -> void:
	_known_local.clear()
	_shared.clear()
	_protected.clear()
	_excluded_roots.clear()
	var player := world.get("player") as Node
	var bridge := world.get("player_depth_bridge") as Node
	if is_instance_valid(player): _excluded_roots.append(player)
	if is_instance_valid(bridge): _excluded_roots.append(bridge)
	for root in _excluded_roots:
		var pending: Array[Node] = [root]
		while not pending.is_empty():
			var node := pending.pop_back() as Node
			for child in node.get_children(): pending.append(child)
			if node is GeometryInstance3D:
				if node.material_override != null: _protected[node.material_override] = true
				if node.material_overlay != null: _protected[node.material_overlay] = true
				if node is MeshInstance3D and node.mesh != null:
					for index in node.mesh.get_surface_count():
						var active: Material = node.get_active_material(index)
						if active != null: _protected[active] = true
	for component in world.get_tree().get_nodes_in_group(&"office_dither_lighting"):
		if component.get_parent() != world: continue
		for material in component.materials.values(): _known_local[material] = true
		for material in component.furniture_dark_materials.values(): _known_local[material] = true
	var reflection := world.get_node_or_null(^"FloorReflections")
	if reflection != null:
		for material in reflection.floor_materials: _known_local[material] = true
		for material in reflection.static_variants.values(): _known_local[material] = true
		for record in reflection.actor_shaders:
			var material: Material = record.material.get_ref()
			if material != null: _known_local[material] = true
	for material in SWATCHES.materials.values(): _shared[material] = true
	for material in SWATCHES.sample_furniture_materials.values(): _shared[material] = true
	if ATLAS_ART._material != null: _shared[ATLAS_ART._material] = true
	for material in ATLAS_ART._surfaces.values(): _shared[material] = true


func _can_preserve_identity(material: ShaderMaterial) -> bool:
	if _shared.has(material) or _protected.has(material):
		return false
	# Registries identify actual owner-local materials, including floor variants
	# whose duplicate may retain an authored resource path.
	if _known_local.has(material):
		return true
	if not material.resource_path.is_empty():
		return false
	return material.resource_local_to_scene \
		or bool(material.get_meta(&"runtime_uniform_owner", false)) \
		or material.has_meta(&"dither_origin")


func _replace_shader(material: ShaderMaterial, shader: Shader) -> void:
	var saved: Dictionary = {}
	if material.shader != null:
		for uniform in material.shader.get_shader_uniform_list():
			var value: Variant = material.get_shader_parameter(uniform.name)
			if value != null: saved[uniform.name] = value
	material.shader = shader
	for uniform in shader.get_shader_uniform_list():
		if saved.has(uniform.name): material.set_shader_parameter(uniform.name, saved[uniform.name])


func _copy_parameters(source: ShaderMaterial, target: ShaderMaterial, names: Array) -> void:
	for name in names:
		target.set_shader_parameter(name, source.get_shader_parameter(name))


func _slot_material(node: GeometryInstance3D, slot: int) -> Material:
	if slot == -1: return node.material_override
	if slot == -2: return node.material_overlay
	if node is MeshInstance3D and node.mesh != null and slot < node.mesh.get_surface_count():
		return node.get_surface_override_material(slot)
	return null


func _set_slot(node: GeometryInstance3D, slot: int, material: Material) -> void:
	if slot == -1: node.material_override = material
	elif slot == -2: node.material_overlay = material
	elif node is MeshInstance3D and node.mesh != null and slot < node.mesh.get_surface_count():
		node.set_surface_override_material(slot, material)


func _unsupported(node: Node, reason: String) -> void:
	if node is Node3D and not node.is_visible_in_tree():
		return
	unsupported_count += 1
	if unsupported_names.size() < 256:
		unsupported_names.append("%s: %s" % [world.get_path_to(node), reason])
