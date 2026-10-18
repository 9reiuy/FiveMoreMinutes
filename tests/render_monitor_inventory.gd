extends SceneTree
func _initialize() -> void:
	for owner in [&"Material",&"BaseMaterial3D",&"RenderingServer"]:
		for method in ClassDB.class_get_method_list(owner):
			if "shader" in String(method.name) and ("rid" in String(method.name) or "material" in String(method.name)):
				print("MATERIAL_SHADER_METHOD ",owner," ",method.name)
	for owner in [&"Performance",&"RenderingServer"]:
		var result: Dictionary={}
		for label in ClassDB.class_get_integer_constant_list(owner):
			if "PIPELINE" in label or "SHADER" in label or "RENDERING_INFO" in label:
				result[label]=ClassDB.class_get_integer_constant(owner,label)
		print("RENDER_MONITOR_INVENTORY ",owner," ",JSON.stringify(result))
	quit(0)
