extends Node
## Independent stepped-light / ordered-dither experiment. Cached assets untouched.
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const SURFACE = preload("res://shaders/dream3d/office_pixel_surface.gdshader")
var world: Node3D
var mode := 2
var grid_step := 1.0 / 32.0
var copies: Dictionary = {}
var bindings: Array = []
var lights: Dictionary = {}
var label: Label
var preview_shader: Shader
var shader_copies: Dictionary = {}
var old_mute := false
var positional_quality: int
var directional_quality: int
var scan_left := 0.0

func _ready() -> void:
	positional_quality = int(ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 1))
	directional_quality = int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 1))
	old_mute = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)
	preview_shader = Shader.new()
	var code := SURFACE.code
	code = code.replace("varying vec3 pattern_position;", "uniform int preview_mode = 0;\nuniform float preview_step = 0.0625;\nvarying vec3 preview_world_normal;\nvarying vec3 pattern_position;")
	code = code.replace("void vertex() {", "void vertex() {\n preview_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);")
	code = code.replace("void light() {", """// A fixed, ordered 4x4 Bayer matrix. No time/noise or texture recoloring.
float preview_threshold(vec2 cell) {
	vec2 p = mod(floor(cell), 4.0);
	float x = p.x;
	float y = p.y;
	float value = 0.0;
	if (y < 1.0) { value = x < 1.0 ? 0.0 : (x < 2.0 ? 8.0 : (x < 3.0 ? 2.0 : 10.0)); }
	else if (y < 2.0) { value = x < 1.0 ? 12.0 : (x < 2.0 ? 4.0 : (x < 3.0 ? 14.0 : 6.0)); }
	else if (y < 3.0) { value = x < 1.0 ? 3.0 : (x < 2.0 ? 11.0 : (x < 3.0 ? 1.0 : 9.0)); }
	else { value = x < 1.0 ? 15.0 : (x < 2.0 ? 7.0 : (x < 3.0 ? 13.0 : 5.0)); }
	return (value + 0.5) / 16.0;
}
void light() {
""")
	code = code.replace("DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * noisy_attenuation * n_dot_l / PI;", """float shade = noisy_attenuation * n_dot_l;
	if (preview_mode != 0) {
		// ATTENUATION includes real shadow visibility. Quantize the combined
		// diffuse response, not just the shadow filter or surface texture.
		shade = clamp(ATTENUATION * n_dot_l, 0.0, 1.0);
		vec3 n = abs(preview_world_normal);
		vec2 plane = n.y > max(n.x, n.z) ? architecture_world.xz : (n.x > n.z ? architecture_world.zy : architecture_world.xy);
		float scaled = shade * 3.0;
		float threshold = preview_mode == 2 ? preview_threshold(plane / preview_step) : 0.5;
		float coverage = smoothstep(0.30, 0.70, fract(scaled));
		shade = (floor(scaled) + step(threshold, coverage)) / 3.0;
	}
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * shade / PI;
""")
	# Runtime shaders need absolute include paths (the original shader has them).
	preview_shader.code = code
	world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.use_authored_office_sample = true
	add_child(world)
	world.regenerate(42001)
	for room in world.rooms:
		if String(room.get("archetype", "")) == "open_office":
			world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
			world.activate_room(int(room.id))
			break
	world.player.invulnerability_left = 100000.0
	world.player_has_left_elevator_cab = true
	world.night_lighting.set_flashlight_enabled(false)
	var ui := CanvasLayer.new()
	ui.layer = 110
	add_child(ui)
	label = Label.new()
	label.position = Vector2(10, 10)
	label.add_theme_font_size_override("font_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(label)
	_scan(world)
	_refresh()

func _process(delta: float) -> void:
	# Catch new/destroyed doors, debris, and cross-floor replacement meshes.
	scan_left -= delta
	if scan_left <= 0.0:
		scan_left = 0.25
		_scan(world)

func _scan(node: Node) -> void:
	if node is Light3D and not lights.has(node):
		lights[node] = [node.shadow_blur, node.light_size, node.light_angular_distance]
		_set_light(node)
	if node is MeshInstance3D and node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		if node.material_override != null:
			var replacement := _copy(node.material_override)
			if replacement != node.material_override:
				bindings.append([node, -1, node.material_override])
				node.material_override = replacement
		elif node.mesh != null:
			for index in node.mesh.get_surface_count():
				var original: Material = node.get_active_material(index)
				var replacement := _copy(original)
				if replacement != original:
					bindings.append([node, index, node.get_surface_override_material(index)])
					node.set_surface_override_material(index, replacement)
	for child in node.get_children():
		_scan(child)

func _copy(material: Material) -> Material:
	if not material is ShaderMaterial or material.shader == null:
		return material
	var path: String = material.shader.resource_path
	var supported: bool = path.get_file() in ["office_pixel_surface.gdshader", "office_surface.gdshader", "office_low_pixel.gdshader", "office_low_pixel_refined.gdshader", "office_detail_atlas.gdshader"] or path.get_file().begins_with("interiors_a_floor_")
	if not supported:
		return material
	if not copies.has(material):
		var duplicate: ShaderMaterial = material.duplicate()
		duplicate.shader = preview_shader if material.shader == SURFACE else _build_variant(material.shader)
		# Changing shader resources can drop texture/uniform bindings. Copy every
		# original uniform explicitly, not just base_color (atlas materials differ).
		for uniform in material.shader.get_shader_uniform_list():
			var value: Variant = material.get_shader_parameter(uniform.name)
			if value != null:
				duplicate.set_shader_parameter(uniform.name, value)
		copies[material] = duplicate
		_set_material(duplicate)
	return copies[material]

func _build_variant(source: Shader) -> Shader:
	if shader_copies.has(source):
		return shader_copies[source]
	var code := source.code
	var start := code.find("void light() {")
	var original := "DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * max(dot(NORMAL, LIGHT), 0.0) / PI;"
	if start >= 0:
		# Supported environment shaders have light() as their final function.
		original = code.substr(start + "void light() {".length()).strip_edges().trim_suffix("}")
		code = code.substr(0, start)
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform int preview_mode = 0;\nuniform float preview_step = 0.0625;\nvarying vec3 preview_position;\nvarying vec3 preview_normal;")
	var vertex := "preview_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; preview_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);"
	if code.contains("void vertex() {"):
		code = code.replace("void vertex() {", "void vertex() {\n" + vertex)
	else:
		code += "\nvoid vertex() {" + vertex + "}\n"
	var helper_start := preview_shader.code.find("float preview_threshold")
	var helper_end := preview_shader.code.find("void light() {", helper_start)
	code += preview_shader.code.substr(helper_start, helper_end - helper_start)
	code += """void light() {
	if (preview_mode == 0) {
""" + original + """
	} else {
		float shade = clamp(ATTENUATION * max(dot(NORMAL, LIGHT), 0.0), 0.0, 1.0);
		vec3 n = abs(preview_normal);
		vec2 plane = n.y > max(n.x, n.z) ? preview_position.xz : (n.x > n.z ? preview_position.zy : preview_position.xy);
		float scaled = shade * 3.0;
		float threshold = preview_mode == 2 ? preview_threshold(plane / preview_step) : 0.5;
		float coverage = smoothstep(0.30, 0.70, fract(scaled));
		shade = (floor(scaled) + step(threshold, coverage)) / 3.0;
		DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * shade / PI;
	}
}
"""
	var shader := Shader.new()
	shader.code = code
	shader_copies[source] = shader
	return shader

func _set_material(material: ShaderMaterial) -> void:
	material.set_shader_parameter("preview_mode", mode)
	material.set_shader_parameter("preview_step", grid_step)

func _set_light(light: Light3D) -> void:
	# Preserve real penumbra for ordered coverage at the cast-shadow transition.
	light.shadow_blur = lights[light][0]
	light.light_size = lights[light][1]
	light.light_angular_distance = lights[light][2]

func _refresh() -> void:
	RenderingServer.positional_soft_shadow_filter_set_quality(positional_quality)
	RenderingServer.directional_soft_shadow_filter_set_quality(directional_quality)
	for material in copies.values():
		_set_material(material)
	for light in lights:
		if is_instance_valid(light):
			_set_light(light)
	if label != null:
		label.text = "1 Original / 2 Shade steps / 3 Dither   [ / ] Grid\n%s | grid 1/%d | muted | independent sample" % [["Original", "Shade steps", "Ordered dither"][mode], roundi(1.0 / grid_step)]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_1, KEY_2, KEY_3]:
		mode = event.keycode - KEY_1
	elif event.keycode == KEY_BRACKETLEFT:
		grid_step = maxf(grid_step * 0.5, 1.0 / 128.0)
	elif event.keycode == KEY_BRACKETRIGHT:
		grid_step = minf(grid_step * 2.0, 0.25)
	else:
		return
	_refresh()
	get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	RenderingServer.positional_soft_shadow_filter_set_quality(positional_quality)
	RenderingServer.directional_soft_shadow_filter_set_quality(directional_quality)
	AudioServer.set_bus_mute(0, old_mute)
	for light in lights:
		if is_instance_valid(light):
			light.shadow_blur = lights[light][0]
			light.light_size = lights[light][1]
			light.light_angular_distance = lights[light][2]
	for binding in bindings:
		if is_instance_valid(binding[0]):
			if binding[1] == -1:
				binding[0].material_override = binding[2]
			else:
				binding[0].set_surface_override_material(binding[1], binding[2])
