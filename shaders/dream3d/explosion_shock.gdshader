shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform sampler2D cloud_noise : repeat_enable, filter_nearest;
uniform sampler2D heat_noise : repeat_enable, filter_nearest;
uniform float phase = 0.0;
varying float bottom_cap;
void vertex() { bottom_cap = step(.99, -NORMAL.y); }
void fragment() {
	if (bottom_cap > .5) { discard; }
	float n = texture(cloud_noise, UV * vec2(2.0, .8) + vec2(phase * .08, -phase * .55)).r;
	float torn = texture(heat_noise, UV * vec2(1.2, 1.7) + vec2(0.0, -phase * .57)).r;
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
	float wave = rim * smoothstep(.20, .62, torn) * (.65 + n * .6);
	float fade = smoothstep(0.0, .09, phase) * (1.0 - smoothstep(.42, 1.0, phase));
	// Forward+ unshaded output is ALBEDO; EMISSION is not added in that path.
	ALBEDO = vec3(1.0, .48, .006) * 24.0;
	ALPHA = wave * fade * .95;
}
