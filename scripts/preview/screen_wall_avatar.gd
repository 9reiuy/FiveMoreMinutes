extends Node3D
## Supplied posed avatar receiving physical light from existing rear screens.
const AVATAR_LAYER := 16
const FACE_LAYER := 32
@export var support_monitor := NodePath("Televisions/TV_10")
@export var support_position := Vector3(0.20, 1.83, 3.85)
@onready var geometry: Node3D = $Geometry

func _ready() -> void:
	var materials := {}
	for item in geometry.find_children("*", "MeshInstance3D", true, false):
		var face_only := true
		for surface in item.mesh.get_surface_count():
			var original: StandardMaterial3D = item.get_active_material(surface)
			face_only = face_only and _is_face(original)
			var id := original.get_instance_id()
			if not materials.has(id):
				var shaded := original.duplicate() as StandardMaterial3D
				shaded.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				shaded.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
				shaded.emission_enabled = false
				shaded.rim_enabled = false
				shaded.backlight_enabled = false
				shaded.vertex_color_use_as_albedo = false
				shaded.metallic = 0.0
				shaded.roughness = 0.88 if original.resource_name.contains("Hair") else 0.96
				shaded.metallic_specular = 0.06 if original.resource_name.contains("Hair") else 0.02
				if _is_face(original):
					shaded.metallic_specular = 0.0
					shaded.roughness = 0.97
				materials[id] = shaded
			item.set_surface_override_material(surface,materials[id])
		item.layers = FACE_LAYER if face_only else AVATAR_LAYER
		var body := StaticBody3D.new()
		body.name = "MenuOccluder"
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		collision.shape = item.mesh.create_trimesh_shape()
		body.add_child(collision)
		item.add_child(body)

func _is_face(material: StandardMaterial3D) -> bool:
	return material.resource_name.contains("Skin_Face") or material.resource_name.begins_with("Eye")

func attach_to_wall(wall: Node3D) -> void:
	var support := wall.model.get_node_or_null(support_monitor) as Node3D
	if support != null: support.position = support_position
	for display in wall.displays:
		display.spill_light.light_cull_mask &= ~FACE_LAYER
		# The larger eye CRT must reach the folded forearms below it.
		# Extend its existing spill, keeping the same source and energy.
		if display.chassis == wall.model.get_node(wall.eye_monitor_path):
			display.spill_light.omni_range = 4.3
		if String(display.chassis.name) in ["TV_04", "TV_05"]:
			display.spill_light.omni_range = 4.4
			display.spill_light.shadow_enabled = true
		if display.chassis == support:
			display.spill_light.light_cull_mask &= ~AVATAR_LAYER
		else:
			display.spill_light.light_cull_mask |= AVATAR_LAYER
		if display.spill_light.shadow_enabled:
			display.spill_light.shadow_blur = 0.0
