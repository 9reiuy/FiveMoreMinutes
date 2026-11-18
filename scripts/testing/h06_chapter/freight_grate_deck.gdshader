shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/dream3d/passage_end_fade.gdshaderinc"

uniform sampler2D metal_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metal_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 steel_base : source_color = vec4(0.18, 0.21, 0.23, 1.0);
uniform vec4 frame_base : source_color = vec4(0.24, 0.26, 0.22, 1.0);
uniform vec4 rust_tint : source_color = vec4(0.32, 0.18, 0.11, 1.0);
uniform vec2 panel_span = vec2(2.8, 2.4);
uniform float bar_pitch = 0.165;
uniform float bar_half_width = 0.025;
uniform float unstable_wear = 0.0;
uniform bool use_local_xz = false;
uniform vec4 view_opening = vec4(0.0);
uniform vec4 passage_z_fade = vec4(0.0);
uniform float fade_floor = 0.0;

varying vec2 metres;
varying vec2 pattern_xz;
varying float floor_y;
varying flat vec3 view_eye;

float grate_hash(vec2 p) {
	uvec2 cell = uvec2(ivec2(floor(p)));
	uint h = cell.x * 374761393u + cell.y * 668265263u + 2246822519u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 16777215u) / 16777216.0;
}

float grate_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(grate_hash(i), grate_hash(i + vec2(1.0, 0.0)), f.x),
		mix(grate_hash(i + vec2(0.0, 1.0)), grate_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	metres = world.xz;
	pattern_xz = use_local_xz ? VERTEX.xz : world.xz;
	floor_y = world.y;
	view_eye = MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
}

void fragment() {
	if (view_opening.y > view_opening.x) {
		float depth = metres.y - view_eye.z;
		if (abs(depth) < 0.0001) { discard; }
		float t = (view_opening.z - view_eye.z) / depth;
		vec2 portal = mix(view_eye.xy, vec2(metres.x, floor_y), t);
		if (t < 0.0 || t > 1.0 || portal.x < view_opening.x || portal.x > view_opening.y || portal.y > view_opening.w) { discard; }
	}

	vec2 uv = pattern_xz * 0.55;
	vec3 n_map = texture(metal_normal, uv).rgb;
	float r_map = texture(metal_rough, uv).r;

	// Welded modular steel plate borders & center cross-ribs (mirroring industrial grating catwalk bays)
	vec2 in_panel = fract(pattern_xz / panel_span) * panel_span;
	vec2 edge_dist = min(in_panel, panel_span - in_panel);
	float outer_frame = step(edge_dist.x, 0.105) + step(edge_dist.y, 0.105);
	vec2 mid_dist = abs(in_panel - panel_span * 0.5);
	float cross_brace = step(mid_dist.x, 0.036) + step(mid_dist.y, 0.036);
	float is_frame = clamp(outer_frame + cross_brace, 0.0, 1.0);

	// Corner weld gussets & rivet bolts
	vec2 bolt_pos = abs(edge_dist - vec2(0.055, 0.055));
	float rivet = 1.0 - smoothstep(0.014, 0.024, length(bolt_pos));

	// Fine repeating open iron mesh grid with derivative anti-aliasing to prevent grazing-angle Moire
	vec2 px_grad = max(fwidth(pattern_xz), vec2(0.002));
	float max_grad = clamp(max(px_grad.x, px_grad.y), 0.002, 0.08);
	vec2 cell_pos = abs(fract(pattern_xz / bar_pitch + 0.5) - 0.5) * bar_pitch;
	float aa_x = clamp(px_grad.x * 0.85, 0.003, bar_half_width * 0.9);
	float aa_z = clamp(px_grad.y * 0.85, 0.003, bar_half_width * 0.9);
	float bar_x = 1.0 - smoothstep(bar_half_width - aa_x, bar_half_width + aa_x, cell_pos.x);
	float bar_z = 1.0 - smoothstep(bar_half_width - aa_z, bar_half_width + aa_z, cell_pos.y);
	float is_mesh = clamp(bar_x + bar_z, 0.0, 1.0);
	float distance_soften = smoothstep(0.025, 0.065, max_grad);
	is_mesh = mix(is_mesh, 1.0, distance_soften * 0.55);

	float solid_mask = clamp(is_frame + is_mesh, 0.0, 1.0);
	ALPHA = solid_mask;
	ALPHA_SCISSOR_THRESHOLD = 0.42;
	if (solid_mask < 0.42) {
		discard;
	}

	// Metallic rust/oil weathering across plates
	vec2 bay_id = floor(pattern_xz / panel_span);
	float bay_var = grate_hash(bay_id * 13.7);
	float grime = smoothstep(0.32, 0.78, grate_noise(pattern_xz * 0.42 + vec2(3.1, 7.7)));
	float rust_mask = clamp((step(0.5, is_frame) * 0.45 + grime * 0.35 + unstable_wear * 0.55) * grate_noise(pattern_xz * 1.9), 0.0, 0.85);

	vec3 col = mix(steel_base.rgb, frame_base.rgb, is_frame) * mix(0.86, 1.12, bay_var);
	col = mix(col, rust_tint.rgb, rust_mask * 0.52);
	col *= 1.0 - grime * 0.28;
	col *= 1.0 - rivet * 0.35;
	// Subtle specular rim highlight on top steel grating bar intersections
	float bar_highlight = bar_x * bar_z * 0.05;
	col += vec3(bar_highlight);

	// Passage threshold darkness fade
	float room_fade = 1.0;
	if (passage_end_fade.y > passage_end_fade.x && passage_end_fade.w > passage_end_fade.z) {
		room_fade *= smoothstep(passage_end_fade.x, passage_end_fade.y, metres.x)
			* (1.0 - smoothstep(passage_end_fade.z, passage_end_fade.w, metres.x));
	}
	if (passage_z_fade.y > passage_z_fade.x && passage_z_fade.w > passage_z_fade.z) {
		room_fade *= smoothstep(passage_z_fade.x, passage_z_fade.y, metres.y)
			* (1.0 - smoothstep(passage_z_fade.z, passage_z_fade.w, metres.y));
	}
	float final_fade = mix(fade_floor, 1.0, room_fade);

	ALBEDO = col * final_fade;
	METALLIC = mix(0.62, 0.30, clamp(rust_mask + grime * 0.5, 0.0, 1.0));
	ROUGHNESS = mix(0.46, 0.84, clamp(r_map * 0.55 + grime * 0.35 + rust_mask * 0.4, 0.0, 1.0));
	SPECULAR = 0.48 * final_fade;
	NORMAL_MAP = n_map;
	NORMAL_MAP_DEPTH = 0.38;
}
