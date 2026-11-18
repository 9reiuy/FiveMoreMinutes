extends "res://tests/forklift_combat_test.gd"
## Subpixel Camera motion and world-registered material patches; no combat presentation.
var captured: Array[Dictionary] = []
var materials: Array[Dictionary] = []
var texture_facts: Array[Dictionary] = []
var shader_cache: Dictionary = {}
var mip_cache: Dictionary = {}
var origin := Vector3.ZERO
var environment: Environment
const PATCH := Rect2(-28.4, -21.3, 2.0, 1.2)


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	print("MATERIAL_SHIMMER_PID ", OS.get_process_id())
	create_timer(160.0).timeout.connect(func() -> void: push_error("material probe timed out"); quit(1))
	call_deferred("run")


func collect_materials() -> void:
	var seen := {}
	for parent: Node3D in [world.floor_root, world.wall_root]:
		for mesh: MeshInstance3D in parent.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null: continue
			for index in mesh.mesh.get_surface_count():
				var mat: Material = mesh.get_active_material(index)
				if mat == null or seen.has(mat.get_instance_id()): continue
				seen[mat.get_instance_id()] = true
				if mat is ShaderMaterial:
					var values := {}
					for parameter in mat.shader.get_shader_uniform_list():
						var key: StringName = parameter.name
						values[key] = mat.get_shader_parameter(key)
					materials.append({"mat": mat, "shader": mat.shader, "values": values})
				elif mat is StandardMaterial3D:
					materials.append({"mat": mat, "filter": mat.texture_filter, "normal": mat.normal_enabled})
	for id: String in ["concrete_floor_worn_001_Diffuse.res", "concrete_floor_worn_001_nor_gl.res", "concrete_floor_worn_001_Rough.res"]:
		var texture: Texture2D = load("res://art/Dream/CC0/PolyHavenResearch/" + id)
		var img: Image = texture.get_image()
		texture_facts.append({"source": texture.resource_path, "size": [img.get_width(), img.get_height()],
			"has_mipmaps": img.has_mipmaps(), "mipmap_count": img.get_mipmap_count()})
	print("MATERIAL_TEXTURE_FACTS ", JSON.stringify(texture_facts))


func mipmapped(texture: Texture2D, normal: bool) -> Texture2D:
	if mip_cache.has(texture): return mip_cache[texture]
	var img := texture.get_image()
	if img.is_compressed(): img.decompress()
	if not img.has_mipmaps(): img.generate_mipmaps(normal)
	var result := ImageTexture.create_from_image(img)
	mip_cache[texture] = result
	return result


func configure_case(label: String) -> void:
	var filtering := label in ["linear", "data_linear", "linear_mips"]
	var mips := label in ["mipmaps", "linear_mips"]
	var normals := label != "no_normals"
	world.get_viewport().use_taa = label == "taa"
	for state in materials:
		var mat: Material = state.mat
		if mat is ShaderMaterial:
			var code: String = state.shader.code
			if filtering:
				if label == "data_linear":
					var lines := code.split("\n")
					for i in lines.size():
						if "surface_normal" in lines[i] or "roughness_map" in lines[i]:
							lines[i] = lines[i].replace("filter_nearest_mipmap_anisotropic", "filter_linear_mipmap_anisotropic")
					code = "\n".join(lines)
				else:
					code = code.replace("filter_nearest_mipmap_anisotropic", "filter_linear_mipmap_anisotropic")
				var key: String = str(state.shader.get_instance_id()) + ":" + str(label == "data_linear")
				if not shader_cache.has(key):
					var candidate := Shader.new()
					candidate.code = code
					shader_cache[key] = candidate
				mat.shader = shader_cache[key]
			else: mat.shader = state.shader
			for parameter: StringName in state.values:
				var value: Variant = state.values[parameter]
				if not normals and parameter in [&"normal_depth", &"normal_strength"]: value = 0.0
				if mips and value is Texture2D and parameter in [&"concrete", &"precast", &"plaster_albedo", &"surface_normal", &"roughness_map"]:
					value = mipmapped(value, parameter == &"surface_normal")
				mat.set_shader_parameter(parameter, value)
		elif mat is StandardMaterial3D:
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if filtering and label != "data_linear" else state.filter
			mat.normal_enabled = state.normal and normals


func camera_frame(index: int) -> void:
	world.camera_rig.position = origin + Vector3(index * 0.016, 0, index * -0.004)
	var gp: Vector2 = world._player_ground_anchor_position()
	var ground: Vector3 = world.to_global(Vector3(gp.x / 32.0, world._floor_height_at(gp / 32.0), gp.y / 32.0))
	world.gameplay_canvas.transform = Transform2D(Vector2.RIGHT, Vector2.DOWN, world.camera_3d.unproject_position(ground) - gp)


func sample_case(label: String) -> void:
	configure_case(label)
	camera_frame(0)
	await frames(24)
	var folder := evidence.path_join(label)
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 96:
		await physics_frame
		camera_frame(i)
		await process_frame
		await RenderingServer.frame_post_draw
		var points: Array[Vector2] = []
		for point: Vector2 in [PATCH.position, PATCH.position + Vector2(PATCH.size.x, 0), PATCH.end, PATCH.position + Vector2(0, PATCH.size.y)]:
			points.append(world.camera_3d.unproject_position(world.to_global(Vector3(point.x, 3.04, point.y))))
		captured.append({"case": label, "frame": i, "points": points, "camera": str(world.camera_3d.global_position),
			"projectiles": get_nodes_in_group(&"dream_projectiles").size(), "taa": world.get_viewport().use_taa})
		root.get_texture().get_image().save_png(folder.path_join("frame_%03d.png" % i))
	print("MATERIAL_SHIMMER_CASE ", label)


func run() -> void:
	evidence = OS.get_environment("FLICKER_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	preload("res://tests/support/background_gpu.gd").start(self)
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await enter_chapter(CHAPTER.Save.PUMP)
	world.restart_queued = true
	for actor in world.enemy_root.get_children(): actor.queue_free()
	await frames(4)
	place_feet(Vector2(-25.5, -18.7))
	world.player.movement_enabled = false
	world.player.set_attacking_enabled(false, true)
	world.set_process(false)
	origin = Vector3(world.player.global_position.x / 32.0, 3.04, world.player.global_position.y / 32.0)
	collect_materials()
	for label in ["original_a", "no_normals", "mipmaps", "data_linear", "linear", "linear_mips", "taa", "original_b"]:
		await sample_case(label)
	check(captured.size() == 768, "all material sampling comparisons complete")
	var file := FileAccess.open(evidence.path_join("trace.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"records": captured, "textures": texture_facts, "checks": checks,
		"failures": failures, "pid": OS.get_process_id(), "audio": AudioServer.get_driver_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "patch": str(PATCH),
		"scope": "Same real Camera motion, stationary non-firing player; world-registered empty floor patch. Shader/filter changes apply only to this disposable test instance."}, "\t"))
	verify_audio()
	current_scene.queue_free()
	await frames(4)
	print("MATERIAL_SHIMMER_PROBE frames=", captured.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
