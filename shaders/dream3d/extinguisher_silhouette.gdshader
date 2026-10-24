shader_type spatial;
// Ordered after gas, but still using the actor's real reference depth.
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, blend_mix, depth_draw_never;
#include "res://shaders/dream3d/character_reference_depth.gdshaderinc"
uniform sampler2D capture_texture : filter_nearest, repeat_disable;
void fragment() {
	if(texture(capture_texture,UV).a<=.05)discard;
	DEPTH=reference_fragment_depth(reference_view_position(VERTEX,INV_VIEW_MATRIX,VIEW_MATRIX),FRAGCOORD.z,PROJECTION_MATRIX);
	ALBEDO=vec3(0.0);
	ALPHA=1.0;
}
