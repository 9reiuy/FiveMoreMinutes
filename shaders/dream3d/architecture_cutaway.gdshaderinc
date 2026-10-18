uniform bool architecture_cutaway = false;
uniform float architecture_wall_height = 2.6;
uniform float architecture_floor_y = 0.0;
varying vec3 architecture_world;

float architecture_visibility(vec3 p) {
	float edge = architecture_floor_y + architecture_wall_height * 0.3;
	float coverage = clamp((edge + 0.05 - p.y) / 0.10, 0.0, 1.0);
	vec2 cell = floor(p.xz * 32.0 + p.y * 8.0);
	float threshold = (mod(cell.x + mod(cell.y, 4.0) * 3.0, 4.0) + 0.5) / 4.0;
	return step(threshold, coverage);
}
