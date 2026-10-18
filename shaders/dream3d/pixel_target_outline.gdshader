shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://shaders/dream3d/character_reference_depth.gdshaderinc"
uniform sampler2D capture_texture : filter_nearest, repeat_disable;
uniform bool billboard_enabled = true;
uniform vec4 outline_color : source_color = vec4(1.0);
void vertex() {
	if (billboard_enabled) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
			INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
	}
}
void fragment() {
	DEPTH = reference_fragment_depth(reference_view_position(VERTEX, INV_VIEW_MATRIX, VIEW_MATRIX), FRAGCOORD.z, PROJECTION_MATRIX);
	vec2 px = 1.0 / vec2(textureSize(capture_texture, 0));
	float centre = texture(capture_texture, UV).a;
	float edge = 0.0;
	for (int x=-1; x<=1; x++) {
		for (int y=-1; y<=1; y++) {
			edge = max(edge, texture(capture_texture, UV + vec2(float(x),float(y)) * px).a);
		}
	}
	if (centre > 0.05 || edge <= 0.05) { discard; }
	ALBEDO = outline_color.rgb;
	EMISSION = outline_color.rgb;
	ALPHA = outline_color.a;
}
