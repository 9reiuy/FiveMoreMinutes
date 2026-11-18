extends Node3D
## Shadow-only comparison; visible forklift surfaces, cutout and driving remain unchanged.
var sources: Array[Dictionary] = []
var full_casters: Array[MeshInstance3D] = []
var hull_casters: Array[MeshInstance3D] = []
var mode := 0
var shadow_material := StandardMaterial3D.new()


func configure(model: Node3D, unit_scale: float, canopy_rise: float) -> void:
	name = "ForkliftStableShadow"
	shadow_material.resource_name = "ForkliftShadowDepthOnly"
	shadow_material.albedo_color = Color.BLACK
	shadow_material.roughness = 1.0
	var parts := model.find_children("*", "MeshInstance3D", true, false)
	for source: MeshInstance3D in parts:
		if source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON: continue
		sources.append({"mesh": source, "cast": source.cast_shadow})
		full_casters.append(caster(source, "FullShadow", source.mesh))
		if source == model.get("body_mesh_instance"):
			box(source, "ChassisShadow", Vector3(-.20,.39,0), Vector3(1.40,.64,1.04), unit_scale)
			box(source, "CounterweightShadow", Vector3(-.65,.58,0), Vector3(.36,.52,1.14), unit_scale)
			box(source, "CanopyShadow", Vector3(-.19,1.52+canopy_rise,0), Vector3(.92,.12,1.10), unit_scale)
			for side in [-1,1]:
				box(source, "CanopyPostShadow", Vector3(-.51,1.18+canopy_rise*.5,side*.475), Vector3(.14,.85+canopy_rise,.105), unit_scale)
				box(source, "MastShadow", Vector3(.80,1.36,side*.34), Vector3(.12,2.04,.12), unit_scale)
				box(source, "ForkShadow", Vector3(1.21,.075,side*.30), Vector3(.98,.085,.14), unit_scale)
			box(source, "MastCrossShadow", Vector3(.80,.86,0), Vector3(.12,.12,.74), unit_scale)
		else:
			var bounds := source.mesh.get_aabb()
			var wheel := CylinderMesh.new()
			wheel.top_radius = maxf(bounds.size.x, bounds.size.y)*.5
			wheel.bottom_radius = wheel.top_radius
			wheel.height = bounds.size.z
			wheel.radial_segments = 12
			var wheel_shadow := caster(source, "WheelShadow", wheel)
			wheel_shadow.position = bounds.get_center()
			wheel_shadow.rotation.x = PI*.5
			hull_casters.append(wheel_shadow)
	set_mode(0)


func caster(source: MeshInstance3D, label: String, mesh: Mesh) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.material_override = shadow_material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	part.layers = source.layers
	part.hide()
	source.add_child(part)
	return part


func box(source: MeshInstance3D, label: String, at: Vector3, size: Vector3, factor: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size*factor
	var part := caster(source, label, mesh)
	part.position = at*factor
	hull_casters.append(part)


func set_mode(value: int) -> void:
	mode = value
	for source in sources:
		if is_instance_valid(source.mesh):
			source.mesh.cast_shadow = source.cast if mode == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for part in full_casters: part.visible = mode == 1
	for part in hull_casters: part.visible = mode == 2


func _exit_tree() -> void:
	for source in sources:
		if is_instance_valid(source.mesh): source.mesh.cast_shadow = source.cast
	for part in full_casters + hull_casters:
		if is_instance_valid(part) and not part.is_queued_for_deletion(): part.queue_free()
