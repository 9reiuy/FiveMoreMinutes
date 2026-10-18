// light_noise_contour.gdshaderinc
// Universal light contour noise shaping for retro 3D pixel lighting in Godot Compatibility mode.

global uniform bool light_noise_contour_enabled;
global uniform float light_noise_scale;
global uniform float light_noise_strength;
global uniform float light_noise_softness;
global uniform float light_noise_band_steps;

vec3 _lnc_mod289_3(vec3 x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec2 _lnc_mod289_2(vec2 x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 _lnc_permute(vec3 x) {
	return _lnc_mod289_3(((x * 34.0) + 1.0) * x);
}

float lnc_simplex_2d(vec2 v) {
	const vec4 C = vec4(
		0.211324865405187,  // (3.0 - sqrt(3.0)) / 6.0
		0.366025403784439,  // 0.5 * (sqrt(3.0) - 1.0)
		-0.577350269189626, // -1.0 + 2.0 * C.x
		0.024390243902439   // 1.0 / 41.0
	);
	vec2 i  = floor(v + dot(v, C.yy));
	vec2 x0 = v - i + dot(i, C.xx);
	vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;
	i = _lnc_mod289_2(i);
	vec3 p = _lnc_permute(_lnc_permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
	vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
	m = m * m;
	m = m * m;
	vec3 x = 2.0 * fract(p * C.www) - 1.0;
	vec3 h = abs(x) - 0.5;
	vec3 ox = floor(x + 0.5);
	vec3 a0 = x - ox;
	m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
	vec3 g;
	g.x  = a0.x  * x0.x  + h.x  * x0.y;
	g.yz = a0.yz * x12.xz + h.yz * x12.yw;
	return 130.0 * dot(m, g);
}

float lnc_fbm_2d(vec2 p) {
	float n = lnc_simplex_2d(p);
	n += 0.5 * lnc_simplex_2d(p * 2.02 + vec2(1.7, 4.3));
	return n / 1.5;
}

float apply_light_noise_contour(float raw_attenuation, vec3 world_pos) {
	if (!light_noise_contour_enabled) {
		return raw_attenuation;
	}
	// Absolute dark protection: never leak light into unlit areas or full shadows
	if (raw_attenuation <= 0.005) {
		return 0.0;
	}
	// Core brightness protection: preserve full clarity in the center of the light
	if (raw_attenuation >= 0.85) {
		return raw_attenuation;
	}

	// 2D world-space noise sampling (XZ plane for ground, combined with Y for vertical walls)
	vec2 sample_pos = world_pos.xz + vec2(world_pos.y * 0.35, -world_pos.y * 0.25);
	float scale = max(light_noise_scale, 0.1);
	float noise_val = lnc_fbm_2d(sample_pos * scale);

	// Edge modulation mask: focused on the outer falloff rim (0.005 - 0.60).
	// The interior core of the light (>= 0.60) stays completely smooth and clean.
	float edge_mask = smoothstep(0.005, 0.10, raw_attenuation) * (1.0 - smoothstep(0.25, 0.60, raw_attenuation));
	
	// Perturb raw attenuation with noise
	float perturbed = raw_attenuation + noise_val * (light_noise_strength * 0.50) * edge_mask;

	// Soft transition near zero: feather smoothly into darkness
	float softness = max(light_noise_softness, 0.02);
	float fade = smoothstep(0.0, softness, perturbed);
	float shaped = max(perturbed, 0.0) * fade;
	
	// Smoothly blend back to raw attenuation as we transition from perimeter to core (0.28 -> 0.60)
	float core_blend = smoothstep(0.28, 0.60, raw_attenuation);
	float final_att = mix(shaped, raw_attenuation, core_blend);

	// Optional posterized banding (if steps >= 2.0)
	if (light_noise_band_steps >= 2.0) {
		float bands = light_noise_band_steps;
		float stepped = floor(final_att * bands + 0.5) / bands;
		final_att = mix(final_att, stepped, 0.30);
	}

	return clamp(final_att, 0.0, 1.0);
}
