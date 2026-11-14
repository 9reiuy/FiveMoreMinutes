shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform float moon_visibility = 1.0;
uniform vec3 city_tint : source_color = vec3(0.17, 0.19, 0.25);
uniform vec3 mist_tint : source_color = vec3(0.23, 0.18, 0.29);
uniform vec3 cool_windows : source_color = vec3(0.42, 0.66, 0.70);
uniform vec3 amber_windows : source_color = vec3(0.67, 0.52, 0.33);
uniform bool facade_detail = false;
uniform sampler2D facade_map : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec2 window_grid = vec2(7.0, 24.0);
uniform float window_gain : hint_range(0.0, 1.0) = 0.38;
varying vec3 world_position;
varying vec3 facade_position;
varying vec3 facade_normal;

float room_hash(vec2 address) {
	return fract(sin(dot(address, vec2(37.21, 91.73))) * 18317.37);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	facade_position = VERTEX;
	facade_normal = NORMAL;
}

void fragment() {
	float depth = smoothstep(575.0, 950.0, distance(CAMERA_POSITION_WORLD, world_position));
	float at_shore = 1.0 - smoothstep(4.0, 70.0, world_position.y);
	float mist = clamp(depth * 0.58 + at_shore * 0.34, 0.0, 0.84);
	vec3 facade = city_tint;
	vec3 windows = vec3(0.0);
	if (facade_detail) {
		vec3 baked = texture(facade_map, UV).rgb;
		float detail = dot(baked, vec3(0.2126, 0.7152, 0.0722));
		facade *= mix(0.62, 1.60, smoothstep(0.022, 0.107, detail));
		float along = abs(facade_normal.z) >= abs(facade_normal.x) ? facade_position.x : facade_position.z;
		vec2 address = (vec2(along, facade_position.y) + 0.5) * window_grid;
		vec2 room = floor(address);
		vec2 cell = abs(fract(address) - vec2(0.5, 0.46));
		vec2 edge = clamp(fwidth(address) * 0.38, vec2(0.03), vec2(0.28));
		vec2 frame = 1.0 - smoothstep(vec2(0.32, 0.19) - edge, vec2(0.32, 0.19) + edge, cell);
		float occupied = room_hash(room + floor(MODEL_MATRIX[3].xz * 0.13));
		float floor_lit = room_hash(vec2(room.y + window_grid.x, 3.0));
		float coverage = frame.x * frame.y * step(mix(0.48, 0.80, floor_lit), occupied);
		coverage *= 1.0 - smoothstep(0.13, 0.29, abs(facade_normal.y));
		coverage *= 1.0 - smoothstep(0.68, 1.5, max(fwidth(address).x, fwidth(address).y));
		windows = mix(cool_windows, amber_windows, step(0.88, occupied)) * coverage * window_gain;
	}
	// The short story pulses own saturated red. Ordinary windows remain quiet.
	float night = mix(0.32, 1.0, moon_visibility);
	ALBEDO = facade * (1.0 - mist * 0.72);
	EMISSION = mix(facade * 0.38, mist_tint * 0.58, mist) * night;
	EMISSION += windows * (1.0 - mist) * mix(0.36, 1.0, moon_visibility);
	ROUGHNESS = 1.0;
}
