shader_type spatial;
// Door B 材质的"外观等价孪生"（原 interiors_a_door_material.tres StandardMaterial3D）：
// 贴图/UV/roughness/specular 一致。门体旋转/物理/描边与本材质无关。
render_mode blend_mix, depth_draw_never, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/dream3d/architecture_cutaway.gdshaderinc"
varying vec3 door_pattern_position;

void vertex() {
	architecture_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	door_pattern_position = VERTEX * vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
}

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_disable;
uniform bool mirror_u = false;
uniform bool office_metal = false;
uniform bool metal_glass = false;
uniform bool observation_window = false;
uniform vec2 panel_size = vec2(1.0,2.0);
uniform vec4 surface_tint : source_color = vec4(1.0);
uniform sampler2D pixel_wood : source_color, filter_nearest, repeat_enable;
// Door_B is an atlas.  UV2 carries the min/max U of the connected atlas
// island for this face so a mirrored leaf stays inside the same texture
// island instead of sampling an unrelated panel on the other side of the
// atlas.  The default keeps old hand-authored meshes safe.
uniform bool mirror_u_use_uv2 = true;

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
	vec2 sample_uv = UV;
	if (mirror_u) {
		if (mirror_u_use_uv2 && UV2.y > UV2.x + 0.000001) {
			sample_uv.x = UV2.x + UV2.y - sample_uv.x;
		} else {
			sample_uv.x = 1.0 - sample_uv.x;
		}
	}
	vec4 base = texture(albedo_texture, sample_uv);
	vec2 wood_uv = (floor(door_pattern_position.xy * 32.0) + 0.5) / 32.0;
	ALBEDO = mix(vec3(dot(base.rgb, vec3(.299, .587, .114))), vec3(1.0), .65) * texture(pixel_wood, wood_uv).rgb * surface_tint.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	float occlusion_cut = base.a * combined_cutout(SCREEN_UV);
	if (occlusion_cut < 0.35) { discard; }
	ALPHA = occlusion_cut;
	if (office_metal) {
		vec2 p = (floor(door_pattern_position.xy*32.0)+.5)/32.0;
		vec2 inset = panel_size*.5-abs(p);
		float rim = step(min(inset.x,inset.y),.0625);
		float kick_plate = 1.0-step(-panel_size.y*.5+.25,p.y);
		ALBEDO = mix(surface_tint.rgb,surface_tint.rgb*.48,rim);
		vec2 window_edge = abs(p-vec2(0.0,panel_size.y*.18))-panel_size*vec2(.14,.12);
		float window_trim = (1.0-step(.03125,max(window_edge.x,window_edge.y)))*step(-.03125,max(window_edge.x,window_edge.y));
		// Only panels with a real observation aperture receive the matching trim.
		if (observation_window) { ALBEDO=mix(ALBEDO,surface_tint.rgb*.42,window_trim); }
		ALBEDO = mix(ALBEDO,vec3(.46,.51,.53),kick_plate*.65);
		if (metal_glass) { ALBEDO=vec3(.42,.62,.67); ALPHA*=.32; }
	}
}
