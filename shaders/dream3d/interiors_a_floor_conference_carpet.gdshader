shader_type spatial;
// Conference room central boardroom carpet shader:
// Renders a large continuous deep cold-gray wool rug with a crisp, restrained
// perimeter border under the conference table cluster.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 surface_tint : source_color = vec4(0.48, 0.50, 0.58, 1.0);
uniform vec4 border_color : source_color = vec4(0.22, 0.24, 0.30, 1.0);
uniform float border_width : hint_range(0.01, 0.15) = 0.055;

#include "res://shaders/dream3d/light_noise_contour.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = texture(albedo_texture, UV).rgb;

	// Cell-local UV (FLOOR_BRICKS_PER_TEXTURE = 6)
	vec2 cell_uv = fract(UV * 6.0);
	vec2 edge_dist = min(cell_uv, 1.0 - cell_uv);
	float min_edge = min(edge_dist.x, edge_dist.y);

	// Deep cold-gray wool base
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 wool_base = mix(vec3(lum), vec3(0.38, 0.40, 0.46), 0.65);

	// Restrained, clean border along outer perimeter
	if (min_edge < border_width) {
		wool_base = mix(wool_base, border_color.rgb, 0.85);
	} else if (min_edge < border_width + 0.02) {
		// Subtle inner accent transition line
		wool_base = mix(wool_base, border_color.rgb * 1.3, 0.45);
	}

	ALBEDO = wool_base * surface_tint.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	float noisy_attenuation = apply_light_noise_contour(ATTENUATION, world_pos);
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * noisy_attenuation * n_dot_l / PI;
}
