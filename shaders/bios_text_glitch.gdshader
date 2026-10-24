shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float t = clamp(progress, 0.0, 1.0);
	if (t < 0.325 || t >= 0.968) {
		COLOR = vec4(0.0);
	} else {
		float active_t = clamp((t - 0.33) / 0.50, 0.0, 1.0);
		float burst_in = 1.0 - clamp((t - 0.33) / 0.065, 0.0, 1.0);
		float collapse_t = clamp((t - 0.83) / 0.135, 0.0, 1.0);
		float tick = floor(t * 60.0);

		// 1. Clean Magnification & Slow Panning Crop of the BIOS Text Canvas:
		// Starts zoomed-in on the upper-left so left-edge prefixes are cropped off-screen,
		// and slowly pans right as t progresses (matching "a" -> "a]" -> "ua]" and "REPLIKA" -> "1F REPLIKA" -> "51F REPLIKA").
		vec2 pivot = vec2(0.08, 0.24);
		float zoom_x = mix(1.18, 1.06, smoothstep(0.0, 0.85, active_t)) + burst_in * 0.08;
		float zoom_y = mix(1.22, 1.10, smoothstep(0.0, 0.85, active_t)) + burst_in * 0.06;
		vec2 pan_uv = vec2(
			mix(0.028, 0.0, smoothstep(0.0, 0.90, active_t)),
			mix(0.010, 0.0, smoothstep(0.0, 0.90, active_t))
		);

		vec2 uv = (UV - pivot) / vec2(zoom_x, zoom_y) + pivot + pan_uv;

		// Collapse phase horizontal slice displacement & rectangular block cropping (f=153..156)
		float coarse_band = floor(uv.y * 28.0);
		float block_col = floor(uv.x * 8.0);
		float block_rng = hash21(vec2(coarse_band * 3.7 + block_col, floor(t * 30.0)));
		bool cropped_out = false;

		if (collapse_t > 0.02) {
			float tear_rng = hash21(vec2(coarse_band, tick));
			if (tear_rng > 0.45) {
				uv.x += (tear_rng - 0.5) * 0.065 * collapse_t;
			}
			// Crop away left and right sides in rectangular blocks during collapse (like f=156)
			float dist_from_mid = abs(uv.x - 0.24);
			if (dist_from_mid > (0.28 * (1.0 - collapse_t * 0.55)) && block_rng < collapse_t * 0.92) {
				cropped_out = true;
			}
			if (block_rng < collapse_t * 0.45) {
				cropped_out = true;
			}
		}

		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || cropped_out) {
			COLOR = vec4(0.0);
		} else {
			// Primary crisp text with subtle chromatic edge and initial burst smear
			vec4 main_col = texture(TEXTURE, uv);
			vec2 rgb_shift = vec2(0.0018 + 0.006 * burst_in + 0.006 * collapse_t, 0.0);
			vec4 col_r = texture(TEXTURE, clamp(uv + rgb_shift, vec2(0.0), vec2(1.0)));
			vec4 col_b = texture(TEXTURE, clamp(uv - rgb_shift * 1.25, vec2(0.0), vec2(1.0)));

			vec3 crisp_rgb = vec3(
				max(main_col.r, col_r.r * 0.72),
				main_col.g,
				max(main_col.b, col_b.b * 0.82)
			);
			float crisp_a = max(main_col.a, max(col_r.a * 0.55, col_b.a * 0.65));

			// Faint zoomed-in background ghost of the text block itself (1.12x zoom, shifted right/down)
			vec2 ghost_uv = (uv - vec2(0.10, 0.30)) / 1.12 + vec2(0.10, 0.30) - vec2(0.022, 0.008);
			vec4 ghost_sample = vec4(0.0);
			if (ghost_uv.x >= 0.0 && ghost_uv.x <= 1.0 && ghost_uv.y >= 0.0 && ghost_uv.y <= 1.0) {
				ghost_sample = texture(TEXTURE, ghost_uv);
			}
			vec3 ghost_rgb = ghost_sample.rgb * vec3(0.38, 0.58, 0.98);
			float ghost_a = ghost_sample.a * 0.24 * (1.0 - collapse_t * 0.6);

			vec3 final_rgb = max(crisp_rgb, ghost_rgb);
			float final_a = clamp(max(crisp_a, ghost_a), 0.0, 1.0);

			// Shift into deep CRT blue during final collapse (f=152..158)
			vec3 deep_crt_blue = vec3(0.14, 0.30, 0.88);
			final_rgb = mix(final_rgb, deep_crt_blue, clamp(collapse_t * 1.25, 0.0, 1.0));
			final_a *= (1.0 - smoothstep(0.45, 1.0, collapse_t));

			COLOR = vec4(final_rgb, final_a);
		}
	}
}
