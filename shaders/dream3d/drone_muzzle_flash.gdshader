shader_type spatial;
// Additive muzzle flash for the drone sample: unshaded, no depth write, so it
// stacks over the weapon and the room without sorting artefacts.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 flash_color : source_color = vec4(1.0, 0.48, 0.10, 1.0);
uniform float intensity = 1.0;

void fragment() {
	ALBEDO = flash_color.rgb * intensity;
	ALPHA = clamp(intensity, 0.0, 1.0);
}
