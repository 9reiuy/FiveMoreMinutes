shader_type canvas_item;

// CRT power-off effect: the full screen is vertically squeezed into a
// bright horizontal line, which then collapses into a dot and fades out.
//
// progress timeline:
//   0.00 - 0.62  vertical collapse (with jitter)
//   0.62 - 0.80  white line flare
//   0.80 - 1.00  dot collapse + fade to black

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	const float LINE_Y = 0.5;
	vec3 color = vec3(0.0);

	// ── Phase A: vertical collapse ──────────────────────────────────────
	float collapse = smoothstep(0.0, 0.62, progress);
	float half_visible = 0.5 * (1.0 - collapse);
	float dy = uv.y - LINE_Y;
	if (abs(dy) <= half_visible) {
		// Inverse map: what source pixel lands at this display row.
		float src_y = LINE_Y + dy / max(1.0 - collapse, 0.0001);
		// CRT jitter while the beam is collapsing.
		float jitter = sin(progress * 420.0 + uv.x * 18.0) * collapse * 0.02;
		src_y += jitter;
		color = texture(screen_texture, vec2(uv.x, clamp(src_y, 0.0, 1.0))).rgb;
	}

	// ── Phase B: white line flare ───────────────────────────────────────
	float flare = smoothstep(0.62, 0.72, progress);
	float line_half = mix(0.030, 0.006, smoothstep(0.62, 0.80, progress));
	float line_mask = 1.0 - smoothstep(line_half, line_half + 0.014, abs(uv.y - LINE_Y));
	color = mix(color, vec3(1.0), line_mask * flare);

	// ── Phase C: dot collapse + fade ────────────────────────────────────
	float dot_t = smoothstep(0.80, 1.0, progress);
	float dot_half = mix(0.006, 0.0, dot_t);
	float dot_dist = abs(uv.x - 0.5) + abs(uv.y - LINE_Y);
	float dot_mask = 1.0 - smoothstep(dot_half, dot_half + 0.010, dot_dist);
	float dot_alpha = 1.0 - dot_t;
	color = mix(color, vec3(0.92, 0.95, 1.0), dot_mask * dot_alpha);

	// Global dim as the phosphor dies out.
	color *= 1.0 - dot_alpha * 0.45;

	COLOR = vec4(color, 1.0);
}
