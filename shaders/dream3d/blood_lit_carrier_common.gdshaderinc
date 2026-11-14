uniform sampler2D capture_texture : filter_nearest, repeat_disable;
uniform bool use_captured_alpha = true;
uniform float dark_glow_strength : hint_range(0.0, 0.6) = 0.42;
uniform float lit_glow_strength : hint_range(0.0, 1.5) = 0.0;
// Calibrated against the same mask on the approved floor's native Decal.
// Keeps the sprite carrier from overexposing relative to surface-attached blood.
uniform float blood_direct_light_strength : hint_range(0.0, 1.0) = 0.33;
uniform vec4 blood_albedo : source_color = vec4(0.8745098, 0.4549020, 0.1176471, 1.0);

float bayer4(vec2 p) {
	vec2 c = mod(floor(p), 4.0);
	if (c.y < 1.0) {
		if (c.x < 1.0) return 0.0;
		if (c.x < 2.0) return 8.0;
		return c.x < 3.0 ? 2.0 : 10.0;
	}
	if (c.y < 2.0) {
		if (c.x < 1.0) return 12.0;
		if (c.x < 2.0) return 4.0;
		return c.x < 3.0 ? 14.0 : 6.0;
	}
	if (c.y < 3.0) {
		if (c.x < 1.0) return 3.0;
		if (c.x < 2.0) return 11.0;
		return c.x < 3.0 ? 1.0 : 9.0;
	}
	if (c.x < 1.0) return 15.0;
	if (c.x < 2.0) return 7.0;
	return c.x < 3.0 ? 13.0 : 5.0;
}

float stamp_alpha(ivec2 cell, ivec2 dimensions) {
	if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, dimensions))) return 0.0;
	float alpha = texelFetch(capture_texture, cell, 0).a;
	// Fade grains belong to the captured blood texels, never the moving screen.
	if (alpha <= 0.0) return 0.0;
	if (alpha >= 1.0) return 1.0;
	return alpha > (bayer4(vec2(cell)) + 0.5) / 16.0 ? 1.0 : 0.0;
}

float blood_coverage(vec2 uv) {
	ivec2 dimensions = textureSize(capture_texture, 0);
	vec2 texel = uv * vec2(dimensions);
	vec2 footprint = abs(dFdx(texel)) + abs(dFdy(texel));
	float span = max(footprint.x, footprint.y);
	// Use the original hardware point sample at magnification, including its
	// exact texel-boundary tie behaviour; integer fetches below integrate area.
	float nearest_alpha = texture(capture_texture, uv).a;
	if (nearest_alpha > 0.0 && nearest_alpha < 1.0) {
		nearest_alpha = nearest_alpha > (bayer4(floor(texel)) + 0.5) / 16.0 ? 1.0 : 0.0;
	}
	// Magnified source pixels keep their original nearest-neighbour outline.
	if (span <= 1.0) return nearest_alpha;
	// Integrate alpha coverage only; the authored RGB and texel grid stay sharp.
	// The bound also caps work for a nearly edge-on or far-off-screen surface.
	vec2 width = clamp(footprint, vec2(0.0001), vec2(8.0));
	vec2 low = texel - width * 0.5;
	vec2 high = texel + width * 0.5;
	ivec2 first = ivec2(floor(low));
	ivec2 last = ivec2(ceil(high));
	float area = 0.0;
	for (int y = first.y; y < last.y; y++) {
		float wy = min(high.y, float(y + 1)) - max(low.y, float(y));
		for (int x = first.x; x < last.x; x++) {
			float wx = min(high.x, float(x + 1)) - max(low.x, float(x));
			area += stamp_alpha(ivec2(x, y), dimensions) * wx * wy;
		}
	}
	float coverage = clamp(area / (width.x * width.y), 0.0, 1.0);
	return mix(nearest_alpha, coverage, smoothstep(1.0, 1.125, span));
}

void fragment() {
	float coverage = use_captured_alpha ? blood_coverage(UV) : 1.0;
	if (coverage <= 0.0001) discard;
	ALBEDO = blood_albedo.rgb;
	ROUGHNESS = 0.9;
	EMISSION = blood_albedo.rgb * dark_glow_strength;
#ifdef BLOOD_GROUND_EDGE_BLEND
	// Partly covered screen pixels fade at the edge while the core stays opaque.
	// Texel fetches, fully covered pixels and the game viewport remain sharp.
	ALPHA = min(coverage / 0.76, 1.0);
#else
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.05;
#endif
}

void light() {
	float incidence = max(dot(NORMAL, LIGHT), 0.0);
	vec3 received = LIGHT_COLOR * (ATTENUATION * incidence / PI);
	float amount = max(received.r, max(received.g, received.b));
	float lit_gate = smoothstep(0.015, 0.20, amount);
	vec3 local_glow = min(received, vec3(1.0)) * (lit_glow_strength * lit_gate);
	DIFFUSE_LIGHT += received * blood_direct_light_strength + local_glow;
}
