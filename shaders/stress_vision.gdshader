shader_type canvas_item;

uniform vec2 viewport_size = vec2(640.0, 360.0);
uniform vec2 player_screen_position = vec2(320.0, 180.0);
uniform float vision_radius = 150.0;
uniform float edge_softness_ratio : hint_range(0.05, 1.0) = 0.28;
uniform float darkness : hint_range(0.0, 1.0) = 0.94;

void fragment() {
	vec2 pixel_position = SCREEN_UV * viewport_size;
	float distance_from_player = length(pixel_position - player_screen_position);
	float softness = max(1.0, vision_radius * edge_softness_ratio);
	float mask = smoothstep(vision_radius - softness, vision_radius + softness, distance_from_player);
	COLOR = vec4(0.005, 0.009, 0.018, mask * darkness);
}
