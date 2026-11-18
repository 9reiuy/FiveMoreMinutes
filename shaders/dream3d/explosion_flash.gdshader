shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform sampler2D flash_mask : repeat_disable, filter_nearest;
uniform float age = 0.0;
void fragment() {
	float mask = pow(texture(flash_mask, UV).r, 2.1);
	float fade = smoothstep(0.0, .008, age) * (1.0 - smoothstep(.035, .105, age));
	ALBEDO = vec3(1.0, .62, .025) * 4.0;
	ALPHA = mask * fade;
}
