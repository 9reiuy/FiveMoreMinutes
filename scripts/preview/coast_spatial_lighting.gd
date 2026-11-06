extends Node3D
## Authored light nodes, driven by the same scene clock/pause/cloud owner.
## Soft fill approximates bounced light; it is not a dynamic GI solver.
var lights: Array[Light3D] = []
var air_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	for node in get_parent().find_children("*", "Light3D", true, false):
		if node.has_meta(&"coast_base_energy"): lights.append(node)
	for node in find_children("*", "MeshInstance3D", true, false):
		var material: ShaderMaterial = node.material_override as ShaderMaterial
		if material != null and material.shader.resource_path.ends_with("coast_local_light_volume.gdshader"):
			air_materials.append(material)

func update_lighting(moon: float, scene_time: float) -> void:
	for light in lights:
		var base := float(light.get_meta(&"coast_base_energy"))
		var cloud_scale := float(light.get_meta(&"coast_cloud_scale", 1.))
		var pulse := float(light.get_meta(&"coast_pulse", 0.))
		# Gentle continuous lamp variation, never an on/off warning strobe.
		light.light_energy = base * lerpf(cloud_scale, 1., moon) * (1. - pulse * (.5 + .5 * sin(scene_time * .7)))
	for material in air_materials:
		material.set_shader_parameter("scene_time", scene_time)
		material.set_shader_parameter("moon_visibility", moon)
