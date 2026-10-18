shader_type canvas_item;

// Bayer 4x4 Ordered Dither Transition Shader
// Designed for 640x360 retro pixel canvas in Godot 4.7 Compatibility renderer.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool invert = false;

const float bayer_matrix[16] = float[16](
	0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
	3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
	15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
);

void fragment() {
	ivec2 pixel_coord = ivec2(FRAGCOORD.xy);
	int x = pixel_coord.x % 4;
	int y = pixel_coord.y % 4;
	float threshold = bayer_matrix[y * 4 + x];

	float p = invert ? (1.0 - progress) : progress;
	if (p >= threshold) {
		COLOR = fade_color;
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
}
