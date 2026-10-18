shader_type spatial;
// Lounge room floor accent shader: renders a warm woven mat with framed borders
// with direct light support.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 surface_tint : source_color = vec4(0.90, 0.82, 0.86, 1.0);

#include "res://shaders/dream3d/light_noise_contour.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = texture(albedo_texture, UV).rgb;

	// Lounge mat: comfortable, low-frequency fabric carpet
	vec2 cell_uv = fract(UV * 6.0);
	vec2 edge_dist = min(cell_uv, 1.0 - cell_uv);
	float min_edge = min(edge_dist.x, edge_dist.y);

	// Carpet base: cohesive soft medium-dark fabric tone without noisy checks
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 carpet_base = mix(vec3(lum), vec3(0.36, 0.38, 0.44), 0.65);

	// Distinct single clean border hem
	if (min_edge < 0.065) {
		vec3 hem_color = vec3(0.20, 0.21, 0.26);
		carpet_base = mix(carpet_base, hem_color, 0.85);
	}

	ALBEDO = carpet_base * surface_tint.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	float noisy_attenuation = apply_light_noise_contour(ATTENUATION, world_pos);
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * noisy_attenuation * n_dot_l / PI;
}
