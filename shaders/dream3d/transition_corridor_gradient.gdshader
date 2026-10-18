shader_type spatial;

// A local, world-space endpoint fade.  It is deliberately separate from the
// map-edge mask: the transition trigger lives inside the opaque end of this
// finite plane and never depends on screen-space UI or alpha sampling.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 black_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float fade_power = 1.25;

void fragment() {
	float progress = clamp(UV.y, 0.0, 1.0);
	float alpha = pow(smoothstep(0.0, 1.0, progress), max(fade_power, 0.01));
	ALBEDO = black_color.rgb;
	ALPHA = alpha * black_color.a;
}
