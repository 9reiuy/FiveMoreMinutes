extends Node3D
## Keep camera cutout/display materials out of the forklift's shadow pass.
## Shadow carriers reuse the exact visible mesh and inherit its roll/steering.
const NODE_NAME := &"ForkliftShadowCaster"
var sources: Array[Dictionary] = []
var casters: Array[MeshInstance3D] = []
var enabled := true
var depth_material := StandardMaterial3D.new()


static func install(model: Node3D) -> Node3D:
	var existing := model.get_node_or_null(NodePath(NODE_NAME))
	if existing != null: return existing
	var component := new() as Node3D
	component.name = NODE_NAME
	model.add_child(component)
	component.configure(model)
	return component


func configure(model: Node3D) -> void:
	depth_material.resource_name = "ForkliftShadowDepthOnly"
	depth_material.albedo_color = Color.BLACK
	depth_material.roughness = 1.0
	# Snapshot first: adding carriers must not register them as visible sources.
	var parts := model.find_children("*", "MeshInstance3D", true, false)
	for source: MeshInstance3D in parts:
		if source.mesh == null or source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON: continue
		var carrier := MeshInstance3D.new()
		carrier.name = "StableShadow"
		carrier.mesh = source.mesh
		carrier.material_override = depth_material
		carrier.layers = source.layers
		carrier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		source.add_child(carrier)
		sources.append({"mesh": source, "cast": source.cast_shadow})
		casters.append(carrier)
	set_enabled(true)


func set_enabled(value: bool) -> void:
	enabled = value
	for i in sources.size():
		var source: MeshInstance3D = sources[i].mesh
		if not is_instance_valid(source): continue
		source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if enabled else sources[i].cast
		if is_instance_valid(casters[i]):
			casters[i].layers = source.layers
			casters[i].visible = enabled
	# Carriers belong to the source mesh tree. They survive region reparenting
	# and are freed with the model, without a second independent lifetime.
