shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/dream3d/reception_wear.gdshaderinc"

varying vec2 floor_metres;

void vertex() {
	floor_metres = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 texel = floor(floor_metres * 32.0);
	float dirt = reception_noise(texel * .091 + vec2(31.0, 12.0));
	float flake = reception_hash(texel + vec2(7.0, 41.0));
	if (flake > mix(.995, .94, dirt)) {
		discard;
	}
	ALBEDO = COLOR.rgb * mix(.66, 1.0, flake) * mix(1.0, .68, dirt);
	ROUGHNESS = .88;
	SPECULAR = .12;
}
