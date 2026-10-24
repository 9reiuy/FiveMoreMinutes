shader_type spatial;
// LCD panel for the hotel delivery robot: the face texture already contains the
// dot-matrix gaps, so this just keeps it crisp, unlit and slightly glowing.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D screen_texture : filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(0.92, 0.99, 1.0, 1.0);
uniform float brightness = 1.15;
uniform bool flip_u = false;

void fragment() {
	vec2 uv = vec2(flip_u ? 1.0 - UV.x : UV.x, UV.y);
	vec3 colour = texture(screen_texture, uv).rgb * tint.rgb * brightness;
	ALBEDO = colour;
	EMISSION = colour * 0.55;
}
