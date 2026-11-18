shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo_tint : source_color = vec4(0.24, 0.27, 0.30, 1.0);
uniform float metallic_amt = 0.45;
uniform float roughness_amt = 0.65;
uniform float fade_top = -0.9;
uniform float fade_bottom = -8.5;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float vis = smoothstep(fade_bottom, fade_top, world_y);
	ALBEDO = albedo_tint.rgb * vis;
	METALLIC = metallic_amt * vis;
	ROUGHNESS = mix(1.0, roughness_amt, vis);
	SPECULAR = 0.35 * vis;
}
