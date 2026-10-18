// NOTE: Shader automatically converted from Godot Engine 4.4.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0,1.0,1.0,1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
//uniform ivec2 albedo_texture_size;
//uniform float point_size : hint_range(0.1, 128.0, 0.1);
uniform sampler2D texture_orm : source_color, filter_linear_mipmap, repeat_enable;

uniform sampler2D texture_alpha : hint_roughness_g, filter_linear_mipmap, repeat_enable;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.001) = 0.9;

uniform float roughness : hint_range(0.0,2.0) = 1.0;
//uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
//uniform vec4 metallic_texture_channel;
//uniform sampler2D texture_roughness : hint_roughness_g, filter_linear_mipmap, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01)=0.5;
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.0;

uniform sampler2D texture_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;

//uniform sampler2D texture_ambient_occlusion : hint_default_white, filter_linear_mipmap, repeat_enable;
//uniform vec4 ao_texture_channel;
uniform float ao_light_affect : hint_range(0.0, 1.0, 0.01);

uniform sampler2D texture_emission : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec4 emission : source_color;
uniform float emission_energy : hint_range(0.0, 100.0, 0.01);

uniform vec3 uv1_scale = vec3(1.0,1.0,1.0);
uniform vec3 uv1_offset;
//uniform vec3 uv2_scale;
//uniform vec3 uv2_offset;


void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
}

void fragment() {
	vec2 base_uv = UV;

	vec4 albedo_tex = texture(texture_albedo, base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;

	float alpha_tex = dot(texture(texture_alpha, base_uv),vec4(1.0, 0.0, 0.0, 0.0));
	ALPHA = alpha_tex;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;

	vec4 orm_tex = texture(texture_orm, base_uv);
	//float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
	METALLIC = orm_tex.b * metallic;
	SPECULAR = specular;

	//vec4 roughness_texture_channel = vec4(0.0, 1.0, 0.0, 0.0);
	//float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
	ROUGHNESS = orm_tex.g * roughness;

	// Normal Map: Enabled
	NORMAL_MAP = texture(texture_normal, base_uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale;

	// Ambient Occlusion: Enabled
	AO = orm_tex.r;
	AO_LIGHT_AFFECT = ao_light_affect;

	vec3 emission_tex = texture(texture_emission, base_uv).rgb;
	// Emission Operator: Add
	EMISSION = (emission.rgb * emission_tex) * emission_energy;




}
