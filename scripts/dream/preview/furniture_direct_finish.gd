extends RefCounted
## Direct-light material profiles for the existing office furniture faces.
const INCLUDE := "res://shaders/dream3d/furniture_direct_finish.gdshaderinc"
const NEUTRAL_SLOPE := 128.0 / 255.0
# Roughness, direct finish strength, maximum tangent-space slope.
const PROFILES := {
	"flat": Vector3(1.0, 0.0, 0.0),
	"wood": Vector3(.88, .027, .055),
	"paint": Vector3(.84, .044, .050),
	"bare_metal": Vector3(.74, .066, .065),
	"plastic": Vector3(.87, .034, .065),
	"fabric": Vector3(.98, .012, .105),
	"leather": Vector3(.83, .041, .100),
	"ceramic": Vector3(.81, .048, .058),
}
static var shaders: Dictionary = {}
static var atlases: Dictionary = {}

static func apply_faces(material: ShaderMaterial, mesh: Mesh, kind: String, result: Dictionary) -> void:
	var shader := _finish_shader(material.shader)
	if shader == null:
		return
	var key := "%s:%s" % [mesh.get_instance_id(), kind]
	if not atlases.has(key):
		atlases[key] = _face_atlas(result.image.get_size(), result.faces, kind)
	material.shader = shader
	material.set_shader_parameter("furniture_finish_atlas", atlases[key])
	material.set_shader_parameter("furniture_finish_atlas_enabled", true)


static func apply_catalogue(mesh: MeshInstance3D, kind: String, materials: Dictionary, dither: Node) -> void:
	if mesh.material_override != null:
		# The copier is made of separate boxes for its shell, lid and paper slot.
		var profile := "plastic" if kind == "copier" else ""
		var candidate := _catalogue_material(mesh.material_override, profile, materials, dither)
		if candidate != null:
			mesh.material_override = candidate
		return
	if mesh.mesh == null:
		return
	for slot in mesh.mesh.get_surface_count():
		var authored := mesh.mesh.surface_get_material(slot)
		if not authored is StandardMaterial3D or authored.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var profile := ""
		match authored.resource_name:
			"wood", "woodDark": profile = "wood"
			"metalLight", "metalDark": profile = "paint"
			"metal": profile = "bare_metal"
			"carpet": profile = "fabric"
		var candidate := _catalogue_material(mesh.get_active_material(slot), profile, materials, dither)
		if candidate != null:
			mesh.set_surface_override_material(slot, candidate)


static func _catalogue_material(active: Material, profile: String, materials: Dictionary, dither: Node) -> ShaderMaterial:
	var source := active as ShaderMaterial
	if profile.is_empty() or source == null or source.shader == null:
		return null
	if source.get_meta(&"furniture_finish_catalogue", false) or source.get_shader_parameter("glow") == true:
		return null
	if not source.shader.code.contains("uniform sampler2D pixel_texture"):
		return null
	var key := "%s:%s" % [source.get_instance_id(), profile]
	if not materials.has(key):
		# Preserve the same swatch light body the existing dither pass would install.
		if dither != null:
			source = dither._material(source)
		var shader := _finish_shader(source.shader)
		if shader == null:
			return null
		var material := source.duplicate() as ShaderMaterial
		material.shader = shader
		for uniform in source.shader.get_shader_uniform_list():
			var value: Variant = source.get_shader_parameter(uniform.name)
			if value != null:
				material.set_shader_parameter(uniform.name, value)
		var finish: Vector3 = PROFILES[profile]
		material.set_shader_parameter("furniture_finish_uniform", Vector2(finish.x, finish.y))
		material.set_meta(&"furniture_finish_catalogue", true)
		materials[key] = material
	return materials[key]


static func _finish_shader(source: Shader) -> Shader:
	if source == null:
		return null
	var signature := source.code
	if not shaders.has(signature):
		var code := signature
		if not code.contains("void fragment() {") or not code.contains("void light() {") or not code.contains("dot(NORMAL, LIGHT)"):
			shaders[signature] = null
			return null
		code = code.replace("shader_type spatial;", "shader_type spatial;\n#include \"" + INCLUDE + "\"")
		code = code.replace("void fragment() {", """void fragment() {
	furniture_direct_normal = NORMAL;
	furniture_direct_finish = vec2(1.0, 0.0);
	if (furniture_finish_enabled) {
		furniture_direct_finish = furniture_finish_uniform;
		if (furniture_finish_atlas_enabled) {
			vec4 data = texture(furniture_finish_atlas, UV);
			vec2 footprint = fwidth(UV * vec2(textureSize(furniture_finish_atlas, 0)));
			float detail = 1.0 - smoothstep(2.0, 6.0, max(footprint.x, footprint.y));
			vec2 slope = (data.rg * 255.0 - vec2(128.0)) * (detail / 127.0);
			furniture_direct_normal = furniture_finish_normal(NORMAL, VERTEX, UV, slope);
			furniture_direct_finish = vec2(data.b, data.a * detail);
		}
	}
""")
		code = code.replace("dot(NORMAL, LIGHT)", "dot(furniture_direct_normal, LIGHT)")
		code = code.replace("void light() {", """void light() {
	if (furniture_direct_finish.y > 0.0) {
		float finish = furniture_finish_lobe(LIGHT, VIEW, furniture_direct_normal, furniture_direct_finish);
		SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * finish / PI;
	}
""")
		var shader := Shader.new()
		shader.code = code
		shaders[signature] = shader
	return shaders[signature]


static func _face_atlas(size: Vector2i, faces: Array, kind: String) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(_texel(PROFILES.flat))
	for face: Dictionary in faces:
		var rect: Rect2i = face.rect
		var finish: Vector3 = PROFILES[face_profile(kind, String(face.tile))]
		image.fill_rect(rect.grow(2).intersection(Rect2i(Vector2i.ZERO, size)), _texel(finish))
		# Broad, weak relief only on faces large enough to show two texel bands.
		# Leave paper, screens, dark recesses and narrow trim perfectly flat.
		var band := mini(4, floori(float(mini(rect.size.x, rect.size.y)) / 6.0))
		if band < 1 or finish.z <= 0.0:
			continue
		_bevel(image, rect, band, finish)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func _bevel(image: Image, rect: Rect2i, width: int, finish: Vector3) -> void:
	for inset in width:
		var band := rect.grow(-inset)
		var slope := finish.z * (1.0 - float(inset) / width)
		image.fill_rect(Rect2i(band.position, Vector2i(1, band.size.y)), _texel(finish, Vector2(-slope, 0.0)))
		image.fill_rect(Rect2i(band.end.x - 1, band.position.y, 1, band.size.y), _texel(finish, Vector2(slope, 0.0)))
		image.fill_rect(Rect2i(band.position, Vector2i(band.size.x, 1)), _texel(finish, Vector2(0.0, -slope)))
		image.fill_rect(Rect2i(band.position.x, band.end.y - 1, band.size.x, 1), _texel(finish, Vector2(0.0, slope)))


static func _texel(finish: Vector3, slope := Vector2.ZERO) -> Color:
	var encoded := Vector2(NEUTRAL_SLOPE, NEUTRAL_SLOPE) + slope * (127.0 / 255.0)
	return Color(encoded.x, encoded.y, finish.x, finish.y)


static func face_profile(kind: String, tile: String) -> String:
	match tile:
		"desk_top", "wood", "wood_top", "reception":
			return "wood"
		"chair_seat", "chair_back", "fabric", "partition":
			return "fabric"
		"sofa":
			return "leather"
		"drawer", "cabinet_front", "cabinet_side", "desk_side", "rack", "port", "counter":
			return "paint"
		"metal_top", "sink", "steel", "frame":
			return "bare_metal"
		"screen_back", "screen_bezel", "tray", "door", "tile":
			return "plastic"
		"kitchen":
			return "paint" if kind == "fridge" else "plastic"
		"porcelain":
			return "ceramic"
		"light":
			return "ceramic" if kind in ["toilet", "washbasin"] else "plastic"
		"side":
			if kind == "sofa": return "fabric"
			if kind == "appliance_counter": return "plastic"
			return "paint"
	return "flat"
