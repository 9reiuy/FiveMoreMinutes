shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
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

// Multi-tap radial + horizontal RGB dispersion without overexposing highlights
vec3 sample_rgb_dispersed(sampler2D tex, vec2 uv, vec2 center, float radial_amount, float horiz_amount) {
	vec2 clamped_uv = clamp(uv, vec2(0.002), vec2(0.998));
	vec2 radial_dir = clamped_uv - center;
	vec2 offset_r = radial_dir * radial_amount + vec2(horiz_amount, -radial_amount * 0.12);
	vec2 offset_b = -radial_dir * (radial_amount * 1.15) - vec2(horiz_amount * 1.10, -radial_amount * 0.12);

	vec3 c0 = texture(tex, clamped_uv).rgb;
	vec3 cr1 = texture(tex, clamp(clamped_uv + offset_r, vec2(0.002), vec2(0.998))).rgb;
	vec3 cr2 = texture(tex, clamp(clamped_uv + offset_r * 1.65, vec2(0.002), vec2(0.998))).rgb;
	vec3 cb1 = texture(tex, clamp(clamped_uv + offset_b, vec2(0.002), vec2(0.998))).rgb;
	vec3 cb2 = texture(tex, clamp(clamped_uv + offset_b * 1.65, vec2(0.002), vec2(0.998))).rgb;

	float r = cr1.r * 0.58 + cr2.r * 0.27 + c0.r * 0.15;
	float g = c0.g * 0.72 + (cr1.g + cb1.g) * 0.14;
	float b = cb1.b * 0.56 + cb2.b * 0.30 + c0.b * 0.14;
	return vec3(r, g, b);
}

void fragment() {
	float t = clamp(progress, 0.0, 1.0);
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.54, 0.48);

	if (t >= 0.965) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Phase weights:
		// 0.00 -> 0.14: initial red/crimson impact pulse + rapid zoom kick
		// 0.08 -> 0.85: continuous camera zoom-in + radial RGB dispersion + expanding double-exposure ghosts
		// 0.78 -> 0.965: deep CRT blue scanline collapse -> black screen
		float impact_pulse = sin(clamp(t / 0.15, 0.0, 1.0) * 3.14159265);
		float ghost_phase = smoothstep(0.04, 0.20, t) * (1.0 - smoothstep(0.84, 0.96, t));
		float blue_collapse = clamp((t - 0.78) / 0.185, 0.0, 1.0);

		// 1. Continuous Zoom-In on main scene (1.0x -> 1.38x)
		float main_zoom = 1.0 + 0.07 * impact_pulse + 0.34 * pow(clamp(t / 0.90, 0.0, 1.0), 0.78);
		vec2 main_uv = (uv - center) / main_zoom + center;

		// Subtle horizontal CRT band tear
		float tick = floor(t * 55.0);
		float band_idx = floor(uv.y * 42.0);
		float band_rng = hash21(vec2(band_idx, tick));
		float tear_x = 0.0;
		if (band_rng > 0.76 - 0.35 * blue_collapse) {
			tear_x = (band_rng - 0.5) * (0.014 * ghost_phase + 0.08 * blue_collapse);
		}
		main_uv.x += tear_x;

		// 2. Radial & Horizontal RGB Dispersion
		float radial_disp = 0.025 * impact_pulse + (0.045 + 0.040 * sin(t * 16.0)) * ghost_phase + 0.075 * blue_collapse;
		float horiz_disp = 0.008 * impact_pulse + 0.015 * ghost_phase + 0.032 * blue_collapse;
		vec3 main_col = sample_rgb_dispersed(screen_texture, main_uv, center, radial_disp, horiz_disp);

		// 3. Dynamic Expanding Background Ghost Layers (Double/Triple Exposure的重影放大效果)
		// Ghost 1: Medium-fast zoom (1.14x -> 1.62x), drifts right/up
		float ghost1_zoom = 1.14 + 0.48 * pow(clamp(t / 0.86, 0.0, 1.0), 0.70);
		vec2 ghost1_drift = vec2(
			-0.042 * ghost_phase + 0.010 * sin(t * 19.0),
			0.020 * ghost_phase + 0.006 * cos(t * 15.0)
		);
		vec2 ghost1_uv = (uv - center) / ghost1_zoom + center + ghost1_drift + vec2(tear_x * 1.4, 0.0);
		vec3 ghost1_col = sample_rgb_dispersed(screen_texture, ghost1_uv, center, radial_disp * 1.55, horiz_disp * 1.7);

		// Ghost 2: Wide outer phantom zoom (1.26x -> 2.05x), drifts left/down with strong red/blue split
		float ghost2_zoom = 1.26 + 0.79 * pow(clamp(t / 0.86, 0.0, 1.0), 0.82);
		vec2 ghost2_drift = vec2(
			0.048 * ghost_phase - 0.012 * cos(t * 13.0),
			-0.026 * ghost_phase + 0.008 * sin(t * 17.0)
		);
		vec2 ghost2_uv = (uv - center) / ghost2_zoom + center + ghost2_drift - vec2(tear_x * 1.2, 0.0);
		vec3 ghost2_col = sample_rgb_dispersed(screen_texture, ghost2_uv, center, radial_disp * 2.1, -horiz_disp * 1.9);
		ghost2_col *= vec3(1.12, 0.82, 1.24);

		// Energy-preserving double-exposure blend (prevents blowing out center to white!)
		vec3 ghost_mix = mix(ghost1_col, ghost2_col, 0.42);
		vec3 col = mix(main_col, max(main_col * 0.78, ghost_mix * 0.92), 0.58 * ghost_phase);
		col = mix(col, ghost_mix, 0.34 * ghost_phase);
		// Soft highlight compression so bright floor lights never clip to pure white
		col = col / (1.0 + max(vec3(0.0), col - vec3(0.62)) * 0.85);

		// 4. Reference Video Left-Side Dark Terminal Panel Contrast (f=90..150):
		// In the reference video, the left ~48% of the frame has a dark crimson/obsidian CRT shadow
		// with a vertical split transition around x = 0.44..0.58 so the white BIOS text pops cleanly.
		float terminal_phase = smoothstep(0.28, 0.36, t);
		float left_panel_mask = (1.0 - smoothstep(0.36, 0.64, uv.x)) * terminal_phase;
		col *= mix(1.0, 0.34, left_panel_mask);
		// Subtle dark-red tint near the vertical split line (like f=90..138 in reference video)
		float split_band = exp(-pow((uv.x - 0.48) / 0.11, 2.0)) * terminal_phase * (1.0 - blue_collapse);
		col += vec3(0.16, 0.02, 0.04) * split_band;

		// Initial crimson shock tint & cool-blue CRT wash
		col = mix(col, col * vec3(1.42, 0.58, 0.64) + vec3(0.12, 0.01, 0.02), 0.55 * impact_pulse);
		col = mix(col, col * vec3(0.76, 0.86, 1.18) + vec3(0.02, 0.05, 0.14), 0.32 * ghost_phase);

		// Scanlines & subtle VHS grain
		float scanline = 0.90 + 0.10 * sin(uv.y * 360.0 * 3.14159265);
		col *= scanline;
		float grain = (hash21(uv * vec2(320.0, 180.0) + vec2(tick * 1.7, tick * 3.1)) - 0.5) * (0.06 * ghost_phase + 0.12 * blue_collapse);
		col += vec3(grain * 0.5, grain * 0.6, grain);

		// 5. Final CRT deep-blue collapse -> black
		if (blue_collapse > 0.0) {
			float luma = dot(col, vec3(0.299, 0.587, 0.114));
			vec3 deep_blue = vec3(0.02, 0.06, 0.28) + vec3(0.05, 0.14, 0.58) * luma;
			col = mix(col, deep_blue, smoothstep(0.0, 0.52, blue_collapse));
			float scan_drop = step(blue_collapse * 0.82, hash21(vec2(floor(uv.y * 95.0), tick)));
			col *= mix(1.0, scan_drop, smoothstep(0.30, 0.85, blue_collapse));
			float fade_black = 1.0 - smoothstep(0.52, 1.0, blue_collapse);
			col *= fade_black;
		}

		COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
	}
}
