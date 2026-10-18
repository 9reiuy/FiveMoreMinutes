extends Node3D
## Test-only exact-source atlas prototype. Keep existing shadow proxies intact.
var originals: Array[Sprite3D] = []
var batch: MultiMeshInstance3D
var individuals: Array[MeshInstance3D] = []
func build(bridges: Array) -> void:
	bridges = bridges.duplicate()
	top_level = true
	global_transform = Transform3D.IDENTITY
	var shader := Shader.new()
	var code: String = preload("res://shaders/dream3d/lit_pixel_carrier.gdshader").code
	code = code.replace("void fragment() {", "varying vec4 atlas_cell;\nvoid vertex() { atlas_cell = INSTANCE_CUSTOM; }\nvoid fragment() {")
	var individual := "--individual" in OS.get_cmdline_user_args()
	if individual:
		code = code.replace("varying vec4 atlas_cell;", "uniform vec4 atlas_region;\nvarying vec4 atlas_cell;").replace("atlas_cell = INSTANCE_CUSTOM", "atlas_cell = atlas_region")
	code = code.replace("vec4 pixel = texture(capture_texture, UV);", "vec2 p = floor(UV * 128.0) - vec2(64.0) + vec2(0.5);\nif (atlas_cell.z > 2.5) { p = vec2(-p.y, p.x); } else if (atlas_cell.z > 1.5) { p = -p; } else if (atlas_cell.z > 0.5) { p = vec2(p.y, -p.x); }\np = floor(p) + vec2(16.0);\nif (p.x < 0.0 || p.y < 0.0 || p.x >= 32.0 || p.y >= 32.0) { discard; }\nvec4 pixel = texture(capture_texture, (atlas_cell.xy * 32.0 + p + vec2(0.5)) / vec2(224.0, 192.0));")
	shader.code = code
	var material := ShaderMaterial.new(); material.shader = shader
	var source: Node2D = bridges[0].source_actor
	material.set_shader_parameter("capture_texture", source.sprite.texture)
	# Copy the native Sprite3D mesh, including its triangle diagonal and decoded
	# compressed normal, rather than substituting a generic QuadMesh.
	var arrays: Array = RenderingServer.mesh_surface_get_arrays(bridges[0].actor_sprite.get_base(),0)
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var native: Dictionary = RenderingServer.mesh_get_surface(bridges[0].actor_sprite.get_base(),0)
	var copied: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(),0)
	print("DEBRIS_NATIVE_LAYOUT ",JSON.stringify({"native_format":native.format,"copied_format":copied.format,"native_vertex_bytes":native.vertex_data.size(),"copied_vertex_bytes":copied.vertex_data.size(),"native_attribute_bytes":native.attribute_data.size(),"copied_attribute_bytes":copied.attribute_data.size()}))
	if native.vertex_data.size()==copied.vertex_data.size() and native.attribute_data.size()==copied.attribute_data.size():
		mesh.surface_update_vertex_region(0,0,native.vertex_data)
		mesh.surface_update_attribute_region(0,0,native.attribute_data)
	var multi := MultiMesh.new(); multi.transform_format = MultiMesh.TRANSFORM_3D; multi.use_custom_data = true
	multi.mesh = mesh; multi.instance_count = bridges.size()
	batch = MultiMeshInstance3D.new(); batch.multimesh = multi; batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
	for index in bridges.size():
		var bridge: Node = bridges[index]
		var sprite: Sprite3D = bridge.actor_sprite
		var art: Sprite2D = bridge.source_actor.sprite
		originals.append(sprite)
		var pose := sprite.global_transform
		multi.set_instance_transform(index, global_transform.affine_inverse() * pose)
		multi.set_instance_custom_data(index, Color(float(art.frame % 7), float(art.frame / 7), float(posmod(roundi(art.global_rotation/(PI*.5)),4)), 0))
		if individual:
			var item := MeshInstance3D.new(); item.mesh = mesh
			item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var own := material.duplicate() as ShaderMaterial
			own.set_shader_parameter("atlas_region", multi.get_instance_custom_data(index))
			item.material_override = own; add_child(item); item.global_transform = sprite.global_transform
			individuals.append(item)
	set_enabled(false)
func set_enabled(enabled: bool) -> void:
	batch.visible = enabled and individuals.is_empty()
	for item in individuals: item.visible = enabled
	for sprite in originals: sprite.visible = not enabled
