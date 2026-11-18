shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/dream3d/passage_end_fade.gdshaderinc"

// Dark brushed gunmetal steel-plate industrial bunker deck for Chapter 1-4:
// - Staggered rectangular bolted steel deck plates (RockLow_Metal12 PBR grain + BrushedIron wear)
// - Anti-slip diamond-tread console pit mat & central east-west cable trench channel
// - Painted red/yellow safety keylines, NE Weapon Corner emblem, and flush industrial grates
uniform sampler2D deck_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D deck_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D deck_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D iron_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D iron_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D iron_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 safety : source_color = vec4(0.88, 0.72, 0.19, 1.0);
uniform vec4 stencil_color : source_color = vec4(0.76, 0.78, 0.74, 1.0);
uniform vec4 hazard_color : source_color = vec4(0.76, 0.58, 0.17, 1.0);
uniform vec4 emblem_color : source_color = vec4(0.54, 0.19, 0.16, 1.0);
uniform vec4 view_opening = vec4(0.0);
uniform vec4 passage_z_fade = vec4(0.0);
uniform float fade_floor = 0.0;
instance uniform vec4 grate_rect = vec4(0.0);

varying vec2 metres;
varying float floor_y;
varying flat vec3 view_eye;

float deck_hash(vec2 p) {
	uvec2 cell = uvec2(ivec2(floor(p)));
	uint h = cell.x * 374761393u + cell.y * 668265263u + 2246822519u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 16777215u) / 16777216.0;
}

float deck_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(deck_hash(i), deck_hash(i + vec2(1.0, 0.0)), f.x),
		mix(deck_hash(i + vec2(0.0, 1.0)), deck_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float deck_fbm(vec2 p) {
	return deck_noise(p) * 0.55 + deck_noise(p * 2.13 + vec2(7.3, 1.9)) * 0.30 + deck_noise(p * 4.41 + vec2(2.1, 9.7)) * 0.15;
}

float seam(float position, float pitch, float half_width, float aa) {
	float distance_to_joint = abs(fract(position / pitch + 0.5) - 0.5) * pitch;
	return 1.0 - smoothstep(half_width, half_width + aa, distance_to_joint);
}

float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void apply_floor_grate(vec4 rect, vec2 p_world, float aa, float tone, inout vec3 finish, inout float rough_out, inout float metal_out) {
	if (rect.z <= rect.x) { return; }
	vec2 size = rect.zw - rect.xy;
	vec2 p = p_world - rect.xy;
	vec2 to_edge = min(p, size - p);
	float edge = min(to_edge.x, to_edge.y);
	if (edge < -0.22) { return; }
	float across = size.x < size.y ? p.x : p.y;
	float along = size.x < size.y ? p.y : p.x;
	float frame = 1.0 - smoothstep(0.065, 0.115, edge);
	float end_bar = seam(along, 1.65, 0.038, aa);
	float fine_bar = seam(across, 0.17, 0.023, aa);
	float cross_wire = seam(along, 0.34, 0.014, aa);
	float joint_plate = max(frame, end_bar);
	float lip = seam(across - 0.016, 0.17, 0.009, aa);
	vec3 steel = mix(vec3(0.014, 0.016, 0.018), vec3(0.036, 0.042, 0.046), cross_wire);
	steel = mix(steel, vec3(0.054, 0.062, 0.066), fine_bar);
	steel += vec3(0.020) * lip * fine_bar;
	steel = mix(steel, vec3(0.082, 0.090, 0.095), joint_plate);
	steel *= 0.86 + 0.55 * tone;
	float inset = smoothstep(-aa, aa, edge);
	finish = mix(finish, steel, inset);
	rough_out = mix(rough_out, 0.60, inset);
	metal_out = mix(metal_out, 0.34, inset);
	float keyline = 1.0 - smoothstep(0.025, 0.025 + aa, abs(edge + 0.115));
	float at_corner = 1.0 - smoothstep(0.62, 0.68, max(to_edge.x, to_edge.y));
	finish = mix(finish, safety.rgb * (0.72 + 0.32 * tone), keyline * at_corner);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	metres = world.xz;
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
	vec2 dx = dFdx(metres), dy = dFdy(metres);
	float aa = clamp(max(fwidth(metres.x), fwidth(metres.y)), 0.008, 0.1);

	float d_pit = sd_box(metres - vec2(32.6, 26.7), vec2(4.2, 3.9));
	float in_pit = 1.0 - smoothstep(-aa, aa, d_pit);
	float d_trench = sd_box(metres - vec2(39.6, 26.8), vec2(2.8, 1.0));
	float in_trench = 1.0 - smoothstep(-aa, aa, d_trench);
	float in_armory_zone = smoothstep(-aa, aa, -sd_box(metres - vec2(43.3, 17.65), vec2(2.9, 3.8)));

	// Dark brushed gunmetal steel deck plates (staggered 1.8m x 1.2m armored plates)
	vec2 plate_span = vec2(1.8, 1.2);
	float row_idx = floor(metres.y / plate_span.y);
	vec2 plate_world = vec2(metres.x + mod(row_idx, 2.0) * (plate_span.x * 0.5), metres.y);

	float deck_repeat = 2.6;
	float iron_repeat = 1.5;
	vec2 uv_deck = plate_world / deck_repeat;
	vec2 uv_iron = metres / iron_repeat;

	vec3 deck_diff = textureGrad(deck_albedo, uv_deck, dx / deck_repeat, dy / deck_repeat).rgb;
	float deck_rgh = textureGrad(deck_rough, uv_deck, dx / deck_repeat, dy / deck_repeat).r;
	vec3 deck_nrm = textureGrad(deck_normal, uv_deck, dx / deck_repeat, dy / deck_repeat).rgb;

	vec3 iron_diff = textureGrad(iron_albedo, uv_iron, dx / iron_repeat, dy / iron_repeat).rgb;
	float iron_rgh = textureGrad(iron_rough, uv_iron, dx / iron_repeat, dy / iron_repeat).r;
	vec3 iron_nrm = textureGrad(iron_normal, uv_iron, dx / iron_repeat, dy / iron_repeat).rgb;

	float zone_blend = clamp(max(in_pit, in_trench), 0.0, 1.0);
	vec3 grain = mix(deck_diff, iron_diff, 0.25 + 0.55 * zone_blend);
	float rough_tex = mix(deck_rgh, iron_rgh, 0.25 + 0.55 * zone_blend);
	vec3 nrm = normalize(mix(deck_nrm, iron_nrm, 0.22 + 0.58 * zone_blend));
	float tone = dot(grain, vec3(0.27, 0.55, 0.18));
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = mix(0.64, 0.78, zone_blend);

	float joint = max(seam(plate_world.x, plate_span.x, 0.0085, aa), seam(plate_world.y, plate_span.y, 0.0085, aa));
	vec2 plate_id = floor(plate_world / plate_span);
	float casting = fract(sin(dot(plate_id, vec2(27.13, 13.41))) * 43758.54);
	vec2 within = fract(plate_world / plate_span) * plate_span;
	vec2 rim = min(within, plate_span - within);
	float bevel = 1.0 - smoothstep(0.015, 0.08, min(rim.x, rim.y));
	float corner_bolt = 1.0 - smoothstep(0.016, 0.022 + aa, length(rim - vec2(0.085, 0.085)));
	float side_bolt = 1.0 - smoothstep(0.015, 0.021 + aa, length(rim - vec2(0.32, 0.085)));
	float fastener = clamp(max(corner_bolt, side_bolt), 0.0, 1.0) * (1.0 - zone_blend * 0.7);

	// Deep charcoal gunmetal steel palette with warmer dark mineral steel near NE Weapon Corner
	vec3 met_mid = vec3(0.679, 0.729, 0.789);
	vec3 tex_boost = clamp((grain / max(met_mid, vec3(0.05)) - vec3(1.0)) * 1.65 + vec3(1.0), vec3(0.42), vec3(1.48));
	vec3 deck_base = mix(vec3(0.096, 0.105, 0.116), vec3(0.118, 0.124, 0.132), in_armory_zone * 0.75);
	vec3 finish = deck_base * tex_boost * mix(0.84, 1.16, casting);
	// Subtle brushed specular bevel along steel plate edges
	finish = mix(finish, finish * 1.18 + vec3(0.012, 0.014, 0.016), bevel * 0.35);

	// Dark anti-slip perforated steel mat inside Console Pit & Cable Trench
	float tread_ribs = clamp(seam(metres.x, 0.24, 0.014, aa) + seam(metres.y, 0.24, 0.014, aa), 0.0, 1.0);
	float tread_studs = 1.0 - smoothstep(0.020, 0.032 + aa, length(fract(metres * 4.0) - vec2(0.5)) * 0.25);
	vec3 pit_col = vec3(0.058, 0.064, 0.072) * (0.85 + 0.26 * tone) + vec3(0.016, 0.018, 0.020) * max(tread_ribs * 0.7, tread_studs * 0.5);
	finish = mix(finish, pit_col, zone_blend);

	float rough_out = mix(0.36, 0.62, rough_tex);
	rough_out = mix(rough_out, 0.52, zone_blend);
	float metal_out = mix(0.32, 0.18, zone_blend);
	metal_out = mix(metal_out, 0.28, in_armory_zone * 0.5);

	finish *= (1.0 - 0.42 * joint) * (1.0 - 0.38 * fastener);
	rough_out = mix(rough_out, 0.72, joint * 0.65);

	// Oil & traffic foot-scuff modulation across deck plates
	vec2 px = floor(metres * 32.0) / 32.0;
	float mottle = deck_fbm(px * 0.65 + vec2(4.2, 8.7));
	float oil_stain = smoothstep(0.44, 0.78, deck_fbm(px * 0.42 + vec2(17.1, 3.4)));
	float edge_wear = clamp(bevel * 0.30 + oil_stain * 0.42, 0.0, 1.0);
	finish *= mix(0.84, 1.14, mottle);
	finish = mix(finish, vec3(0.038, 0.042, 0.048), oil_stain * 0.36);
	rough_out = clamp(rough_out - oil_stain * 0.14 + bevel * 0.06, 0.28, 0.86);
	metal_out = clamp(metal_out - edge_wear * 0.10, 0.16, 0.52);

	float wear_mask = mix(0.68, 0.96, smoothstep(0.22, 0.76, deck_noise(metres * 2.8)));

	// Crisp red inner perimeter stripe + outer yellow keyline around Console Pit & East-West Cable Trench
	float pit_red = 1.0 - smoothstep(0.0, 0.048 + aa, abs(d_pit + 0.06));
	float pit_yellow = 1.0 - smoothstep(0.0, 0.042 + aa, abs(d_pit - 0.06));
	float trench_edges = step(36.8, metres.x) * step(metres.x, 42.4);
	float trench_red = (1.0 - smoothstep(0.0, 0.045 + aa, min(abs(metres.y - 25.88), abs(metres.y - 27.72)))) * trench_edges;
	float trench_yellow = (1.0 - smoothstep(0.0, 0.040 + aa, min(abs(metres.y - 25.74), abs(metres.y - 27.86)))) * trench_edges;
	float red_mask = clamp(max(pit_red, trench_red), 0.0, 1.0) * wear_mask;
	float yellow_mask = clamp(max(pit_yellow, trench_yellow), 0.0, 1.0) * wear_mask;
	finish = mix(finish, vec3(0.66, 0.18, 0.15) * (0.82 + 0.24 * tone), red_mask);
	finish = mix(finish, vec3(0.82, 0.64, 0.18) * (0.82 + 0.24 * tone), yellow_mask);

	// Entrance (47, 34) and North Exit (38, 13) hazard threshold bars
	float hatch_diag = abs(fract((metres.x + metres.y) * 2.2) - 0.5);
	float in_entry_bar = step(sd_box(metres - vec2(46.65, 34.0), vec2(0.42, 1.55)), 0.0);
	float in_exit_bar = step(sd_box(metres - vec2(38.0, 13.15), vec2(1.55, 0.35)), 0.0);
	float hazard_bars = clamp(in_entry_bar + in_exit_bar, 0.0, 1.0) * smoothstep(0.22, 0.25, hatch_diag) * 0.64 * wear_mask;
	finish = mix(finish, hazard_color.rgb * (0.76 + 0.30 * tone), hazard_bars);

	// Subtle weathered crimson workshop emblem centered under Open Weapon Corner workbench (43.3, 17.65)
	float r_emb = length(metres - vec2(43.3, 17.65));
	float ring_outer = 1.0 - smoothstep(0.0, 0.065 + aa, abs(r_emb - 1.50));
	float ring_inner = 1.0 - smoothstep(0.0, 0.048 + aa, abs(r_emb - 1.12));
	float emb_mask = clamp(max(ring_outer, ring_inner), 0.0, 1.0) * in_armory_zone * wear_mask * 0.62;
	finish = mix(finish, emblem_color.rgb * (0.82 + 0.28 * tone), emb_mask);

	float paint_mask = clamp(max(max(red_mask, yellow_mask), max(hazard_bars, emb_mask)), 0.0, 1.0);
	metal_out = mix(metal_out, 0.08, paint_mask);
	rough_out = mix(rough_out, 0.56, paint_mask * 0.7);

	// Two clean recessed industrial grates in open aisle space
	apply_floor_grate(grate_rect, metres, aa, tone, finish, rough_out, metal_out);
	apply_floor_grate(vec4(38.8, 32.2, 42.4, 33.5), metres, aa, tone, finish, rough_out, metal_out);
	apply_floor_grate(vec4(34.2, 18.2, 37.6, 19.4), metres, aa, tone, finish, rough_out, metal_out);

	float spec_out = 0.42;
	ROUGHNESS = rough_out;
	SPECULAR = spec_out;
	METALLIC = metal_out;
	ALBEDO = finish;

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
	if (fade_floor < 0.001 && passage_end_fade.y <= passage_end_fade.x && passage_z_fade.y <= passage_z_fade.x) {
		final_fade = 1.0;
	}
	ALBEDO *= final_fade;
	SPECULAR *= final_fade;
	ROUGHNESS = mix(1.0, ROUGHNESS, final_fade);
}
