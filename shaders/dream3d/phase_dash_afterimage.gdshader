shader_type spatial;
// Surviving silhouette pixels must write depth, otherwise the late-drawn
// approved floor materials repaint them. Discarded pixels never write depth.
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_opaque;
#include "res://shaders/dream3d/phase_dash_ink.gdshaderinc"
#include "res://shaders/dream3d/character_reference_depth.gdshaderinc"
uniform sampler2D capture_texture : filter_nearest, repeat_disable;
uniform float band = 0.0;
uniform float opacity = 0.0;
void fragment() {
	vec4 pixel = texture(capture_texture, UV);
	if (pixel.a < 0.5 || opacity < phase_dash_coverage(FRAGCOORD.xy)) discard;
	vec3 spatial_position = reference_view_position(VERTEX, INV_VIEW_MATRIX, VIEW_MATRIX);
	DEPTH = reference_fragment_depth(spatial_position, FRAGCOORD.z, PROJECTION_MATRIX);
	float shade = dot(pixel.rgb,vec3(0.2126,0.7152,0.0722)) > 0.075 ? 1.0 : 0.45;
	ALBEDO = phase_dash_ink(band)*shade;
}
