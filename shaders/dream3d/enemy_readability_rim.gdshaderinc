// Opt-in on character bodies. Source-texel width keeps the border on
// the same grid as the character art, without a blurred halo or screen copy.
uniform bool enemy_rim_enabled = false;
uniform vec4 enemy_rim_color : source_color = vec4(0.55, 0.58, 0.62, 1.0);

float enemy_rim_alpha(vec2 uv) {
	vec2 texel = 1.0 / vec2(textureSize(capture_texture, 0));
	float neighbour = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			neighbour = max(neighbour, texture(capture_texture, uv + vec2(float(x), float(y)) * texel).a);
		}
	}
	return step(0.05, neighbour);
}
