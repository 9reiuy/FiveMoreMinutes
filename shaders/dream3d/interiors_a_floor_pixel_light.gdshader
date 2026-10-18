shader_type spatial;
// Floor B 材质的"外观等价孪生"：贴图/UV/roughness/specular 与原 StandardMaterial3D
// （interiors_a_floor_material.tres）保持一致；保留原贴图、UV 和直射光表现。
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 surface_tint : source_color = vec4(0.84, 0.89, 0.98, 1.0);
uniform float texture_contrast : hint_range(0.0, 2.0) = 0.50;

#include "res://shaders/dream3d/light_noise_contour.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 raw_tex = texture(albedo_texture, UV).rgb;
	// Tonal compression: suppress high-frequency noise inside tile face, preserve clean grout lines
	float lum = dot(raw_tex, vec3(0.299, 0.587, 0.114));
	vec3 compressed = mix(vec3(lum), raw_tex, texture_contrast);

	// Grout line separation: grout is dark (lum < 0.35), tile face is brighter
	float grout = smoothstep(0.22, 0.38, lum);
	vec3 tile_face = mix(vec3(0.58), compressed, 0.70);
	vec3 floor_base = mix(vec3(0.18, 0.19, 0.24), tile_face, grout);

	ALBEDO = floor_base * surface_tint.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

// Keep the floor's direct-light path explicit for the Compatibility renderer.
// Include the sampled floor colour in the contribution so Compatibility does
// not render a white light term that replaces the tiled albedo.
void light() {
	float noisy_attenuation = apply_light_noise_contour(ATTENUATION, world_pos);
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * noisy_attenuation * n_dot_l / PI;
}
