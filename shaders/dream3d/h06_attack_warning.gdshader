shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

// The bright contour is the damage boundary. Only its faint halo spills out.
uniform vec2 half_size = vec2(1.0);
uniform bool circular = false;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
const float MARGIN = 0.28;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * (half_size * 2.0 + vec2(MARGIN * 2.0));
	vec2 q = abs(p) - half_size;
	float distance_to_edge = circular ? length(p) - half_size.x
		: length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
	float aa = max(fwidth(distance_to_edge), 0.006);
	float inside = 1.0 - smoothstep(-aa, aa, distance_to_edge);
	float rim = 1.0 - smoothstep(0.022, 0.052 + aa, abs(distance_to_edge));
	float inner_glow = exp(-max(-distance_to_edge, 0.0) / 0.25) * inside;
	float outer_glow = exp(-max(distance_to_edge, 0.0) / 0.075) * (1.0 - inside);
	outer_glow *= 1.0 - smoothstep(0.21, MARGIN, distance_to_edge);
	float travel = circular ? length(p) / half_size.x : (p.y / half_size.y + 1.0) * 0.5;
	float fill = 1.0 - smoothstep(charge - 0.12, charge + 0.12, travel);
	float outer_ring = circular ? (1.0 - smoothstep(0.010, 0.025 + aa, abs(distance_to_edge - 0.17))) : 0.0;
	ALBEDO = vec3(1.0, 0.025, 0.012);
	EMISSION = vec3(1.0, 0.012, 0.004) * (rim * 1.65 + inner_glow * 0.48 + outer_glow * 0.55);
	ALPHA = clamp(inside * (0.045 + fill * 0.20) + inner_glow * 0.24 + rim * 0.66 + outer_glow * 0.18 + outer_ring * 0.18, 0.0, 0.94);
}
