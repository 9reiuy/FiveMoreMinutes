shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/dream3d/occlusion_cutout.gdshaderinc"

uniform sampler2D finish_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D finish_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D finish_roughness : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D finish_metalness : filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 finish_colour : source_color = vec4(1.0);
uniform vec3 tex_midpoint = vec3(0.5);
uniform float repeat_metres = 0.85;
uniform float albedo_contrast = 2.0;
uniform float luma_only = 0.0;
uniform float normal_strength = 0.85;
uniform vec2 roughness_range = vec2(0.32, 0.82);
uniform float metallic_level = 0.0;
uniform float specular_level = 0.35;

uniform float wear_amount = 0.85;
uniform float rust_amount = 0.35;
uniform float edge_wear = 1.0;
uniform float edge_band = 0.042;
uniform vec4 exposed_substrate : source_color = vec4(0.20, 0.23, 0.26, 1.0);
uniform vec4 grime_colour : source_color = vec4(0.08, 0.075, 0.070, 1.0);

varying vec3 world_pos;
varying vec3 world_n;
varying vec3 local_metres;
varying vec3 normal_local;
varying vec3 box_size;
varying vec2 instance_seed;
varying flat float camera_pass;

float sr_hash(vec2 p) {
	uvec2 cell = uvec2(ivec2(floor(p)));
	uint h = cell.x * 374761393u + cell.y * 668265263u + 2246822519u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 16777215u) / 16777216.0;
}

float sr_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(sr_hash(i), sr_hash(i + vec2(1.0, 0.0)), f.x),
		mix(sr_hash(i + vec2(0.0, 1.0)), sr_hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float sr_fbm(vec2 p) {
	return sr_noise(p) * 0.55 + sr_noise(p * 2.17 + vec2(7.3, 1.9)) * 0.30 + sr_noise(p * 4.43 + vec2(2.1, 9.7)) * 0.15;
}

vec4 triplanar_tex(sampler2D tex, vec3 p, vec3 w, float scale, vec2 seed_off) {
	vec2 ux = p.zy / scale + seed_off;
	vec2 uy = p.xz / scale + seed_off * vec2(1.3, 0.7);
	vec2 uz = p.xy / scale + seed_off * vec2(0.7, 1.3);
	return texture(tex, ux) * w.x + texture(tex, uy) * w.y + texture(tex, uz) * w.z;
}

void vertex() {
	box_size = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	local_metres = VERTEX * box_size;
	normal_local = normalize(NORMAL);
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	instance_seed = fract(vec2(dot(origin.xz, vec2(0.37, 0.71)), dot(origin.xy, vec2(0.53, 0.29))));
	camera_pass = float(all(equal(INV_VIEW_MATRIX[3], MAIN_CAM_INV_VIEW_MATRIX[3])));
}

void fragment() {
	if (main_camera_cutout(SCREEN_UV, camera_pass)) { discard; }

	vec3 w = pow(max(abs(normal_local), vec3(0.0001)), vec3(8.0));
	w /= (w.x + w.y + w.z);

	vec3 raw_albedo = triplanar_tex(finish_albedo, local_metres, w, repeat_metres, instance_seed).rgb;
	float raw_rough = triplanar_tex(finish_roughness, local_metres, w, repeat_metres, instance_seed).r;
	float raw_metal = triplanar_tex(finish_metalness, local_metres, w, repeat_metres, instance_seed).r;
	vec3 raw_normal = triplanar_tex(finish_normal, local_metres, w, repeat_metres, instance_seed).rgb;

	vec3 mid = max(tex_midpoint, vec3(0.04));
	if (luma_only > 0.5) {
		float rl = dot(raw_albedo, vec3(0.299, 0.587, 0.114));
		float ml = max(dot(mid, vec3(0.299, 0.587, 0.114)), 0.04);
		raw_albedo = vec3(rl);
		mid = vec3(ml);
	}
	vec3 ratio = raw_albedo / mid;
	vec3 detail = clamp((ratio - vec3(1.0)) * albedo_contrast + vec3(1.0), vec3(0.26), vec3(1.85));
	vec3 albedo = finish_colour.rgb * detail;
	float rough = mix(roughness_range.x, roughness_range.y, raw_rough);
	float met = metallic_level * raw_metal;

	if (wear_amount > 0.001) {
		vec3 half_m = box_size * 0.5;
		vec3 edge_d = max(half_m - abs(local_metres), vec3(0.0));
		vec3 ln = abs(normal_local);
		vec2 face_edge = ln.y > 0.65 ? edge_d.xz : (ln.x > ln.z ? edge_d.zy : edge_d.xy);
		float min_span = min(box_size.x, min(box_size.y, box_size.z));
		float valid_edge = smoothstep(0.035, 0.095, min_span);

		float macro = sr_fbm(world_pos.xz * 1.45 + world_pos.xy * 0.95 + instance_seed * 17.0);
		float chip_n = sr_fbm(local_metres.xz * 7.8 + local_metres.xy * 5.6 + instance_seed * 29.0);
		float edge_mask = (1.0 - smoothstep(edge_band * 0.22, edge_band * (0.55 + 1.05 * chip_n), min(face_edge.x, face_edge.y))) * valid_edge * edge_wear;

		float streak = sr_noise(local_metres.xz * vec2(16.0, 2.2) + local_metres.xy * vec2(2.4, 12.0));
		float scratch_mask = smoothstep(0.68, 0.88, streak * 0.68 + chip_n * 0.42);

		float top_face = smoothstep(0.65, 0.88, world_n.y);
		float low_kick = (1.0 - smoothstep(0.02, 0.34, max(0.0, world_pos.y))) * (1.0 - top_face) * smoothstep(0.30, 0.72, box_size.y);
		float top_stain = top_face * smoothstep(0.56, 0.84, macro);
		float rust_n = smoothstep(0.54, 0.82, sr_fbm(world_pos.xz * 3.9 + world_pos.xy * 4.3 + vec2(12.7, 5.1)));

		float chip_total = clamp((edge_mask * 0.82 + scratch_mask * 0.46) * wear_amount, 0.0, 0.92);
		float patina = clamp((low_kick * 0.68 + top_stain * 0.48) * wear_amount, 0.0, 0.78);
		float rust = clamp((edge_mask * 0.78 + low_kick * 0.88) * rust_n * rust_amount, 0.0, 0.84);

		albedo *= mix(0.84, 1.14, macro);
		albedo = mix(albedo, exposed_substrate.rgb * mix(0.82, 1.18, chip_n), chip_total);
		albedo = mix(albedo, grime_colour.rgb, patina);
		albedo = mix(albedo, vec3(0.24, 0.115, 0.052), rust);
		rough = clamp(rough - top_face * 0.08 * macro + patina * 0.14 - chip_total * 0.10, 0.16, 0.96);
		met = mix(met, clamp(met + 0.34, 0.0, 0.88), chip_total * smoothstep(0.15, 0.55, 1.0 - rust));
	}

	ALBEDO = albedo;
	NORMAL_MAP = raw_normal;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = rough;
	METALLIC = met;
	SPECULAR = specular_level;
}
