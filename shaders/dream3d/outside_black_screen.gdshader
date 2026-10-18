shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D footprint_distance : filter_linear, repeat_disable;
uniform vec2 grid_origin = vec2(0.0);
uniform vec2 grid_size = vec2(1.0);
uniform float cell_world_size = 1.0;
uniform vec3 map_origin = vec3(0.0);
uniform vec3 map_x_axis = vec3(1.0, 0.0, 0.0);
uniform vec3 map_z_axis = vec3(0.0, 0.0, 1.0);
uniform vec3 ray_origin_tl = vec3(0.0);
uniform vec3 ray_origin_dx = vec3(0.0);
uniform vec3 ray_origin_dy = vec3(0.0);
uniform vec3 ray_direction_tl = vec3(0.0, -1.0, 0.0);
uniform vec3 ray_direction_dx = vec3(0.0);
uniform vec3 ray_direction_dy = vec3(0.0);
uniform bool door_cutout_enabled = false;
uniform vec2 door_screen_min = vec2(0.0);
uniform vec2 door_screen_max = vec2(0.0);

void fragment() {
	vec2 screen = SCREEN_UV;
	vec3 origin = ray_origin_tl + ray_origin_dx * screen.x + ray_origin_dy * screen.y;
	vec3 direction = ray_direction_tl + ray_direction_dx * screen.x + ray_direction_dy * screen.y;
	float alpha = 1.0;
	if (direction.y < -0.0001) {
		vec3 ground = origin + direction * (-origin.y / direction.y);
		vec3 relative = ground - map_origin;
		vec2 map_cell = vec2(dot(relative, map_x_axis), dot(relative, map_z_axis)) / cell_world_size;
		vec2 uv = (map_cell - grid_origin + vec2(0.5)) / grid_size;
		if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) {
			float distance_to_floor = texture(footprint_distance, uv).r;
			alpha = smoothstep(0.0, 1.0, distance_to_floor);
		}
	}
	if (door_cutout_enabled && all(greaterThanEqual(screen, door_screen_min)) && all(lessThanEqual(screen, door_screen_max))) {
		alpha = 0.0;
	}
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
