shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

// The vertical wall is viewed at a shallow perspective angle.  Trilinear and
// anisotropic filtering removes the temporal shimmer that nearest sampling of
// the fine 2K grain produces under a moving SpotLight.  The fade remains a
// presentation-only operation; gameplay topology is untouched.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 surface_tint : source_color = vec4(1.04, 1.03, 1.08, 1.0);
uniform float texture_contrast : hint_range(0.0, 2.0) = 0.65;
uniform float baseboard_height : hint_range(0.0, 0.5) = 0.22;
uniform vec4 baseboard_color : source_color = vec4(0.16, 0.17, 0.22, 1.0);
uniform float wainscot_height : hint_range(0.0, 1.5) = 0.88;
uniform vec4 wainscot_color : source_color = vec4(0.36, 0.38, 0.44, 1.0);

#include "res://shaders/dream3d/light_noise_contour.gdshaderinc"

varying float vert_y;
varying vec3 world_pos;

void vertex() {
	vert_y = VERTEX.y;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
	vec4 base = texture(albedo_texture, UV);
	float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 compressed = mix(vec3(lum), base.rgb, texture_contrast);
	vec3 wall_body = compressed * surface_tint.rgb;

	float is_wainscot = 1.0 - smoothstep(wainscot_height - 0.02, wainscot_height, vert_y);
	float divider = 1.0 - smoothstep(0.0, 0.02, abs(vert_y - wainscot_height));
	vec3 wall_col = mix(wall_body, wall_body * wainscot_color.rgb * 1.6, is_wainscot * 0.40);
	wall_col = mix(wall_col, baseboard_color.rgb, divider * 0.70);

	float is_baseboard = 1.0 - smoothstep(baseboard_height - 0.015, baseboard_height, vert_y);
	wall_col = mix(wall_col, baseboard_color.rgb, is_baseboard);

	// Authored wall side UVs run V=1 at the floor and V=0 at the top.
	float height_ratio = clamp(1.0 - UV.y, 0.0, 1.0);
	float vertical_alpha;
	if (height_ratio < 0.5) {
		vertical_alpha = mix(0.30, 0.70, height_ratio * 2.0);
	} else {
		vertical_alpha = mix(0.70, 1.00, (height_ratio - 0.5) * 2.0);
	}
	ALBEDO = wall_col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	float occlusion_cut = base.a * vertical_alpha * combined_cutout(SCREEN_UV);
	if (occlusion_cut < 0.35) { discard; }
	ALPHA = occlusion_cut;
}

void light() {
	float noisy_attenuation = apply_light_noise_contour(ATTENUATION, world_pos);
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * noisy_attenuation * n_dot_l / PI;
}
