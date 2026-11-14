extends RefCounted
## Retain the imported PBR maps and add wear only to the playable 0-6 consist.

const WEAR_INCLUDE := "#include \"res://shaders/dream3d/train_surface_wear.gdshaderinc\"\n"
const WALL_FINISHES := ["PBR_StainlessMetroBody", "PBR_LowerStainlessCarriage", "PBR_InteriorCoatedPanels"]
var materials: Dictionary[StandardMaterial3D, ShaderMaterial] = {}
var _shaders: Dictionary[Shader, Shader] = {}
var _cutout: RefCounted


func _init(cutout: RefCounted) -> void:
	_cutout = cutout


func apply_car(car: Node3D, index: int) -> void:
	for visual: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
		if visual.mesh == null:
			continue
		var applied := false
		for surface in visual.mesh.get_surface_count():
			var original := visual.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null or original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var floor_surface := original.resource_name == "PBR_RubberCarriageFloor"
			if not floor_surface and original.resource_name not in WALL_FINISHES:
				continue
			visual.set_surface_override_material(surface, _material(original, floor_surface))
			applied = true
		if applied:
			var relative := car.global_transform.affine_inverse() * visual.global_transform
			visual.set_instance_shader_parameter(&"train_wear_origin", relative.origin)
			visual.set_instance_shader_parameter(&"train_wear_basis_x", relative.basis.x)
			visual.set_instance_shader_parameter(&"train_wear_basis_y", relative.basis.y)
			visual.set_instance_shader_parameter(&"train_wear_basis_z", relative.basis.z)
			visual.set_instance_shader_parameter(&"train_wear_seed", float(index + 1))


func set_amount(amount: float) -> void:
	for material in materials.values():
		material.set_shader_parameter(&"train_wear_amount", clampf(amount, 0.0, 1.0))


func _material(original: StandardMaterial3D, floor_surface: bool) -> ShaderMaterial:
	if materials.has(original):
		return materials[original]
	var base: ShaderMaterial = _cutout.pbr_material(original)
	if not _shaders.has(base.shader):
		# Extend the same PBR conversion used by the existing wall cutout.
		var shader := Shader.new()
		var code := base.shader.code
		code = code.insert(code.find("uniform vec4 albedo_color"), WEAR_INCLUDE)
		code = code.replace("void vertex() {", "void vertex() {\n" +
			"\ttrain_surface_position = train_wear_origin + train_wear_basis_x * VERTEX.x + train_wear_basis_y * VERTEX.y + train_wear_basis_z * VERTEX.z;\n" +
			"\ttrain_surface_normal = train_wear_basis_x * NORMAL.x + train_wear_basis_y * NORMAL.y + train_wear_basis_z * NORMAL.z;\n")
		code = code.replace("if (main_camera_cutout(", "if (!train_floor && main_camera_cutout(")
		code = code.insert(code.rfind("\n}"), "\n\tapply_train_wear(ALBEDO, ROUGHNESS, METALLIC, SPECULAR);")
		shader.code = code
		_shaders[base.shader] = shader
	var material := base.duplicate() as ShaderMaterial
	material.shader = _shaders[base.shader]
	material.resource_name = original.resource_name + "_TrainWorn"
	for field in base.shader.get_shader_uniform_list():
		var value: Variant = base.get_shader_parameter(field.name)
		if value != null:
			material.set_shader_parameter(field.name, value)
	material.set_shader_parameter(&"train_floor", floor_surface)
	materials[original] = material
	return material
