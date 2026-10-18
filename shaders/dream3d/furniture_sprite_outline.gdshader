shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://shaders/dream3d/character_reference_depth.gdshaderinc"
#include "res://shaders/dream3d/occlusion_cutout.gdshaderinc"
uniform sampler2D capture_texture : filter_nearest, repeat_disable;

void fragment() {
	DEPTH = reference_fragment_depth(reference_view_position(VERTEX, INV_VIEW_MATRIX, VIEW_MATRIX), FRAGCOORD.z, PROJECTION_MATRIX);
	vec2 pixel_uv = max(fwidth(UV), vec2(0.00001));
	float centre = texture(capture_texture, UV).a;
	if (centre > 0.05) { discard; }
	float edge = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			edge = max(edge, texture(capture_texture, UV + vec2(float(x), float(y)) * pixel_uv).a);
		}
	}
	if (edge <= 0.05) { discard; }
	if (combined_cutout(SCREEN_UV) < 0.35) { discard; }
	ALBEDO = vec3(0.0);
	ALPHA = 1.0;
}
