shader_type canvas_item;

uniform sampler2D scene_screen : hint_screen_texture, repeat_disable, filter_nearest;
uniform float curvature : hint_range(0.0, 0.12) = 0.042;

void fragment() {
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	vec2 bent = centered * (1.0 + curvature * vec2(centered.y * centered.y, centered.x * centered.x));
	vec2 sample_uv = bent * 0.5 + 0.5;
	float inside = step(0.0, sample_uv.x) * step(sample_uv.x, 1.0) * step(0.0, sample_uv.y) * step(sample_uv.y, 1.0);
	vec3 scene = texture(scene_screen, clamp(sample_uv, vec2(0.0), vec2(1.0))).rgb;
	float vignette = smoothstep(0.32, 1.38, dot(centered, centered));
	float line = mix(0.955, 1.0, step(0.46, fract(SCREEN_UV.y / SCREEN_PIXEL_SIZE.y * 0.5)));
	COLOR = vec4(mix(scene * line * (1.0 - vignette * 0.31), vec3(0.004, 0.014, 0.019), 1.0 - inside), 1.0);
}
