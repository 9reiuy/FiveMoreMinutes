shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/dream3d/occlusion_cutout.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform float metallic_specular = 0.5;
uniform vec4 emission : source_color = vec4(0.0);
uniform float emission_energy_multiplier = 0.0;

uniform bool textured = false;
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_roughness_r, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D metallic_texture : hint_default_white, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_roughness_normal, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform vec4 metallic_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 roughness_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform bool normal_enabled = false;
uniform float normal_scale = 1.0;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);

uniform bool ao_enabled = false;
uniform sampler2D ao_texture : hint_default_white, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform vec4 ao_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float ao_light_affect = 0.0;
uniform bool clearcoat_enabled = false;
uniform sampler2D clearcoat_texture : hint_default_white, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform float clearcoat = 0.0;
uniform float clearcoat_roughness = 0.0;
varying flat float cutout_camera_pass;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	cutout_camera_pass = float(all(equal(INV_VIEW_MATRIX[3], MAIN_CAM_INV_VIEW_MATRIX[3])));
}

void fragment() {
	if (main_camera_cutout(SCREEN_UV, cutout_camera_pass)) {
		discard;
	}
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = metallic_specular;
	EMISSION = emission.rgb * emission_energy_multiplier;
	if (textured) {
		ALBEDO *= texture(albedo_texture, UV).rgb;
		ROUGHNESS *= dot(texture(roughness_texture, UV), roughness_channel);
		METALLIC *= dot(texture(metallic_texture, UV), metallic_channel);
	}
	if (normal_enabled) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
	if (ao_enabled) {
		AO = dot(texture(ao_texture, UV), ao_channel);
		AO_LIGHT_AFFECT = ao_light_affect;
	}
	if (clearcoat_enabled) {
		vec2 coat_map = texture(clearcoat_texture, UV).rg;
		CLEARCOAT = clearcoat * coat_map.r;
		CLEARCOAT_ROUGHNESS = clearcoat_roughness * coat_map.g;
	}
}
