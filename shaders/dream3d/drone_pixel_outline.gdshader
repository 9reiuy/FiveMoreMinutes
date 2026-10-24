shader_type spatial;
// White one-pixel inverted hull, matching the outline the game draws around
// enemies (pixel_target_outline) but usable on real 3D geometry instead of a
// capture quad.
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;

uniform float outline_pixels = 1.8;
uniform vec4 outline_color : source_color = vec4(0.93, 0.95, 1.0, 1.0);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 projected_normal = (PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xy;
	float length_px = length(projected_normal);
	if (length_px > 0.00001) {
		clip.xy += projected_normal / length_px * (2.0 * outline_pixels * clip.w / VIEWPORT_SIZE);
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	EMISSION = outline_color.rgb * 0.65;
	ALPHA = outline_color.a;
}
