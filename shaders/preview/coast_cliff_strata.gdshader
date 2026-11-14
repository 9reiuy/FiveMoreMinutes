shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
#include "res://shaders/preview/coast_shape.gdshaderinc"

uniform float scene_time = 0.0;
uniform float moon_visibility = 1.0;
uniform vec3 sand_lit_tint : source_color = vec3(0.72, 0.57, 0.42);
uniform vec3 sand_cool_tint : source_color = vec3(0.46, 0.35, 0.29);
uniform vec3 open_sand : source_color = vec3(0.70, 0.73, 0.86);
uniform vec3 wet_sand : source_color = vec3(0.58, 0.39, 0.47);
varying vec3 world_position;
varying vec3 world_normal;

float stone_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float low_sand = (1.0 - smoothstep(0.56, 1.42, world_position.y)) * smoothstep(0.53, 0.92, world_normal.y);
	vec3 facet = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	facet = dot(facet, NORMAL) < 0.0 ? -facet : facet;
	NORMAL = normalize(mix(facet, NORMAL, low_sand));
	vec3 pixel = floor(world_position * 32.0) / 32.0;
	float top = smoothstep(0.45, 0.83, world_normal.y);
	float along = pixel.x + pixel.z * 0.37;
	float strata = pixel.y * 2.35 + along * 0.25 + sin(along * 0.76) * 0.19;
	float seam = 1.0 - smoothstep(0.025, 0.12, abs(fract(strata) - 0.5));
	float weathering = stone_hash(vec2(floor(along * 0.49), floor(strata)));
	float chips = stone_hash(floor(pixel.xz * 11.0));
	float fracture = (1.0 - smoothstep(0.025, 0.095, abs(fract(along * 0.69 + pixel.y * 0.47) - 0.5))) * step(0.58, weathering);
	vec3 stone = mix(sand_cool_tint, sand_lit_tint, mix(0.32, 0.84, top));
	stone *= mix(0.83, 1.10, weathering) * (1.0 - (seam * 0.31 + fracture * 0.21) * (1.0 - top));
	stone *= mix(0.92, 1.04, chips);
	float wet_base = (1.0 - smoothstep(0.1, 1.15, pixel.y)) * (1.0 - top * 0.30);
	stone = mix(stone, stone * vec3(0.84, 0.66, 0.63), wet_base);
	float swell = 0.38 * sin(scene_time * 1.15 + pixel.x * 0.28) + 0.14 * sin(scene_time * 1.73 + pixel.x * 1.1);
	float shore = coast_distance(world_position.xz);
	float front = shore - swell;
	float spray = (1.0 - smoothstep(0.05, 1.2, abs(front + 0.55))) * step(0.965, stone_hash(floor(pixel.xz * 32.0)));
	spray *= step(0.1, sin(scene_time * 1.3 + pixel.x * 5.0 + pixel.z * 4.0));
	float damp = 1.0 - smoothstep(0.20, 2.80, -shore);
	// Fade grain when several world texels fall into one grazing-angle pixel.
	float grain_visible = 1.0 - smoothstep(0.25, 0.85, length(fwidth(world_position.xz)) * 11.0);
	float grain = (chips - 0.5) * grain_visible * 0.036;
	float sand_drift = sin(world_position.x * 0.42 + world_position.z * 0.24) * sin(world_position.z * 0.57);
	vec3 beach = mix(open_sand, wet_sand, damp * 0.76) * (1.0 + grain + sand_drift * 0.019);
	stone = mix(stone, beach, low_sand);
	ALBEDO = mix(stone, vec3(0.58, 0.53, 0.57), spray);
	EMISSION = stone * mix(0.30, 0.18, moon_visibility) + vec3(0.024, 0.004, 0.007) * wet_base * (1.0 - low_sand);
	EMISSION += beach * low_sand * .13;
	EMISSION += vec3(0.041, 0.008, 0.016) * damp * low_sand;
	EMISSION += vec3(0.38, 0.33, 0.36) * spray * mix(0.1, 1.0, moon_visibility);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
