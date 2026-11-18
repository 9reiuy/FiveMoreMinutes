shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/dream3d/occlusion_cutout.gdshaderinc"

uniform vec4 brick_light : source_color = vec4(0.66, 0.56, 0.39, 1.0);
uniform vec4 brick_dark : source_color = vec4(0.49, 0.41, 0.28, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.28, 0.24, 0.18, 1.0);
uniform vec4 baseboard_color : source_color = vec4(0.24, 0.25, 0.23, 1.0);

varying vec2 wall_uv;
varying float world_y;
varying flat float camera_pass;

float b_hash(vec2 p) {
	uvec2 cell = uvec2(ivec2(floor(p)));
	uint h = cell.x * 374761393u + cell.y * 668265263u + 2246822519u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 16777215u) / 16777216.0;
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 normal = MODEL_NORMAL_MATRIX * NORMAL;
	wall_uv = vec2(abs(normal.x) > abs(normal.z) ? world.z : world.x, world.y);
	world_y = world.y;
	camera_pass = float(all(equal(INV_VIEW_MATRIX[3], MAIN_CAM_INV_VIEW_MATRIX[3])));
}

void fragment() {
	if (main_camera_cutout(SCREEN_UV, camera_pass)) { discard; }
	float bw = 0.26;
	float bh = 0.115;
	float row = floor(wall_uv.y / bh);
	float offset = mod(row, 2.0) * 0.5;
	float bx = wall_uv.x / bw + offset;
	float by = wall_uv.y / bh;
	vec2 id = floor(vec2(bx, by));
	vec2 f = fract(vec2(bx, by));
	float aa = clamp(max(fwidth(bx), fwidth(by)), 0.015, 0.12);
	float mx = min(f.x, 1.0 - f.x);
	float my = min(f.y, 1.0 - f.y);
	float bevel_x = smoothstep(0.035, 0.095, mx);
	float bevel_y = smoothstep(0.055, 0.135, my);
	float in_brick = smoothstep(0.035, 0.035 + aa, mx) * smoothstep(0.055, 0.055 + aa, my);
	float tone = b_hash(id);
	float grain = b_hash(floor(wall_uv * 28.0));
	vec3 col = mix(brick_dark.rgb, brick_light.rgb, tone) * mix(0.84, 1.12, grain);
	vec3 finish = mix(mortar_color.rgb, col, in_brick);

	// Procedural brick mortar normal relief for crisp specular & light grazing
	float nx = (f.x < 0.12 ? -1.0 : (f.x > 0.88 ? 1.0 : 0.0)) * (1.0 - bevel_x) * in_brick;
	float ny = (f.y < 0.16 ? -1.0 : (f.y > 0.84 ? 1.0 : 0.0)) * (1.0 - bevel_y) * in_brick;
	NORMAL_MAP = vec3(0.5 + nx * 0.34, 0.5 + ny * 0.34, 0.92);
	NORMAL_MAP_DEPTH = 1.1;

	float sill = smoothstep(0.22, 0.25, world_y);
	finish = mix(baseboard_color.rgb, finish, sill);
	float bottom_shade = (1.0 - smoothstep(0.0, 0.42, world_y)) * 0.22;
	finish *= 1.0 - bottom_shade;

	ALBEDO = finish;
	ROUGHNESS = mix(0.95, 0.78, in_brick * grain);
	METALLIC = 0.02;
	SPECULAR = 0.18;
}
