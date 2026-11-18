extends "res://tests/h06_forklift_stable_shadow_comparison.gd"
## Compare the integrated full-detail caster against inset closed shadow volumes.
var previous_caster: Node3D


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	diagnostic_case = "stable_hull"
	diagnostic_title = "封闭简化投影"
	print("COMPACT_SHADOW_COMPARISON_PID ", OS.get_process_id())
	call_deferred("run")


func apply_comparison() -> void:
	if not is_instance_valid(shadow_proxy):
		previous_caster = lift.visual.stable_shadow_caster
		previous_caster.set_enabled(false)
		shadow_proxy = SHADOW.new()
		lift.visual.add_child(shadow_proxy)
		shadow_proxy.configure(lift.visual, lift.visual.MODEL_SCALE, lift.visual.CANOPY_RAISE)
		# Recess the closed proxy surfaces to avoid coincident receiver/caster faces.
		shadow_proxy.shadow_material.grow = true
		shadow_proxy.shadow_material.grow_amount = -.008
		check(shadow_proxy.shadow_material.grow and is_equal_approx(shadow_proxy.shadow_material.grow_amount,-.008), "shadow surfaces use the intended inward offset")
		audit_tangents()
	world.get_viewport().use_taa = false
	world.get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
	if comparison_mode == 0:
		shadow_proxy.set_mode(0)
		previous_caster.set_enabled(true)
	else:
		previous_caster.set_enabled(false)
		shadow_proxy.set_mode(2)
	comparison_label.text = "F6 切换对照　·　" + ("B 封闭简化投影" if comparison_mode != 0 else "A 当前正式投影") + "　·　请左右移动视角"
	comparison_trace.append({"mode": comparison_mode, "time_usec": Time.get_ticks_usec()})
	FileAccess.open(evidence.path_join("switches.json"), FileAccess.WRITE).store_string(JSON.stringify(comparison_trace,"\t"))


func check_comparison_mode(mode: int) -> bool:
	return previous_caster.enabled == (mode == 0) and shadow_proxy.mode == (0 if mode == 0 else 2) and lift.visual.visible


func align_comparison_camera() -> void:
	pass


func audit_tangents() -> void:
	var result := {"vertices":0,"invalid_vertices":0,"invalid_normals":0,"zero_normals":0,
		"tangent_components":0,"invalid_tangents":0,"zero_tangents":0,"source_count":0}
	for state in previous_caster.sources:
		var part: MeshInstance3D = state.mesh
		result.source_count += 1
		for surface in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(surface)
			for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				result.vertices += 1
				if not v.is_finite(): result.invalid_vertices += 1
			for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
				if not n.is_finite(): result.invalid_normals += 1
				if n.length_squared() < .01: result.zero_normals += 1
			var tangents: Variant = arrays[Mesh.ARRAY_TANGENT]
			if tangents == null: continue
			for t: float in tangents:
				result.tangent_components += 1
				if not is_finite(t): result.invalid_tangents += 1
			for i in range(0,tangents.size(),4):
				if Vector3(tangents[i],tangents[i+1],tangents[i+2]).length_squared() < .01: result.zero_tangents += 1
	FileAccess.open(evidence.path_join("geometry_audit.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
