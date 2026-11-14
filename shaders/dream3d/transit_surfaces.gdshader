shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/dream3d/occlusion_cutout.gdshaderinc"

uniform vec4 face_colour : source_color = vec4(.64, .60, .53, 1.0);
uniform vec4 joint_colour : source_color = vec4(.25, .23, .20, 1.0);
uniform vec4 skirting_colour : source_color = vec4(.22, .20, .17, 1.0);
uniform vec2 tile_span = vec2(.34);
uniform float joint_width = .014;
uniform float finish_roughness = .58;
uniform float wear = .25;
uniform float terrazzo = 0.0;
uniform bool wall_surface = false;
uniform bool occlusion_cutout_enabled = false;
uniform vec2 west_fade = vec2(0.0);
uniform vec2 north_fade = vec2(0.0);
uniform vec2 south_fade = vec2(0.0);
varying vec3 surface_world;
varying vec3 surface_normal;
varying flat float cutout_camera_pass;

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
	surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = MODEL_NORMAL_MATRIX * NORMAL;
	cutout_camera_pass = float(all(equal(INV_VIEW_MATRIX[3], MAIN_CAM_INV_VIEW_MATRIX[3])));
}

void fragment() {
	if (occlusion_cutout_enabled && main_camera_cutout(SCREEN_UV, cutout_camera_pass)) {
		discard;
	}
	vec3 direction = abs(surface_normal);
	vec2 uv = surface_world.xz;
	if (wall_surface) {
		uv = direction.x > direction.z ? surface_world.zy : surface_world.xy;
	}
	vec2 tile = uv / tile_span;
	vec2 inset = (.5 - abs(fract(tile) - .5)) * tile_span;
	vec2 half_pixel = max(fwidth(uv) * .5, vec2(.001));
	vec2 edges = 1.0 - smoothstep(vec2(joint_width) - half_pixel, vec2(joint_width) + half_pixel, inset);
	float joint = max(edges.x, edges.y);
	vec2 texel = floor(uv * 32.0);
	float grain = hash_cell(texel);
	float patches = stain(texel * .036 + vec2(11, 29));
	float tracked = stain(texel * .012 + vec2(2, 37));
	float edge_wear = (1.0 - smoothstep(.015, .10, min(inset.x, inset.y))) * patches;
	float dirt = mix(tracked, edge_wear, .27) * wear;
	float shade = 1.0 + (hash_cell(floor(tile)) - .5) * .18 + (grain - .5) * .095 - dirt;
	vec3 colour = face_colour.rgb * shade;
	colour *= 1.0 + terrazzo * (step(.93, grain) * .73 - (1.0 - step(.08, grain)) * .25);
	ALBEDO = mix(colour, joint_colour.rgb * (.84 + patches * .23), joint);
	ROUGHNESS = mix(clamp(finish_roughness + dirt * .33 + grain * .07, .14, .93), .93, joint);
	SPECULAR = mix(.34, .12, joint);
	if (wall_surface && surface_world.y < .19) {
		ALBEDO = skirting_colour.rgb * (.83 + patches * .23);
		ROUGHNESS = .61 + dirt * .21;
	}

	float fade = 1.0;
	if (west_fade.x < west_fade.y) {
		fade *= smoothstep(west_fade.x, west_fade.y, surface_world.x);
	}
	if (north_fade.x < north_fade.y) {
		fade *= smoothstep(north_fade.x, north_fade.y, surface_world.z);
	}
	if (south_fade.x < south_fade.y) {
		fade *= 1.0 - smoothstep(south_fade.x, south_fade.y, surface_world.z);
	}
	ALBEDO *= fade;
	ROUGHNESS = mix(1.0, ROUGHNESS, fade);
	SPECULAR *= fade;
}
