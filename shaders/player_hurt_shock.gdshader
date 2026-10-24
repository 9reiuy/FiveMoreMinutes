shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float strength = 0.0;
uniform float distort_strength = 1.0;
uniform float phase = 0.0;
uniform vec2 hit_center = vec2(0.5);
void fragment() {
	// Full-world transient CRT-like punch, AFTER the palette. No HUD is sampled.
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float radial = dot(centered, centered);
	float edge = smoothstep(0.20, 1.35, radial);
	vec2 warp = centered * radial * 0.022;
	warp += vec2(sin(centered.y * 9.0 + phase * 12.0), 0.0) * 0.003;
	warp += (SCREEN_UV - hit_center) * 0.012;
	vec2 uv = clamp(SCREEN_UV + warp * strength * distort_strength, vec2(0.001), vec2(0.999));
	vec2 direction = normalize(centered + vec2(0.001));
	vec2 shift = direction * SCREEN_PIXEL_SIZE * (2.0 + 4.0 * edge) * strength;
	vec4 source = texture(screen_texture, uv);
	source.r = texture(screen_texture, clamp(uv + shift,vec2(0.001),vec2(0.999))).r;
	source.b = texture(screen_texture, clamp(uv - shift,vec2(0.001),vec2(0.999))).b;
	source.rgb *= 1.0 - 0.52 * edge * strength;
	COLOR = source;
}
