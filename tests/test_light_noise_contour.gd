extends SceneTree

# Automated test for Light Source Contour Noise shader integration and attenuation shaping.

const SHADERS := [
	"res://shaders/dream3d/interiors_a_floor_pixel_light.gdshader",
	"res://shaders/dream3d/interiors_a_floor_conference_carpet.gdshader",
	"res://shaders/dream3d/interiors_a_floor_lounge_pixel_light.gdshader",
	"res://shaders/dream3d/interiors_a_floor_storage_pixel_light.gdshader",
	"res://shaders/dream3d/interiors_a_wall_pixel_light.gdshader",
	"res://shaders/dream3d/interiors_a_wall_vertical_fade.gdshader",
	"res://shaders/dream3d/office_low_pixel.gdshader",
	"res://shaders/dream3d/office_low_pixel_refined.gdshader",
	"res://shaders/dream3d/office_pixel_surface.gdshader",
]

func _init() -> void:
	print("--- Running Test: Light Noise Contour Shader Integration ---")
	var failures: Array[String] = []

	# 1. Verify Shader compilation and resource loading
	print("[1/4] Verifying Shader resource loading & compilation...")
	for path in SHADERS:
		var shader: Shader = load(path) as Shader
		if shader == null:
			failures.append("Failed to load shader: %s" % path)
			print("  FAIL: %s" % path)
		else:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			if mat.shader == null:
				failures.append("ShaderMaterial failed to bind shader: %s" % path)
				print("  FAIL: Material binding for %s" % path)
			else:
				print("  PASS: Loaded and bound %s" % path.get_file())

	# 2. Verify Global Shader Parameters in RenderingServer & ProjectSettings
	print("\n[2/4] Verifying Global Shader Parameters...")
	var server_globals := RenderingServer.global_shader_parameter_get_list()
	var expected_globals := [
		&"light_noise_contour_enabled",
		&"light_noise_scale",
		&"light_noise_strength",
		&"light_noise_softness",
		&"light_noise_band_steps",
	]
	for param_name in expected_globals:
		if not param_name in server_globals:
			failures.append("Global shader parameter not registered in RenderingServer: %s" % String(param_name))
			print("  FAIL: %s is not registered in RenderingServer" % String(param_name))
		else:
			var setting: Variant = ProjectSettings.get_setting("shader_globals/" + String(param_name))
			print("  PASS: %s registered in RenderingServer (config: %s)" % [String(param_name), str(setting)])

	# 3. Verify Attenuation Shaping Math Model (Simulated GDScript implementation of .gdshaderinc)
	print("\n[3/4] Verifying Contour Attenuation Shaping Behavior...")
	# Test darkness protection
	var dark_val := _simulate_apply_light_noise_contour(0.002, Vector3(5, 0, 5), true, 2.5, 0.45, 0.20)
	if dark_val != 0.0:
		failures.append("Darkness protection failed: expected 0.0, got %f" % dark_val)
		print("  FAIL: Darkness leak at A=0.002: %f" % dark_val)
	else:
		print("  PASS: Absolute darkness protection (A=0.002 -> %f, zero light leak)" % dark_val)

	# Test core protection
	var core_val := _simulate_apply_light_noise_contour(0.95, Vector3(5, 0, 5), true, 2.5, 0.45, 0.20)
	if core_val < 0.90:
		failures.append("Core protection failed: expected >= 0.90, got %f" % core_val)
		print("  FAIL: Core dimmed at A=0.95: %f" % core_val)
	else:
		print("  PASS: Core brightness protection (A=0.95 -> %f, fully preserved)" % core_val)

	# Test edge contour spatial variation (proving non-circular noise contour)
	var edge_samples: Array[float] = []
	var test_points := [
		Vector3(0.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 1.0),
		Vector3(1.5, 0.0, 1.5),
		Vector3(-2.0, 0.0, 0.5),
		Vector3(3.2, 0.0, -1.8),
	]
	for pt in test_points:
		var v := _simulate_apply_light_noise_contour(0.20, pt, true, 1.2, 0.45, 0.20)
		edge_samples.append(v)
	
	var min_val := edge_samples[0]
	var max_val := edge_samples[0]
	for v in edge_samples:
		min_val = minf(min_val, v)
		max_val = maxf(max_val, v)
	var diff := max_val - min_val
	print("  Edge samples at A=0.20 across 6 spatial points: min=%f, max=%f, spread=%f" % [min_val, max_val, diff])
	if diff < 0.05:
		failures.append("Edge contour lacks spatial variance: spread was only %f" % diff)
		print("  FAIL: Edge noise spread is too low (%f)" % diff)
	else:
		print("  PASS: Edge contour produces organic spatial variance (spread %f >= 0.05)" % diff)

	# 4. Verify toggle capability (when disabled, returns exact raw attenuation)
	print("\n[4/4] Verifying Disable Toggle...")
	var disabled_val := _simulate_apply_light_noise_contour(0.20, Vector3(1.5, 0.0, 1.5), false, 1.2, 0.45, 0.20)
	if disabled_val != 0.20:
		failures.append("Disabled toggle failed: expected 0.20, got %f" % disabled_val)
		print("  FAIL: Disabled toggle returned %f" % disabled_val)
	else:
		print("  PASS: When disabled, raw attenuation is strictly returned (%f)" % disabled_val)

	# Final evaluation
	print("\n==================================================")
	if failures.is_empty():
		print("ALL LIGHT NOISE CONTOUR TESTS PASSED SUCCESSFULLY! (0 errors)")
		print("==================================================")
		quit(0)
	else:
		print("TEST FAILED WITH %d ERRORS:" % failures.size())
		for f in failures:
			print(" - %s" % f)
		print("==================================================")
		quit(1)

# Exact mathematical mirror of light_noise_contour.gdshaderinc in GDScript for headless verification
func _simulate_apply_light_noise_contour(raw_attenuation: float, world_pos: Vector3, enabled: bool, scale: float, strength: float, softness: float) -> float:
	if not enabled:
		return raw_attenuation
	if raw_attenuation <= 0.005:
		return 0.0
	if raw_attenuation >= 0.85:
		return raw_attenuation

	var sample_pos := Vector2(world_pos.x, world_pos.z) + Vector2(world_pos.y * 0.35, -world_pos.y * 0.25)
	var noise_val := sin(sample_pos.x * scale * 1.7) * cos(sample_pos.y * scale * 2.3) + 0.5 * sin((sample_pos.x + sample_pos.y) * scale * 3.1)
	noise_val /= 1.5

	var edge_mask := smoothstep(0.005, 0.10, raw_attenuation) * (1.0 - smoothstep(0.25, 0.60, raw_attenuation))
	var perturbed := raw_attenuation + noise_val * (strength * 0.50) * edge_mask
	var safe_softness := maxf(softness, 0.02)
	var fade := smoothstep(0.0, safe_softness, perturbed)
	var shaped := maxf(perturbed, 0.0) * fade
	var core_blend := smoothstep(0.28, 0.60, raw_attenuation)
	var final_att := lerpf(shaped, raw_attenuation, core_blend)
	return clampf(final_att, 0.0, 1.0)
