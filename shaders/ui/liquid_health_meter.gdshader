shader_type canvas_item;
render_mode unshaded;
uniform vec3 health_fill = vec3(1.0);
uniform vec3 damage_fill = vec3(1.0);
uniform vec2 panel_size = vec2(82.0, 16.0);
uniform vec2 surface_size = vec2(153.0, 22.0);
uniform float cell_gap = 3.0;
uniform vec4 liquid_color : source_color = vec4(0.620, 0.227, 0.314, 1.0);
uniform vec4 foreground_color : source_color = vec4(0.384, 0.133, 0.224, 1.0);
uniform float wave_phase = 0.0;
uniform float foreground_phase = 1.4;
uniform float wave_energy = 0.0;
uniform float wave_activity : hint_range(0.0, 1.0) = 0.0;
uniform float liquid_tilt = 0.0;
uniform float glow_padding = 4.0;
uniform float damage_glow : hint_range(0.0, 1.0) = 0.0;

float liquid_distance(vec2 p, float extent, float top, float bottom) {
	vec2 edge = vec2(max(-p.x, p.x - extent), max(top - p.y, p.y - bottom));
	return length(max(edge, vec2(0.0))) + min(max(edge.x, edge.y), 0.0);
}

float coverage(float distance_to_edge) {
	float edge_width = max(fwidth(distance_to_edge) * 0.5, 0.0001);
	return 1.0 - smoothstep(-edge_width, edge_width, distance_to_edge);
}

float halo(float distance_to_edge) {
	// Keep the boss bar's local halo approach, with a tighter range for the HUD.
	float outside = max(distance_to_edge, 0.0);
	return exp(-outside * 1.15) * (1.0 - smoothstep(1.3, 3.0, outside));
}

void fragment() {
	vec2 pixel = (UV * (panel_size + vec2(glow_padding * 2.0)) - vec2(glow_padding)) * surface_size / panel_size;
	float cell_width = (surface_size.x - cell_gap * 2.0) / 3.0;
	float stride = cell_width + cell_gap;
	// One continuous surface is evaluated before the three gaps cut the liquid.
	float wave = (sin(pixel.x * 0.105 + wave_phase) * (1.1 + wave_energy * 1.4)
		+ sin(pixel.x * 0.049 - wave_phase * 0.65) * (0.7 + wave_energy * 0.55)) * wave_activity
		+ liquid_tilt * (pixel.x / surface_size.x * 2.0 - 1.0);
	float bottom = surface_size.y * 0.75;
	float back_top = clamp(5.0 + wave, 0.8, bottom - 5.5);
	float front_wave = (sin(pixel.x * 0.084 + foreground_phase) * (0.9 + wave_energy * 0.55)
		+ sin(pixel.x * 0.044 + foreground_phase * 0.53 + 2.2) * 0.45) * wave_activity
		+ liquid_tilt * 0.65 * (pixel.x / surface_size.x * 2.0 - 1.0);
	float front_top = clamp(7.1 + front_wave, 1.3, bottom - 2.0);
	vec3 body_colour = vec3(0.0);
	float body_alpha = 0.0;
	vec3 glow_colour = vec3(0.0);
	float glow_weight = 0.0;
	float health_units = health_fill.x + health_fill.y + health_fill.z;
	float damage_units = damage_fill.x + damage_fill.y + damage_fill.z - health_units;
	float health_front = health_units * cell_width + clamp(ceil(health_units) - 1.0, 0.0, 2.0) * cell_gap;
	float near_seam = exp(-abs(pixel.x - health_front) * 0.20)
		* step(0.001, damage_units) * step(0.001, health_units);
	for (int cell = 0; cell < 3; cell++) {
		vec2 p = vec2(pixel.x - float(cell) * stride, pixel.y);
		float health_extent = health_fill[cell] * cell_width;
		float white_extent = max(0.0, damage_fill[cell] - health_fill[cell]) * cell_width;
		float red_has = step(0.001, health_extent);
		float white_has = step(0.001, white_extent);
		float back_distance = liquid_distance(p, health_extent, back_top, bottom);
		float front_distance = liquid_distance(p, health_extent, front_top, bottom);
		float red_distance = min(back_distance, front_distance);
		float white_distance = liquid_distance(p - vec2(health_extent, 0.0), white_extent, min(back_top, front_top), bottom);
		float back = coverage(back_distance) * red_has;
		float front = coverage(front_distance) * red_has;
		float red = front + back * (1.0 - front);
		float white = coverage(white_distance) * white_has;
		vec3 red_colour = (foreground_color.rgb * front + liquid_color.rgb * back * (1.0 - front)) / max(red, 0.001);
		float seam = exp(-abs(p.x - health_extent) * 2.4) * red * white_has * damage_glow;
		red_colour = mix(red_colour, vec3(0.94, 0.84, 0.85), seam * 0.40);
		body_colour += red_colour * red + vec3(white);
		body_alpha += red + white;
		float red_glow = halo(red_distance) * red_has * damage_glow * (0.025 + near_seam * 0.25);
		float white_glow = halo(white_distance) * white_has * damage_glow * (0.07 + near_seam * 0.32);
		glow_colour += vec3(0.78, 0.25, 0.36) * red_glow + vec3(0.94, 0.98, 1.0) * white_glow;
		glow_weight += red_glow + white_glow;
	}
	float body_coverage = min(body_alpha, 1.0);
	float outer_glow = min(glow_weight, 0.85) * (1.0 - body_coverage);
	vec3 premultiplied = body_colour / max(body_alpha, 0.001) * body_coverage
		+ glow_colour / max(glow_weight, 0.001) * outer_glow;
	float alpha = body_coverage + outer_glow;
	COLOR *= vec4(premultiplied / max(alpha, 0.001), alpha);
}
