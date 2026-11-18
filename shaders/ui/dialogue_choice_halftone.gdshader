shader_type canvas_item;
render_mode unshaded;

uniform vec2 row_size = vec2(168.0, 23.0);
uniform float selected = 0.0;
uniform float disabled = 0.0;
uniform vec3 accent = vec3(0.91, 0.97, 0.95);
uniform vec3 selected_fill = vec3(0.060, 0.105, 0.115);

vec4 layer_over(vec4 underneath, vec3 tint, float opacity) {
	return vec4(tint * opacity, opacity) + underneath * (1.0 - opacity);
}

void fragment() {
	vec2 p = UV * row_size;
	float aa = max(fwidth(p.x) * 0.5, 0.2);
	float first_x = 10.0;
	vec2 half_extent = vec2((row_size.x - first_x) * 0.5, row_size.y * 0.5 - 0.8);
	vec2 center = vec2(first_x + half_extent.x, row_size.y * 0.5);
	float corner_radius = 2.7;
	vec2 q = abs(p - center) - (half_extent - corner_radius);
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	float body = 1.0 - smoothstep(-aa, aa, distance_to_edge);
	float stroke_width = mix(0.8, 1.15, selected);
	float stroke = smoothstep(-stroke_width - aa, -stroke_width + aa, distance_to_edge);

	// Keep the label on a solid fill, then shrink the disks in the tail.
	float fade_start = row_size.x - 53.0;
	float pitch = 5.2;
	vec2 grid = p - vec2(fade_start, 0.0);
	grid.x += mod(floor(grid.y / pitch), 2.0) * 0.5 * pitch;
	vec2 cell = mod(grid, pitch) - vec2(pitch * 0.5);
	float cell_x = p.x - cell.x;
	float density = 1.0 - smoothstep(fade_start + 3.0, row_size.x - 1.5, cell_x);
	float radius = 2.9 * pow(density, 0.8);
	float dots = (1.0 - smoothstep(radius - aa, radius + aa, length(cell))) * step(0.16, radius);
	float tail = mix(1.0, dots, smoothstep(fade_start, fade_start + 7.0, p.x));

	vec3 fill = mix(vec3(0.027, 0.036, 0.044), selected_fill, selected);
	float fill_alpha = body * tail * mix(0.79, 0.91, selected);
	vec4 pixel = vec4(fill * fill_alpha, fill_alpha);

	// This flat tint crosses both the fill and the spaces between the dots.
	// It is strongest at the top and fades gently downward and outward.
	float top_grade = 1.0 - smoothstep(0.0, row_size.y, p.y);
	float tint_tail = 1.0 - smoothstep(fade_start - 13.0, row_size.x, p.x);
	pixel = layer_over(pixel, vec3(0.016), body * top_grade * tint_tail * 0.33);

	// The selected white is concentrated at the left corner. The much
	// quieter rim and the dark halftone have their own falloff.
	float bright_edge = selected * (1.0 - smoothstep(first_x + 11.0, first_x + 66.0, p.x));
	float quiet_edge = 1.0 - smoothstep(first_x + 26.0, fade_start - 9.0, p.x);
	vec3 rim = mix(vec3(0.33, 0.40, 0.44), accent, bright_edge);
	float rim_alpha = body * stroke * mix(0.37 * quiet_edge, 0.96, bright_edge);
	pixel = layer_over(pixel, rim, rim_alpha);

	float arrow_t = clamp((p.x - 1.2) / 5.4, 0.0, 1.0);
	float arrow_shape = max(max(1.2 - p.x, p.x - 6.6), abs(p.y - center.y) - 3.4 * (1.0 - arrow_t));
	float arrow = selected * (1.0 - smoothstep(-aa, aa, arrow_shape));
	pixel = layer_over(pixel, accent, arrow);
	COLOR = vec4(pixel.rgb / max(pixel.a, 0.001), pixel.a * mix(1.0, 0.55, disabled) * COLOR.a);
}
