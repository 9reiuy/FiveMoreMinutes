// Procedural sample-only surface wear. No external game textures are used.
// The caller supplies world coordinates before any display-only vertex snap.
// Applied to ALBEDO inside the original shader, this preserves its original
// dynamic lighting, cutaway, alpha/discard rules, and depth/shadow behavior.

float hk_surface_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float hk_surface_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hk_surface_hash(cell), hk_surface_hash(cell + vec3(1.0, 0.0, 0.0)), u.x),
			mix(hk_surface_hash(cell + vec3(0.0, 1.0, 0.0)), hk_surface_hash(cell + vec3(1.0, 1.0, 0.0)), u.x), u.y),
		mix(mix(hk_surface_hash(cell + vec3(0.0, 0.0, 1.0)), hk_surface_hash(cell + vec3(1.0, 0.0, 1.0)), u.x),
			mix(hk_surface_hash(cell + vec3(0.0, 1.0, 1.0)), hk_surface_hash(cell + vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}

vec3 hk_weathered_albedo(vec3 base, vec3 world_position, float strength) {
	if (strength <= 0.0) return base;
	vec3 p = floor(world_position * 32.0 + vec3(0.0001)) / 32.0;
	float broad = hk_surface_noise(p * 0.83 + vec3(7.1, 13.8, 4.4));
	float detail = hk_surface_noise(p * 5.3 + vec3(16.4, 2.5, 8.7));
	float streak = hk_surface_noise(p * vec3(7.0, 0.48, 7.0) + vec3(3.2, 9.1, 11.7));
	float grain = hk_surface_hash(floor(p * 32.0));
	float damp = smoothstep(0.38, 0.71, broad) * (0.44 + 0.56 * detail);
	float tide = smoothstep(0.47, 0.74, streak) * smoothstep(0.40, 0.70, broad);
	float pits = step(0.80, grain) * smoothstep(0.38, 0.68, detail);
	float scuff = step(0.975, grain) * (1.0 - smoothstep(0.40, 0.67, broad));
	vec3 worn = base * (1.0 - damp * 0.53 - tide * 0.20 - pits * 0.18);
	float rust_mask = smoothstep(0.61, 0.77, broad) * smoothstep(0.39, 0.64, detail);
	float base_value = dot(base, vec3(0.2126, 0.7152, 0.0722));
	vec3 rust = vec3(0.54, 0.10, 0.17) * clamp(base_value * 1.45, 0.035, 0.7);
	worn = mix(worn, rust, rust_mask * 0.65);
	worn += vec3(0.10, 0.085, 0.12) * scuff * clamp(base_value * 2.0, 0.0, 1.0);
	return mix(base, clamp(worn, vec3(0.0), vec3(1.0)), clamp(strength, 0.0, 1.0));
}
