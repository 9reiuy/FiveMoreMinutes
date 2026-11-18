shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/dream3d/passage_end_fade.gdshaderinc"

uniform sampler2D concrete : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal : hint_normal, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_map : hint_roughness_r, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform vec4 base : source_color = vec4(.69, .68, .65, 1.);
uniform vec4 safety : source_color = vec4(.88, .72, .19, 1.);
uniform vec2 slab_span = vec2(2.6, 1.65);
uniform bool loading_lane = false;
uniform vec4 passage_z_fade = vec4(0.);
uniform float fade_floor = 0.;
uniform float seam_strength = 1.;
uniform float fastener_strength = 1.;
uniform float normal_depth = .16;
uniform float wear_strength = 0.;
uniform float tex_repeat = 4.0;
uniform float albedo_contrast = 1.0;
uniform vec3 tex_midpoint = vec3(.135, .134, .134);
uniform vec4 green_zone_rect = vec4(0.);
uniform vec4 green_zone_color : source_color = vec4(.32, .44, .37, 1.);
// Set only on the brief view into the adjoining room as it streams in.
uniform vec4 view_opening = vec4(0.);
// World-space extents keep the grating flush with the actual floor, including under moving actors.
instance uniform vec4 grate_rect = vec4(0.);
varying vec2 metres;
varying float floor_y;
varying flat vec3 view_eye;

float deck_hash(vec2 p) {
	uvec2 cell = uvec2(ivec2(floor(p)));
	uint h = cell.x * 374761393u + cell.y * 668265263u + 2246822519u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 16777215u) / 16777216.;
}

float deck_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3. - 2. * f);
	return mix(mix(deck_hash(i), deck_hash(i + vec2(1., 0.)), f.x),
		mix(deck_hash(i + vec2(0., 1.)), deck_hash(i + vec2(1., 1.)), f.x), f.y);
}

float deck_fbm(vec2 p) {
	return deck_noise(p) * .55 + deck_noise(p * 2.13 + vec2(7.3, 1.9)) * .30 + deck_noise(p * 4.41 + vec2(2.1, 9.7)) * .15;
}

float deck_crack(vec2 point) {
	vec2 w = point + vec2(deck_noise(point * 2.3), deck_noise(point * 2.3 + vec2(11.4, 5.2))) * .36;
	float r1 = 1. - smoothstep(.004, .014, abs(deck_noise(w * .94 + vec2(3.1, 7.4)) - .5));
	float r2 = 1. - smoothstep(.003, .012, abs(deck_noise(w * 1.48 + vec2(19.2, 4.7)) - .5));
	float m1 = smoothstep(.64, .84, deck_noise(point * .36 + vec2(1.5, 9.1)));
	float m2 = smoothstep(.68, .88, deck_noise(point * .42 + vec2(8.2, 2.3)));
	return clamp(r1 * m1 + r2 * m2 * .65, 0., 1.);
}

float seam(float position, float pitch, float half_width, float aa) {
	float distance_to_joint = abs(fract(position / pitch + .5) - .5) * pitch;
	return 1. - smoothstep(half_width, half_width + aa, distance_to_joint);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.)).xyz;
	metres = world.xz;
	floor_y = world.y;
	view_eye = MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
}

void fragment() {
	if (view_opening.y > view_opening.x) {
		float depth = metres.y - view_eye.z;
		if (abs(depth) < .0001) { discard; }
		float t = (view_opening.z - view_eye.z) / depth;
		vec2 portal = mix(view_eye.xy, vec2(metres.x, floor_y), t);
		if (t < 0. || t > 1. || portal.x < view_opening.x || portal.x > view_opening.y || portal.y > view_opening.w) { discard; }
	}
	vec2 dx = dFdx(metres), dy = dFdy(metres);
	float aa = clamp(max(fwidth(metres.x), fwidth(metres.y)), .008, .1);
	vec2 uv = (floor(metres * 32.) + .5) / (32. * tex_repeat);
	if (albedo_contrast > 1.01) {
		uv = metres / tex_repeat;
	}
	vec3 grain = textureGrad(concrete, uv, dx / tex_repeat, dy / tex_repeat).rgb;
	float tone = dot(grain, vec3(.27, .55, .18));
	float rough = textureGrad(roughness_map, uv, dx / tex_repeat, dy / tex_repeat).r;
	NORMAL_MAP = textureGrad(surface_normal, uv, dx / tex_repeat, dy / tex_repeat).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	float joint = max(seam(metres.x, slab_span.x, .009, aa), seam(metres.y, slab_span.y, .009, aa));
	vec2 slab = floor(metres / slab_span);
	float casting = fract(sin(dot(slab, vec2(27.13, 13.41))) * 43758.54);
	vec2 within = fract(metres / slab_span) * slab_span;
	vec2 rim = min(within, slab_span - within);
	float grime = 1. - smoothstep(.02, .21, min(rim.x, rim.y));
	float fastener = (1. - smoothstep(.017, .022 + aa, length(rim - vec2(.095, .085)))) * fastener_strength;
	float aggregate = clamp((sqrt(max(.0, tone)) - .30) * 1.9, -.34, .46);
	vec3 finish = base.rgb * (.83 + aggregate) * mix(.93, 1.055, casting);
	if (albedo_contrast > 1.01) {
		vec3 tex_boost = clamp((grain / max(tex_midpoint, vec3(.04)) - vec3(1.)) * albedo_contrast + vec3(1.), vec3(.30), vec3(1.72));
		finish = base.rgb * tex_boost * mix(.88, 1.09, casting);
	}
	if (green_zone_rect.z > green_zone_rect.x) {
		vec2 d_lo = metres - green_zone_rect.xy;
		vec2 d_hi = green_zone_rect.zw - metres;
		float edge_z = min(min(d_lo.x, d_hi.x), min(d_lo.y, d_hi.y));
		float in_zone = smoothstep(-.02, .02, edge_z);
		float zone_border = 1. - smoothstep(.015, .045, abs(edge_z));
		finish = mix(finish, green_zone_color.rgb * mix(.92, 1.08, tone), in_zone * .86);
		finish *= 1. - zone_border * .22 * step(-.05, edge_z);
	}
	finish *= (1. - .31 * joint * seam_strength) * (1. - .09 * grime * seam_strength) * (1. - .32 * fastener);
	float rough_out = mix(.61, .92, rough);
	if (wear_strength > .001) {
		vec2 px = floor(metres * 32.) / 32.;
		float mottle = deck_fbm(px * .72 + vec2(4.2, 8.7));
		float stain = smoothstep(.38, .76, deck_fbm(px * .44 + vec2(17.1, 3.4)));
		float chalk = smoothstep(.46, .80, deck_fbm(px * .88 + vec2(29.0, 11.5))) * (1. - stain * .65);
		float crack = wear_strength > .30 ? deck_crack(px) : 0.;
		float soil = (stain * .44 + grime * .52 + crack * .34) * wear_strength;
		finish *= mix(.82, 1.12, mottle);
		finish = mix(finish, finish * 1.24 + vec3(.032, .035, .038), clamp(chalk * .54 * wear_strength, 0., .44));
		finish = mix(finish, vec3(.062, .068, .072), clamp(soil * .58, 0., .66));
		finish *= 1. - crack * .42 * wear_strength;
		NORMAL_MAP_DEPTH += crack * .28 * wear_strength;
		rough_out = clamp(rough_out + chalk * .14 * wear_strength - stain * .18 * wear_strength, .34, .95);
	}
	if (loading_lane) {
		bool outbound = metres.y < 24.;
		float side = outbound ? metres.x - 38.25 : metres.y - 33.80;
		float along = outbound ? metres.y : metres.x;
		float active = outbound ? step(13., along) : step(18.5, along) * step(along, 45.);
		float tyre = abs(abs(side + .055*sin(along*.82)) - .77);
		float scuff = (1. - smoothstep(.04,.145,tyre)) * (.37+.63*rough) * active;
		float paint = (1. - smoothstep(.017,.027+aa,abs(abs(side)-2.15)))
			* (1. - smoothstep(1.33,1.43,mod(along,3.65))) * active;
		finish *= 1. - .30*scuff;
		finish = mix(finish,vec3(.42,.43,.39),paint*(.38+.25*rough));
	}
	ROUGHNESS = rough_out;
	SPECULAR = .23;
	METALLIC = .035;
	if (grate_rect.z > grate_rect.x) {
		vec2 size = grate_rect.zw - grate_rect.xy;
		vec2 p = metres - grate_rect.xy;
		vec2 to_edge = min(p, size - p);
		float edge = min(to_edge.x, to_edge.y);
		float across = size.x < size.y ? p.x : p.y;
		float along = size.x < size.y ? p.y : p.x;
		float frame = 1. - smoothstep(.065, .115, edge);
		float end_bar = seam(along, 1.65, .038, aa);
		float fine_bar = seam(across, .17, .023, aa);
		float cross_wire = seam(along, .34, .014, aa);
		float joint_plate = max(frame, end_bar);
		float lip = seam(across - .016, .17, .009, aa);
		vec3 steel = mix(vec3(.016, .019, .019), vec3(.042, .049, .048), cross_wire);
		steel = mix(steel, vec3(.061, .069, .068), fine_bar);
		steel += vec3(.023) * lip * fine_bar;
		steel = mix(steel, vec3(.090, .098, .095), joint_plate);
		steel *= .86 + .62 * tone;
		float inset = smoothstep(-aa, aa, edge);
		finish = mix(finish, steel, inset);
		ROUGHNESS = mix(ROUGHNESS, .66, inset);
		METALLIC = mix(.035, .20, inset);
		float keyline = (1. - smoothstep(.025, .025 + aa, abs(edge + .115)));
		float at_corner = 1. - smoothstep(.62, .68, max(to_edge.x, to_edge.y));
		finish = mix(finish, safety.rgb * (.72 + .32 * tone), keyline * at_corner);
	}
	ALBEDO = finish;
	float room_fade = 1.;
	if (passage_end_fade.y > passage_end_fade.x && passage_end_fade.w > passage_end_fade.z) {
		room_fade *= smoothstep(passage_end_fade.x, passage_end_fade.y, metres.x)
			* (1. - smoothstep(passage_end_fade.z, passage_end_fade.w, metres.x));
	}
	if (passage_z_fade.y > passage_z_fade.x && passage_z_fade.w > passage_z_fade.z) {
		room_fade *= smoothstep(passage_z_fade.x, passage_z_fade.y, metres.y)
			* (1. - smoothstep(passage_z_fade.z, passage_z_fade.w, metres.y));
	}
	float final_fade = mix(fade_floor, 1., room_fade);
	ALBEDO *= final_fade;
	SPECULAR *= final_fade;
	ROUGHNESS = mix(1., ROUGHNESS, final_fade);
}
