// Stable surface-space ordered shading. No palette replacement or time noise.
uniform bool office_dither_enabled = true;
uniform float office_dither_step = 0.03125;
uniform bool office_tonal_sample = false;
varying vec3 office_dither_position;
varying vec3 office_dither_normal;

float office_dither_threshold(vec2 cell) {
	vec2 p = mod(floor(cell), 4.0);
	float x = p.x;
	float y = p.y;
	float v;
	if (y < 1.0) { v = x < 1.0 ? 0.0 : (x < 2.0 ? 8.0 : (x < 3.0 ? 2.0 : 10.0)); }
	else if (y < 2.0) { v = x < 1.0 ? 12.0 : (x < 2.0 ? 4.0 : (x < 3.0 ? 14.0 : 6.0)); }
	else if (y < 3.0) { v = x < 1.0 ? 3.0 : (x < 2.0 ? 11.0 : (x < 3.0 ? 1.0 : 9.0)); }
	else { v = x < 1.0 ? 15.0 : (x < 2.0 ? 7.0 : (x < 3.0 ? 13.0 : 5.0)); }
	return (v + 0.5) / 16.0;
}

float office_dither_response(float response) {
	if (office_tonal_sample) {
		// Let final color quantization own the visible steps; keep local lighting
		// mostly continuous instead of quantizing every light independently.
		float value = clamp(response, 0.0, 1.0);
		return mix(value, floor(value * 12.0 + 0.5) / 12.0, 0.15);
	}
	vec3 n = abs(office_dither_normal);
	vec2 plane = n.y > max(n.x, n.z) ? office_dither_position.xz : (n.x > n.z ? office_dither_position.zy : office_dither_position.xy);
	float scaled = clamp(response, 0.0, 1.0) * 3.0;
	float coverage = smoothstep(0.30, 0.70, fract(scaled));
	return (floor(scaled) + step(office_dither_threshold(plane / office_dither_step), coverage)) / 3.0;
}
