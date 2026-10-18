shader_type spatial;
render_mode specular_schlick_ggx;

#include "res://shaders/ui/phone_environment_sampling.gdshaderinc"

uniform vec4 body_colour : source_color = vec4(0.7, 0.72, 0.76, 1.0);
uniform float body_roughness : hint_range(0.0, 1.0) = 0.5;
uniform float body_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float body_specular : hint_range(0.0, 1.0) = 0.4;
uniform sampler2D body_texture : source_color, filter_nearest, repeat_disable;
uniform bool body_has_texture = false;

void fragment() {
	vec3 base = body_colour.rgb;
	if (body_has_texture) { base *= texture(body_texture, UV).rgb; }
	ALBEDO = base;
	ROUGHNESS = body_roughness;
	METALLIC = body_metallic;
	SPECULAR = body_specular;
	vec3 normal = normalize(NORMAL);
	vec3 incoming = -normalize(VIEW);
	vec3 shell_direction = (INV_VIEW_MATRIX * vec4(reflect(incoming, normal), 0.0)).xyz;
	float grazing = pow(1.0 - max(dot(normal, normalize(VIEW)), 0.0), 5.0);
	vec3 f0 = mix(vec3(0.04 * body_specular * 2.0), base, body_metallic);
	vec3 fresnel = mix(f0, vec3(1.0), grazing);
	EMISSION = phone_environment(shell_direction, body_roughness) * fresnel * (1.0 - body_roughness * 0.55);
}
