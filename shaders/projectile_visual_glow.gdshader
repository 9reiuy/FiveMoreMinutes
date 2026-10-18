shader_type canvas_item;
render_mode unshaded;

// Dynamic history textures supply their head anchor; the default also supports
// the compact 56x11 tracer. Keep the halo confined to this single head.
uniform float glow_strength = 0.65;
uniform vec4 glow_color : source_color = vec4(1.0);
uniform vec2 head_uv = vec2(0.88392857, 0.5);

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 delta_px = (UV - head_uv) / TEXTURE_PIXEL_SIZE;
	float distance_px = length(delta_px);
	float ring = 1.0 - smoothstep(1.8, 4.8, distance_px);
	float halo = ring * clamp(glow_strength, 0.0, 1.0) * 0.42;
	vec3 result_rgb = clamp(base.rgb + glow_color.rgb * halo, 0.0, 1.0);
	float result_alpha = max(base.a, halo * 0.34);
	COLOR = vec4(result_rgb, result_alpha);
}
