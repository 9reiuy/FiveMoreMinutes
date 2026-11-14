shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform float moon_visibility = 1.0;
uniform vec3 body_colour : source_color = vec3(0.13,0.20,0.23);

void fragment() {
	ALBEDO = body_colour;
	EMISSION = body_colour * mix(0.11,0.16,moon_visibility);
	ROUGHNESS = 0.97;
	SPECULAR = 0.0;
}
