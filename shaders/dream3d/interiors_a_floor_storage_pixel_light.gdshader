shader_type spatial;
// Storage room floor accent shader: renders low-contrast warehouse staging boundary lines
// on top of worn concrete base with direct light support.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 surface_tint : source_color = vec4(0.80, 0.86, 0.94, 1.0);

#include "res://shaders/dream3d/light_noise_contour.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = texture(albedo_texture, UV).rgb;

	// Wide-joint concrete slab (FLOOR_BRICKS_PER_TEXTURE = 6)
	vec2 cell_uv = fract(UV * 6.0);
	vec2 edge_dist = min(cell_uv, 1.0 - cell_uv);
	float min_edge = min(edge_dist.x, edge_dist.y);

	// Tonal compression: smooth matte industrial concrete, suppress noisy cracks
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 concrete_base = mix(vec3(lum), vec3(0.40, 0.41, 0.45), 0.65);

	// Wide concrete expansion joint at tile seams
	if (min_edge < 0.018) {
		concrete_base = mix(concrete_base, vec3(0.20, 0.21, 0.25), 0.80);
	}
	// Low-contrast pale staging bay boundary lane
	else if (min_edge < 0.052) {
		vec3 lane_color = vec3(0.88, 0.90, 0.95);
		concrete_base = mix(concrete_base, lane_color, 0.55);
	}

	ALBEDO = concrete_base * surface_tint.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	float noisy_attenuation = apply_light_noise_contour(ATTENUATION, world_pos);
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * noisy_attenuation * n_dot_l / PI;
}
