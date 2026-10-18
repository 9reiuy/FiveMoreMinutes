shader_type canvas_item;

// Reference death sequence shader (SIGNALIS / VLNK_BIOS style):
//   0.00 - 0.06  Crimson fatal-hit flash into VHS/CRT desync
//   0.06 - 0.38  Double-exposure ghosting, RGB split, blue/red grading, cyan proxy wake surge
//   0.38 - 0.82  Corrupted live feed with dark left-side terminal vignette for BIOS error readout
//   0.82 - 0.95  Deep cobalt-blue CRT signal collapse with horizontal scanline slicing
//   0.95 - 1.00  Final phosphor horizontal streak fade to 100% pure black

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash11(float p) {
	return fract(sin(p * 127.1) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = clamp(progress, 0.0, 1.0);

	if (t >= 0.995) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		float time_seed = floor(t * 60.0);

		// Horizontal VHS tracking slices & scanline tear
		float band_y = floor(uv.y * 42.0);
		float band_rnd = hash12(vec2(band_y, time_seed));
		float slice_active = step(0.76, band_rnd);
		float tear_strength = mix(0.014, 0.028, smoothstep(0.25, 0.88, t));
		float x_jitter = (band_rnd - 0.5) * tear_strength * slice_active;
		x_jitter += sin(uv.y * 95.0 + t * 85.0) * 0.0025;

		// Collapse phase horizontal displacement
		float collapse_phase = smoothstep(0.80, 0.96, t);
		x_jitter += (hash12(vec2(floor(uv.y * 90.0), time_seed * 1.7)) - 0.5) * 0.065 * collapse_phase;

		vec2 main_uv = clamp(uv + vec2(x_jitter, 0.0), vec2(0.001), vec2(0.999));

		// Chromatic aberration (RGB split) on primary image
		float chroma = mix(0.006, 0.015, smoothstep(0.0, 0.75, t)) + collapse_phase * 0.012;
		vec3 base_col;
		base_col.r = texture(screen_texture, clamp(main_uv + vec2(chroma, 0.0), vec2(0.001), vec2(0.999))).r;
		base_col.g = texture(screen_texture, main_uv).g;
		base_col.b = texture(screen_texture, clamp(main_uv - vec2(chroma, 0.0), vec2(0.001), vec2(0.999))).b;

		// Double-exposure ghost layer (shifted, slightly zoomed & warped copy as seen in reference video)
		float ghost_drift = sin(t * 9.0) * 0.008;
		vec2 ghost_uv = (uv - 0.5) * 0.88 + 0.5 + vec2(-0.048 + ghost_drift, 0.026 - ghost_drift * 0.5);
		ghost_uv = clamp(ghost_uv + vec2(x_jitter * 0.6, 0.0), vec2(0.001), vec2(0.999));
		vec3 ghost_col;
		ghost_col.r = texture(screen_texture, clamp(ghost_uv + vec2(chroma * 1.4, -0.004), vec2(0.001), vec2(0.999))).r;
		ghost_col.g = texture(screen_texture, ghost_uv).g;
		ghost_col.b = texture(screen_texture, clamp(ghost_uv - vec2(chroma * 1.4, 0.004), vec2(0.001), vec2(0.999))).b;

		// Blend primary and double-exposure ghost
		vec3 combined = mix(base_col, ghost_col, 0.42);

		// Grade into corrupted CRT blue/indigo shadows + crimson/amber highlights
		float luma = dot(combined, vec3(0.299, 0.587, 0.114));
		float red_dominance = clamp((combined.r - max(combined.g, combined.b)) * 2.4, 0.0, 1.0);
		vec3 cold_grade = mix(
			vec3(0.04, 0.07, 0.24),
			vec3(0.56, 0.64, 0.86),
			 clamp(pow(luma, 0.85) * 1.25, 0.0, 1.0)
		);
		vec3 graded = mix(cold_grade, combined * vec3(1.15, 0.88, 1.25), 0.52);
		// Preserve vivid crimson blood / red highlights
		graded = mix(graded, vec3(0.88, 0.10, 0.14), red_dominance * 0.65);

		// Initial fatal hit crimson flash (0.00 - 0.07)
		float hit_flash = 1.0 - smoothstep(0.0, 0.07, t);
		graded = mix(graded, vec3(0.82, 0.09, 0.12) + base_col * 0.35, hit_flash * 0.62);

		// Proxy chip awakening surge (around t = 0.24 - 0.40, matching frames 72..90)
		float wake_pulse = smoothstep(0.20, 0.31, t) * (1.0 - smoothstep(0.31, 0.42, t));
		float radial_pulse = 1.0 - smoothstep(0.0, 0.55, distance(uv, vec2(0.56, 0.48)));
		graded += vec3(0.18, 0.38, 0.68) * wake_pulse * (0.35 + radial_pulse * 0.55);

		// Left-side dark vignette for BIOS terminal legibility (ramps in as text starts at t ~ 0.34)
		float text_backdrop = smoothstep(0.32, 0.42, t);
		float left_mask = 1.0 - smoothstep(0.08, 0.82, uv.x);
		float top_mask = 1.0 - smoothstep(0.15, 0.92, uv.y);
		float terminal_shade = clamp(left_mask * 0.78 + left_mask * top_mask * 0.18, 0.0, 0.88);
		graded *= 1.0 - text_backdrop * terminal_shade;

		// CRT horizontal scanlines + fine vertical aperture grill
		float scanline = 0.5 + 0.5 * sin(uv.y * 360.0 * 3.14159265 * 2.0);
		graded *= mix(1.0, 0.78, scanline);
		float grain = (hash12(uv * vec2(640.0, 360.0) + vec2(time_seed * 7.1, time_seed * 3.3)) - 0.5) * 0.07;
		graded += vec3(grain * 0.6, grain * 0.7, grain);

		// Bottom corrupted magenta/red VHS tracking bar (visible in frames 42..138)
		if (uv.y > 0.968 && t < 0.82) {
			float bar_mask = step(0.28, uv.x) * step(uv.x, 0.88);
			float bar_flicker = 0.65 + 0.35 * sin(uv.x * 180.0 + t * 90.0);
			graded = mix(graded, vec3(0.85, 0.22, 0.32) * bar_flicker, bar_mask * 0.75);
		}

		// Phase 3: Deep CRT cobalt-blue signal collapse into pure black (0.82 - 1.00)
		if (t > 0.80) {
			float blue_shift = smoothstep(0.80, 0.90, t);
			vec3 deep_blue = vec3(0.02, 0.05, 0.28) + graded * vec3(0.12, 0.20, 0.65);
			// Horizontal blanking bands eating away the picture
			float slice_blank = step(hash12(vec2(floor(uv.y * 55.0), time_seed * 2.3)), smoothstep(0.82, 0.95, t) * 0.85);
			deep_blue *= (1.0 - slice_blank * 0.75);
			graded = mix(graded, deep_blue, blue_shift);

			float black_fade = smoothstep(0.86, 0.975, t);
			graded *= (1.0 - black_fade);

			// Final lingering horizontal CRT phosphor streaks near bottom (matching frames 165..174)
			float streak_phase = smoothstep(0.88, 0.93, t) * (1.0 - smoothstep(0.94, 0.995, t));
			float streak1 = exp(-pow((uv.y - 0.83) * 110.0, 2.0)) * step(uv.x, 0.62);
			float streak2 = exp(-pow((uv.y - 0.90) * 90.0, 2.0)) * step(uv.x, 0.74);
			graded += vec3(0.14, 0.22, 0.42) * (streak1 * 0.85 + streak2 * 0.55) * streak_phase;
		}

		COLOR = vec4(clamp(graded, vec3(0.0), vec3(1.0)), 1.0);
	}
}

