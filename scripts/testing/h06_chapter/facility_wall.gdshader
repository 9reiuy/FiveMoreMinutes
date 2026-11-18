shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/dream3d/occlusion_cutout.gdshaderinc"
#include "res://shaders/dream3d/passage_end_fade.gdshaderinc"

uniform sampler2D precast : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaster_albedo : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal : hint_normal, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_map : hint_roughness_r, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform vec4 enamel : source_color = vec4(.85, .85, .82, 1.);
uniform vec4 dado_color : source_color = vec4(.063, .068, .066, 1.);
uniform vec4 passage_z_fade = vec4(0.);
uniform float fade_floor = 0.;
uniform float normal_depth = 0.;
uniform float weathering = 0.;
uniform float plaster_blend = 0.;
uniform float institutional_panel = 0.;
uniform float panel_pitch = 2.8;
uniform vec3 tex_midpoint = vec3(.132, .116, .103);
uniform float albedo_contrast = 2.6;
uniform bool attached_finish = false;
varying vec2 metres;
varying vec2 world_xz;
varying float height;
varying flat float camera_pass;

float wall_hash(vec2 p) {
	uvec2 cell = uvec2(ivec2(floor(p)));
	uint h = cell.x * 374761393u + cell.y * 668265263u + 2246822519u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 16777215u) / 16777216.;
}

float wall_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3. - 2. * f);
	return mix(mix(wall_hash(i), wall_hash(i + vec2(1., 0.)), f.x),
		mix(wall_hash(i + vec2(0., 1.)), wall_hash(i + vec2(1., 1.)), f.x), f.y);
}

float wall_fbm(vec2 p) {
	return wall_noise(p) * .55 + wall_noise(p * 2.13 + vec2(7.3, 1.9)) * .30 + wall_noise(p * 4.41 + vec2(2.1, 9.7)) * .15;
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.)).xyz;
	vec3 normal = MODEL_NORMAL_MATRIX * NORMAL;
	vec3 surface_point = attached_finish ? VERTEX : world;
	metres = vec2(abs(normal.x) > abs(normal.z) ? surface_point.z : surface_point.x, surface_point.y);
	world_xz = world.xz;
	height = VERTEX.y;
	camera_pass = float(all(equal(INV_VIEW_MATRIX[3], MAIN_CAM_INV_VIEW_MATRIX[3])));
}

void fragment() {
	if (main_camera_cutout(SCREEN_UV, camera_pass)) { discard; }
	vec2 dx_uv = dFdx(metres) / 3.5;
	vec2 dy_uv = dFdy(metres) / 3.5;
	vec2 uv = (floor(metres * 32.) + .5) / 112.;
	vec3 texture_color = textureGrad(precast, uv, dx_uv, dy_uv).rgb;
	if (plaster_blend > .001) {
		texture_color = mix(texture_color, textureGrad(plaster_albedo, uv, dx_uv, dy_uv).rgb, plaster_blend);
	}
	float grain = dot(texture_color, vec3(.27, .55, .18));
	float aa = clamp(fwidth(metres.x), .008, .09);
	float edge = abs(fract(metres.x / panel_pitch + .5) - .5) * panel_pitch;
	float joint = 1. - smoothstep(.014, .016 + aa, edge);
	float panel_tone = wall_hash(vec2(floor(metres.x / panel_pitch), 11.0));
	float sill = smoothstep(.66, .69, height);
	vec3 finish = mix(dado_color.rgb, enamel.rgb, sill) * (.79 + .37 * grain);
	float reveal = 1. - smoothstep(.018, .042, abs(height - .69));
	finish *= 1. - max(joint * .46, reveal * .56);
	float rough = mix(.78, .91, grain);
	if (normal_depth > .001) {
		NORMAL_MAP = textureGrad(surface_normal, uv, dx_uv, dy_uv).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
	if (institutional_panel > .5) {
		vec3 tex_clean = clamp((texture_color / max(vec3(.26), vec3(.04)) - vec3(1.)) * .45 + vec3(1.), vec3(.78), vec3(1.14));
		float trim_top = 1. - smoothstep(.012, .032, abs(height - 1.98));
		float vent_groove = 1. - smoothstep(.008, .022, abs(height - .24));
		finish = mix(dado_color.rgb, enamel.rgb, sill) * tex_clean * mix(.94, 1.05, panel_tone);
		finish *= 1. - max(max(joint * .32, reveal * .45), max(trim_top * .22, vent_groove * .26));
		float lower_dust = (1. - smoothstep(.02, .18, max(0., height))) * .16;
		finish *= 1. - lower_dust;
		rough = mix(.48, .68, grain);
	} else if (weathering > .001) {
		vec2 px = floor(metres * 32.) / 32.;
		float rough_sample = textureGrad(roughness_map, uv, dx_uv, dy_uv).r;
		vec3 tex_hi = textureGrad(precast, metres / 3.5, dx_uv, dy_uv).rgb;
		if (plaster_blend > .001) {
			tex_hi = mix(tex_hi, textureGrad(plaster_albedo, metres / 3.5, dx_uv, dy_uv).rgb, plaster_blend);
		}
		vec3 plaster_detail = clamp((tex_hi / max(tex_midpoint, vec3(.04)) - vec3(1.)) * albedo_contrast + vec3(1.), vec3(.32), vec3(1.75));
		finish = mix(vec3(.070, .075, .072), enamel.rgb, sill) * plaster_detail * mix(.85, 1.15, panel_tone);
		finish *= 1. - max(joint * .52, reveal * .60);
		float mottle = wall_fbm(px * .75 + vec2(3.1, 8.7));
		float peel_field = wall_fbm(px * 1.15 + vec2(17.2, 5.4));
		float patch_peel = smoothstep(.56, .78, peel_field) * sill;
		float peel_lip = smoothstep(.49, .55, peel_field) * (1. - smoothstep(.56, .63, peel_field)) * sill;
		float streak_col = wall_noise(vec2(px.x * 2.6, px.y * .11) + vec2(5.1, 1.7));
		float streak_fine = wall_noise(vec2(px.x * 8.2, px.y * .34) + vec2(11.3, 4.9));
		float drip = smoothstep(.48, .82, streak_col * .66 + streak_fine * .38) * smoothstep(.38, 2.25, height);
		float seam_drip = (1. - smoothstep(.02, .28, edge)) * smoothstep(.34, .76, wall_noise(px * vec2(1.9, .38)));
		float lower_damp = (1. - smoothstep(.04, .66, max(0., height))) * .54;
		float upper_soot = smoothstep(1.68, 2.48, height) * (.38 + .48 * mottle);
		vec2 crack_w = px + vec2(wall_noise(px * 2.1), wall_noise(px * 2.1 + vec2(9.4, 3.7))) * .36;
		float crack = (1. - smoothstep(.008, .025, abs(wall_noise(crack_w * 1.15 + vec2(2.3, 6.1)) - .5)))
			* smoothstep(.48, .76, wall_noise(px * .38 + vec2(4.1, 8.2))) * sill;
		float grime = (drip * .54 + seam_drip * .68 + lower_damp + upper_soot * .42 + patch_peel * .32) * weathering;
		finish *= mix(.78, 1.16, mottle);
		finish = mix(finish, vec3(.145, .132, .118) * mix(.85, 1.15, grain), clamp(patch_peel * .72 * weathering, 0., .62));
		finish += vec3(.085, .088, .086) * clamp(peel_lip * .68 * weathering, 0., .48);
		finish = mix(finish, vec3(.155, .105, .072), clamp((seam_drip * .62 + drip * .38) * weathering, 0., .52));
		finish = mix(finish, vec3(.060, .065, .066), clamp(grime * .62, 0., .74));
		finish *= 1. - crack * .62 * weathering;
		rough = clamp(mix(rough, rough_sample, .62) + grime * .16 - patch_peel * .10, .38, .96);
	}
	float screw = 1. - smoothstep(.020, .038, length(vec2(edge - .08, height - .81)));
	ALBEDO = mix(finish, vec3(.12), screw * .62);
	METALLIC = .06;
	SPECULAR = .22;
	ROUGHNESS = rough;
	float room_fade = 1.;
	if (passage_end_fade.y > passage_end_fade.x && passage_end_fade.w > passage_end_fade.z) {
		room_fade *= smoothstep(passage_end_fade.x, passage_end_fade.y, world_xz.x)
			* (1. - smoothstep(passage_end_fade.z, passage_end_fade.w, world_xz.x));
	}
	if (passage_z_fade.y > passage_z_fade.x && passage_z_fade.w > passage_z_fade.z) {
		room_fade *= smoothstep(passage_z_fade.x, passage_z_fade.y, world_xz.y)
			* (1. - smoothstep(passage_z_fade.z, passage_z_fade.w, world_xz.y));
	}
	float final_fade = mix(fade_floor, 1., room_fade);
	ALBEDO *= final_fade;
	SPECULAR *= final_fade;
	ROUGHNESS = mix(1., ROUGHNESS, final_fade);
}
