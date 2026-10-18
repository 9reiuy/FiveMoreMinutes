extends SceneTree
const PREVIEW = preload("res://scenes/dream/preview/PixelShadowPreview.tscn")
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)

func _run() -> void:
	var original_code: String = preload("res://shaders/dream3d/office_pixel_surface.gdshader").code
	var preview := PREVIEW.instantiate()
	root.add_child(preview)
	await process_frame
	check(preview.world.use_authored_office_sample, "Not the approved sample")
	check(preview.copies.size() > 0, "No receiver materials found")
	check(preview.preview_shader.code.contains("preview_threshold"), "Ordered matrix missing")
	check(preview.preview_shader.code.contains("ATTENUATION * n_dot_l"), "Real shadows absent from shade")
	check(not original_code.contains("preview_grid"), "Production shader modified")
	for source in preview.copies:
		var duplicate: ShaderMaterial = preview.copies[source]
		check(source != duplicate, "Shared material mutated")
		check(source.shader != duplicate.shader, "Shared shader mutated")
		var names: Array = []
		for uniform in duplicate.shader.get_shader_uniform_list():
			names.append(String(uniform.name))
		check("preview_mode" in names, "Receiver shader failed compilation")
		check(source.get_shader_parameter("base_color") == duplicate.get_shader_parameter("base_color"), "Environment color changed")
		for uniform in source.shader.get_shader_uniform_list():
			check(source.get_shader_parameter(uniform.name) == duplicate.get_shader_parameter(uniform.name), "Original uniform lost: " + String(uniform.name))
	for mode in [0, 1, 2, 0, 2]:
		preview.mode = mode
		preview._refresh()
		for material in preview.copies.values():
			check(material.get_shader_parameter("preview_mode") == mode, "Wrong shading mode")
	# Existing actor capture viewports remain; the preview adds no world viewport.
	for child in preview.get_children():
		check(not child is SubViewport, "Extra world render added")
	preview.queue_free()
	await process_frame
	check(preload("res://shaders/dream3d/office_pixel_surface.gdshader").code == original_code, "Production changed after exit")
	print("PIXEL_SHADOW_TEST_PASS ", checks)
	quit()
