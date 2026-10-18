shader_type spatial;

// Projectile pixels are a visual-only, camera-facing carrier. Keep them
// independent from room lighting while retaining the same depth-tested
// Sprite3D path as Player and Enemy. The separate OmniLight3D pool remains a
// tiny environment cue; this material is the projectile's own brightness.
render_mode cull_disabled, unshaded, fog_disabled, blend_mix, depth_prepass_alpha, specular_disabled;
#include "res://shaders/dream3d/character_reference_depth.gdshaderinc"

uniform sampler2D capture_texture : filter_nearest, repeat_disable;
uniform float projectile_emission_strength = 0.85;

// The SubViewport capture is sampled as linear by the spatial shader. Match
// the existing pixel-carrier colour-space correction before using the pixel as
// both its visible colour and its emissive contribution.
float _srgb_encode(float linear_value) {
	return linear_value <= 0.0031308 ? linear_value * 12.92 : 1.055 * pow(linear_value, 1.0 / 2.4) - 0.055;
}

void fragment() {
	vec4 pixel = texture(capture_texture, UV);
	DEPTH = reference_fragment_depth(reference_view_position(VERTEX, INV_VIEW_MATRIX, VIEW_MATRIX), FRAGCOORD.z, PROJECTION_MATRIX);
	if (pixel.a <= 0.05) {
		discard;
	}
	vec3 color = vec3(
		_srgb_encode(pixel.r),
		_srgb_encode(pixel.g),
		_srgb_encode(pixel.b)
	);
	ALBEDO = color;
	EMISSION = color * max(projectile_emission_strength, 0.0);
	ALPHA = pixel.a;
	ALPHA_SCISSOR_THRESHOLD = 0.05;
	ROUGHNESS = 1.0;
}
