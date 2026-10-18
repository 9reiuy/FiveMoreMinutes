shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler2D footprint_distance : filter_linear, repeat_disable;
uniform vec2 grid_origin = vec2(0.0);
uniform vec2 grid_size = vec2(1.0);
uniform float cell_world_size = 1.0;
uniform vec2 map_x_axis = vec2(1.0, 0.0);
uniform vec2 map_z_axis = vec2(0.0, 1.0);

varying vec2 world_xz;

void vertex() {
	vec2 physical_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	world_xz = vec2(dot(physical_xz, map_x_axis), dot(physical_xz, map_z_axis));
}

void fragment() {
	vec2 uv = (world_xz / cell_world_size - grid_origin + vec2(0.5)) / grid_size;
	float distance_to_floor = texture(footprint_distance, uv).r;
	float alpha = smoothstep(0.0, 1.0, distance_to_floor);
	ALBEDO = vec3(0.0);
	ALPHA = alpha;
}
