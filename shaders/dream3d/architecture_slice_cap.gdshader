shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform float wall_height = 2.6;
void vertex() {
	float cut_offset = VERTEX.y;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world.y = wall_height * .3 + cut_offset;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
}
void fragment() { ALBEDO = vec3(0.0, 0.0, 0.0); }
