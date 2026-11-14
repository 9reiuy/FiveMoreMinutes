shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/dream3d/occlusion_cutout.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_r, filter_nearest_mipmap_anisotropic, repeat_enable;

uniform mat4 building_inv = mat4(1.0);
uniform vec4 tint_colour : source_color = vec4(0.86, 0.88, 0.87, 1.0);
uniform vec4 grime_colour : source_color = vec4(0.11, 0.10, 0.08, 1.0);
uniform vec4 rust_colour : source_color = vec4(0.28, 0.13, 0.07, 1.0);
uniform vec4 dust_colour : source_color = vec4(0.42, 0.44, 0.45, 1.0);
uniform vec2 tile_span = vec2(2.8, 2.8);
uniform float roughness_bias = 0.54;
uniform float normal_depth = 0.34;
uniform float metallic_amount = 0.04;
uniform float seam_strength = 0.20;
uniform float seam_width = 0.008;
uniform float tex_contrast = 0.48;
uniform float wear_amount = 0.78;
uniform float wetness = 0.56;
uniform float crack_strength = 0.65;
uniform bool is_wall = false;
uniform bool occlusion_cutout_enabled = false;

varying vec3 v_build_pos;
varying vec3 v_build_normal;
varying flat float cutout_camera_pass;

float hash21(vec2 p) {
	uvec2 cell = uvec2(ivec2(floor(p)));
	uint h = cell.x * 374761393u + cell.y * 668265263u + 2246822519u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 16777215u) / 16777216.0;
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm2(vec2 p) {
	float v = 0.0;
	v += noise21(p) * 0.55;
	v += noise21(p * 2.13 + vec2(7.3, 1.9)) * 0.30;
	v += noise21(p * 4.41 + vec2(2.1, 9.7)) * 0.15;
	return v;
}

float concrete_scuff(vec2 point) {
	vec2 cell = floor(point / 1.15);
	float seed = hash21(cell + vec2(17.0, 31.0));
	vec2 shift = vec2(hash21(cell + 7.0), hash21(cell + 23.0)) * 0.30 - 0.15;
	vec2 offset = mod(point, 1.15) - 0.575 - shift;
	float angle = (hash21(cell + 5.0) - 0.5) * 2.5;
	vec2 dir = vec2(cos(angle), sin(angle));
	float half_len = mix(0.10, 0.34, seed);
	vec2 closest = dir * clamp(dot(offset, dir), -half_len, half_len);
	return (1.0 - smoothstep(0.012, 0.044, distance(offset, closest))) * smoothstep(0.55, 0.84, seed);
}

float concrete_crack(vec2 point) {
	vec2 warped = point + vec2(noise21(point * 2.3), noise21(point * 2.3 + vec2(11.4, 5.2))) * 0.42;
	float ridge_a = abs(noise21(warped * 0.92 + vec2(3.1, 7.4)) - 0.5);
	float ridge_b = abs(noise21(warped * 1.48 + vec2(19.2, 4.7)) - 0.5);
	float crack_a = 1.0 - smoothstep(0.008, 0.026, ridge_a);
	float crack_b = 1.0 - smoothstep(0.007, 0.022, ridge_b);
	float mask_a = smoothstep(0.42, 0.72, noise21(point * 0.35 + vec2(1.5, 9.1)));
	float mask_b = smoothstep(0.46, 0.76, noise21(point * 0.42 + vec2(8.2, 2.3)));
	return clamp(crack_a * mask_a + crack_b * mask_b * 0.75, 0.0, 1.0);
}

void vertex() {
	v_build_pos = (building_inv * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_build_normal = normalize((mat3(building_inv) * mat3(MODEL_MATRIX) * NORMAL));
	cutout_camera_pass = float(all(equal(INV_VIEW_MATRIX[3], MAIN_CAM_INV_VIEW_MATRIX[3])));
}

void fragment() {
	if (occlusion_cutout_enabled && main_camera_cutout(SCREEN_UV, cutout_camera_pass)) {
		discard;
	}

	vec3 n = abs(v_build_normal);
	vec2 world_uv;
	if (!is_wall && n.y >= 0.45) {
		world_uv = v_build_pos.xz;
	} else if (n.x > n.z) {
		world_uv = vec2(v_build_pos.z, v_build_pos.y);
	} else {
		world_uv = vec2(v_build_pos.x, v_build_pos.y);
	}

	vec2 uv = world_uv / tile_span;
	vec3 tex_col = texture(albedo_tex, uv).rgb;
	vec3 tex_nrm = texture(normal_tex, uv).rgb;
	float tex_rgh = texture(rough_tex, uv).r;

	vec2 px = floor(world_uv * 32.0) / 32.0;

	// Chipped & weathered expansion joints aligned 1:1 with tile_span
	vec2 cell_uv = fract(uv);
	float edge_x = min(cell_uv.x, 1.0 - cell_uv.x) * tile_span.x;
	float edge_y = min(cell_uv.y, 1.0 - cell_uv.y) * tile_span.y;
	float joint_dist = min(edge_x, edge_y);
	float chip_jitter = noise21(px * 7.5 + vec2(2.7, 9.1)) * 0.016 * wear_amount;
	float seam = 1.0 - smoothstep(seam_width * 0.4, seam_width * 1.6 + chip_jitter, joint_dist);

	vec2 cell_id = floor(uv);
	float panel_tone = mix(0.88, 1.08, hash21(cell_id + vec2(13.0, 7.0)));

	// Pixel-coherent 32px/m industrial aging (cracks, spalling, stains, rust, dusty abrasion, wet puddles)
	float aggregate = hash21(floor(world_uv * 32.0));
	float pits = step(0.955, aggregate) * wear_amount;
	float mottling = fbm2(px * 0.95 + vec2(4.2, 8.7));
	float broad_stain = smoothstep(0.36, 0.78, fbm2(px * 0.45 + vec2(19.0, 3.0)));
	float rust_stain = smoothstep(0.60, 0.86, fbm2(px * 0.62 + vec2(27.4, 14.1))) * wear_amount;
	float cracks = concrete_crack(px) * crack_strength * wear_amount;
	float spall_patch = smoothstep(0.68, 0.84, fbm2(px * 1.45 + vec2(11.3, 6.8))) * wear_amount;
	float seam_dirt = (1.0 - smoothstep(0.01, 0.30, joint_dist)) * (0.45 + broad_stain * 0.75) * wear_amount;

	float grime = broad_stain * 0.44 * wear_amount + seam_dirt * 0.56 + pits * 0.34 + cracks * 0.65;
	float damp = 0.0;
	float abrasion = 0.0;
	float dust_wear = 0.0;

	if (is_wall) {
		// Vertical seepage columns & soot leaks running down concrete joints and top parapets
		float streak_col = noise21(vec2(px.x * 2.4, px.y * 0.09) + vec2(5.1, 1.7));
		float streak_fine = noise21(vec2(px.x * 7.8, px.y * 0.28) + vec2(13.2, 4.3));
		float streak = smoothstep(0.50, 0.82, streak_col * 0.68 + streak_fine * 0.38);
		float joint_drip = (1.0 - smoothstep(0.02, 0.28, edge_x)) * smoothstep(0.38, 0.78, noise21(px * vec2(1.8, 0.35)));
		// Repeating damp baseboard & upper lintel grime independent of absolute story elevation
		float local_band = 1.0 - smoothstep(0.10, 0.58, abs(fract((v_build_pos.y - 1.28) / 2.0) - 0.0));
		float lower_base = 1.0 - smoothstep(0.06, 0.75, max(0.0, v_build_pos.y));
		grime += (streak * 0.52 + joint_drip * 0.62 + lower_base * 0.36 + local_band * 0.24) * wear_amount;
		rust_stain += (streak * joint_drip * 0.65 + spall_patch * 0.45) * wear_amount;
	} else {
		damp = smoothstep(0.46, 0.76, fbm2(px * 0.58 + vec2(9.2, 4.1))) * wetness;
		abrasion = concrete_scuff(px) * wear_amount;
		// Chalky dusty foot-traffic / scraped aggregate brightening on dark worn slabs
		dust_wear = smoothstep(0.48, 0.82, fbm2(px * 0.82 + vec2(31.0, 12.0))) * (1.0 - damp) * 0.38 * wear_amount;
		dust_wear = max(dust_wear, abrasion * 0.52);
		grime += concrete_scuff(px * 0.72 + vec2(8.6, 4.1)) * 0.32 * wear_amount;
		rust_stain *= (0.45 + seam_dirt * 1.15);
	}

	float luma = dot(tex_col, vec3(0.333));
	vec3 normalized_tex = mix(vec3(0.84), vec3(luma), tex_contrast);
	float mottled_var = mix(0.80, 1.14, mottling) * mix(0.92, 1.06, aggregate);
	vec3 base_rgb = normalized_tex * tint_colour.rgb * panel_tone * mottled_var;

	// Spalled dark aggregate patches & dusty concrete chalk wear
	base_rgb = mix(base_rgb, base_rgb * 0.66, spall_patch * 0.42);
	base_rgb = mix(base_rgb, dust_colour.rgb, clamp(dust_wear * 0.48, 0.0, 0.46));

	// Dark grime, rust stains, and glossy dark dampness
	base_rgb = mix(base_rgb, rust_colour.rgb, clamp(rust_stain * 0.48, 0.0, 0.46));
	base_rgb = mix(base_rgb, grime_colour.rgb, clamp(grime * 0.62, 0.0, 0.74));
	base_rgb = mix(base_rgb, base_rgb * vec3(0.46, 0.52, 0.56), damp * 0.84);
	base_rgb *= 1.0 - cracks * 0.68;
	base_rgb *= 1.0 - seam * seam_strength;

	ALBEDO = clamp(base_rgb, vec3(0.025), vec3(0.92));
	NORMAL_MAP = tex_nrm;
	NORMAL_MAP_DEPTH = normal_depth + pits * 0.22 + cracks * 0.38 + spall_patch * 0.16;
	ROUGHNESS = clamp(
		mix(roughness_bias, tex_rgh, 0.40) + clamp(grime, 0.0, 0.6) * 0.20 + dust_wear * 0.22 + cracks * 0.26 - damp * 0.46 + seam * 0.16,
		0.12,
		0.96
	);
	METALLIC = clamp(metallic_amount * (1.0 - grime * 0.65 - dust_wear * 0.8), 0.0, 0.85);
	SPECULAR = mix(0.24, 0.74, damp);
}
