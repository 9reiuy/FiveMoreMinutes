shader_type spatial;

// Hit halos blend over the already-rendered actor. They must test scene depth,
// but must not prewrite opaque depth and erase the body under translucent pixels.
render_mode cull_disabled, unshaded, fog_disabled, blend_mix, depth_draw_never, shadows_disabled;
#include "res://shaders/dream3d/character_reference_depth.gdshaderinc"
uniform sampler2D capture_texture : filter_nearest, repeat_disable;
float srgb_encode(float value) {
	return value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1.0 / 2.4) - 0.055;
}
void fragment() {
	vec4 pixel = texture(capture_texture, UV);
	if (pixel.a <= 0.005) { discard; }
	DEPTH = reference_fragment_depth(reference_view_position(VERTEX, INV_VIEW_MATRIX, VIEW_MATRIX), FRAGCOORD.z, PROJECTION_MATRIX);
	ALBEDO = vec3(srgb_encode(pixel.r), srgb_encode(pixel.g), srgb_encode(pixel.b));
	ALPHA = pixel.a;
}
