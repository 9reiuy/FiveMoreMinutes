shader_type canvas_item;
render_mode unshaded;

uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec2 size_px = vec2(324.0, 22.0);

float box_distance(vec2 point, vec2 center, vec2 half_size) {
	vec2 edge = abs(point - center) - half_size;
	return length(max(edge, vec2(0.0))) + min(max(edge.x, edge.y), 0.0);
}

void fragment() {
	vec2 point = (UV - vec2(0.5)) * size_px;
	vec2 half_track = vec2(size_px.x * 0.5 - 8.0, 3.5);
	float half_fill = half_track.x * health_ratio;
	float track = 1.0 - step(0.0, box_distance(point, vec2(0.0), half_track));
	float edge = box_distance(point, vec2(half_fill - half_track.x, 0.0), vec2(half_fill, half_track.y));
	float has_health = step(0.0001, health_ratio);
	float fill = (1.0 - step(0.0, edge)) * has_health;
	float halo = 0.55 * exp(-max(edge, 0.0) * 0.32) * (1.0 - smoothstep(4.0, 7.5, edge)) * has_health;
	float red = max(fill, halo);
	float base = track * 0.74 * (1.0 - red);
	vec3 color = (vec3(1.0, 0.10, 0.055) * red + vec3(0.16, 0.019, 0.025) * base) / max(red + base, 0.001);
	COLOR = vec4(color, (red + base) * COLOR.a);
}
