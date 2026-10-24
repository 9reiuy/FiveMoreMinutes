extends SceneTree
const FLOOR = preload("res://scripts/dream/preview/sample_floor_texture_review.gd")
const DITHER = preload("res://scripts/dream/office_dither_lighting.gd")
const REFLECTION = preload("res://scripts/dream/floor_reflections.gd")
const OLD = preload("res://shaders/dream3d/office_low_pixel.gdshader")
var checks := 0
var failures: Array[String] = []
var metrics: Array = []
var output := "res://.runtime/solid_floor_pipeline_20261023"
var builder: Node
var reflector: Node3D
var arena: Node3D
var camera: Camera3D
var floor_mesh: MeshInstance3D
var reflection_texture: Texture2D

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func opaque(shader: Shader) -> bool:
	var token := RegEx.new()
	token.compile("\\bALPHA\\b")
	return token.search(shader.code) == null and not shader.code.contains("depth_draw_never")
func legacy(source: ShaderMaterial) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = DITHER._shader(OLD).code.replace("filter_nearest_mipmap", "filter_nearest")
	if source.shader.code.contains("review_bevel"):
		shader.code = shader.code.replace("varying vec3 world_normal;", "varying vec3 world_normal;\nuniform sampler2D review_bevel : hint_normal, filter_nearest, repeat_disable;")
		shader.code = shader.code.replace("ROUGHNESS = 1.0;", "NORMAL_MAP = texture(review_bevel, atlas_uv).rgb;\nNORMAL_MAP_DEPTH = 1.0;\nROUGHNESS = 1.0;")
	var result := source.duplicate() as ShaderMaterial
	result.shader = shader
	return result
func reflected(source: ShaderMaterial, key: String) -> ShaderMaterial:
	var result := source.duplicate() as ShaderMaterial
	result.shader = reflector._surface_shader(source.shader)
	var profile: Vector4 = REFLECTION.profile(key)
	result.set_shader_parameter("sample_reflection_texture", reflection_texture)
	result.set_shader_parameter("sample_reflection_size", Vector2(32, 32))
	result.set_shader_parameter("sample_reflection_projection", camera.get_camera_projection())
	result.set_shader_parameter("sample_reflection_view", camera.global_transform.affine_inverse())
	result.set_shader_parameter("sample_reflection_strength", profile.x)
	result.set_shader_parameter("sample_reflection_blur", profile.y)
	result.set_shader_parameter("sample_surface_gloss", profile.z)
	result.set_shader_parameter("sample_surface_roughness", profile.w)
	result.set_shader_parameter("sample_surface_enabled", true)
	return result
func draw(material: ShaderMaterial) -> Image:
	floor_mesh.material_override = material
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func compare(current: ShaderMaterial, previous: ShaderMaterial, label: String) -> void:
	check(opaque(current.shader), "Ground stays opaque after all wrappers " + label)
	var texture_parameter := "pixel_texture" if current.shader.code.contains("uniform sampler2D pixel_texture") else "atlas"
	check(current.get_shader_parameter(texture_parameter) == previous.get_shader_parameter(texture_parameter), "Exact albedo texture retained " + label)
	var before := await draw(previous)
	var after := await draw(current)
	check(before.get_size() == after.get_size(), "A/B render target size is stable " + label)
	var area := Rect2i(256, 130, 128, 96)
	var old := before.get_region(area).get_data()
	var now := after.get_region(area).get_data()
	var maximum := 0
	var total := 0
	for index in old.size():
		if index % 4 == 3: continue
		var difference := absi(int(old[index]) - int(now[index]))
		maximum = maxi(maximum, difference)
		total += difference
	var mean := float(total) / (128.0 * 96.0 * 3.0)
	metrics.append({"style": label, "max_channel_255": maximum, "mean_channel_255": mean})
	check(maximum <= 2 and mean < 0.25, "GPU lighting/normal/texture parity " + label + " max=%d mean=%.4f" % [maximum, mean])
	if label in ["corridor_0", "reception_0_reflection", "office_0"]:
		before.save_png(output.path_join(label + "_before.png"))
		after.save_png(output.path_join(label + "_after.png"))
	if maximum > 2:
		before.save_png(output.path_join(label + "_failed_before.png"))
		after.save_png(output.path_join(label + "_failed_after.png"))

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	builder = FLOOR.new()
	reflector = REFLECTION.new()
	arena = Node3D.new()
	root.add_child(arena)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.0
	arena.add_child(camera)
	camera.position = Vector3(0, 3, 5)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("141b2b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("8094ab")
	environment.environment.ambient_light_energy = 0.4
	arena.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -25, 0)
	light.light_energy = 1.1
	arena.add_child(light)
	floor_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(5, 5)
	floor_mesh.mesh = plane
	arena.add_child(floor_mesh)
	var reflection := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32: reflection.set_pixel(x, y, Color(float(x) / 32.0, 0.1, float(y) / 32.0))
	reflection_texture = ImageTexture.create_from_image(reflection)
	for key in ["office", "conference", "manager", "archive", "server", "pantry", "restroom", "lounge", "reception", "corridor", "lift"]:
		for variant in 3:
			var material: ShaderMaterial = builder._material(FLOOR.floor_image(key, variant), FLOOR.floor_normal_image(key, variant) if key != "office" else null)
			var old := legacy(material)
			await compare(material, old, "%s_%d" % [key, variant])
			if variant == 0:
				await compare(reflected(material, key), reflected(old, key), key + "_0_reflection")
	var swatches = preload("res://scripts/dream/office_pixel_materials.gd")
	for kind in ["floor_carpet", "floor_tile", "office_tiles", "wet_tiles", "rug"]:
		var material: ShaderMaterial = swatches.make(Color("8b8e95"), kind)
		check(opaque(material.shader), "Fallback floor swatch is opaque " + kind)
		check(opaque(DITHER._shader(material.shader)), "Fallback dither preserves ground pipeline " + kind)
	check(opaque(swatches.make_floor(Color.WHITE, "fabric").shader), "Lounge fabric rug uses explicit ground policy")
	check(not opaque(swatches.make(Color.WHITE, "fabric").shader), "Furniture fabric retains original cutout pipeline")
	check(opaque(preload("res://scripts/dream/office_low_pixel_art.gd").surface("floor").shader), "Atlas fallback floor uses ground shader")
	check(not opaque(preload("res://scripts/dream/office_low_pixel_art.gd").material().shader), "Furniture atlas remains untouched")
	for kind in ["floor_carpet", "floor_tile", "office_tiles", "wet_tiles", "rug", "fabric", "wood", "tile"]:
		var current := swatches.make_floor(Color("8b8e95"), kind).duplicate() as ShaderMaterial
		var old := current.duplicate() as ShaderMaterial
		current.shader = DITHER._shader(current.shader)
		old.shader = DITHER._shader(preload("res://shaders/dream3d/office_pixel_surface.gdshader"))
		await compare(current, old, "swatch_" + kind)
	# Reproduce the old late-ground bug with an intentionally depthless ghost.
	# This must be fixed by ground policy, not by changing this effect's depth.
	var ghost := Sprite3D.new()
	var pixels := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	ghost.texture = ImageTexture.create_from_image(pixels)
	ghost.pixel_size = 0.04
	arena.add_child(ghost)
	ghost.global_basis = camera.global_basis
	ghost.position = Vector3(0, 0.8, 0)
	var ink := ShaderMaterial.new()
	var depthless := Shader.new()
	depthless.code = load("res://shaders/dream3d/phase_dash_afterimage.gdshader").code.replace("depth_draw_opaque", "depth_draw_never")
	ink.shader = depthless
	ink.set_shader_parameter("capture_texture", ghost.texture)
	ink.set_shader_parameter("opacity", 1.0)
	ink.set_shader_parameter("band", 3.0)
	ghost.material_override = ink
	var ground := builder._material(FLOOR.floor_image("office", 0)) as ShaderMaterial
	for old_ground in [true, false]:
		var picture := await draw(legacy(ground) if old_ground else ground)
		var scale := Vector2(picture.get_size()) / root.get_visible_rect().size
		var color := picture.get_pixelv(Vector2i(camera.unproject_position(ghost.position) * scale))
		var pink := color.r > 0.7 and color.b > 0.3 and color.g < 0.4
		check(not pink if old_ground else pink, "Depthless ghost disappears on legacy ground and survives opaque ground: %s" % old_ground)
		picture.save_png(output.path_join("depthless_legacy.png" if old_ground else "depthless_opaque.png"))
	var file := FileAccess.open(output.path_join("gpu_parity.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "comparisons": metrics}, "\t"))
	file.close()
	print("SOLID_FLOOR_GPU checks=", checks, " failures=", failures.size(), " comparisons=", metrics.size())
	arena.free()
	builder.free()
	reflector.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
