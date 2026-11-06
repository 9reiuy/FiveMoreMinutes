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
	// Irradiance must stay continuous while lights accumulate. Three bands PER
	// light produced intersecting rings even with the tonal enhancement enabled
	// (authored wall materials also missed that flag). The final world palette
	// owns color quantization and its restrained ordered dither, once per pixel.
	return clamp(response, 0.0, 1.0);
}
