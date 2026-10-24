shader_type canvas_item;
render_mode unshaded;
// Crisp comic-print shadow, in HUD pixels, outside world palette/postprocessing.
void fragment() {
	vec4 ink = texture(TEXTURE, UV) * COLOR;
	if (mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0) < 1.0) discard;
	COLOR = ink;
}
