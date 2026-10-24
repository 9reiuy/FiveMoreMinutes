shader_type spatial;
render_mode cull_disabled, depth_draw_never, shadows_disabled;
uniform float dust_clock = 0.0;
uniform vec4 dust_tint : source_color = vec4(0.58, 0.58, 0.62, 1.0);
varying float visibility;
varying float grain;
varying float glint;
void vertex() {
	// Instance X basis carries a prevalidated world-space travel segment.
	vec3 trail = MODEL_MATRIX[0].xyz;
	float life = max(2.0, length(trail) / mix(0.18, 0.28, INSTANCE_CUSTOM.y));
	float raw_phase = dust_clock / life + INSTANCE_CUSTOM.x;
	float phase = fract(raw_phase);
	float cycle = floor(raw_phase);
	float seed = INSTANCE_CUSTOM.w * 6.2831853;
	float direction = sin(cycle * 2.399 + seed) >= 0.0 ? 1.0 : -1.0;
	visibility = smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(0.86, 1.0, phase));
	grain = INSTANCE_CUSTOM.z;
	float period = mix(3.2, 7.5, INSTANCE_CUSTOM.w);
	float flash_time = mod(dust_clock + INSTANCE_CUSTOM.w * 11.31, period);
	glint = pow(max(0.0, 1.0 - abs(flash_time - period * 0.55) / 0.10), 1.2) * visibility;
	float turn = sin(phase * 3.14159265) * (0.65 + 0.35 * sin(phase * mix(3.769911, 8.796459, INSTANCE_CUSTOM.w) + seed));
	vec3 drift = trail * (phase - 0.5) * direction
		+ MODEL_MATRIX[2].xyz * turn * direction
		+ vec3(0.0, (phase - 0.5) * 0.18, 0.0);
	mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	facing[3].xyz += drift;
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	VERTEX *= mix(0.045, 0.095, grain) * (1.0 + glint * 0.20);
}
void fragment() {
	// A four-texel stepped fleck, not a soft smoke disc or screen-space overlay.
	vec2 pixel = floor(UV * 4.0);
	if (length(pixel - vec2(1.5)) > 2.0) discard;
	float threshold = mod(pixel.x * 2.0 + pixel.y * 3.0, 5.0) / 5.0;
	if (visibility * 0.85 < threshold + 0.08) discard;
	ALBEDO = mix(dust_tint.rgb * mix(0.55, 0.85, grain), vec3(0.96), glint);
	// Brief reflected glints, not Light3D nodes or permanent luminous confetti.
	vec3 flash_tint = mix(vec3(0.90, 0.96, 1.0), vec3(1.0, 0.93, 0.78), grain);
	EMISSION = dust_tint.rgb * 0.04 + flash_tint * glint * 1.4;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
