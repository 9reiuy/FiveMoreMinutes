shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/dream3d/passage_end_fade.gdshaderinc"

uniform vec4 tile_colour : source_color = vec4(.43, .46, .44, 1.0);
uniform vec4 grout_colour : source_color = vec4(.19, .21, .20, 1.0);
const float TILE_SIZE = .78;
varying vec2 world_floor;

float hash_cell(vec2 point) {
	uvec2 cell = uvec2(ivec2(point));
	uint h = cell.x * 374761393u + cell.y * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float((h ^ (h >> 16u)) & 16777215u) / 16777216.0;
}

float stain(vec2 point) {
	vec2 cell = floor(point);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(point));
	return mix(mix(hash_cell(cell), hash_cell(cell + vec2(1, 0)), f.x),
		mix(hash_cell(cell + vec2(0, 1)), hash_cell(cell + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_floor = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 tiles = world_floor / TILE_SIZE;
	vec2 from_seam = (.5 - abs(fract(tiles) - .5)) * TILE_SIZE;
	// Keep the narrow grout lines readable at the grazing angles of the game Camera.
	vec2 half_pixel = max(fwidth(world_floor) * .5, vec2(.001));
	vec2 seam = 1.0 - smoothstep(vec2(.019) - half_pixel, vec2(.019) + half_pixel, from_seam);
	float grout = max(seam.x, seam.y);
	vec2 texel = floor(world_floor * 32.0);
	float mineral = hash_cell(texel + vec2(7, 15)) - .5;
	float wear = stain(texel * .078 + vec2(16.0, 31.0));
	float grime = smoothstep(.47, .86, stain(texel * .024 + vec2(3.0, 17.0)));
	float variation = .92 + (hash_cell(floor(tiles)) - .5) * .23 + mineral * .13 + wear * .19;
	vec3 ceramic = tile_colour.rgb * variation * (1.0 - grime * .27);
	ALBEDO = mix(ceramic, grout_colour.rgb * (.83 + wear * .27), grout);
	ROUGHNESS = mix(.45 + wear * .18 + grime * .19, .97, grout);
	SPECULAR = mix(.32 - grime * .08, .08, grout);
	apply_passage_end_fade(world_floor.x, ALBEDO, ROUGHNESS, SPECULAR);
}
