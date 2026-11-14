extends RefCounted
## Tutorial equipment uses the existing coated-metal finish at its authored colours.

const FINISH = preload("res://shaders/dream3d/reception_furniture_pbr.gdshader")
const COMPANY_WALL = preload("res://shaders/dream3d/tutorial_company_wall.gdshader")
const METAL_ALBEDO = preload("res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_Color.png")
const METAL_NORMAL = preload("res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_NormalGL.png")
const METAL_ROUGHNESS = preload("res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_Roughness.png")
const METALNESS = preload("res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_Metalness.png")


static func wall_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = COMPANY_WALL
	material.resource_name = "TutorialCompanyWall"
	# Same three paint colours as the approved company corridor.
	material.set_shader_parameter("upper_paint", Color("b8c0bf"))
	material.set_shader_parameter("lower_paint", Color("667373"))
	material.set_shader_parameter("skirting_paint", Color("424d50"))
	return material


static func equipment_material(colour: Color, roughness := .65) -> ShaderMaterial:
	var source := StandardMaterial3D.new()
	source.albedo_color = colour
	source.roughness = roughness
	source.metallic = .18
	source.metallic_specular = .30
	return _finish(source,{})


static func set_mesh_bounds(mesh: MeshInstance3D) -> void:
	_set_bounds(mesh)


static func apply(layout: Node3D, fixtures: Node3D) -> void:
	var finishes: Dictionary = {}
	for mesh in layout.find_children("*", "MeshInstance3D", true, false):
		# The screen, indicator, white boundary and floor strips have their own
		# lesson/power behaviour. Work on the equipment around those surfaces.
		if mesh.name in [&"Indicator", &"StatusLED", &"Screen"]:
			continue
		if mesh.has_meta(&"floor_light_strip") or mesh.has_meta(&"painted_line"):
			continue
		if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		if String(mesh.name).begins_with("ObservationGlass"):
			continue
		if mesh.name == &"CC0_CRT_Chassis":
			# Each donated CRT instance owns its surface overrides. The shared
			# mesh and the menu's original materials keep their existing data.
			for index in mesh.mesh.get_surface_count():
				var source := mesh.get_surface_override_material(index) as StandardMaterial3D
				if _can_age(source):
					mesh.set_surface_override_material(index, _finish(source, finishes))
			_set_bounds(mesh)
		else:
			_apply_mesh(mesh, finishes)
	for fixture in fixtures.get_children():
		_apply_mesh(fixture.get_node("LampHousing"), finishes)


static func _can_age(source: StandardMaterial3D) -> bool:
	return (
		source != null
		and source.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
		and source.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
		and not source.emission_enabled
		and source.albedo_texture == null
	)


static func _apply_mesh(mesh: MeshInstance3D, finishes: Dictionary) -> void:
	var source := mesh.material_override as StandardMaterial3D
	if _can_age(source):
		mesh.material_override = _finish(source, finishes)
		_set_bounds(mesh)


static func _set_bounds(mesh: MeshInstance3D) -> void:
	var bounds := mesh.get_aabb()
	mesh.set_instance_shader_parameter(&"wear_bounds_center", bounds.get_center())
	mesh.set_instance_shader_parameter(&"wear_bounds_half", bounds.size * 0.5)


static func _finish(source: StandardMaterial3D, finishes: Dictionary) -> ShaderMaterial:
	var key := [source.albedo_color, source.roughness, source.metallic, source.metallic_specular]
	if finishes.has(key):
		return finishes[key]
	var material := ShaderMaterial.new()
	material.shader = FINISH
	material.resource_name = "TutorialWornEquipment"
	material.set_shader_parameter("finish_albedo", METAL_ALBEDO)
	material.set_shader_parameter("finish_normal", METAL_NORMAL)
	material.set_shader_parameter("finish_roughness", METAL_ROUGHNESS)
	material.set_shader_parameter("finish_metalness", METALNESS)
	material.set_shader_parameter("finish_colour", source.albedo_color)
	material.set_shader_parameter("repeat_metres", Vector2(1.05, 1.25))
	material.set_shader_parameter("albedo_midpoint", Vector3(.88, .88, .88))
	material.set_shader_parameter("albedo_contrast", .38)
	material.set_shader_parameter("normal_strength", .24)
	material.set_shader_parameter("roughness_range", Vector2(maxf(.32, source.roughness - .12), minf(.99, source.roughness + .18)))
	material.set_shader_parameter("metallic_level", source.metallic)
	material.set_shader_parameter("specular_level", source.metallic_specular)
	material.set_shader_parameter("wear_amount", 1.05)
	# Hinged and sliding assemblies carry their finish with the moving mesh.
	material.set_shader_parameter("object_space_finish", true)
	material.set_shader_parameter("furniture_age", 1.7)
	material.set_shader_parameter("handling_marks", .85)
	material.set_shader_parameter("exposed_substrate", Vector3(.07, .059, .046))
	finishes[key] = material
	return material
