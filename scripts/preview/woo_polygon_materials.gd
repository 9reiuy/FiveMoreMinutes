extends Node
## One shared silhouette texture, bound once. Existing material owners keep
## their identities and live uniforms. No periodic scene scan or per-wall copy.
const MARKER := "woo_polygon_material_variant"
const CAPTURE_SCRIPTS := ["res://scripts/dream/dream_3d_actor_depth_bridge.gd", "res://scripts/dream/blood_airborne_carrier_3d.gd"]
const ENABLED := &"hk_woo_polygon_enabled"
const RECT := &"hk_woo_polygon_rect"
const MAP_X := &"hk_woo_polygon_map_x"
const MAP_Z := &"hk_woo_polygon_map_z"
const INK_PALETTE := &"hk_woo_ink_palette"
const INK_PALETTE_HEADER := "\n#include \"res://shaders/preview/hellkind_sample/ink_points.gdshaderinc\"\nglobal uniform bool hk_woo_ink_palette;\n"
const SPECIAL_UNIT_OWNERS := ["res://scripts/entities/hotel_robot_visual.gd", "res://scripts/entities/exterior_patrol_drone_3d.gd"]
const SPECIAL_UNIT_OUTLINE := preload("res://scripts/dream/units/special_unit_outline.gd")
const ENVIRONMENT_INKS := preload("res://scripts/preview/sample_environment_halftone.gd")
static var globals_registered := false
const HEADER := """
// woo_polygon_material_variant
global uniform bool hk_woo_polygon_enabled;
global uniform vec4 hk_woo_polygon_rect;
global uniform vec4 hk_woo_polygon_map_x;
global uniform vec4 hk_woo_polygon_map_z;
uniform sampler2D woo_polygon_mask : filter_nearest, repeat_disable;
varying vec3 woo_position;
varying float woo_occluded;
float woo_polygon_occlusion(vec3 point) {
    if (!hk_woo_polygon_enabled) { return 0.0; }
    vec4 p = vec4(point, 1.0);
    vec2 map_point = vec2(dot(hk_woo_polygon_map_x, p), dot(hk_woo_polygon_map_z, p)) * 32.0;
    vec2 uv = (map_point - hk_woo_polygon_rect.xy) / hk_woo_polygon_rect.zw;
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) { return 1.0; }
    return 1.0 - step(0.5, texture(woo_polygon_mask, uv).r);
}
"""
const VERTEX_TAIL := "\nwoo_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n"
const FRAGMENT_TAIL := """
woo_occluded = woo_polygon_occlusion(woo_position);
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
const DESKTOP_INK_HEADER := """
uniform int desktop_ink_count = 0;
uniform vec4 desktop_ink_rects[32];
"""
const DESKTOP_INK_TAIL := """
	if (woo_occluded < 0.5) {
		// Leave headroom for the line pass to define the furniture in shadow.
		ALBEDO *= 0.62;
		for (int i = 0; i < desktop_ink_count; i++) {
			vec4 area = desktop_ink_rects[i];
			if (all(greaterThanEqual(UV, area.xy)) && all(lessThan(UV, area.zw))) {
			// Keep a hint of device detail without filling the dark worktop with white.
			EMISSION += min(ALBEDO * 0.10, vec3(0.010));
				break;
			}
		}
	}
"""
const FLOOR_INK_LIGHT := """
	float floor_reference = dot(textureLod(atlas, vec2(0.07, 0.04), 0.0).rgb * 0.5, vec3(0.2126, 0.7152, 0.0722));
	float floor_texel = dot(ALBEDO, vec3(0.2126, 0.7152, 0.0722));
	// Leave the joints to the ink pass and avoid amplifying carpet grain.
	float texture_response = clamp(1.0 + (floor_texel - floor_reference) * 2.0, 0.94, 1.06);
	float light_gain = LIGHT_IS_DIRECTIONAL ? 1.15 : 1.95;
	DIFFUSE_LIGHT = prior_diffuse + DIFFUSE_LIGHT * light_gain * texture_response;
"""
const FLOOR_INK_HEADER := """
uniform vec4 floor_join_layout = vec4(0.0);
"""
const FLOOR_INK_JOINS := """
	vec2 texel = atlas_uv * vec2(textureSize(atlas, 0));
	// Boards span several atlas repeats. Anchor them to the room's map axes.
	if (floor_join_layout.z > 0.0) {
		vec4 world_point = vec4(woo_position, 1.0);
		texel = vec2(dot(hk_woo_polygon_map_x, world_point), dot(hk_woo_polygon_map_z, world_point)) * 32.0;
	}
	// Use the dominant screen axis to avoid doubling diagonal joints.
	vec2 half_pixel = max(abs(dFdx(texel)), abs(dFdy(texel))) * 0.5;
	if (woo_occluded < 0.5 && world_surface == 0) {
		bool seam = false;
		if (floor_join_layout.x > 0.0) {
			vec2 repeat_size = floor_join_layout.xy;
			float row = floor(texel.y / repeat_size.y);
			float stagger = mod(row * floor_join_layout.z, repeat_size.x);
			vec2 joint = texel + vec2(stagger + floor_join_layout.w, 0.0) - 0.5;
			vec2 distance_to_join = abs(mod(joint + repeat_size * 0.5, repeat_size) - repeat_size * 0.5);
			seam = any(lessThanEqual(distance_to_join, half_pixel));
		}
		// Tag the matte floor in the existing normal/roughness buffer. The
		// preview compositor uses these two codes to draw joints in either ink.
		ROUGHNESS = (seam ? 119.0 : 120.0) / 127.0;
	}
"""

var world: Node3D
var field: Node
var enabled := false
var managed_count := 0
var binding_count := 0
var unsupported_count := 0
var unsupported_names: Array[String] = []
var shader_rejections: Dictionary = {}
var last_update_usec := 0
var last_scan_usec := 0
var full_scans := 0
var parameter_writes := 0
var _records: Dictionary = {}
var _variants: Dictionary = {}
var _code_variants: Dictionary = {}
var _ink_variants: Dictionary = {}
var _ink_glass_variants: Dictionary = {}
var _ink_unit_variants: Dictionary = {}
var _unit_flash_materials: Dictionary = {}
var _unit_flash_parts: Dictionary = {}
var _desktop_ink_regions: Dictionary = {}
var _ink_environment := false
var _material_users: Dictionary = {}
var _unused_materials: Dictionary = {}
var _copies: Dictionary = {}
var _protected: Dictionary = {}
var _geometry: Dictionary = {}
var _pending: Dictionary = {}
var _bindings: Dictionary = {}
var _protection_dirty := false
var _pending_protected: Dictionary = {}
var _dirty_geometry: Dictionary = {}
var _wall_owners: Dictionary = {}
var _last_room := -999
var _last_transform := Transform3D()
var _actor_root: Node
var preparing := false

func configure(owner_world: Node3D, visibility_field: Node) -> void:
	restore()
	world = owner_world
	field = visibility_field
	_actor_root = world.get_node_or_null(^"ActorDepthBridges")
	if not globals_registered:
		for item in [[ENABLED, RenderingServer.GLOBAL_VAR_TYPE_BOOL, false], [RECT, RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4()], [MAP_X, RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4()], [MAP_Z, RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4()]]:
			RenderingServer.global_shader_parameter_add(item[0], item[1], item[2])
		RenderingServer.global_shader_parameter_add(INK_PALETTE, RenderingServer.GLOBAL_VAR_TYPE_BOOL, false)
		globals_registered = true
	RenderingServer.global_shader_parameter_set(RECT, Vector4(field.mask_rect.position.x, field.mask_rect.position.y, field.mask_rect.size.x, field.mask_rect.size.y))
	_publish_transform(true)
	_collect_protected()
	_collect_desktop_ink_regions()
	var started := Time.get_ticks_usec()
	var pending: Array[Node] = [world]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		for child in node.get_children(): pending.append(child)
		if node is GeometryInstance3D: _track(node)
	last_scan_usec = Time.get_ticks_usec() - started
	full_scans += 1
	world.get_tree().node_added.connect(_node_added)
	enabled = true
	update_now()
	RenderingServer.global_shader_parameter_set(ENABLED, true)

func _collect_desktop_ink_regions() -> void:
	var art: Node = world.office_art_root.get_node_or_null(^"ApprovedOfficeArt")
	if art == null: return
	for record in art.furniture.records:
		if record.kind != "workstation": continue
		var mesh: MeshInstance3D = record.node.get_ref()
		if not is_instance_valid(mesh): continue
		var rects := PackedVector4Array()
		var size := Vector2(record.result.image.get_size())
		for face in record.result.faces:
			var tile: String = face.tile
			var tabletop: bool = tile == "dark" and face.normal.y > 0.5 and face.points[0].y > 0.74
			if not tile.begins_with("screen_") and tile not in ["document", "paper", "tray", "coffee"] and not tabletop: continue
			var start := Vector2(face.rect.position) / size
			var end := Vector2(face.rect.end) / size
			rects.append(Vector4(start.x, start.y, end.x, end.y))
			if rects.size() == 32: break
		_desktop_ink_regions[mesh.material_override] = rects

func _node_added(node: Node) -> void:
	if not is_instance_valid(world) or not node is GeometryInstance3D: return
	if not preparing and not world.is_ancestor_of(node): return
	_pending[node.get_instance_id()] = weakref(node)
	if _is_player(node): _pending_protected[node.get_instance_id()] = weakref(node)

func _is_player(node: Node) -> bool:
	# Woo's object LOS owns complete sprites; do not shade each character or
	# transient sprite again as an architectural receiving surface.
	if node == world.player_depth_bridge or world.player_depth_bridge.is_ancestor_of(node) or node == world.player or world.player.is_ancestor_of(node): return true
	if preparing:
		var ancestor := node.get_parent()
		while ancestor != null:
			var preparation_script := ancestor.get_script() as Script
			if preparation_script != null and preparation_script.resource_path in CAPTURE_SCRIPTS: return true
			ancestor = ancestor.get_parent()
	if not is_instance_valid(_actor_root) or not _actor_root.is_ancestor_of(node): return false
	var cursor := node
	while cursor != null and cursor.get_parent() != _actor_root: cursor = cursor.get_parent()
	var script := cursor.get_script() as Script if cursor != null else null
	return script != null and script.resource_path in CAPTURE_SCRIPTS

func _collect_protected() -> void:
	_protection_dirty = false
	_protected.clear()
	var roots: Array[Node] = [world.player_depth_bridge, world.player]
	if is_instance_valid(_actor_root):
		for child in _actor_root.get_children():
			var script := child.get_script() as Script
			if script != null and script.resource_path in CAPTURE_SCRIPTS: roots.append(child)
	for root in roots:
		if not is_instance_valid(root): continue
		for node in root.find_children("*", "GeometryInstance3D", true, false):
			if node.material_override != null: _protected[node.material_override] = true
			if node.material_overlay != null: _protected[node.material_overlay] = true
			if node is MeshInstance3D and node.mesh != null:
				for index in node.mesh.get_surface_count():
					var material: Material = node.get_active_material(index)
					if material != null: _protected[material] = true
	var rebind_needed := false
	for material: ShaderMaterial in _records.keys():
		var record: Dictionary = _records[material]
		if material == record.source and _protected.has(material):
			_unpatch(material, record)
			_records.erase(material)
			rebind_needed = true
	if rebind_needed:
		for entry: Dictionary in _geometry.values(): entry.initialized = false

func _track(node: GeometryInstance3D) -> void:
	if _is_player(node) or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: return
	if not node is MeshInstance3D and not node is MultiMeshInstance3D and not node is GPUParticles3D and not node is Sprite3D: return
	var id := node.get_instance_id()
	if _geometry.has(id): return
	var entry := {"node": weakref(node), "override": null, "overlay": null, "surfaces": [], "initialized": false}
	_geometry[id] = entry
	_dirty_geometry[id] = true
	node.tree_exiting.connect(_geometry_exiting.bind(id), CONNECT_ONE_SHOT)
	node.visibility_changed.connect(_geometry_visibility.bind(id))
	var cursor: Node = node
	while cursor != null and cursor != world:
		var script := cursor.get_script() as Script
		if script != null and script.resource_path in SPECIAL_UNIT_OWNERS:
			entry["special_unit"] = true
			_track_unit_flash(cursor.get("hit_flash"))
			break
		if script != null and script.resource_path == "res://scripts/dream/wall_segment_3d.gd":
			var owner_id := cursor.get_instance_id()
			if not _wall_owners.has(owner_id):
				_wall_owners[owner_id] = {"node": weakref(cursor), "cutaway": cursor.cutaway_mode, "geometry": []}
			_wall_owners[owner_id].geometry.append(id)
			break
		cursor = cursor.get_parent()

func _geometry_exiting(id: int) -> void:
	if _geometry.has(id):
		for material in _geometry[id].get("materials", {}): _remove_user(material)
		for key in _geometry[id].get("bindings", []): _bindings.erase(key)
	_geometry.erase(id)
	_dirty_geometry.erase(id)
	_unit_flash_parts.erase(id)

func _track_unit_flash(flash: Node) -> void:
	if not is_instance_valid(flash): return
	var white: ShaderMaterial = flash.white
	if white == null or _unit_flash_materials.has(white): return
	_unit_flash_materials[white] = true
	if not _patch(white, white, white.shader, true):
		_unit_flash_materials.erase(white)
		return
	for part: Dictionary in flash.parts:
		var mesh: MeshInstance3D = part.mesh.get_ref()
		if is_instance_valid(mesh):
			_unit_flash_parts[mesh.get_instance_id()] = {"part": part, "white": white}
	flash.tree_exiting.connect(func():
		_unit_flash_materials.erase(white)
		_unused_materials[white] = true, CONNECT_ONE_SHOT)

func _geometry_visibility(id: int) -> void:
	_dirty_geometry[id] = true

func _protect_added(node: GeometryInstance3D) -> void:
	var materials: Array[Material] = []
	if node.material_override != null: materials.append(node.material_override)
	if node.material_overlay != null: materials.append(node.material_overlay)
	if node is MeshInstance3D and node.mesh != null:
		for index in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(index)
			if material != null: materials.append(material)
	for material in materials:
		_protected[material] = true
		if _records.has(material) and _records[material].source == material:
			_unpatch(material, _records[material])
			_records.erase(material)
			for id in _geometry:
				_geometry[id].initialized = false
				_dirty_geometry[id] = true

func notify_geometry_dirty() -> void:
	for id in _geometry:
		_geometry[id].initialized = false
		_dirty_geometry[id] = true

func update_now() -> void:
	var started := Time.get_ticks_usec()
	if not is_instance_valid(world) or not is_instance_valid(field): return
	parameter_writes = 0
	for material: ShaderMaterial in _unused_materials:
		if _material_users.get(material, 0) == 0 and _records.has(material) and not _unit_flash_materials.has(material):
			var source: ShaderMaterial = _records[material].source
			_unpatch(material, _records[material])
			_records.erase(material)
			if material != source: _copies.erase(source)
	_unused_materials.clear()
	if _protection_dirty: _collect_protected()
	for reference: WeakRef in _pending_protected.values():
		var node := reference.get_ref() as GeometryInstance3D
		if is_instance_valid(node): _protect_added(node)
	_pending_protected.clear()
	for reference: WeakRef in _pending.values():
		var node := reference.get_ref() as GeometryInstance3D
		if is_instance_valid(node): _track(node)
	_pending.clear()
	_publish_transform(false)
	# Poll only slots with a native owner that can rebind them continuously.
	# Other slots are checked on creation, visibility/room changes, not each frame.
	var room := int(world.get("current_room_id"))
	if room != _last_room:
		_last_room = room
		notify_geometry_dirty()
	# A wall rebinds its mesh/materials only when its cutaway state changes.
	# Door/furniture materials are installed at creation and keep their identity.
	for owner_id in _wall_owners.keys():
		var owner_record: Dictionary = _wall_owners[owner_id]
		var owner_node: Node = owner_record.node.get_ref()
		if not is_instance_valid(owner_node):
			_wall_owners.erase(owner_id)
			continue
		if owner_record.cutaway != owner_node.cutaway_mode:
			owner_record.cutaway = owner_node.cutaway_mode
			for id in owner_record.geometry:
				if _geometry.has(id):
					_geometry[id].initialized = false
					_dirty_geometry[id] = true
	var dirty := _dirty_geometry.keys()
	_dirty_geometry.clear()
	for id in dirty:
		if not _geometry.has(id): continue
		var entry: Dictionary = _geometry[id]
		var node := entry.node.get_ref() as GeometryInstance3D
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			_geometry.erase(id)
			continue
		var override: Material = node.material_override
		if override != entry.override or not entry.initialized:
			entry.override = _install_slot(node, -1, override)
		if node.material_override == null:
			if node is MeshInstance3D and node.mesh != null:
				var surfaces: Array = entry.surfaces
				for index in node.mesh.get_surface_count():
					var current: Material = node.get_active_material(index)
					if index >= surfaces.size(): surfaces.append(null)
					if current != surfaces[index] or not entry.initialized:
						surfaces[index] = _install_slot(node, index, current)
			elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
				if node.multimesh.mesh.get_surface_count() == 1:
					entry.override = _install_slot(node, -1, node.multimesh.mesh.surface_get_material(0))
		var overlay: Material = node.material_overlay
		if overlay != entry.overlay or not entry.initialized:
			entry.overlay = _install_slot(node, -2, overlay)
		entry.initialized = true
		var used: Dictionary = {}
		if entry.override != null: used[entry.override] = true
		else:
			for material in entry.surfaces:
				if material != null: used[material] = true
		if entry.overlay != null: used[entry.overlay] = true
		var previous: Dictionary = entry.get("materials", {})
		for material in previous:
			if not used.has(material): _remove_user(material)
		for material in used:
			if not previous.has(material): _material_users[material] = int(_material_users.get(material, 0)) + 1
		entry.materials = used
	for material: ShaderMaterial in _records:
		var record: Dictionary = _records[material]
		var source := record.source as ShaderMaterial
		if material.shader != record.installed:
			_patch(material, source, material.shader, record.special_unit)
			record = _records[material]
		elif source != material and source.shader != record.source_shader:
			_patch(material, source, source.shader, record.special_unit)
			record = _records[material]
		if source != material:
			# Rare player-shared resources get one world copy; other live material
			# owners update their original instance directly, without mirroring.
			for uniform in record.uniforms:
				var value: Variant = source.get_shader_parameter(uniform)
				if not record.values.has(uniform) or record.values[uniform] != value:
					material.set_shader_parameter(uniform, value)
					record.values[uniform] = value
					parameter_writes += 1
	managed_count = _records.size()
	binding_count = _geometry.size()
	last_update_usec = Time.get_ticks_usec() - started

func _remove_user(material: Material) -> void:
	var users := int(_material_users.get(material, 0)) - 1
	if users <= 0:
		_material_users.erase(material)
		if material is ShaderMaterial: _unused_materials[material] = true
	else: _material_users[material] = users

func _publish_transform(force: bool) -> void:
	var transform := world.global_transform.affine_inverse()
	if not force and transform == _last_transform: return
	_last_transform = transform
	RenderingServer.global_shader_parameter_set(MAP_X, Vector4(transform.basis.x.x, transform.basis.y.x, transform.basis.z.x, transform.origin.x))
	RenderingServer.global_shader_parameter_set(MAP_Z, Vector4(transform.basis.x.z, transform.basis.y.z, transform.basis.z.z, transform.origin.z))

func _install_slot(node: GeometryInstance3D, slot: int, material: Material) -> Material:
	if not material is ShaderMaterial or material.shader == null: return material
	var special_unit: bool = _geometry[node.get_instance_id()].get("special_unit", false)
	if _records.has(material) and material.shader == _records[material].installed:
		if special_unit and slot == -1: _bind_unit_override(node, material)
		return material
	var target := material as ShaderMaterial
	if _protected.has(material):
		target = _copies.get(material) as ShaderMaterial
		if target == null:
			target = material.duplicate() as ShaderMaterial
			_copies[material] = target
	if not _patch(target, material, material.shader, special_unit): return material
	if target != material or (node is MultiMeshInstance3D and node.material_override == null):
		var key := "%d:%d" % [node.get_instance_id(), slot]
		if not _bindings.has(key):
			_bindings[key] = {"node": weakref(node), "slot": slot, "original": _assignment(node, slot), "installed": target}
			var entry: Dictionary = _geometry[node.get_instance_id()]
			if not entry.has("bindings"): entry.bindings = []
			entry.bindings.append(key)
		_assign(node, slot, target)
	if special_unit and slot == -1: _bind_unit_override(node, target)
	return target

func _bind_unit_override(node: GeometryInstance3D, material: ShaderMaterial) -> void:
	# The preview lighting setup can copy overrides. Native hit flash must
	# restore the live body, and the outline must update the material drawn.
	var outline := node.get_parent()
	if outline.get_script() == SPECIAL_UNIT_OUTLINE and outline.border == node:
		outline.material = material
	var flash: Dictionary = _unit_flash_parts.get(node.get_instance_id(), {})
	if not flash.is_empty() and material != flash.white: flash.part.rest = material

func _patch(material: ShaderMaterial, source: ShaderMaterial, shader: Shader, special_unit: bool) -> bool:
	if shader == null or shader.code.contains(MARKER): return false
	var variant := _variant_for(shader)
	if variant == null: return false
	if _ink_environment: variant = _select_ink_variant(variant, material, special_unit)
	var uniforms: Array[StringName] = []
	if source != material:
		for uniform in source.shader.get_shader_uniform_list():
			if not String(uniform.name).begins_with("woo_") and not String(uniform.name).begins_with("hk_woo_"): uniforms.append(StringName(uniform.name))
	_records[material] = {"source": source, "original": shader, "installed": variant, "source_shader": source.shader, "uniforms": uniforms, "values": {}, "special_unit": special_unit}
	_replace_shader(material, variant)
	material.set_shader_parameter("woo_polygon_mask", field.texture)
	_bind_ink_parameters(material, source)
	parameter_writes += 1
	return true

func _variant_for(shader: Shader) -> Shader:
	var shader_id := shader.get_instance_id()
	if _variants.has(shader_id): return _variants[shader_id] as Shader
	var expanded := _expand_includes(shader.code, shader.resource_path, {}, 0)
	if not bool(expanded.ok):
		shader_rejections[shader.resource_path] = expanded.reason
		return null
	var code: String = expanded.code
	var source_key := code.sha256_text()
	if _code_variants.has(source_key):
		_variants[shader_id] = _code_variants[source_key]
		return _code_variants[source_key]
	var skeleton := _skeleton(code)
	var regex := RegEx.new()
	regex.compile("\\bshader_type\\s+spatial\\s*;")
	var found := regex.search(skeleton)
	if found == null or skeleton.contains("skip_vertex_transform"): return null
	var tail := "\nwoo_position = VERTEX;\n" if skeleton.contains("world_vertex_coords") else VERTEX_TAIL
	code = code.insert(found.get_end(), HEADER)
	code = _append_stage(code, "vertex", tail, true)
	code = _append_stage(code, "fragment", FRAGMENT_TAIL, true)
	code = _append_stage(code, "light", LIGHT_TAIL, false)
	if code.is_empty(): return null
	var result := Shader.new()
	result.code = code
	_variants[shader_id] = result
	_code_variants[source_key] = result
	return result

func _select_ink_variant(variant: Shader, material: ShaderMaterial, special_unit: bool) -> Shader:
	if special_unit:
		return _unit_ink_variant(variant, _unit_flash_materials.has(material))
	return _ink_variant(variant, material)

func _unit_ink_variant(shader: Shader, hit_flash: bool) -> Shader:
	var key := [shader, hit_flash]
	if _ink_unit_variants.has(key): return _ink_unit_variants[key]
	var code := shader.code
	var tail: String
	# Forward+ packs the marks into the existing normal/roughness buffer.
	# Hidden fragments keep the native visibility pass's zero light and no mark.
	# The native builders can copy shaders before the sample sees them.
	# Match their uniforms here, after verifying the owning unit at registration.
	if hit_flash:
		tail = "if (woo_occluded < 0.5) { ROUGHNESS = 115.0 / 127.0; }"
	elif code.contains("uniform float paint_amount") and code.contains("uniform bool glow"):
		# Broad painted faces are shaded by scene light rather than by the swatch.
		code = code.replace("texture(pixel_texture, uv).rgb", "vec3(1.0)")
		tail = """
			if (woo_occluded < 0.5) {
				float tag = 121.0;
				if (glow) { tag = base_color.r > base_color.b ? 117.0 : 116.0; }
				else if (paint_amount > 0.5) { tag = 118.0; }
				ROUGHNESS = tag / 127.0;
			}
		"""
	elif code.contains("uniform sampler2D panel_texture"):
		# Invert the authored cabinet seams onto a dark panel. Their contrast
		# is still lit and shadowed by the scene, just like the rest of the shell.
		tail = """
			if (woo_occluded < 0.5) {
				vec2 delta = 2.0 / vec2(textureSize(panel_texture, 0));
				float line = min(ALBEDO.g, texture(panel_texture, panel_uv + vec2(delta.x, 0.0)).g);
				line = min(line, texture(panel_texture, panel_uv - vec2(delta.x, 0.0)).g);
				line = min(line, texture(panel_texture, panel_uv + vec2(0.0, delta.y)).g);
				line = min(line, texture(panel_texture, panel_uv - vec2(0.0, delta.y)).g);
				ALBEDO = vec3(line < 0.12 ? 0.72 : 0.10);
				ROUGHNESS = 121.0 / 127.0;
			}
		"""
	elif code.contains("uniform sampler2D screen_texture"):
		# Read the center of each authored LCD dot. At game scale the tiny
		# texture gaps would fragment the eyes and mouth as the camera moves.
		code = code.replace("void fragment() {", """
			vec3 lcd_sample(vec2 cell, ivec2 grid) {
				ivec2 at = clamp(ivec2(floor(cell)), ivec2(0), grid - ivec2(1));
				return texelFetch(screen_texture, at * 5 + ivec2(2), 0).rgb;
			}
			void fragment() {""")
		code = code.replace("vec3 colour = texture(screen_texture, uv).rgb", """
			ivec2 lcd_grid = (textureSize(screen_texture, 0) + ivec2(1)) / 5;
			vec2 cell = uv * vec2(lcd_grid);
			vec2 pad = min(fwidth(cell) * 0.33, vec2(0.85));
			vec3 glyph = lcd_sample(cell, lcd_grid);
			glyph = max(glyph, lcd_sample(cell + vec2(pad.x, 0.0), lcd_grid));
			glyph = max(glyph, lcd_sample(cell - vec2(pad.x, 0.0), lcd_grid));
			glyph = max(glyph, lcd_sample(cell + vec2(0.0, pad.y), lcd_grid));
			glyph = max(glyph, lcd_sample(cell - vec2(0.0, pad.y), lcd_grid));
			vec3 colour = glyph""")
		tail = "if (woo_occluded < 0.5) { ROUGHNESS = 122.0 / 127.0; }"
	elif code.contains("uniform sampler2D silhouette") and code.contains("uniform vec4 rim_color"):
		code = code.replace("shader_type spatial;", "shader_type spatial;" + INK_PALETTE_HEADER + "uniform vec3 unit_rim_ink;\n")
		tail = """
			if (woo_occluded > 0.5) { discard; }
			if (rim_color.r < 0.8) {
				ALBEDO = hk_woo_ink_palette ? ink_output(unit_rim_ink) : vec3(1.0);
				EMISSION = vec3(0.0);
			}
		"""
	else:
		_ink_unit_variants[key] = shader
		return shader
	var result := Shader.new()
	result.code = _append_stage(code, "fragment", tail, false)
	_ink_unit_variants[key] = result
	return result

func _ink_variant(shader: Shader, material: ShaderMaterial) -> Shader:
	# Glazing keeps its own transparent pass. Solid geometry uses ordered
	# coverage for reveal holes and continues writing depth for occlusion.
	if material.get_shader_parameter("metal_glass") == true or shader.code.contains("uniform sampler2D glass_pixels"):
		return _ink_glass_variant(shader)
	if _ink_variants.has(shader): return _ink_variants[shader]
	var code := shader.code
	if code.contains("uniform sampler2D city_void") and code.contains("uniform bool own_facade"):
		# Static facade walls are scenery. Their existing depth and footprint
		# tests still apply, but their ink must not flicker with the player's
		# moving eye position or disappear past the indoor sight range.
		var exterior := Shader.new()
		exterior.code = code.replace(FRAGMENT_TAIL, """
			if (!neon_surface && abs(face_normal.y) < 0.5) {
				woo_occluded = 0.0;
				ROUGHNESS = (own_facade ? 124.0 : 125.0) / 127.0;
			} else {
		""" + FRAGMENT_TAIL + """
				if (woo_occluded < 0.5) { ROUGHNESS = 123.0 / 127.0; }
			}
		""")
		_ink_variants[shader] = exterior
		return exterior
	if code.contains("uniform float outline_pixels") and code.contains("uniform bool occlusion_cutout_enabled"):
		# The camera compositor now traces furniture geometry in both inks.
		var hidden_outline := Shader.new()
		hidden_outline.code = code.replace("void fragment() {", "void fragment() {\n\tdiscard;")
		_ink_variants[shader] = hidden_outline
		return hidden_outline
	if code.contains("uniform float shadow_opacity"):
		var shadow := Shader.new()
		code = code.replace("shader_type spatial;", "shader_type spatial;" + INK_PALETTE_HEADER)
		shadow.code = _append_stage(code, "fragment", """
			if (ALPHA <= shadow_opacity * 0.60) { discard; }
			ALBEDO = hk_woo_ink_palette && woo_occluded < 0.5 ? ink_output(vec3(25.0, 29.0, 46.0) / 255.0) : vec3(0.0);
			ALPHA = 1.0;
		""", false)
		_ink_variants[shader] = shadow
		return shadow
	if code.contains("float floor_shoulder"):
		code = code.replace("void light() {", "void light() {\nvec3 prior_diffuse = DIFFUSE_LIGHT;\nDIFFUSE_LIGHT = vec3(0.0);\n")
		code = code.replace("shader_type spatial;", "shader_type spatial;\n" + FLOOR_INK_HEADER)
		code = _append_stage(code, "fragment", FLOOR_INK_JOINS, false)
		var floor_shader := Shader.new()
		floor_shader.code = _append_stage(code, "light", FLOOR_INK_LIGHT, false)
		_ink_variants[shader] = floor_shader
		return floor_shader
	if not _skeleton(code).contains("ALPHA = occlusion_cut;"):
		_ink_variants[shader] = shader
		return shader
	code = code.replace("ALPHA = occlusion_cut;", """
	float ink_pixel_scale = max(1.0, VIEWPORT_SIZE.y / 360.0);
	if (occlusion_cut < ink_threshold(FRAGCOORD.xy / ink_pixel_scale)) { discard; }
	""")
	code = code.replace("ALPHA*=.32;", "")
	if _skeleton(code).contains("ALPHA"):
		_ink_variants[shader] = shader
		return shader
	code = code.replace("shader_type spatial;", "shader_type spatial;\n#include \"res://shaders/preview/hellkind_sample/ink_points.gdshaderinc\"")
	code = code.replace("depth_draw_never", "depth_draw_opaque")
	if code.contains("uniform vec3 review_door_size"):
		code = _append_stage(code, "fragment", "\nALBEDO *= 1.4;\n", false)
	if code.contains("uniform vec4 standby_screen_rect"):
		code = code.replace("shader_type spatial;", "shader_type spatial;\n" + DESKTOP_INK_HEADER)
		code = _append_stage(code, "fragment", DESKTOP_INK_TAIL, false)
	var result := Shader.new()
	result.code = code
	_ink_variants[shader] = result
	return result

func _bind_ink_parameters(material: ShaderMaterial, source: ShaderMaterial) -> void:
	if not _ink_environment: return
	if material.shader.code.contains("uniform vec3 unit_rim_ink"):
		material.set_shader_parameter("unit_rim_ink", ENVIRONMENT_INKS.ROOM_LIGHT_RGB / 255.0)
	if material.shader.code.contains("floor_join_layout"):
		var style := String(source.get_meta(&"floor_surface_style", ""))
		var layout := Vector4(32.0, 32.0, 0.0, 0.0)
		match style:
			"": layout = Vector4.ZERO # Standalone rugs share the floor lighting shader.
			"office": layout = Vector4(176.0, 16.0, 61.0, 0.0)
			"conference", "manager", "lounge":
				var variant := posmod((str(world.active_seed) + style).hash(), 3)
				layout = Vector4(160.0, 12.0, 59.0, variant * 8.0)
			"reception", "corridor": layout = Vector4(64.0, 64.0, 0.0, 0.0)
			"restroom": layout = Vector4(16.0, 16.0, 0.0, 0.0)
			"server": layout = Vector4(32.0, 16.0, 0.0, 0.0)
		material.set_shader_parameter("floor_join_layout", layout)
		return
	if not _desktop_ink_regions.has(source) or not material.shader.code.contains("desktop_ink_count"): return
	var rects: PackedVector4Array = _desktop_ink_regions[source].duplicate()
	material.set_shader_parameter("desktop_ink_count", rects.size())
	rects.resize(32)
	material.set_shader_parameter("desktop_ink_rects", rects)

func _ink_glass_variant(shader: Shader) -> Shader:
	if _ink_glass_variants.has(shader): return _ink_glass_variants[shader]
	var code := shader.code.replace("shader_type spatial;", "shader_type spatial;" + INK_PALETTE_HEADER)
	code = code.replace("render_mode ", "render_mode unshaded, ")
	var pane_coverage := "ALPHA * 0.22" if code.contains("uniform bool metal_glass") else "ALPHA > 0.10 ? ALPHA : 0.0"
	code = _append_stage(code, "fragment", """
		float glass_scale = max(1.0, VIEWPORT_SIZE.y / 360.0);
		if ((%s) < ink_threshold(FRAGCOORD.xy / glass_scale)) { discard; }
		vec3 light_ink = hk_woo_ink_palette ? ink_output(vec3(255.0, 225.0, 232.0) / 255.0) : vec3(1.0);
		ALBEDO = woo_occluded < 0.5 ? light_ink : vec3(0.0);
		ALPHA = 1.0;
	""" % pane_coverage, false)
	var result := Shader.new()
	result.code = code
	_ink_glass_variants[shader] = result
	return result

func set_ink_environment(value: bool) -> void:
	if _ink_environment == value: return
	_ink_environment = value
	for material: ShaderMaterial in _records:
		var record: Dictionary = _records[material]
		if material.shader != record.installed: continue
		var variant := _variant_for(record.original)
		if value: variant = _select_ink_variant(variant, material, record.special_unit)
		if variant == record.installed: continue
		record.installed = variant
		_replace_shader(material, variant)
		material.set_shader_parameter("woo_polygon_mask", field.texture)
		_bind_ink_parameters(material, record.source)

func set_enabled(value: bool) -> void:
	enabled = value
	RenderingServer.global_shader_parameter_set(ENABLED, enabled)

func set_ink_palette(value: bool) -> void:
	RenderingServer.global_shader_parameter_set(INK_PALETTE, value)

func prune_unused() -> void:
	# Loading preparation uses temporary native render carriers. Retain their
	# compiled variants, but not dead instances/materials in the live update set.
	var used: Dictionary = {}
	for entry: Dictionary in _geometry.values():
		var node := entry.node.get_ref() as GeometryInstance3D
		if not is_instance_valid(node) or node.is_queued_for_deletion(): continue
		if node.material_override != null: used[node.material_override] = true
		if node.material_overlay != null: used[node.material_overlay] = true
		if node is MeshInstance3D and node.mesh != null:
			for index in node.mesh.get_surface_count(): used[node.get_active_material(index)] = true
	for material: ShaderMaterial in _records.keys():
		if used.has(material) or _unit_flash_materials.has(material): continue
		_unpatch(material, _records[material])
		_records.erase(material)
	managed_count = _records.size()

func _unpatch(material: ShaderMaterial, record: Dictionary) -> void:
	material.set_shader_parameter("woo_polygon_mask", null)
	if material.shader == record.installed: _replace_shader(material, record.original)

func restore() -> void:
	if is_instance_valid(world):
		if world.get_tree() != null and world.get_tree().node_added.is_connected(_node_added): world.get_tree().node_added.disconnect(_node_added)
		RenderingServer.global_shader_parameter_set(ENABLED, false)
		set_ink_palette(false)
	for binding: Dictionary in _bindings.values():
		var node := binding.node.get_ref() as GeometryInstance3D
		if is_instance_valid(node) and _assignment(node, binding.slot) == binding.installed: _assign(node, binding.slot, binding.original)
	for material: ShaderMaterial in _records: _unpatch(material, _records[material])
	_records.clear()
	_variants.clear()
	_code_variants.clear()
	_ink_variants.clear()
	_ink_glass_variants.clear()
	_ink_unit_variants.clear()
	_unit_flash_materials.clear()
	_unit_flash_parts.clear()
	_desktop_ink_regions.clear()
	_ink_environment = false
	_material_users.clear()
	_unused_materials.clear()
	_copies.clear()
	_protected.clear()
	_geometry.clear()
	_pending.clear()
	_pending_protected.clear()
	_dirty_geometry.clear()
	_wall_owners.clear()
	_bindings.clear()
	world = null
	field = null
	_actor_root = null
	enabled = false
	managed_count = 0
	binding_count = 0

func _replace_shader(material: ShaderMaterial, shader: Shader) -> void:
	var saved: Dictionary = {}
	if material.shader != null:
		for uniform in material.shader.get_shader_uniform_list():
			if String(uniform.name).begins_with("woo_") or String(uniform.name).begins_with("hk_woo_"): continue
			var value: Variant = material.get_shader_parameter(uniform.name)
			if value != null: saved[uniform.name] = value
	material.shader = shader
	for uniform in shader.get_shader_uniform_list():
		if saved.has(uniform.name): material.set_shader_parameter(uniform.name, saved[uniform.name])

func _assignment(node: GeometryInstance3D, slot: int) -> Material:
	if slot == -1: return node.material_override
	if slot == -2: return node.material_overlay
	return (node as MeshInstance3D).get_surface_override_material(slot)

func _assign(node: GeometryInstance3D, slot: int, material: Material) -> void:
	if slot == -1: node.material_override = material
	elif slot == -2: node.material_overlay = material
	else: (node as MeshInstance3D).set_surface_override_material(slot, material)

func _exit_tree() -> void:
	restore()

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




