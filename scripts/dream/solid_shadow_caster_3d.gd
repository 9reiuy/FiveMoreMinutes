extends RefCounted

## An opaque, identity-transform child shares the visible mesh but not its
## cutaway/actor-occlusion shader. Parenting to the source makes hinge motion,
## furniture Fake Height, visibility, and destruction authoritative automatically.
static var _material: StandardMaterial3D
const NODE_NAME := "SolidShadowCaster"

static func attach(source: MeshInstance3D) -> MeshInstance3D:
	if source == null or source.mesh == null:
		return null
	var caster := source.get_node_or_null(NODE_NAME) as MeshInstance3D
	if caster == null:
		caster = MeshInstance3D.new()
		caster.name = NODE_NAME
		source.add_child(caster)
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	caster.mesh = source.mesh
	caster.material_override = _material
	caster.layers = source.layers
	caster.transform = Transform3D.IDENTITY
	caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return caster

## Preserve deliberate non-casters (contact decals, glass, LEDs and small
## accessories). Only opaque gameplay geometry whose shader may visually cut
## it needs a separate blocker; ordinary materials already cast correctly.
static func protect_shader_meshes(root: Node) -> void:
	for child in root.get_children():
		if child.name != NODE_NAME:
			protect_shader_meshes(child)
	if not root is MeshInstance3D:
		return
	var source := root as MeshInstance3D
	if source.mesh == null or source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
		return
	for surface in source.mesh.get_surface_count():
		if source.get_active_material(surface) is ShaderMaterial:
			attach(source)
			return
