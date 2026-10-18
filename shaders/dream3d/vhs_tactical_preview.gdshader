shader_type canvas_item;

// Katana Zero style VHS / CRT tactical rewind & pre-calculation preview shader
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_count : hint_range(50.0, 800.0) = 280.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.16;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.60;
uniform float aberration_amount : hint_range(0.0, 0.02) = 0.003;
uniform float tape_noise_intensity : hint_range(0.0, 1.0) = 0.06;
uniform vec4 tint_color : source_color = vec4(0.92, 0.96, 1.0, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;

	// Subtle VHS tracking jitter on scanlines
	float jitter = sin(TIME * 25.0 + uv.y * 30.0) * aberration_amount * 0.35;

	// Chromatic aberration (RGB split)
	float r = texture(screen_texture, vec2(uv.x + aberration_amount + jitter, uv.y)).r;
	float g = texture(screen_texture, vec2(uv.x + jitter * 0.5, uv.y)).g;
	float b = texture(screen_texture, vec2(uv.x - aberration_amount, uv.y)).b;
	vec3 color = vec3(r, g, b) * tint_color.rgb;

	// Horizontal CRT scanlines
	float scanline = sin(uv.y * scanline_count * 3.14159 * 2.0) * 0.5 + 0.5;
	color -= color * scanline * scanline_intensity;

	// Vignette around screen edges
	vec2 uv_vignette = (uv - 0.5) * 2.0;
	float vig = clamp(dot(uv_vignette, uv_vignette) * 0.35 * vignette_intensity, 0.0, 1.0);
	color = mix(color, color * 0.40, vig);

	// Subtle tape noise
	float noise = fract(sin(dot(uv + vec2(fract(TIME * 43.12), fract(TIME * 19.34)), vec2(12.9898, 78.233))) * 43758.5453);
	color += (noise - 0.5) * tape_noise_intensity;

	COLOR = vec4(color, 1.0);
}
