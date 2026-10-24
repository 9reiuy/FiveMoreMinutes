shader_type canvas_item;
render_mode unshaded;
uniform vec4 word_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float dot_pixels = 3.0;
uniform vec4 red_ink : source_color = vec4(1.0, 0.16, 0.12, 1.0);
void fragment() {
	vec4 ink = texture(TEXTURE, UV) * COLOR;
	// Recolour only the white glyph face, never the dark pixel contour.
	if (min(ink.r, min(ink.g, ink.b)) > 0.75) {
		vec2 p = (SCREEN_UV - word_rect.xy) / max(word_rect.zw, vec2(0.0001));
		float progress = floor(clamp(p.x * 0.60 + p.y * 0.40 - 0.18, 0.0, 1.0) * 8.0) / 8.0;
		vec2 cell = fract(FRAGCOORD.xy / max(dot_pixels, 1.0)) - 0.5;
		float red = step(length(cell), progress * 0.90);
		ink.rgb = mix(ink.rgb, red_ink.rgb, red);
	}
	COLOR = ink;
}
