extends Node
## Diagnostic-only use of the engine's native-shader inspection callback.
## Inspection can force material shader generation; timings are not acceptance.
var pending: Array[Dictionary]=[]
func _ready() -> void: add_to_group(&"_native_shader_source_visualizer")
func inspect_mesh(node: Node) -> void:
	if not node is MeshInstance3D or not node.get_parent() is Furniture3DDebris: return
	var material: StandardMaterial3D=node.material_override
	if node!=node.get_parent().get_child(0): return
	call_deferred("inspect_material",material,"burst",node.get_parent().global_position)
func inspect_material(material: StandardMaterial3D,label: String,position: Vector3) -> void:
	if material==null: return
	var properties: Dictionary={}
	for property in material.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_STORAGE)==0: continue
		var value: Variant=material.get(property.name)
		if typeof(value) in [TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_COLOR,TYPE_VECTOR3,TYPE_VECTOR2,TYPE_STRING,TYPE_STRING_NAME]: properties[property.name]=value
	pending.append({"label":label,"position":position,"texture":material.albedo_texture.resource_path if material.albedo_texture!=null else "none","texture_class":material.albedo_texture.get_class() if material.albedo_texture!=null else "none","properties":properties})
	material.inspect_native_shader_code()
func _inspect_shader(shader: RID) -> void:
	if pending.is_empty(): push_error("Shader callback without request"); return
	var result: Dictionary=pending.pop_front()
	var code:=RenderingServer.shader_get_code(shader)
	result.shader_rid=shader.get_id(); result.code_hash=code.hash(); result.code_bytes=code.length()
	print("DESTRUCTION_NATIVE_SHADER ",JSON.stringify(result))
