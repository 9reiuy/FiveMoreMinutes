extends RefCounted
## Shared, packaged assets for the accepted cloud style and its reference page.
const MESH:=preload("res://art/Effects/StylizedGas/cloud_mesh.res")
const INDEXED_MESH:=preload("res://art/Effects/StylizedGas/cloud_mesh_indexed.res")
const SHADOW_MESH:=preload("res://art/Effects/StylizedGas/cloud_shadow.res")
const NOISE:=preload("res://art/Effects/StylizedGas/cloud_noise.res")
const SHADER:=preload("res://shaders/dream3d/stylized_cloud.gdshader")
const LIGHT_GAIN:=1.25

static func make_material()->ShaderMaterial:
	var material:=ShaderMaterial.new()
	material.shader=SHADER
	var gradient:=Gradient.new()
	gradient.interpolation_mode=Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient.offsets=PackedFloat32Array([0.0,.22])
	gradient.colors=PackedColorArray([palette_input(Color("777c8d")),palette_input(Color("d5dbe5"))])
	var ramp:=GradientTexture1D.new()
	ramp.width=256
	ramp.gradient=gradient
	material.set_shader_parameter("Color_1D_Gradient",ramp)
	material.set_shader_parameter("Dissolve_Texture",NOISE)
	material.set_shader_parameter("dissolve_enabled",true)
	material.set_shader_parameter("particle_age_from_custom",true)
	return material

static func palette_input(color:Color)->Color:
	var linear:=color.srgb_to_linear()
	return Color(linear.r/LIGHT_GAIN,linear.g/LIGHT_GAIN,linear.b/LIGHT_GAIN,1.0).linear_to_srgb()
