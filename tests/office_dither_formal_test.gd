extends SceneTree
const COMPONENT = preload("res://scripts/dream/office_dither_lighting.gd")
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func frames(count: int) -> void:
	for i in count:
		await process_frame

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	var saved: Dictionary = settings.values.duplicate(true)
	var world := WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.use_authored_office_sample = true
	root.add_child(world)
	await frames(4)
	var component: Node = world.get_node_or_null("OfficeDitherLighting")
	check(component != null, "Formal Dream has no Dither component")
	for floor in 3:
		check(world.regenerate(42001 + floor), "Floor generation failed")
		await frames(5)
		check(component.materials.size() > 0, "No material coverage")
		check(get_nodes_in_group(&"office_dither_lighting").size() == 1, "Duplicate component across floors")
		for source_key in component.materials:
			var material: ShaderMaterial = component.materials[source_key]
			# The cache now uses identity+flavour strings; the actual immutable
			# source is retained as metadata on each generated material.
			var source: ShaderMaterial = material.get_meta(&"dither_origin")
			check(material != source, "Shared material changed")
			check(material.get_shader_parameter("office_dither_enabled") == true, "Dither disabled")
			check(is_equal_approx(material.get_shader_parameter("office_dither_step"), 1.0/32.0), "Wrong grid")
			var names: Array = []
			for uniform in material.shader.get_shader_uniform_list():
				names.append(String(uniform.name))
			check("office_dither_enabled" in names, "Shader failed compilation")
			for uniform in source.shader.get_shader_uniform_list():
				var expected: Variant=String(source_key).ends_with("|furniture") if String(uniform.name)=="occlusion_cutout_enabled" else source.get_shader_parameter(uniform.name)
				check(material.get_shader_parameter(uniform.name) == expected, "Original uniform lost: " + String(uniform.name))
	for pixels in [false, true]:
		for palette in [false, true]:
			settings.values["pixelation_enabled"] = pixels
			settings.values["palette_enabled"] = palette
			settings.setting_changed.emit(&"pixelation_enabled", pixels)
			settings.setting_changed.emit(&"palette_enabled", palette)
			await frames(2)
			for material in component.materials.values():
				check(material.get_shader_parameter("office_dither_enabled") == true, "Display switch changed Dither")
	# Ensure exclusions and shader compilation even outside the sample's assets.
	for filename in ["office_window_glass.gdshader", "lit_pixel_carrier.gdshader", "office_contact_shadow.gdshader", "furniture_pixel_outline.gdshader", "blood_semantic_carrier.gdshader"]:
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/dream3d/" + filename)
		check(component._material(material) == material, "Out-of-scope shader changed")
	world.queue_free()
	await frames(4)
	check(get_nodes_in_group(&"office_dither_lighting").is_empty(), "Component leaked")
	settings.values = saved
	print("OFFICE_DITHER_FORMAL checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
