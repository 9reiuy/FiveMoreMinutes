shader_type spatial;
render_mode blend_mix, depth_draw_never, diffuse_lambert;
#include "res://shaders/dream3d/architecture_cutaway.gdshaderinc"
#include "res://shaders/dream3d/light_noise_contour.gdshaderinc"
uniform sampler2D atlas : source_color, filter_nearest_mipmap, repeat_disable;
uniform int world_surface = 0;
uniform vec4 tile_rect = vec4(0.0, 0.0, 16.0, 16.0);
varying vec3 world_normal;

global uniform vec4 occlusion_cutout_0;
global uniform vec4 occlusion_cutout_1;
global uniform vec4 occlusion_cutout_2;
global uniform vec4 occlusion_cutout_3;
global uniform vec4 occlusion_cutout_4;
global uniform vec4 occlusion_cutout_5;
global uniform vec4 occlusion_cutout_6;
global uniform vec4 occlusion_cutout_7;
global uniform vec2 occlusion_viewport_size;

// Hard-open cutout: depth_draw_never + discard core (<0.35) + soft ALPHA rim. Transparent queue; no depth prepass seal.
// Floor/actors stay opaque and draw first; furniture blends over them.
uniform bool occlusion_cutout_enabled = false;

// Cutouts use a stylized gradient circular halftone effect.  Numerically
// identical to the wall/door carriers so a hole reads the same wherever it opens.
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

void vertex() {
	architecture_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	if (architecture_cutaway && architecture_visibility(architecture_world) < 0.5) { discard; }
	vec2 atlas_uv = UV;
	if (world_surface > 0) {
		vec2 panel;
		if (world_surface == 1) {
			panel = fract(architecture_world.xz / 2.0);
		} else {
			float along = abs(world_normal.x) > abs(world_normal.z) ? architecture_world.z : architecture_world.x;
			panel = vec2(fract(along / 2.0), clamp(1.0 - (architecture_world.y - architecture_floor_y) / architecture_wall_height, 0.0, 0.999));
		}
		vec2 atlas_size = vec2(textureSize(atlas, 0));
		atlas_uv = (tile_rect.xy + floor(panel * tile_rect.zw) + vec2(.5)) / atlas_size;
	}
	ALBEDO = texture(atlas, atlas_uv).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float occlusion_cut = occlusion_cutout_enabled ? combined_cutout(SCREEN_UV) : 1.0;
	// Hard-open core (matches proven mini probe): discard so Compat leaves prior opaque actors/floor.
	if (occlusion_cut < 0.35) { discard; }
	ALPHA = occlusion_cut;
}

void light() {
	float noisy_attenuation = apply_light_noise_contour(ATTENUATION, architecture_world);
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * noisy_attenuation * n_dot_l / PI;
}
