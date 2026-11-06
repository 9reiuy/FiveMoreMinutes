shader_type spatial;

// Blood remains a Sprite3D in the main world so the engine's normal depth
// buffer continues to occlude it behind floors, walls, furniture and actors.
// Only its presentation colour is semantic; gameplay/lifetime stay owned by
// BlackBloodEffect.
render_mode cull_disabled, unshaded, fog_disabled, blend_mix, depth_prepass_alpha, specular_disabled;

uniform sampler2D capture_texture : filter_nearest, repeat_disable;

// The semantic carrier is shared by Blood and other presentation-only effects
// that must survive the final palette pass. Match BlackBloodEffect's original
// ground stain colour (#D96B18), distinct from the pure-red charge marker.
uniform vec3 semantic_marker = vec3(0.8509804, 0.4196078, 0.0941176);

// A small fixed Bayer matrix converts fade alpha into coverage (visible vs
// discard) instead of blending the marker with the world and losing identity.
float bayer4(vec2 p) {
	vec2 cell = mod(floor(p), 4.0);
	float x = cell.x;
	float y = cell.y;
	if (y < 1.0) {
		if (x < 1.0) return 0.0;
		if (x < 2.0) return 8.0;
		if (x < 3.0) return 2.0;
		return 10.0;
	}
	if (y < 2.0) {
		if (x < 1.0) return 12.0;
		if (x < 2.0) return 4.0;
		if (x < 3.0) return 14.0;
		return 6.0;
	}
	if (y < 3.0) {
		if (x < 1.0) return 3.0;
		if (x < 2.0) return 11.0;
		if (x < 3.0) return 1.0;
		return 9.0;
	}
	if (x < 1.0) return 15.0;
	if (x < 2.0) return 7.0;
	if (x < 3.0) return 13.0;
	return 5.0;
}


#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
// These are authored display codes, including reserved effect identities.
// Decode once before the linear spatial output; keep alpha/depth unchanged.
vec3 r2_effect_decode(vec3 encoded) {
    return mix(encoded / 12.92, pow((encoded + vec3(0.055)) / 1.055, vec3(2.4)),
        step(vec3(0.04045), encoded));
}
#endif

void fragment() {
	vec4 pixel = texture(capture_texture, UV);
	// Keep fully/partially transparent capture texels out of the depth pass.
	// At intermediate fade values the ordered threshold reduces coverage while
	// every surviving fragment remains the exact semantic marker.
	float threshold = (bayer4(FRAGCOORD.xy) + 0.5) / 16.0;
	if (pixel.a <= threshold) {
		discard;
	}
	ALBEDO = semantic_marker;
#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
	ALBEDO = r2_effect_decode(ALBEDO);
#endif
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.05;
}
