shader_type spatial;
render_mode diffuse_lambert;
varying vec3 stone_world;
void vertex() { stone_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 pixel = floor(stone_world.xz * 32.0);
	vec2 slab = floor(pixel / 64.0);
	vec2 edge = mod(pixel, 64.0);
	float variation = mod(slab.x * 3.0 + slab.y * 7.0, 5.0) / 4.0;
	vec3 stone = mix(vec3(.28,.33,.39), vec3(.35,.40,.46), variation);
	if (edge.x < 1.0 || edge.y < 1.0) { stone *= .63; }
	else if (edge.x == 1.0 || edge.y == 1.0) { stone *= 1.045; }
	ALBEDO = stone;
	ROUGHNESS = 1.0; SPECULAR = 0.0; METALLIC = 0.0;
}
