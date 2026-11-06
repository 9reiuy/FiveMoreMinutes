shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

void fragment() {
	vec3 rgb = texture(screen_texture, SCREEN_UV).rgb;
	vec2 p = SCREEN_UV * 2.0 - 1.0;
	float vignette = 1.0 - smoothstep(0.42, 1.10, length(p * vec2(1.0, 0.52))) * 0.92;
	COLOR = vec4(rgb * vignette, 1.0);
}
