shader_type spatial;
// Billboarded pixel muzzle star.  A box cross reads as a flat bar from a
// top-down camera; a camera-facing star keeps the burst readable at any angle.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D burst_texture : filter_nearest, repeat_disable;
uniform vec4 flash_color : source_color = vec4(1.0, 0.62, 0.24, 1.0);
uniform float intensity = 1.0;

void fragment() {
	float mask = texture(burst_texture, UV).a;
	ALBEDO = flash_color.rgb * intensity;
	ALPHA = mask * clamp(intensity, 0.0, 1.0);
}
