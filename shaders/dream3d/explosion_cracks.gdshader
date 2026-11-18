shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform sampler2D cracks : repeat_disable, filter_nearest;
uniform float age = 0.0;
void fragment() {
	float mask = pow(texture(cracks, UV).r, .80);
	float circle = 1.0 - smoothstep(.29, .49, length(UV - .5));
	float fade = smoothstep(.035, .16, age) * (1.0 - smoothstep(1.0, 2.50, age));
	vec3 color = mix(vec3(1.0, .35, .006), vec3(.9, .10, .001), smoothstep(.8, 2.0, age));
	ALBEDO = color * 4.5;
	ALPHA = min(mask * 2.2, 1.0) * circle * fade;
}
