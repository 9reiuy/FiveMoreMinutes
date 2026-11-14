// Regression reference for the former point-alpha blood path; never a runtime material.
shader_type spatial;
render_mode cull_disabled, fog_disabled, blend_mix, depth_prepass_alpha, diffuse_lambert, specular_disabled;

uniform sampler2D capture_texture : filter_nearest, repeat_disable;
uniform bool use_captured_alpha = true;
uniform float dark_glow_strength : hint_range(0.0, 0.6) = 0.22;
uniform float lit_glow_strength : hint_range(0.0, 1.5) = 1.0;
uniform vec4 blood_albedo : source_color = vec4(0.8509804, 0.4196078, 0.0941176, 1.0);

float bayer4(vec2 p) {
	vec2 cell = mod(floor(p), 4.0);
	float x = cell.x;
	float y = cell.y;
	if (y < 1.0) {
		if (x < 1.0) return 0.0;
		if (x < 2.0) return 8.0;
		if (x < 3.0) return 2.0;
		return 10.0;
	}
	if (y < 2.0) {
		if (x < 1.0) return 12.0;
		if (x < 2.0) return 4.0;
		if (x < 3.0) return 14.0;
		return 6.0;
	}
	if (y < 3.0) {
		if (x < 1.0) return 3.0;
		if (x < 2.0) return 11.0;
		if (x < 3.0) return 1.0;
		return 9.0;
	}
	if (x < 1.0) return 15.0;
	if (x < 2.0) return 7.0;
	if (x < 3.0) return 13.0;
	return 5.0;
}

void fragment() {
	if (use_captured_alpha) {
		float alpha = texture(capture_texture, UV).a;
		if (alpha <= (bayer4(FRAGCOORD.xy) + 0.5) / 16.0) {
			discard;
		}
	}
	ALBEDO = blood_albedo.rgb;
	ROUGHNESS = 0.9;
	EMISSION = blood_albedo.rgb * dark_glow_strength;
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.05;
}

// Add brightness only to this blood pixel and only from a light that reaches it.
// ATTENUATION includes real shadows. The separate emission floor stays readable in darkness.
void light() {
    float incidence = max(dot(NORMAL, LIGHT), 0.0);
    vec3 received = LIGHT_COLOR * (ATTENUATION * incidence / PI);
    float amount = max(received.r, max(received.g, received.b));
    float lit_gate = smoothstep(0.015, 0.20, amount);
    vec3 local_glow = min(received, vec3(1.0)) * (lit_glow_strength * lit_gate);
    DIFFUSE_LIGHT += received + local_glow;
}
