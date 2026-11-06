shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled;
#include "res://shaders/preview/hellkind_sample/ink_points.gdshaderinc"

void fragment() {
	float forward = UV.y;
	float width = mix(.57, .83, smoothstep(0.0, .46, forward));
	float side = abs(UV.x * 2.0 - 1.0) / width;
	float spread = (1.0 - smoothstep(.14, 1.0, side));
	float density = .82 * spread * pow(1.0 - forward, 1.75) * smoothstep(0.0, .13, forward);
	float pixel_scale = max(1.0, VIEWPORT_SIZE.y / 360.0);
	if (ink_threshold(FRAGCOORD.xy / pixel_scale) >= density) discard;
	vec3 near_ink = vec3(235.0, 174.0, 107.0) / 255.0;
	vec3 far_ink = vec3(151.0, 85.0, 53.0) / 255.0;
	ALBEDO = ink_output(forward < .47 ? near_ink : far_ink);
	ALPHA = 1.0;
}
