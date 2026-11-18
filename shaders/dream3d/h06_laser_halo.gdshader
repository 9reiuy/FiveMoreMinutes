shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

varying flat float beam_length;
varying flat float beam_radius;
// Age, phase offset and intensity come from the firing ray.
instance uniform vec3 sweep = vec3(0.0, 0.0, 1.0);

void vertex() {
	vec3 center = MODELVIEW_MATRIX[3].xyz;
	vec3 along = MODELVIEW_MATRIX[1].xyz;
	vec3 to_camera = PROJECTION_MATRIX[3][3] > 0.5 ? vec3(0.0, 0.0, 1.0) : -center;
	vec3 across = cross(along, to_camera);
	across = length(across) > 0.001 ? normalize(across) : vec3(1.0, 0.0, 0.0);
	beam_length = length(along);
	beam_radius = length(MODELVIEW_MATRIX[0].xyz);
	vec3 point = center + along * VERTEX.y + across * VERTEX.x * beam_radius;
	POSITION = PROJECTION_MATRIX * vec4(point, 1.0);
}

float profile(float offset, float width) {
	float v = offset / width;
	return exp2(-v*v);
}

void fragment() {
	float x = (UV.x * 2.0 - 1.0) * beam_radius;
	float along = (1.0 - UV.y) * beam_length;
	float age = sweep.x;
	float phase = sweep.y;
	float end_distance = min(along, beam_length - along);
	float attached = smoothstep(0.0, 0.56, end_distance);
	float bend = (0.031 * sin(along * 1.88 - age * 17.0 + phase)
		+ 0.008 * sin(along * 6.4 - age * 26.0 + phase * 2.1)) * attached;
	float wave = sin(along * 2.05 - age * 23.0 + 0.54 * sin(along * 0.9 + phase));
	float pulse = smoothstep(0.24, 0.98, wave);
	float core_width = max(fwidth(x) * 0.52, 0.030 + 0.008 * pulse);
	float core = profile(x - bend, core_width);
	float filament_offset = bend + 0.115 * sin(along * 2.1 - age * 16.0 + phase) * attached;
	float filament = profile(x - filament_offset, max(0.025, fwidth(x) * 0.44)) * (0.30 + 0.70 * pulse);
	float corona = profile(x - bend, 0.196 + 0.042 * pulse);
	float air = profile(x - bend * 1.5, 0.53 + 0.07 * pulse);
	float edge = 1.0 - smoothstep(0.69, 1.0, abs(UV.x * 2.0 - 1.0));
	float core_end = smoothstep(0.0, 0.17, end_distance);
	float glow_end = smoothstep(0.0, 0.69, end_distance);
	vec3 glow = vec3(1.0, 0.175, 0.077) * filament * 0.49
		+ vec3(1.10, 0.077, 0.044) * corona * (0.47 + 0.30 * pulse)
		+ vec3(0.41, 0.021, 0.008) * air * (0.82 + 0.18 * pulse);
	ALBEDO = vec3(3.95, 2.54, 1.91) * core * core_end * (0.72 + 0.29 * pulse) + glow * glow_end;
	ALPHA = sweep.z * edge;
}
