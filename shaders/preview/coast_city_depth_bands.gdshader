shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform float moon_visibility = 1.0;
uniform vec3 body_colour : source_color = vec3(0.18, 0.22, 0.29);
uniform vec3 haze_colour : source_color = vec3(0.26, 0.25, 0.34);
uniform float distance_haze : hint_range(0.0, 1.0) = 0.20;
varying float world_height;

void vertex() {
	world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float shore_mist = 1.0 - smoothstep(4.0, 76.0, world_height);
	float haze = clamp(distance_haze + shore_mist * 0.24, 0.0, 0.92);
	vec3 silhouette = mix(body_colour, haze_colour, haze);
	ALBEDO = silhouette * 0.36;
	EMISSION = silhouette * 0.66 * mix(0.64, 1.0, moon_visibility);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
