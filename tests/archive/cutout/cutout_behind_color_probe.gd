extends SceneTree
## Minimal cutout behind-color probe for Compatibility.
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
		print("FAIL ", label)
	else:
		print("OK ", label)

func _initialize() -> void:
	call_deferred("run")

func make_shader(render_modes: String) -> Shader:
	var code := """
shader_type spatial;
render_mode %s;
global uniform vec4 occlusion_cutout_0;
global uniform vec2 occlusion_viewport_size;
uniform vec3 solid_color = vec3(0.2, 0.35, 0.9);
uniform bool use_discard = false;
float cut_f(vec2 uv) {
	vec4 slot = occlusion_cutout_0;
	if (slot.w < 0.5 || slot.z <= 0.0) { return 1.0; }
	vec2 d = (uv - slot.xy) * occlusion_viewport_size;
	float dist = length(d);
	if (dist >= slot.z) { return 1.0; }
	float nd = dist / slot.z;
	if (nd < 0.35) { return 0.0; }
	float t = (nd - 0.35) / 0.65;
	float density = 1.0 - t;
	float spacing = 6.0;
	vec2 rot = vec2(d.x*0.707-d.y*0.707, d.x*0.707+d.y*0.707);
	vec2 cell = fract(rot/spacing) - vec2(0.5);
	float hole_r = spacing * 0.45 * density;
	float hf = smoothstep(hole_r-0.6, hole_r+0.6, length(cell)*spacing);
	return max(hf, smoothstep(slot.z-2.0, slot.z, dist));
}
void fragment() {
	float f = cut_f(SCREEN_UV);
	ALBEDO = solid_color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (use_discard) {
		if (f < 0.5) { discard; }
	} else {
		ALPHA = f;
	}
}
""" % render_modes
	var shader := Shader.new()
	shader.code = code
	return shader

func add_quad(parent: Node3D, color: Color, z: float, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	mi.mesh = mesh
	if mat == null:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = color
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = sm
	else:
		mi.material_override = mat
	mi.position = Vector3(0, 0, z)
	parent.add_child(mi)
	return mi

func capture(vp: SubViewport) -> Image:
	await process_frame
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()

func avg_region(img: Image, cx: int, cy: int, r: int) -> Color:
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			sum += img.get_pixel(x, y)
			n += 1
	return sum / float(maxi(n, 1))

func run_case(mode: String, render_modes: String, use_discard: bool) -> Dictionary:
	var host := Node.new()
	root.add_child(host)
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	host.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 3)
	cam.current = true
	world.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	world.add_child(light)
	add_quad(world, Color(0.1, 0.9, 0.2), -1.0)
	var mat := ShaderMaterial.new()
	mat.shader = make_shader(render_modes)
	mat.set_shader_parameter("solid_color", Vector3(0.2, 0.35, 0.9))
	mat.set_shader_parameter("use_discard", use_discard)
	add_quad(world, Color.WHITE, 0.0, mat)
	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", Vector2(256, 256))
	RenderingServer.global_shader_parameter_set("occlusion_cutout_0", Vector4(0.5, 0.5, 48.0, 1.0))
	var img: Image = await capture(vp)
	var center := avg_region(img, 128, 128, 6)
	var rim := avg_region(img, 128, 90, 3)
	var out_path := OS.get_user_data_dir().path_join("cutout_behind_probe_%s.png" % mode)
	img.save_png(out_path)
	print("CASE ", mode, " center=", center, " rim=", rim, " saved=", out_path)
	host.queue_free()
	await process_frame
	return {"mode": mode, "center": center, "rim": rim, "path": out_path}

func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var cases: Array = []
	cases.append(await run_case("discard_opaque", "diffuse_lambert", true))
	cases.append(await run_case("alpha_blend", "blend_mix, diffuse_lambert", false))
	cases.append(await run_case("alpha_prepass", "blend_mix, depth_prepass_alpha, diffuse_lambert", false))
	for d in cases:
		var c: Color = d["center"]
		var greenish := c.g > 0.45 and c.g > c.r + 0.15 and c.g > c.b + 0.15
		var blackish := c.r + c.g + c.b < 0.12
		check(greenish, "%s hole shows behind green (not black)" % d["mode"])
		check(not blackish, "%s hole is not clear-black" % d["mode"])
	print("CUTOUT_BEHIND_PROBE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)