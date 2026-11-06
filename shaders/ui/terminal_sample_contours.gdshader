shader_type canvas_item;

uniform float motion_time = 0.0;
uniform vec4 contour_color : source_color = vec4(0.30, 0.70, 0.77, 0.30);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float smooth_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float height_field(vec2 p) {
	return 0.61 * smooth_noise(p) + 0.27 * smooth_noise(p * 2.05 + vec2(7.1, 2.3))
		+ 0.12 * smooth_noise(p * 4.1 + vec2(1.7, 8.4));
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(6.3, 2.7);
	float time = motion_time * 0.025;
	vec2 flow = vec2(time, sin(time * 1.8) * 0.15);
	vec2 warp = vec2(smooth_noise(p * 0.55 + flow + vec2(3.0, 5.0)),
		smooth_noise(p * 0.55 - flow + vec2(8.0, 1.0))) - vec2(0.5);
	float height = height_field(p + warp * 0.7 + flow);
	float levels = height * 16.0;
	float distance_to_line = abs(fract(levels + 0.5) - 0.5);
	float width = max(fwidth(levels) * 0.65, 0.015);
	float line = 1.0 - smoothstep(width, width * 2.15, distance_to_line);
	float vignette = smoothstep(0.0, 0.09, UV.x) * smoothstep(0.0, 0.09, 1.0 - UV.x)
		* smoothstep(0.0, 0.09, UV.y) * smoothstep(0.0, 0.11, 1.0 - UV.y);
	COLOR = vec4(contour_color.rgb, contour_color.a * line * vignette);
}
