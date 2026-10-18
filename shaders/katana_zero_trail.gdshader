shader_type canvas_item;
render_mode unshaded;

// ============================================================
// Katana ZERO Style Dash Afterimage Shader
// 1. Dual-tone chromatic aberration (split along motion vector)
// 2. High-emission neon core (Cyan / Magenta / Violet)
// 3. Retro CRT/VHS 1px scanlines
// 4. Subtle digital slice / glitch displacement
// ============================================================

uniform vec4 primary_color : source_color = vec4(0.0, 0.95, 1.0, 1.0);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.08, 0.62, 1.0);
uniform vec2 motion_uv_dir = vec2(1.0, 0.0);
uniform float split_pixels : hint_range(0.0, 8.0) = 2.4;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.28;
uniform float glitch_slice_amount : hint_range(0.0, 8.0) = 0.0;
uniform float core_brightness : hint_range(1.0, 3.0) = 1.35;
uniform vec4 region_uv = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec2 uv = UV;

	// Micro-slice glitch displacement
	if (glitch_slice_amount > 0.05) {
		float slice_y = floor(uv.y * 24.0);
		float slice_hash = fract(sin(slice_y * 127.1) * 43758.5453);
		if (slice_hash > 0.78) {
			uv.x += (slice_hash - 0.89) * ps.x * glitch_slice_amount * 3.5;
		}
	}

	// Chromatic split offset in UV space
	vec2 offset = motion_uv_dir * ps * split_pixels;

	// 3-tap sample: leading edge, center, trailing edge
	vec2 uv_lead = uv - offset;
	vec2 uv_trail = uv + offset;
	float a_lead = (uv_lead.x < region_uv.x || uv_lead.x > region_uv.z || uv_lead.y < region_uv.y || uv_lead.y > region_uv.w) ? 0.0 : texture(TEXTURE, uv_lead).a;
	float a_center = (uv.x < region_uv.x || uv.x > region_uv.z || uv.y < region_uv.y || uv.y > region_uv.w) ? 0.0 : texture(TEXTURE, uv).a;
	float a_trail = (uv_trail.x < region_uv.x || uv_trail.x > region_uv.z || uv_trail.y < region_uv.y || uv_trail.y > region_uv.w) ? 0.0 : texture(TEXTURE, uv_trail).a;

	float total_a = max(max(a_lead, a_center), a_trail);
	if (total_a < 0.01) {
		discard;
	}

	// Katana ZERO dual-chromatic composition:
	// - Trailing edge gets secondary color (e.g. Hot Magenta)
	// - Leading edge gets primary color (e.g. Electric Cyan)
	// - Overlapping center gets hyper-bright core
	vec3 col_lead = primary_color.rgb;
	vec3 col_trail = secondary_color.rgb;
	vec3 col_center = mix(primary_color.rgb, vec3(1.0), 0.55);

	float trail_weight = max(0.0, a_trail - a_center * 0.65);
	float lead_weight = max(0.0, a_lead - a_center * 0.65);
	float center_weight = a_center;

	vec3 final_rgb = col_trail * trail_weight + col_lead * lead_weight + col_center * center_weight;
	final_rgb *= core_brightness;

	// Retro CRT scanlines: dim alternate pixel rows
	float scanline = 1.0 - scanline_strength * mod(floor(uv.y / ps.y), 2.0);
	final_rgb *= scanline;

	float final_alpha = total_a * COLOR.a * primary_color.a;

	COLOR = vec4(final_rgb, final_alpha);
}
