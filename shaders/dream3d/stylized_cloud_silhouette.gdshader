shader_type spatial;
// Reveal the existing black actor silhouette through cloud depth only.
// Other opaque geometry still occludes it using the real reference depth.
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, blend_mix, depth_draw_never, depth_test_disabled;
#include "res://shaders/dream3d/character_reference_depth.gdshaderinc"
uniform sampler2D capture_texture : filter_nearest, repeat_disable;
uniform bool warmup_only=false;
uniform sampler2D opaque_color : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D opaque_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 cloud_paper : source_color=vec3(.835294118,.858823529,.898039216);
uniform vec3 cloud_ink : source_color=vec3(.466666667,.486274510,.552941176);
void fragment() {
	if (warmup_only) discard;
	if (texture(capture_texture,UV).a<=.05) discard;
	float actor_depth=reference_fragment_depth(reference_view_position(VERTEX,INV_VIEW_MATRIX,VIEW_MATRIX),FRAGCOORD.z,PROJECTION_MATRIX);
	float scene_depth=texture(opaque_depth,SCREEN_UV).r;
	if (actor_depth+.00001<scene_depth) {
		vec3 color=texture(opaque_color,SCREEN_UV).rgb;
		float match_linear=min(distance(color,cloud_paper),distance(color,cloud_ink));
		float match_display=min(distance(color,vec3(.835294118,.858823529,.898039216)),distance(color,vec3(.466666667,.486274510,.552941176)));
		if (min(match_linear,match_display)>.012) discard;
	}
	DEPTH=actor_depth;
	ALBEDO=vec3(0.0);
	ALPHA=1.0;
}
