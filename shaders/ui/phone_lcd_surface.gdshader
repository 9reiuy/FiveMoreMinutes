shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

#include "res://shaders/ui/phone_environment_sampling.gdshaderinc"

uniform sampler2D lcd_texture : source_color, filter_nearest, repeat_disable;
uniform float glass_reflection_strength : hint_range(0.0, 0.3) = 0.11;
uniform float lcd_surface_effects_strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 lcd = texture(lcd_texture, UV).rgb;
	float edge = smoothstep(0.26, 0.7, length(UV - vec2(0.5)));
	float subpixel = mod(floor(UV.x * 148.0), 3.0) < 0.5 ? 0.994 : 1.0;
	vec3 normal = normalize(NORMAL);
	vec3 view_direction = normalize(VIEW);
	vec3 shell_direction = (INV_VIEW_MATRIX * vec4(reflect(-view_direction, normal), 0.0)).xyz;
	float grazing = pow(1.0 - max(dot(normal, view_direction), 0.0), 5.0);
	vec3 reflected = phone_environment(shell_direction, 0.13);
	// LCD stays self-lit and nearest-sampled. Real mirrored scene lights add
	// their ordinary specular response; there is no animated painted sweep.
	ALBEDO = vec3(0.005);
	ROUGHNESS = 0.16;
	METALLIC = 0.0;
	SPECULAR = 0.35;
	EMISSION = lcd * (1.0 - edge * 0.025 * lcd_surface_effects_strength) * mix(1.0, subpixel, lcd_surface_effects_strength) + reflected * glass_reflection_strength * (0.3 + grazing * 0.7);
}
