extends SceneTree
func _initialize() -> void:
	for owner in ["Performance","RenderingServer"]:
		for key in ClassDB.class_get_integer_constant_list(owner):
			if "PIPELINE" in key or "SHADER" in key:
				print("RENDER_COUNTER ",owner," ",key,"=",ClassDB.class_get_integer_constant(owner,key))
	quit()
