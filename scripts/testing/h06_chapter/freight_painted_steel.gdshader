shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/dream3d/occlusion_cutout.gdshaderinc"

uniform sampler2D iron_color : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D iron_roughness : hint_roughness_r, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D iron_normal : hint_normal, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform vec4 paint : source_color;
uniform vec3 half_extents;
uniform bool frame_steel = false;
uniform bool occlusion_cutout_enabled = false;

varying vec3 sheet;
varying vec3 face;
varying flat float main_camera;

float grain_hash(vec2 cell) {
	vec3 h = fract(vec3(cell.xyx) * .1031);
	h += dot(h, h.yzx + 19.19);
	return fract((h.x + h.y) * h.z);
}

float wear_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 t = fract(point);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(grain_hash(cell), grain_hash(cell + vec2(1,0)), t.x),
		mix(grain_hash(cell + vec2(0,1)), grain_hash(cell + vec2(1,1)), t.x), t.y);
}

void vertex() {
	sheet = VERTEX;
	face = NORMAL;
	main_camera = float(all(equal(INV_VIEW_MATRIX[3], MAIN_CAM_INV_VIEW_MATRIX[3])));
}

void fragment() {
	if (occlusion_cutout_enabled && main_camera_cutout(SCREEN_UV, main_camera)) { discard; }

	vec3 axis = abs(face);
	vec2 point = UV + vec2(dot(face, vec3(1.9,4.5,8.6)), dot(face, vec3(6.3,-3.1,1.7)));
	vec2 detail_uv = point * .76;
	float brushed = texture(iron_color, detail_uv).r;
	float pitted = clamp((texture(iron_roughness, detail_uv).r - .26) * 3.0, 0.0, 1.0);
	float fade = wear_noise(point * 1.36);
	float small = wear_noise(point * 11.8);
	float drip = smoothstep(.50, .86, wear_noise(point * vec2(9.9,1.35) + vec2(4.8,1.9)));
	float lower = (1.0 - smoothstep(.03, .66, sheet.y + half_extents.y)) * (1.0-axis.y);
	float dirt = clamp(drip * (1.0-axis.y) * .45 + lower * .52 + (1.0-fade) * .20, 0.0, 1.0);

	// Measure the two edges on this sheet, excluding its own plane.
	vec3 edge_distance = half_extents - abs(sheet) + axis * 8.0;
	float edge = 1.0 - smoothstep(.03, .17, min(min(edge_distance.x, edge_distance.y), edge_distance.z));
	float chip_signal = small * .53 + fade * .24 + pitted * .16 + edge * .39;
	float chip = smoothstep(.57, .81, chip_signal);
	float oxide = smoothstep(.54,.77, small * .38 + fade * .32 + pitted * .15 + dirt * .46);

	// Painted areas stay diffuse. The exposed edges have the warmer, irregular
	// reflection of rubbed steel, with rust settled in the chips and seams.
	vec3 coat = paint.rgb * mix(.69,1.27,fade) * mix(.82,1.15,pitted);
	coat = mix(coat, vec3(.15,.145,.132), axis.y * fade * .25);
	coat *= 1.0-dirt*.39;
	vec3 steel = vec3(.215,.221,.223) * mix(.58,1.21,brushed);
	vec3 rust = vec3(.22,.080,.032) * mix(.70,1.16,small);
	float exposed = max(chip *.88, frame_steel ? .35 : 0.);
	vec3 finish = mix(coat, steel, exposed);
	ALBEDO = mix(finish, rust, oxide * (.30+chip*.42));
	METALLIC = mix(.075,.73,exposed) * (1.0-oxide*.57);
	ROUGHNESS = mix(.68,.88,clamp(dirt + pitted*.37 + (1.0-fade)*.22,0.,1.));
	ROUGHNESS = mix(ROUGHNESS, .50 + pitted*.11, exposed * (1.0-oxide*.7));
	SPECULAR = mix(.20,.34,exposed);
	NORMAL_MAP = texture(iron_normal, detail_uv).rgb;
	NORMAL_MAP_DEPTH = mix(.25,.40,chip);
}
