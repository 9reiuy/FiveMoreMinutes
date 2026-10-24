class_name OfficePixelMaterials
extends RefCounted

## Shared authored pixel swatches. 32 texels represent one world unit.
## No screen-space mosaic, random noise, or per-object texture allocation.
const SHADER = preload("res://shaders/dream3d/office_pixel_surface.gdshader")
const FLOOR_SHADER = preload("res://shaders/dream3d/office_floor_swatch_opaque.gdshader")
static var textures: Dictionary = {}
static var materials: Dictionary = {}
static var sample_furniture_materials: Dictionary = {}

static func swatch(kind: String) -> Texture2D:
	if textures.has(kind):
		return textures[kind]
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var shade := 1.0
			match kind:
				"wood":
					if x == 0 or x == 31: shade = .65
					elif (x == 6 and y >= 5 and y < 22) or (x == 18 and y >= 13 and y < 29): shade = .84
					elif x == 1: shade = 1.08
				"fabric":
					shade = .96 if (x % 4 == 0 and y % 4 < 2) or (y % 4 == 2 and x % 4 > 1) else 1.0
				"floor_carpet":
					# Broad, quiet seams: the floor must not compete with furniture details.
					shade = .975 if x % 16 == 0 or y % 16 == 0 else 1.0
				"tile":
					if x % 16 == 0 or y % 16 == 0: shade = .83
					elif x % 16 == 1 or y % 16 == 1: shade = 1.05
				"floor_tile":
					if x % 16 == 0 or y % 16 == 0: shade = .975
				"office_tiles":
					if x == 0 or y == 0: shade=.78
					elif x==1 or y==1: shade=1.025
				"wet_tiles":
					if x%16==0 or y%16==0: shade=.72
					elif x%16==1 or y%16==1: shade=1.035
				"rug":
					shade=.94 if (x/4+y/4)%2==0 else 1.0
				"metal":
					if x == 0 or y == 0: shade = .76
					elif x == 1 or y == 1: shade = 1.05
					elif (x == 3 or x == 28) and (y == 3 or y == 28): shade = .6
				"paint":
					if y == 0: shade = .78
					elif y == 1: shade = 1.05
			image.set_pixel(x, y, Color(shade * .9, shade * .9, shade * .9, 1))
	# The 32-texel pattern can project to less than one screen pixel on the
	# rotated wall/floor. Pre-filter only its minified levels; level zero stays
	# exactly the authored nearest-neighbour swatch at gameplay distance.
	image.generate_mipmaps()
	textures[kind] = ImageTexture.create_from_image(image)
	return textures[kind]

static func make(color: Color, kind: String, object_space := false, glow := false) -> ShaderMaterial:
	var key := str(color) + kind + str(object_space) + str(glow)
	if not materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = FLOOR_SHADER if kind in ["floor_carpet", "floor_tile", "office_tiles", "wet_tiles", "rug"] else SHADER
		mat.set_shader_parameter("base_color", color)
		mat.set_shader_parameter("pixel_texture", swatch(kind))
		mat.set_shader_parameter("object_space", object_space)
		mat.set_shader_parameter("glow", glow)
		materials[key] = mat
	return materials[key]

## Explicit ground use of a swatch also shared by furniture (e.g. fabric).
static func make_floor(color: Color, kind: String) -> ShaderMaterial:
	var key := "opaque_floor:" + str(color) + kind
	if not materials.has(key):
		var mat := make(color, kind).duplicate() as ShaderMaterial
		mat.shader = FLOOR_SHADER
		materials[key] = mat
	return materials[key]

static func sample_furniture_variant(source: ShaderMaterial) -> ShaderMaterial:
	if source == null or source.shader != SHADER:
		return source
	var key := source.get_instance_id()
	if not sample_furniture_materials.has(key):
		var variant := source.duplicate() as ShaderMaterial
		variant.set_shader_parameter("sample_furniture_surface", true)
		sample_furniture_materials[key] = variant
	return sample_furniture_materials[key]

