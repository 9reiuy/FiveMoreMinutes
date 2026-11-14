shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 gun_smoke : source_color = vec4(0.72, 0.70, 0.68, 1.0);
uniform vec4 contact_dust : source_color = vec4(0.66, 0.625, 0.565, 1.0);
uniform vec4 glass_dust : source_color = vec4(0.68, 0.727, 0.775, 1.0);

varying flat vec4 particle;

void vertex() {
	particle = INSTANCE_CUSTOM;
	vec2 size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	vec3 center = MODELVIEW_MATRIX[3].xyz;
	MODELVIEW_MATRIX = mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0), vec4(center, 1.0));
	VERTEX.xy *= size;
}

float smoke_lobe(vec2 p, vec2 center, vec2 radius) {
	float distance_to_center = length((p - center) / radius);
	return pow(max(1.0 - distance_to_center, 0.0), 1.1);
}

void fragment() {
	float phase = particle.x;
	float turn = particle.y * 6.283185 + phase * 0.48;
	mat2 rotation = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn)));
	vec2 p = (UV * 2.0 - 1.0) * rotation;
	p += vec2(sin(p.y * 6.8 + turn), cos(p.x * 7.2 - turn)) * (0.085 + phase * 0.055);
	float body = smoke_lobe(p, vec2(-0.11, -0.06), vec2(0.78, 0.79));
	float billow_a = smoke_lobe(p, vec2(0.31, -0.21), vec2(0.54, 0.62));
	float billow_b = smoke_lobe(p, vec2(0.17, 0.34), vec2(0.66, 0.53));
	float billow_c = smoke_lobe(p, vec2(-0.43, 0.27), vec2(0.44, 0.55));
	float ripples = 0.90 + 0.10 * cos(p.x * 13.1 + sin(p.y * 9.5) + turn);
	float density = clamp(body * 0.89 + billow_a * 0.67 + billow_b * 0.72 + billow_c * 0.52, 0.0, 1.0);
	float rise = mix(0.40, 1.0, smoothstep(0.0, 0.20, phase));
	float dissipate = pow(max(1.0 - phase, 0.0), 1.25);
	vec3 tone = mix(gun_smoke.rgb, contact_dust.rgb, smoothstep(0.0, 0.54, particle.z));
	tone = mix(tone, glass_dust.rgb, smoothstep(0.54, 1.0, particle.z));
	vec3 hot_haze = gun_smoke.rgb * vec3(1.53, 1.25, 0.95);
	float afterglow = exp(-phase * 12.0) * (1.0 - smoothstep(0.0, 0.54, particle.z));
	tone = mix(tone, hot_haze, afterglow * 0.63);
	ALBEDO = tone * mix(0.68, 1.12, clamp(density + phase * 0.18, 0.0, 1.0));
	ALPHA = density * ripples * rise * dissipate * particle.w;
	if (ALPHA < 0.006) { discard; }
}
