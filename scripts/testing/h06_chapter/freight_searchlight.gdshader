shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform bool pool_mode = false;
uniform vec3 beam_color : source_color = vec3(0.92, 0.97, 1.0);
uniform float intensity = 1.0;
uniform float red_ratio = 0.0;

void fragment() {
	vec3 white_beam = vec3(0.86, 0.94, 1.0);
	vec3 red_beam = vec3(1.15, 0.035, 0.018);
	float r_curve = clamp(pow(clamp(red_ratio, 0.0, 1.0), 0.62), 0.0, 1.0);
	vec3 col = mix(white_beam, red_beam, r_curve);
	float danger_pulse = 1.0 + r_curve * 0.28 * sin(TIME * 18.0);

	if (pool_mode) {
		vec2 d = UV * 2.0 - vec2(1.0);
		float r = length(d);
		float core = exp(-r * r * 3.4) * mix(0.48, 0.30, r_curve);
		float outer = (1.0 - smoothstep(0.68, 1.0, r)) * 0.20;
		float lock_ring = smoothstep(0.76, 0.82, r) * (1.0 - smoothstep(0.88, 0.94, r)) * r_curve * 0.92;
		float a = (core + outer + lock_ring) * danger_pulse * intensity;
		ALBEDO = col;
		ALPHA = clamp(a, 0.0, 0.92);
	} else {
		// UV.y = 0.0 at H06 visor emitter, 1.0 at floor target
		float along = smoothstep(0.0, 0.08, UV.y) * pow(max(0.0, 1.0 - UV.y), 0.72);
		float ndotv = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float soft_edge = pow(clamp(ndotv, 0.0, 1.0), 1.45);
		float streak = 0.88 + 0.12 * sin(UV.x * 25.1327 + TIME * 2.4);
		float a = along * soft_edge * streak * (0.24 + r_curve * 0.18) * danger_pulse * intensity;
		ALBEDO = col;
		ALPHA = clamp(a, 0.0, 0.56);
	}
}
