// Left black/lit edge and right lit/black edge, in level metres.
uniform vec4 passage_end_fade = vec4(0.0);

void apply_passage_end_fade(float x, inout vec3 albedo, inout float roughness, inout float specular) {
	if (passage_end_fade.y > passage_end_fade.x && passage_end_fade.w > passage_end_fade.z) {
		float left = smoothstep(passage_end_fade.x, passage_end_fade.y, x);
		float right = 1.0 - smoothstep(passage_end_fade.z, passage_end_fade.w, x);
		float light = left * right;
		albedo *= light;
		specular *= light;
		roughness = mix(1.0, roughness, light);
	}
}
