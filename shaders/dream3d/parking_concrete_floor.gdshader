shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/dream3d/reception_wear.gdshaderinc"
#include "res://shaders/dream3d/passage_end_fade.gdshaderinc"

uniform vec4 main_road;
uniform vec4 entry_turn;
uniform vec4 exit_turn;
uniform vec4 polished_concrete : source_color = vec4(.53, .55, .51, 1.0);
uniform vec4 lane_concrete : source_color = vec4(.25, .285, .272, 1.0);

varying vec2 surface_metres;

float inside_road(vec2 point, vec4 bounds) {
	vec2 inside = step(bounds.xy, point) * (vec2(1.0) - step(bounds.zw, point));
	return inside.x * inside.y;
}

void vertex() {
	surface_metres = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 texel = floor(surface_metres * 32.0);
	vec2 point = (texel + .5) / 32.0;
	float lane_span = inside_road(point, main_road);
	float road = max(lane_span, max(inside_road(point, entry_turn), inside_road(point, exit_turn)));
	float clouds = reception_noise(point * .83 + vec2(12.0, 4.0));
	float sand = reception_hash(texel + vec2(7.0, 23.0));
	float fine = reception_noise(point * 5.3);
	float pitting = smoothstep(.956, 1.0, sand);

	// Large poured slabs, with a few pale aggregate grains and darker trowel marks.
	vec2 distance_to_joint = abs(fract((surface_metres + vec2(.52, .61)) / vec2(5.0, 6.5)) - .5);
	float joint = max(smoothstep(.496, .5, distance_to_joint.x), smoothstep(.496, .5, distance_to_joint.y));
	float polish_variation = .88 + clouds * .19 + (fine - .5) * .075 - pitting * .10;
	vec3 polish = polished_concrete.rgb * polish_variation * (1.0 - joint * .16);

	// The matte aisle is grippier and slightly darker where tyres run.
	float from_center = abs(point.x - (main_road.x + main_road.z) * .5);
	float track = (1.0 - smoothstep(.12, .57, abs(from_center - 1.19))) * lane_span;
	float lane_variation = .84 + clouds * .20 + (sand - .5) * .10 - pitting * .11;
	vec3 lane = lane_concrete.rgb * lane_variation * (1.0 - track * (.04 + clouds * .09));
	ALBEDO = mix(polish, lane, road);
	ROUGHNESS = mix(mix(.26, .41, clouds) + joint * .13, mix(.74, .9, fine), road);
	SPECULAR = mix(.45, .19, road);
	METALLIC = 0.0;
	apply_passage_end_fade(surface_metres.x, ALBEDO, ROUGHNESS, SPECULAR);
}
