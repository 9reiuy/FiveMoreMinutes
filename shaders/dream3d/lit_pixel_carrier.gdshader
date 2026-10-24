shader_type spatial;
// The carrier is alpha-tested pixel art.  A depth pre-pass keeps opaque
// furniture pixels as real occluders while the opt-in screen cutout can open
// only its circular hole; transparent actor pixels remain depth-safe too.
render_mode cull_disabled, blend_mix, depth_draw_opaque, diffuse_lambert, specular_disabled;
#include "res://shaders/dream3d/character_reference_depth.gdshaderinc"
uniform sampler2D capture_texture : filter_nearest, repeat_disable;
#include "res://shaders/dream3d/enemy_readability_rim.gdshaderinc"
// Characters receive a tiny visibility floor, but this never becomes a
// Light3D and therefore cannot illuminate floors, walls, or other actors.
// The bridge leaves this at zero for furniture, weapons, blood, and effects.
uniform float character_emission_strength = 0.0;
uniform float hurt_flash_amount = 0.0;
uniform bool smoke_silhouette = false;
// Multiplier on 3D diffuse lighting (e.g. 0.50 for characters, 1.0 for props)
uniform float character_light_scale : hint_range(0.0, 2.0) = 1.0;

global uniform vec4 occlusion_cutout_0;
global uniform vec4 occlusion_cutout_1;
global uniform vec4 occlusion_cutout_2;
global uniform vec4 occlusion_cutout_3;
global uniform vec4 occlusion_cutout_4;
global uniform vec4 occlusion_cutout_5;
global uniform vec4 occlusion_cutout_6;
global uniform vec4 occlusion_cutout_7;
global uniform vec2 occlusion_viewport_size;

// Only visual occluders such as high furniture opt in. Actor carriers keep
// their own pixels intact; the wall/door/furniture material receives the hole.
uniform bool occlusion_cutout_enabled = false;

// Cutouts use a stylized gradient circular halftone effect.
// The hole is fully transparent at the core and dissolves into a 45-degree
// circular halftone dot pattern that smoothly blends into the solid wall/furniture at the perimeter.
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

// 本 capture 管线（ActorDepthBridge → SubViewportTexture → 本 shader）存在
// 可重复的颜色空间偏移：capture 纹理按 sRGB 格式分配，采样时硬件解码为
// linear，且 source_color hint 会在 Compatibility 下注入第二次解码，而输出
// 不做反向编码（blood_color_probe_test 实测 #D96B18 屏幕输出 (195,26,0)，
// G 通道 107→26）。因此这里不用 source_color，并在采样后做精确 sRGB 反变
// 换还原 2D 源颜色；alpha / alpha scissor / ShadowProxy 保持不变。
// 本 capture 管线（ActorDepthBridge → SubViewportTexture → 本 shader）存在
// 可重复的颜色空间偏移：capture 纹理按 sRGB 格式分配，采样时硬件解码为
// linear，且 source_color hint 会注入第二次解码，而管线输出不做反向编码
// （blood_color_probe_test 实测 #D96B18 屏幕输出 G/R 从 0.494 塌陷到 0.13）。
// 因此不用 source_color，并在采样后做精确 sRGB 反变换还原 2D 源颜色；
// alpha / alpha scissor / ShadowProxy 保持不变。
float _srgb_encode(float linear_value) {
	return linear_value <= 0.0031308 ? linear_value * 12.92 : 1.055 * pow(linear_value, 1.0 / 2.4) - 0.055;
}

void fragment() {
	vec4 pixel = texture(capture_texture, UV);
	vec3 spatial_position = reference_view_position(VERTEX, INV_VIEW_MATRIX, VIEW_MATRIX);
	DEPTH = reference_fragment_depth(spatial_position, FRAGCOORD.z, PROJECTION_MATRIX);
	if (reference_depth_enabled) { LIGHT_VERTEX = spatial_position; }
	ALBEDO = vec3(_srgb_encode(pixel.r), _srgb_encode(pixel.g), _srgb_encode(pixel.b));
	ALPHA = pixel.a;
	EMISSION = ALBEDO * max(character_emission_strength, 0.0);
	if (hurt_flash_amount > 0.5 && pixel.a > 0.05) {
		ALBEDO = vec3(1.0);
		EMISSION = vec3(1.0);
	}
	// Only fill formerly transparent edge texels: interior art, lighting and
	// gameplay silhouettes are unchanged. The existing reference DEPTH and
	// alpha scissor apply equally to the rim, so foreground cover still wins.
	if (enemy_rim_enabled && pixel.a < 0.05 && enemy_rim_alpha(UV) > 0.5) {
		ALBEDO = enemy_rim_color.rgb * 0.15;
		EMISSION = enemy_rim_color.rgb * 0.85;
		ALPHA = 1.0;
	}
	if (occlusion_cutout_enabled) {
		ALPHA *= combined_cutout(SCREEN_UV);
	}
	if (smoke_silhouette) {
		ALBEDO=vec3(0.0);
		EMISSION=vec3(0.0);
	}
	ALPHA_SCISSOR_THRESHOLD = 0.05;
	ROUGHNESS = 1.0;
}
void light() {
	// Paper art is readable from either lit face; shadow attenuation remains
	// the real engine shadow map, including walls and rotating door leaves.
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * max(abs(dot(NORMAL,LIGHT)),0.45) * character_light_scale / PI;
}
