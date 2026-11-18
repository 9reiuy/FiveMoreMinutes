extends "res://tests/h06_forklift_flicker_post_comparison.gd"
## Isolate the forklift's render contributions, keeping its visible geometry and gameplay.
var model_parts: Array[Dictionary] = []
var scene_environments: Array[Dictionary] = []


func ensure_model_snapshot() -> void:
	if not model_parts.is_empty(): return
	for part: MeshInstance3D in lift.visual.find_children("*", "MeshInstance3D", true, false):
		var materials: Array[Material] = []
		for i in part.mesh.get_surface_count(): materials.append(part.get_active_material(i))
		model_parts.append({"part": part, "shadow": part.cast_shadow, "material": part.material_override,
			"surfaces": materials})
	for e: Environment in [world.get_world_3d().environment, world.camera_3d.environment]:
		if e == null: continue
		scene_environments.append({"env": e, "ssr": e.ssr_enabled})
	FileAccess.open(evidence.path_join("mesh_audit.json"), FileAccess.WRITE).store_string(JSON.stringify(audit_model(), "\t"))


func audit_model() -> Dictionary:
	var result := {"invalid_vertices": 0, "invalid_normals": 0, "invalid_uvs": 0, "vertices": 0, "parts": []}
	for state in model_parts:
		var part: MeshInstance3D = state.part
		result.parts.append({"name": part.name, "bounds": part.mesh.get_aabb(), "surface_count": part.mesh.get_surface_count()})
		for i in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(i)
			for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				result.vertices += 1
				if not v.is_finite(): result.invalid_vertices += 1
			if arrays[Mesh.ARRAY_NORMAL] != null:
				for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
					if not n.is_finite(): result.invalid_normals += 1
			if arrays[Mesh.ARRAY_TEX_UV] != null:
				for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
					if not uv.is_finite(): result.invalid_uvs += 1
	return result


func check_comparison_mode(_mode: int) -> bool:
	return not world.get_viewport().use_taa and lift.visual.visible


func apply_comparison() -> void:
	ensure_model_snapshot()
	var active := comparison_mode != 0
	world.get_viewport().use_taa = false
	world.get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
	lift.visual.show()
	for saved in scene_environments:
		saved.env.ssr_enabled = saved.ssr and not (active and diagnostic_case == "no_ssr")
	for state in model_parts:
		var part: MeshInstance3D = state.part
		part.visible = not (active and diagnostic_case == "no_glass" and part == lift.visual.windshield_mesh_instance)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if active and diagnostic_case == "no_vehicle_shadows" else state.shadow
		part.material_override = state.material
		for i in state.surfaces.size():
			part.set_surface_override_material(i, state.surfaces[i])
			if active and diagnostic_case == "flat_vehicle":
				var original: Material = state.surfaces[i]
				var flat := StandardMaterial3D.new()
				flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				flat.albedo_color = original.albedo_color if original is StandardMaterial3D else Color("a77a32")
				part.set_surface_override_material(i, flat)
	comparison_label.text = "F6 切换对照　·　" + ("B " + diagnostic_title if active else "A 原画面") + "　·　请左右移动视角"
	comparison_trace.append({"mode": comparison_mode, "case": diagnostic_case, "time_usec": Time.get_ticks_usec()})
	FileAccess.open(evidence.path_join("switches.json"), FileAccess.WRITE).store_string(JSON.stringify(comparison_trace, "\t"))


func align_comparison_camera() -> void:
	var now := Time.get_ticks_usec()
	if now - config_check_usec < 250000: return
	config_check_usec = now
	var path := evidence.path_join("diagnostic_case.json")
	if not FileAccess.file_exists(path): return
	var value := FileAccess.get_file_as_string(path)
	if value == config_text: return
	var config: Variant = JSON.parse_string(value)
	if not config is Dictionary or config.get("case", "") not in ["no_vehicle_shadows", "no_ssr", "no_glass", "flat_vehicle"]: return
	config_text = value
	diagnostic_case = config["case"]
	diagnostic_title = config.get("title", diagnostic_case)
	comparison_mode = 0
	apply_comparison()


func _initialize() -> void:
	diagnostic_case = "no_vehicle_shadows"
	diagnostic_title = "关闭叉车投影"
	super._initialize()
