extends RefCounted
## Preview-only depth classification. No source nodes, materials or gameplay are mutated.

var _source: Node3D
var _viewport: SubViewport
var _root: Node3D
var _camera: Camera3D
var _records: Dictionary = {}
var _shaders: Dictionary = {}
var _materials: Dictionary = {}
var _bindings: Array[Dictionary] = []
var _fallback_shader: Shader

func configure(source_world: Node3D, viewport: SubViewport) -> void:
	dispose()
	_source = source_world
	_viewport = viewport
	viewport.world_3d = World3D.new()
	viewport.transparent_bg = false
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	_root = Node3D.new()
	_root.name = "VisibilityOnlyProxies"
	viewport.add_child(_root)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	viewport.world_3d.environment = environment
	_camera = Camera3D.new()
	_root.add_child(_camera)
	_camera.current = true
	_fallback_shader = Shader.new()
	_fallback_shader.code = "shader_type spatial; render_mode unshaded,cull_disabled; uniform sampler2D mask_texture : filter_nearest; uniform bool has_texture = false; uniform float mask_value = 0.0; uniform vec3 mask_uv_scale = vec3(1.0); uniform vec3 mask_uv_offset = vec3(0.0); void fragment(){ if(has_texture && texture(mask_texture, UV * mask_uv_scale.xy + mask_uv_offset.xy).a < 0.05){discard;} ALBEDO=vec3(mask_value); }"
	refresh_sources()

func refresh_sources() -> void:
	if not is_instance_valid(_source):
		return
	var pending: Array[Node] = [_source]
	var seen: Dictionary = {}
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is SubViewport:
			continue
		for child in node.get_children():
			pending.append(child)
		if not (node is MeshInstance3D or node is Sprite3D or node is MultiMeshInstance3D):
			continue
		if node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var id := node.get_instance_id()
		seen[id] = true
		if _records.has(id):
			continue
		var proxy: GeometryInstance3D
		if node is MeshInstance3D:
			proxy = MeshInstance3D.new()
		elif node is MultiMeshInstance3D:
			proxy = MultiMeshInstance3D.new()
		else:
			proxy = Sprite3D.new()
		proxy.name = "Mask_" + str(node.name)
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(proxy)
		_records[id] = {"source": weakref(node), "proxy": proxy, "white": _is_character_surface(node)}
	var removed := false
	for id in _records.keys():
		if not seen.has(id):
			_records[id].proxy.queue_free()
			_records.erase(id)
			removed = true
	if removed:
		# Drop weak-source bindings and old viewport textures across floor changes.
		_materials.clear()
		_bindings.clear()

func _is_character_surface(node: Node) -> bool:
	var cursor := node.get_parent()
	while cursor != null and cursor != _source:
		var actor: Variant = cursor.get("source_actor")
		if actor is Node2D:
			if not (actor.is_in_group("dream_player") or actor.is_in_group("dream_enemies")):
				return false
			# Attachments contain flash/reload/UI captures, not the held weapon.
			return node == cursor.get("actor_sprite") or node == cursor.get("weapon_sprite")
		cursor = cursor.get_parent()
	return false

func sync_from_camera(camera: Camera3D) -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(camera):
		return
	_camera.global_transform = camera.global_transform
	for key in [&"projection", &"fov", &"size", &"near", &"far", &"keep_aspect", &"frustum_offset", &"h_offset", &"v_offset"]:
		_camera.set(key, camera.get(key))
	for record: Dictionary in _records.values():
		var source: GeometryInstance3D = record.source.get_ref()
		var proxy: GeometryInstance3D = record.proxy
		if not is_instance_valid(source) or source.is_queued_for_deletion():
			proxy.visible = false
			continue
		var shown: bool = source.is_visible_in_tree() and (source.layers & camera.cull_mask) != 0
		if proxy.visible != shown: proxy.visible = shown
		if proxy.global_transform != source.global_transform: proxy.global_transform = source.global_transform
		if proxy.extra_cull_margin != source.extra_cull_margin: proxy.extra_cull_margin = source.extra_cull_margin
		var overlay := _mask_material(source.material_overlay, record.white) if source.material_overlay != null else null
		if proxy.material_overlay != overlay: proxy.material_overlay = overlay
		if source is MeshInstance3D:
			if proxy.mesh != source.mesh: proxy.mesh = source.mesh
			if source.mesh != null:
				for surface in source.mesh.get_surface_count():
					var material := _mask_material(source.get_active_material(surface), record.white)
					if proxy.get_surface_override_material(surface) != material: proxy.set_surface_override_material(surface, material)
		elif source is MultiMeshInstance3D:
			if proxy.multimesh != source.multimesh: proxy.multimesh = source.multimesh
			var material := _mask_material(source.material_override, record.white)
			if proxy.material_override != material: proxy.material_override = material
		elif source is Sprite3D:
			for key in [&"texture", &"pixel_size", &"centered", &"offset", &"axis", &"flip_h", &"flip_v", &"hframes", &"vframes", &"frame", &"region_enabled", &"region_rect", &"billboard", &"fixed_size", &"double_sided", &"no_depth_test"]:
				if proxy.get(key) != source.get(key): proxy.set(key, source.get(key))
			var material := _mask_material(source.material_override, record.white, source.texture)
			if proxy.material_override != material: proxy.material_override = material
	for binding: Dictionary in _bindings:
		var source: ShaderMaterial = binding.source.get_ref()
		if not is_instance_valid(source):
			continue
		for uniform: StringName in binding.uniforms:
			var value: Variant = source.get_shader_parameter(uniform)
			if not binding.last.has(uniform) or binding.last[uniform] != value:
				binding.target.set_shader_parameter(uniform, value)
				binding.last[uniform] = value

func _mask_material(source: Material, white: bool, texture: Texture2D = null) -> Material:
	var key := str(source.get_instance_id() if source != null else 0) + ":" + str(white) + ":" + str(texture.get_instance_id() if texture != null else 0)
	if source is BaseMaterial3D:
		key += ":" + str(source.transparency) + ":" + str(source.albedo_color.a)
	if _materials.has(key):
		return _materials[key]
	var result := ShaderMaterial.new()
	if source is ShaderMaterial and source.shader != null:
		var code: String = source.shader.code
		# Glass transmits the original reference scene; it must not erase its mask.
		if "office_window_glass" in source.shader.resource_path:
			code = "shader_type spatial; void fragment(){discard;}"
		else:
			var start := code.find("void fragment()")
			var opening := code.find("{", start)
			if start >= 0 and opening >= 0:
				var depth := 1
				var end := opening + 1
				while end < code.length() and depth > 0:
					if code[end] == "{": depth += 1
					elif code[end] == "}": depth -= 1
					end += 1
				var value := "1.0" if white else "0.0"
				code = code.insert(end - 1, "\nALBEDO = vec3(" + value + "); EMISSION = vec3(0.0);\n")
			if not "unshaded" in code:
				code = code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode unshaded;")
		if not _shaders.has(code):
			var derived := Shader.new()
			derived.code = code
			_shaders[code] = derived
		result.shader = _shaders[code]
		var uniforms: Array[StringName] = []
		for entry in source.shader.get_shader_uniform_list():
			uniforms.append(StringName(entry.name))
			result.set_shader_parameter(entry.name, source.get_shader_parameter(entry.name))
		_bindings.append({"source": weakref(source), "target": result, "uniforms": uniforms, "last": {}})
	else:
		result.shader = _fallback_shader
		if source is BaseMaterial3D:
			if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and source.albedo_color.a < 0.5:
				var transparent := Shader.new()
				transparent.code = "shader_type spatial; void fragment(){discard;}"
				result.shader = transparent
			texture = source.albedo_texture if source.albedo_texture != null else texture
			result.set_shader_parameter("mask_uv_scale", source.uv1_scale)
			result.set_shader_parameter("mask_uv_offset", source.uv1_offset)
		result.set_shader_parameter("mask_value", 1.0 if white else 0.0)
		result.set_shader_parameter("has_texture", texture != null)
		if texture != null:
			result.set_shader_parameter("mask_texture", texture)
	_materials[key] = result
	return result

func get_stats() -> Dictionary:
	var characters := 0
	for record: Dictionary in _records.values():
		if record.white: characters += 1
	return {"proxies": _records.size(), "character_surfaces": characters, "materials": _materials.size(), "shader_variants": _shaders.size()}

func dispose() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	_records.clear()
	_materials.clear()
	_shaders.clear()
	_bindings.clear()
	_root = null
	_camera = null
	_source = null
	_viewport = null
