extends RefCounted
## Read-only diagnostics. Counter support must be established on the actual
## backend before interpreting zero deltas as absence of compilation.
static func pipelines() -> Dictionary:
	var result: Dictionary={}
	for name in ["CANVAS","MESH","SURFACE","DRAW","SPECIALIZATION"]:
		var key: String="RENDERING_INFO_PIPELINE_COMPILATIONS_"+name
		result[name]=RenderingServer.get_rendering_info(ClassDB.class_get_integer_constant("RenderingServer",key))
	return result

static func lights(world: Node3D) -> Dictionary:
	var result: Dictionary={"interior":[],"muzzle":[]}
	var manager: Node=world.get("shadow_manager")
	if is_instance_valid(manager):
		for light in manager.get("candidates"):
			if is_instance_valid(light) and light.shadow_enabled:
				result.interior.append([light.get_instance_id(),light.visible,light.shadow_opacity])
		var sun: Light3D=manager.get("sun")
		if is_instance_valid(sun): result.sun=[sun.visible,sun.shadow_enabled,sun.shadow_opacity]
	var lighting: Node=world.get("night_lighting")
	if is_instance_valid(lighting):
		for light in lighting.get("muzzle_lights"):
			if light.visible: result.muzzle.append([light.get_instance_id(),light.shadow_enabled,light.light_energy])
	return result
