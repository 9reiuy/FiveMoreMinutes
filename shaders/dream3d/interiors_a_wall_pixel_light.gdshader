shader_type spatial;
// Wall A 材质的"外观等价孪生"（原 interiors_a_wall_material.tres StandardMaterial3D）：
// 贴图/UV/roughness/specular 保持 Interiors A 原材质语义；墙体在透视
// SpotLight 下使用稳定的连续光照，不再对 LIGHT_VERTEX 做旧式像素吸附。
render_mode blend_mix, depth_draw_never, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/dream3d/architecture_cutaway.gdshaderinc"
#include "res://shaders/dream3d/light_noise_contour.gdshaderinc"

// A wall spans several projected pixels at a shallow perspective angle.  Use
// trilinear/aniso filtering here: nearest sampling of the 2K texture creates a
// temporal interference pattern as the SpotLight/camera moves across the fine
// authored grain.  This only changes the wall presentation sampler; gameplay
// UVs, geometry and collision remain unchanged.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 surface_tint : source_color = vec4(1.04, 1.03, 1.08, 1.0);
uniform float texture_contrast : hint_range(0.0, 2.0) = 0.65;
uniform float baseboard_height : hint_range(0.0, 0.5) = 0.22;
uniform vec4 baseboard_color : source_color = vec4(0.16, 0.17, 0.22, 1.0);
uniform float wainscot_height : hint_range(0.0, 1.5) = 0.88;
uniform vec4 wainscot_color : source_color = vec4(0.36, 0.38, 0.44, 1.0);

varying float vert_y;

void vertex() {
	vert_y = VERTEX.y;
	architecture_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

global uniform vec4 occlusion_cutout_0;
global uniform vec4 occlusion_cutout_1;
global uniform vec4 occlusion_cutout_2;
global uniform vec4 occlusion_cutout_3;
global uniform vec4 occlusion_cutout_4;
global uniform vec4 occlusion_cutout_5;
global uniform vec4 occlusion_cutout_6;
global uniform vec4 occlusion_cutout_7;
global uniform vec2 occlusion_viewport_size;

// Cutouts use a stylized gradient circular halftone effect.
// The hole is fully transparent at the core and dissolves into a 45-degree
// circular halftone dot pattern that smoothly blends into the solid wall at the perimeter.
float cutout_factor(vec2 screen_uv, vec4 slot) {
	if (slot.w < 0.5 || slot.z <= 0.0) {
		return 1.0;
	}
	vec2 delta_px = (screen_uv - slot.xy) * occlusion_viewport_size;
	float distance_px = length(delta_px);
	if (distance_px >= slot.z) {
		return 1.0;
	}
	float norm_d = distance_px / slot.z;
	if (norm_d < 0.22) {
		return 0.0;
	}
	float t = (norm_d - 0.22) / 0.78;
	float density = 1.0 - (t * t * (3.0 - 2.0 * t));
	float dot_spacing = clamp(slot.z * 0.12, 5.0, 8.0);
	vec2 rot_px = vec2(
		delta_px.x * 0.7071068 - delta_px.y * 0.7071068,
		delta_px.x * 0.7071068 + delta_px.y * 0.7071068
	);
	vec2 cell = fract(rot_px / dot_spacing) - vec2(0.5);
	float dist_in_cell = length(cell) * dot_spacing;
	float max_hole_r = dot_spacing * 0.75;
	float hole_r = max_hole_r * density;
	float hole_factor = 1.0;
	if (hole_r > 0.05) {
		hole_factor = smoothstep(hole_r - 0.75, hole_r + 0.75, dist_in_cell);
	}
	float rim_mask = smoothstep(slot.z - 3.0, slot.z, distance_px);
	return max(hole_factor, rim_mask);
}

float combined_cutout(vec2 screen_uv) {
	float f = cutout_factor(screen_uv, occlusion_cutout_0);
	f = min(f, cutout_factor(screen_uv, occlusion_cutout_1));
	f = min(f, cutout_factor(screen_uv, occlusion_cutout_2));
	f = min(f, cutout_factor(screen_uv, occlusion_cutout_3));
	f = min(f, cutout_factor(screen_uv, occlusion_cutout_4));
	f = min(f, cutout_factor(screen_uv, occlusion_cutout_5));
	f = min(f, cutout_factor(screen_uv, occlusion_cutout_6));
	f = min(f, cutout_factor(screen_uv, occlusion_cutout_7));
	return f;
}

void fragment() {
	if (architecture_cutaway && architecture_visibility(architecture_world) < 0.5) { discard; }
	// Authored 2K wall grain is much denser than a projected wall texel. Even
	// trilinear sampling can select near-full detail on a shallow wall plane and
	// create moving stripes. Keep its broad 32px material variation, but never
	// sample the high-frequency source levels in the gameplay camera.
	vec3 raw_tex = textureLod(albedo_texture, UV, 6.0).rgb;
	// Tonal compression to reduce high-frequency 2K grain
	float lum = dot(raw_tex, vec3(0.299, 0.587, 0.114));
	vec3 compressed = mix(vec3(lum), raw_tex, texture_contrast);
	vec3 wall_body = compressed * surface_tint.rgb;

	// Wainscot zone
	float is_wainscot = 1.0 - smoothstep(wainscot_height - 0.02, wainscot_height, vert_y);
	float divider = 1.0 - smoothstep(0.0, 0.02, abs(vert_y - wainscot_height));
	vec3 wall_col = mix(wall_body, wall_body * wainscot_color.rgb * 1.6, is_wainscot * 0.40);
	wall_col = mix(wall_col, baseboard_color.rgb, divider * 0.70);

	// Continuous dark baseboard skirting at the floor edge
	float is_baseboard = 1.0 - smoothstep(baseboard_height - 0.015, baseboard_height, vert_y);
	wall_col = mix(wall_col, baseboard_color.rgb, is_baseboard);

	ALBEDO = wall_col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	float occlusion_cut = combined_cutout(SCREEN_UV);
	if (occlusion_cut < 0.35) { discard; }
	ALPHA = occlusion_cut;
}

void light() {
	float noisy_attenuation = apply_light_noise_contour(ATTENUATION, architecture_world);
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * noisy_attenuation * n_dot_l / PI;
}
