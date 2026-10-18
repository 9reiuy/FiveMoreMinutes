shader_type spatial;
render_mode blend_mix, depth_draw_never, diffuse_lambert;
#include "res://shaders/dream3d/architecture_cutaway.gdshaderinc"
#include "res://shaders/dream3d/light_noise_contour.gdshaderinc"
uniform sampler2D pixel_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform bool object_space = false;
uniform bool glow = false;
uniform bool wall_surface = false;
uniform bool sample_furniture_surface = false;
varying vec3 pattern_position;
varying vec3 pattern_normal;

global uniform vec4 occlusion_cutout_0;
global uniform vec4 occlusion_cutout_1;
global uniform vec4 occlusion_cutout_2;
global uniform vec4 occlusion_cutout_3;
global uniform vec4 occlusion_cutout_4;
global uniform vec4 occlusion_cutout_5;
global uniform vec4 occlusion_cutout_6;
global uniform vec4 occlusion_cutout_7;
global uniform vec2 occlusion_viewport_size;

// Same depth_draw_never + discard core path as office_low_pixel (furniture-only).
uniform bool occlusion_cutout_enabled = false;

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
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	pattern_position = object_space ? VERTEX * scale : architecture_world;
	pattern_normal = object_space ? NORMAL : normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	if (architecture_cutaway && architecture_visibility(architecture_world) < 0.5) { discard; }
	vec3 n = abs(pattern_normal);
	vec2 uv = n.y > max(n.x, n.z) ? pattern_position.xz : (n.x > n.z ? pattern_position.zy : pattern_position.xy);
	// The swatch itself is a 32x32 nearest texture. Snapping the UV here
	// destroyed its derivatives, forcing full-detail texels even when a rotated
	// wall/floor projected below one pixel and producing temporal moire.
	ALBEDO = base_color.rgb * texture(pixel_texture, uv).rgb;
	if (sample_furniture_surface) {
		// Crisp face hierarchy without changing lighting or outlining the screen.
		ALBEDO *= pattern_normal.y > 0.55 ? 1.16 : (pattern_normal.y < -0.55 ? 0.68 : 0.82);
	}
	if (wall_surface) {
		float y = floor(architecture_world.y * 32.0) / 32.0;
		if (y < .125) { ALBEDO *= .42; }
		else if (y < .75) { ALBEDO *= .78; }
		else if (y < .8125) { ALBEDO = min(base_color.rgb * 1.18, vec3(.85)); }
		if (y >= architecture_wall_height - .0625) { ALBEDO = min(base_color.rgb * 1.18, vec3(.85)); }
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (glow) { EMISSION = ALBEDO * 0.6; }
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
