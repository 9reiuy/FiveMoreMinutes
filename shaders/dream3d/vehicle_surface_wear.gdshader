shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/dream3d/reception_wear.gdshaderinc"

uniform vec4 finish_colour : source_color;
uniform float finish_roughness = .56;
uniform float finish_specular = .30;
uniform int finish_mode = 0;
uniform float wear_amount : hint_range(0.0, 1.0) = .88;
uniform vec2 stain_offset;
uniform vec4 upper_scrape;
uniform vec4 roof_scrape;
uniform vec4 flank_scrape;
uniform float flank_side = 1.0;
uniform float roof_height = 1.7;
instance uniform float reveal_after_z = -8192.0;

varying vec3 model_position;
varying vec3 model_normal;
varying float level_z;

float scrape(vec2 point, vec4 stroke, float half_width) {
	vec2 axis = stroke.zw - stroke.xy;
	float t = clamp(dot(point - stroke.xy, axis) / max(dot(axis, axis), .001), 0.0, 1.0);
	return 1.0 - smoothstep(half_width * .45, half_width, distance(point, stroke.xy + axis * t));
}

void vertex() {
	model_position = VERTEX;
	model_normal = NORMAL;
	level_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	if (level_z < reveal_after_z) {
		discard;
	}
	// Shared local coordinates across body panels. The marks travel with the car.
	vec3 point = (floor(model_position * 32.0) + .5) / 32.0;
	vec3 n = abs(normalize(model_normal));
	vec2 panel = n.y > .64 ? point.xz : (n.x > n.z ? point.zy : point.xy);
	float blotch = reception_noise(panel * vec2(2.1, 1.38) + stain_offset);
	float residue = reception_noise(panel * vec2(6.2, 2.4) + stain_offset * 1.71);
	float grit = reception_hash(floor(panel * 32.0) + stain_offset * 9.0);
	float lower = 1.0 - smoothstep(.34, .77, point.y);
	float dust = lower * (.25 + .75 * blotch) * (.70 + .30 * residue);

	ALBEDO = finish_colour.rgb;
	ROUGHNESS = finish_roughness;
	SPECULAR = finish_specular;
	METALLIC = 0.0;

	if (finish_mode == 2) {
		float seal_dust = (1.0 - smoothstep(roof_height - .54, roof_height - .18, point.y)) * blotch;
		ALBEDO *= 1.0 + wear_amount * ((blotch - .5) * .095 + seal_dust * .16);
		ROUGHNESS += wear_amount * (.13 * seal_dust + .04 * residue);
	} else {
		vec3 road_dust = vec3(.174, .151, .115);
		float roof_fade = smoothstep(.67, .96, n.y) * smoothstep(roof_height - .27, roof_height - .04, point.y);
		float scuff = 0.0;
		if (finish_mode == 0) {
			float on_top = smoothstep(.63, .92, n.y);
			float top = scrape(point.xz, upper_scrape, .055) * on_top;
			float roof = scrape(point.xz, roof_scrape, .061) * roof_fade;
			float face = scrape(point.zy, flank_scrape, .058) * smoothstep(.64, .91, n.x) * step(0.0, point.x * flank_side);
			float nose_chips = on_top * smoothstep(1.73, 2.02, point.z) * smoothstep(.47, .67, abs(point.x));
			nose_chips *= smoothstep(.91, 1.0, grit) * smoothstep(.42, .75, blotch);
			scuff = max(max(top, roof), face) * (.52 + .48 * smoothstep(.17, .78, grit)) + nose_chips * .62;
		} else {
			float corner = smoothstep(.57, .83, abs(point.x)) * smoothstep(1.82, 2.08, abs(point.z));
			scuff = corner * smoothstep(.66, .88, blotch * .65 + residue * .35);
		}
		vec3 worn = finish_colour.rgb * (1.0 + (blotch - .5) * (.17 + .26 * roof_fade));
		worn = mix(worn, road_dust, dust * .39);
		worn *= 1.0 - scuff * .22;
		worn = mix(worn, vec3(.34, .31, .255), scuff * .64);
		ALBEDO = mix(finish_colour.rgb, worn, wear_amount);
		ROUGHNESS += wear_amount * (.17 * dust + .13 * scuff + .10 * roof_fade * residue);
		SPECULAR *= 1.0 - wear_amount * (.21 * dust + .31 * scuff);
	}
	ROUGHNESS = min(ROUGHNESS, 1.0);
}
