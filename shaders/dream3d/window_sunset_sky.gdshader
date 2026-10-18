shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/dream3d/architecture_cutaway.gdshaderinc"

void vertex() {
	architecture_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Muted, frosted office glazing with a single distant city horizon.
uniform vec4 horizon_color : source_color = vec4(0.48, 0.63, 0.65, 1.0);
uniform vec4 mid_sky_color : source_color = vec4(0.36, 0.49, 0.52, 1.0);
uniform vec4 zenith_color : source_color = vec4(0.27, 0.36, 0.40, 1.0);
uniform float emission_intensity : hint_range(0.5, 3.0) = 1.0;
uniform float sheen_intensity : hint_range(0.0, 1.0) = 0.06;

void fragment() {
	if (architecture_cutaway && architecture_visibility(architecture_world) < 0.5) { discard; }
	// Vertical sky gradient from horizon (UV.y = 1.0 -> h = 0.0) to zenith (UV.y = 0.0 -> h = 1.0)
	float h = clamp(1.0 - UV.y, 0.0, 1.0);

	// Smooth two-tier nocturnal city sky blending
	vec3 sky = mix(horizon_color.rgb, mid_sky_color.rgb, smoothstep(0.08, 0.52, h));
	sky = mix(sky, zenith_color.rgb, smoothstep(0.45, 0.95, h));

	// Distant glittering city lights along the lower horizon
	if (h < 0.15) {
		vec2 city_grid = vec2(architecture_world.x * 32.0, (1.0 - UV.y) * 44.0);
		float cell_hash = fract(sin(dot(floor(city_grid), vec2(12.9898, 78.233))) * 43758.5453);
		if (cell_hash > 0.62 && fract(city_grid.x) > 0.32 && fract(city_grid.y) > 0.32) {
			vec3 win_col = mix(vec3(0.55, 0.85, 1.0), vec3(0.95, 0.85, 0.6), fract(cell_hash * 7.1));
			float dist_fade = 1.0 - smoothstep(0.02, 0.15, h);
			sky += win_col * 0.42 * dist_fade;
		}
	}

	// Subtle cool silver-blue diagonal glass reflection
	float diag = architecture_world.x * 0.32 - UV.y * 0.55;
	float sheen = pow(clamp(sin(diag) * 0.5 + 0.5, 0.0, 1.0), 5.0) * sheen_intensity;
	vec3 sheen_color = vec3(0.7, 0.85, 1.0) * sheen;

	ALBEDO = (sky + sheen_color) * emission_intensity;
}
