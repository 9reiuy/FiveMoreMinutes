shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying float height;
void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.)).y;
}
void fragment() {
	float pitch = fract(height / .17);
	float lip = smoothstep(.04, .23, pitch) * (1. - smoothstep(.26, .40, pitch));
	float blade = smoothstep(.23, .9, pitch);
	ALBEDO = vec3(.048, .054, .052) * (.68 + blade * .47) + vec3(.035) * lip;
	ROUGHNESS = .72;
	METALLIC = .18;
	SPECULAR = .26;
}
