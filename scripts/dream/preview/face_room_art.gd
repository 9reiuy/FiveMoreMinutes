extends RefCounted
## Preview only. Original geometry, atlas artwork and attachments are retained.
static var shader_cache: Dictionary = {}
static var materials: Dictionary = {}
static var light_direction := Vector3(-.8,-1.0,-.12).normalized()

static func material(source: Material) -> Material:
	if source is StandardMaterial3D:
		if materials.has(source): return materials[source]
		var base := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = "shader_type spatial; uniform vec4 base_color : source_color = vec4(1.0); uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable; uniform bool has_texture = false; uniform vec3 uv_scale = vec3(1.0); uniform vec3 uv_offset = vec3(0.0); void fragment() { ALBEDO = base_color.rgb; if (has_texture) { ALBEDO *= texture(albedo_texture, UV * uv_scale.xy + uv_offset.xy).rgb; } ROUGHNESS = 1.0; SPECULAR = 0.0; }"
		base.shader = shader
		base.set_shader_parameter("base_color",source.albedo_color)
		base.set_shader_parameter("has_texture",source.albedo_texture != null)
		base.set_shader_parameter("albedo_texture",source.albedo_texture)
		base.set_shader_parameter("uv_scale",source.uv1_scale)
		base.set_shader_parameter("uv_offset",source.uv1_offset)
		var converted := material(base)
		materials[source] = converted
		return converted
	if not source is ShaderMaterial or source.shader == null: return source
	var code: String = source.shader.code
	if not code.contains("ALBEDO") or code.contains("shadow_opacity") or code.contains("outline_width"): return source
	if materials.has(source): return materials[source]
	var copy := source.duplicate() as ShaderMaterial
	if not shader_cache.has(source.shader):
		var shader := Shader.new()
		var mode := "" if code.contains("unshaded") else "render_mode unshaded;\n"
		var variant := code.replace("shader_type spatial;", "shader_type spatial;\n" + mode + _helpers())
		var vertex := "preview_position = VERTEX * vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz)); preview_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL); preview_local_normal = NORMAL;"
		if variant.contains("void vertex() {"):
			variant = variant.replace("void vertex() {","void vertex() {\n" + vertex)
		else:
			variant += "\nvoid vertex() {" + vertex + "}\n"
		variant = variant.replace("texture(atlas, UV)","texture(atlas, preview_grid_uv(UV))")
		variant = variant.replace("texture(detail_atlas, UV)","texture(detail_atlas, preview_grid_uv(UV))")
		variant = variant.replace("texture(albedo_texture, UV)","texture(albedo_texture, preview_grid_uv(UV))")
		variant = variant.replace("texture(albedo_texture, UV * uv_scale.xy + uv_offset.xy)","texture(albedo_texture, preview_grid_uv(UV) * uv_scale.xy + uv_offset.xy)")
		variant = variant.replace("texture(pixel_texture, uv)","textureGrad(pixel_texture, floor(uv * 32.0) / 32.0 + vec2(0.5/32.0), dFdx(uv), dFdy(uv))")
		var start := variant.find("void fragment()")
		if start >= 0:
			var end := variant.find("{",start) + 1
			var depth := 1
			while depth > 0 and end < variant.length():
				if variant[end] == "{": depth += 1
				elif variant[end] == "}": depth -= 1
				end += 1
			variant = variant.insert(end-1,"\nALBEDO *= preview_face_shade(FRAGCOORD.xy);\n")
		shader.code = variant
		shader_cache[source.shader] = shader
	copy.shader = shader_cache[source.shader]
	for uniform in source.shader.get_shader_uniform_list():
		var value: Variant = source.get_shader_parameter(uniform.name)
		if value != null: copy.set_shader_parameter(uniform.name,value)
	copy.set_shader_parameter("preview_light_direction",light_direction)
	materials[source] = copy
	return copy

static func _helpers() -> String:
	return """
uniform vec3 preview_light_direction = vec3(-0.8,-1.0,-0.12);
varying vec3 preview_position;
varying vec3 preview_normal;
varying vec3 preview_local_normal;
vec2 preview_grid_uv(vec2 uv) {
    vec3 n = abs(preview_local_normal);
    vec2 plane = n.y > max(n.x,n.z) ? preview_position.xz : (n.x > n.z ? preview_position.zy : preview_position.xy);
    mat2 surface = mat2(dFdx(plane),dFdy(plane));
    if (abs(determinant(surface)) < 0.000001) { return uv; }
    vec2 delta = (floor(plane * 32.0) + vec2(0.5)) / 32.0 - plane;
    return uv + mat2(dFdx(uv),dFdy(uv)) * inverse(surface) * delta;
}
vec3 preview_face_shade(vec2 screen_pixel) {
    float facing = dot(normalize(preview_normal), -normalize(preview_light_direction));
    vec3 shade = vec3(0.47,0.51,0.56);
    if (facing >= 0.18) { shade = vec3(0.69,0.72,0.76); }
    if (facing >= 0.52 && facing < 0.72) {
        float checker = mod(floor(screen_pixel.x) + floor(screen_pixel.y),2.0);
        shade = checker < 1.0 ? vec3(1.0) : vec3(0.69,0.72,0.76);
    }
    if (facing >= 0.72) { shade = vec3(1.0); }
    return shade;
}
"""

static func furniture(_kind: String, original: Node3D) -> Node3D:
	var copy := original.duplicate() as Node3D
	copy.name = "FaceShadedOriginalFurniture"
	for mesh in copy.find_children("*","MeshInstance3D",true,false):
		if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		if mesh.material_override != null:
			mesh.material_override = material(mesh.material_override)
		elif mesh.mesh != null:
			for index in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(index, material(mesh.get_active_material(index)))
	return copy

static func set_direction(direction: Vector3) -> void:
	light_direction = direction.normalized()
	for mat in materials.values():
		mat.set_shader_parameter("preview_light_direction",light_direction)
