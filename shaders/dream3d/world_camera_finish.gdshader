shader_type canvas_item;
render_mode unshaded, blend_disabled;

// Keep the accepted 640x360 discrete sampling. No blur kernel or new palette.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool base_enabled = true;
uniform bool vignette_enabled = true;
uniform float base_strength = 0.16;
uniform float vignette_strength = 0.24;
uniform float shock_strength = 0.0;
uniform float distort_strength = 1.0;
uniform float phase = 0.0;
uniform vec2 hit_center = vec2(0.5);

void fragment() {
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float radial = dot(centered, centered);
	float edge = smoothstep(0.20, 1.35, radial);
	float baseline = base_enabled ? base_strength : 0.0;
	// The existing damage deformation remains transient. The ordinary image
	// keeps its green-channel geometry and the existing cursor projection.
	vec2 warp = centered * radial * 0.022;
	warp += vec2(sin(centered.y * 9.0 + phase * 12.0), 0.0) * 0.003;
	warp += (SCREEN_UV - hit_center) * 0.012;
	vec2 uv = clamp(SCREEN_UV + warp * shock_strength * distort_strength, vec2(0.001), vec2(0.999));
	vec2 direction = normalize(centered + vec2(0.001));
	// A maximum, not two passes: baseline displacement is at most 0.96 px.
	vec2 shift = direction * SCREEN_PIXEL_SIZE * (2.0 + 4.0 * edge) * max(baseline, shock_strength);
	vec4 source = texture(screen_texture, uv);
	source.r = texture(screen_texture, clamp(uv + shift, vec2(0.001), vec2(0.999))).r;
	source.b = texture(screen_texture, clamp(uv - shift, vec2(0.001), vec2(0.999))).b;
	// The middle half of the image is untouched. Soft corners darken by at
	// most 24%. A wider falloff makes it visible on the actual dark scene;
	// damage retains its original darkening without adding the two.
	float vignette = vignette_enabled ? vignette_strength * smoothstep(0.55, 1.35, radial) : 0.0;
	source.rgb *= 1.0 - max(vignette, 0.52 * edge * shock_strength);
	COLOR = source;
}
