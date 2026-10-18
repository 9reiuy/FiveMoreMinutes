shader_type spatial;
render_mode unshaded, fog_disabled;
// Architectural top cap renders as solid black.
uniform float wall_height = 2.6;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	// The exposed horizontal wall core is a continuous near-black cap.  Only
	// its vertical skirt follows the cutaway's pixel fade.
	if (world_normal.y <= 0.8) {
		float edge = wall_height * 0.3;
		float coverage = clamp((edge + 0.05 - world_position.y) / 0.10, 0.0, 1.0);
		vec2 cell = floor(world_position.xz * 32.0 + world_position.y * 8.0);
		float threshold = (mod(cell.x + mod(cell.y, 4.0) * 3.0, 4.0) + 0.5) / 4.0;
		if (coverage < threshold) { discard; }
	}
	ALBEDO = vec3(0.0, 0.0, 0.0);
}
