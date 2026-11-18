shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec2 zone_size = vec2(6.0, 4.0);
uniform bool curtain_mode = false;
uniform float pulse_speed = 4.2;
uniform float intensity = 1.0;

void fragment() {
	vec3 neon_red = vec3(1.05, 0.11, 0.06);
	vec3 hot_core = vec3(1.25, 0.28, 0.12);
	float pulse = 0.88 + 0.12 * sin(TIME * pulse_speed);

	if (curtain_mode) {
		// Vertical holographic projector wall: UV.y = 0.0 at ground contact, 1.0 skyward fadeout
		float h = clamp(UV.y, 0.0, 1.0);
		float contact = exp(-h * 6.5) * 0.42;
		float veil = pow(max(0.0, 1.0 - h), 1.8) * 0.19;
		float rays = 0.72 + 0.28 * sin((UV.x * 14.0 - h * 2.2) * 3.14159);
		float v_scan = 0.90 + 0.10 * sin(h * 26.0 - TIME * 5.0);
		float a = (contact + veil * rays) * v_scan * pulse * intensity;
		ALBEDO = mix(neon_red, hot_core, contact * 1.1);
		ALPHA = clamp(a, 0.0, 0.52);
	} else {
		// Ground projection pad matching ref art: outer dashed line, 45-deg warning stripes, inner dashed line, hollow center
		vec2 p = UV * zone_size;
		float dx = min(p.x, zone_size.x - p.x);
		float dz = min(p.y, zone_size.y - p.y);
		float d = min(dx, dz);

		// Proportionally narrow perimeter border on tight strips (< 3.2m) so interior remains clear
		float bscale = clamp(min(zone_size.x, zone_size.y) / 3.2, 0.52, 1.0);
		float db = d / bscale;

		// Use abs(fract(...) - 0.5) for continuous seam-free anti-aliased dashes and diagonal stripes
		float perim_u = (dx < dz) ? p.y : p.x;
		float outer_dash = 1.0 - smoothstep(0.28, 0.33, abs(fract(perim_u * 1.35) - 0.5));
		float inner_dash = 1.0 - smoothstep(0.28, 0.33, abs(fract(perim_u * 1.55 + 0.25) - 0.5));

		float outer_ring = (1.0 - smoothstep(0.045, 0.072, db)) * outer_dash;
		float band_mask = smoothstep(0.11, 0.14, db) * (1.0 - smoothstep(0.44, 0.48, db));
		float chevron = (1.0 - smoothstep(0.22, 0.26, abs(fract((p.x + p.y) * 1.12) - 0.5))) * band_mask;
		float inner_ring = smoothstep(0.52, 0.55, db) * (1.0 - smoothstep(0.59, 0.62, db)) * inner_dash;

		// Faint rim glow restricted to the border zone so the center grating/abyss stays unobstructed
		float rim_glow = (1.0 - smoothstep(0.0, 0.72, db)) * 0.08;
		float line_hit = max(outer_ring * 0.96, max(chevron * 0.92, inner_ring * 0.90));
		float alpha = (line_hit + rim_glow) * pulse * intensity;
		ALBEDO = mix(neon_red, hot_core, line_hit * 0.45);
		ALPHA = clamp(alpha, 0.0, 0.94);
	}
}
