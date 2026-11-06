shader_type canvas_item;

// The eye is rendered separately with its original mask shader and colors.
uniform float reveal_progress : hint_range(0.0, 1.1) = 1.0;
uniform float scan_y = -1.0;
uniform float effect_time = 0.0;
uniform sampler2D portrait_texture : source_color, filter_nearest, repeat_disable;

varying vec4 canvas_modulate;

void vertex() {
	canvas_modulate = COLOR;
}

float alpha_at(vec2 uv) {
	return texture(portrait_texture, clamp(uv, vec2(0.0), vec2(1.0))).a;
}

void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	float band = floor(UV.y * 135.0);
	float tick = floor(effect_time * 5.0);
	float noise = fract(sin(band * 127.1 + tick * 311.7) * 43758.5453);
	float near_beam = 1.0 - smoothstep(0.006, 0.035, abs(UV.y - scan_y));
	float glitch = step(0.91, noise) * near_beam;
	vec2 sample_uv = UV + vec2(glitch * pixel.x * 2.0, 0.0);
	vec4 source = texture(TEXTURE, sample_uv) * canvas_modulate;
	float a = source.a;
	float near_alpha = max(max(alpha_at(sample_uv + vec2(pixel.x * 3.0, 0.0)), alpha_at(sample_uv - vec2(pixel.x * 3.0, 0.0))),
		max(alpha_at(sample_uv + vec2(0.0, pixel.y * 3.0)), alpha_at(sample_uv - vec2(0.0, pixel.y * 3.0))));
	float far_alpha = max(max(alpha_at(sample_uv + vec2(pixel.x * 9.0, 0.0)), alpha_at(sample_uv - vec2(pixel.x * 9.0, 0.0))),
		max(alpha_at(sample_uv + vec2(0.0, pixel.y * 9.0)), alpha_at(sample_uv - vec2(0.0, pixel.y * 9.0))));
	float wide_alpha = max(max(alpha_at(sample_uv + vec2(pixel.x * 17.0, 0.0)), alpha_at(sample_uv - vec2(pixel.x * 17.0, 0.0))),
		max(alpha_at(sample_uv + vec2(0.0, pixel.y * 17.0)), alpha_at(sample_uv - vec2(0.0, pixel.y * 17.0))));
	float outside_glow = max(near_alpha - a, 0.0) * 0.50 + max(far_alpha - a, 0.0) * 0.15 + max(wide_alpha - a, 0.0) * 0.07;
	float inner_edge = max(a - min(min(alpha_at(sample_uv + vec2(pixel.x * 2.0, 0.0)), alpha_at(sample_uv - vec2(pixel.x * 2.0, 0.0))),
		min(alpha_at(sample_uv + vec2(0.0, pixel.y * 2.0)), alpha_at(sample_uv - vec2(0.0, pixel.y * 2.0)))), 0.0);
	float blue = smoothstep(0.055, 0.19, source.b - max(source.r, source.g));
	vec3 projection = source.b * vec3(0.42, 0.80, 0.86);
	vec3 ink = mix(source.rgb, projection, blue);
	float raster = mix(0.79, 1.0, step(0.48, fract(UV.y * 355.0)));
	float shimmer = 0.96 + 0.035 * sin(effect_time * 7.0);
	ink *= raster * shimmer;
	ink = mix(ink, vec3(0.48, 0.95, 1.0), clamp(inner_edge * 0.75 + near_beam * 0.22 * a, 0.0, 0.85));
	float glow_mix = clamp(outside_glow / max(a + outside_glow, 0.001), 0.0, 1.0);
	vec3 color = mix(ink, vec3(0.33, 0.95, 1.0), glow_mix);
	float revealed = smoothstep(-0.014, 0.012, reveal_progress - UV.y);
	COLOR = vec4(color, min(1.0, a + outside_glow) * revealed);
}
