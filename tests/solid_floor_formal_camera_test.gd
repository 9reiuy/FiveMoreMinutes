extends "res://tests/phone_tab_delivery.gd"
var materials: Array[ShaderMaterial] = []
var originals: Array[Shader] = []
func collect(material: Material) -> void:
	if not material is ShaderMaterial or materials.has(material): return
	materials.append(material)
	originals.append(material.shader)
func draw() -> Image:
	world.player_depth_bridge._process(0.0)
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.runtime/"): quit(2); return
	output = "res://.runtime/solid_floor_pipeline_20261023/formal"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await ready_main()
	main.persistent_day_state = main._create_initial_state()
	main.persistent_day_state.tutorial_completed = true
	main._show_dream("basic")
	await ready_main()
	world = main._supported_dream_world
	var deadline := Time.get_ticks_msec() + 60000
	while world.floor_transition_in_progress and Time.get_ticks_msec() < deadline: await wait(0.05)
	check(not world.floor_transition_in_progress, "Actual Main enters formal floor")
	var reflection: Node = world.get_node("FloorReflections")
	check(reflection.surfaces.size() > 0, "Formal reflections are installed, not disabled for parity")
	var floor_count := 0
	for node in world.floor_root.get_children():
		if not node is MeshInstance3D or not node.name.begins_with("FloorBatch_"): continue
		for index in node.mesh.get_surface_count():
			floor_count += 1
			var material: Material = node.get_active_material(index)
			collect(material)
			check(material is ShaderMaterial and not material.shader.code.contains("ALPHA"), "Every live floor batch is outside transparent pipeline")
	for rug in world.floor_root.find_children("ReviewRug_*", "MeshInstance3D", true, false):
		collect(rug.material_override)
		check(not rug.material_override.shader.code.contains("ALPHA"), "Local rug also uses opaque policy")
	check(floor_count > 0, "Actual floor batches inspected")
	for record in reflection.surfaces:
		check(not record.material.shader.code.contains("ALPHA"), "Reflection wrapping never reintroduces floor transparency")
		check(record.material.get_shader_parameter("sample_reflection_texture") == reflection.viewport.get_texture(), "Original reflection texture binding retained")
	var player = world.player
	player.invulnerability_left = 1000.0
	await wait(0.3)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	player.invulnerability_left = 0.0
	player.visual.visible = true
	player.visual.modulate = Color.WHITE
	# Preserve every live uniform and texture while emulating only the old
	# ground queue. Both frames use the same generated floor/camera/reflection.
	for index in materials.size():
		var old := Shader.new()
		old.code = originals[index].code.replace("depth_draw_opaque", "depth_draw_always").replace("ROUGHNESS = 1.0;", "ALPHA = 1.0;\nROUGHNESS = 1.0;")
		materials[index].shader = old
	var before := await draw()
	before.save_png(output.path_join("before.png"))
	for index in materials.size(): materials[index].shader = originals[index]
	var after := await draw()
	after.save_png(output.path_join("after.png"))
	check(materials.all(func(mat: ShaderMaterial) -> bool: return not mat.shader.code.contains("ALPHA")), "All live materials restored to new opaque pipeline")
	check(reflection.surfaces.all(func(record: Dictionary) -> bool: return record.material.get_shader_parameter("sample_reflection_texture") == reflection.viewport.get_texture()), "A/B restores all reflection bindings")
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "floor_surfaces": floor_count, "unique_materials": materials.size(), "scope": "Actual Main camera, same generated floor, textures and reflection; frame pair is visual acceptance, controlled GPU patch parity is measured separately"}, "\t"))
	file.close()
	print("SOLID_FLOOR_FORMAL checks=", checks, " failures=", failures.size())
	main.free()
	quit(0 if failures.is_empty() else 1)
