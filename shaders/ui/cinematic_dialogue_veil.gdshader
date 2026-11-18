shader_type canvas_item;
render_mode unshaded;

// Logical canvas units keep the circular halftone stable at any window size.
uniform vec2 canvas_size = vec2(640.0, 360.0);
uniform float bottom_lift = 0.0;
uniform float presentation_progress : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * canvas_size;
	float side = abs(UV.x * 2.0 - 1.0);
	// The upper black mask hangs down at the center. The lower black mask
	// arches upward at the center, leaving a curved opening for the world.
	float upper_arc = pow(max(0.0, 1.0 - side * side), 0.7);
	float upper_offset = -120.0 * (1.0 - presentation_progress);
	float lower_offset = (136.0 + bottom_lift) * (1.0 - presentation_progress);
	float upper_edge = 31.0 + 22.0 * upper_arc + upper_offset;
	float lower_edge = 279.0 + 22.0 * pow(side, 4.0) - bottom_lift + lower_offset;
	float upper = 1.0 - smoothstep(upper_edge - 24.0, upper_edge + 30.0, p.y);
	float lower = smoothstep(lower_edge - 27.0, lower_edge + 17.0, p.y);
	float gradient = max(upper, lower);
	float top_distance = upper_edge - p.y;
	float bottom_distance = p.y - lower_edge;
	float interior_distance = max(top_distance, bottom_distance);
	float size_weight = smoothstep(-42.0, 6.0, interior_distance);
	// Size carries the halftone fade: solid dots shrink into pinpoints at the
	// outer edge. Fading their alpha instead would look like equal-size dots.
	float pitch = 6.0;
	vec2 pattern = p - vec2(0.0, top_distance > bottom_distance ? upper_offset : lower_offset);
	float row = floor(pattern.y / pitch);
	vec2 cell = vec2(pattern.x + mod(row, 2.0) * pitch * 0.5, pattern.y);
	vec2 local = mod(cell, vec2(pitch)) - vec2(pitch * 0.5);
	float radius = 2.65 * pow(size_weight, 1.25);
	float aa = max(fwidth(length(local)), 0.15);
	float coverage = (1.0 - smoothstep(radius - aa, radius + aa, length(local))) * step(0.04, radius);
	float alpha = max(gradient, coverage * 0.98);
	COLOR = vec4(vec3(0.0), alpha * COLOR.a);
}
