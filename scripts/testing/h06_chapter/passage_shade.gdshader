shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/dream3d/passage_end_fade.gdshaderinc"
#include "res://shaders/dream3d/occlusion_cutout.gdshaderinc"

uniform vec4 mouth_0;
uniform vec4 mouth_1;
uniform vec2 limits_0;
uniform vec2 limits_1;
// Main hangar west edge, apron west edge, the connecting corner, fade width.
uniform vec4 west_hangar_edge = vec4(0.);
// South exit centre X, half width, first and last Z of the fade.
uniform vec4 south_exit = vec4(0.);
uniform vec2 service_entrance = vec2(0.);
uniform vec2 service_passage_z;
varying vec3 world_at;
varying flat float camera_pass;

float passage_shadow(vec4 mouth, vec2 limits, vec3 p) {
	if (limits.x <= 0.0 || p.y < limits.y - .55 || p.y > limits.y + 2.95) { return 0.0; }
	vec2 offset = p.xz - mouth.xy;
	float depth = abs(dot(offset, mouth.zw));
	float side = abs(dot(offset, vec2(-mouth.w, mouth.z)));
	if (depth >= passage_end_fade.y || side >= limits.x + .45) { return 0.0; }
	vec3 light = vec3(1.0);
	float roughness = 1.0, specular = 0.0;
	apply_passage_end_fade(depth, light, roughness, specular);
	return (1.0 - light.r) * (1.0 - smoothstep(limits.x + .04, limits.x + .45, side));
}

float west_edge_shadow(vec3 p) {
	if (west_hangar_edge.w <= 0.0 || p.y >= .30) { return 0.0; }
	float inner = west_hangar_edge.x, outer = west_hangar_edge.y, corner = west_hangar_edge.z;
	float main_edge = distance(p.xz, vec2(inner, min(p.z, corner)));
	float step_edge = distance(p.xz, vec2(clamp(p.x, outer, inner), corner));
	float apron_edge = distance(p.xz, vec2(outer, max(p.z, corner)));
	float edge_distance = min(main_edge, min(step_edge, apron_edge));
	return (1.0 - smoothstep(.06, west_hangar_edge.w, edge_distance))
		* (1.0 - smoothstep(.04, .30, p.y));
}

float south_exit_shadow(vec3 p) {
	if (south_exit.y <= 0.0 || p.y > 2.65) { return 0.0; }
	float side = abs(p.x - south_exit.x) - south_exit.y;
	return smoothstep(south_exit.z, south_exit.w, p.z) * (1.0 - smoothstep(.14, .55, side));
}

float service_entrance_shadow(vec3 p) {
	if (service_entrance.y <= service_entrance.x) { return 0.0; }
	float off_passage = max(1.0 - smoothstep(service_passage_z.x - .6, service_passage_z.x, p.z),
		smoothstep(service_passage_z.y, service_passage_z.y + .6, p.z));
	float fade_start = mix(service_entrance.x, service_entrance.y - .06, off_passage);
	return 1.0 - smoothstep(fade_start, service_entrance.y, p.x);
}

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	camera_pass = float(all(equal(INV_VIEW_MATRIX[3], MAIN_CAM_INV_VIEW_MATRIX[3])));
}
void fragment() {
	float shade = max(passage_shadow(mouth_0, limits_0, world_at), passage_shadow(mouth_1, limits_1, world_at));
	shade = max(shade, west_edge_shadow(world_at));
	shade = max(shade, south_exit_shadow(world_at));
	shade = max(shade, service_entrance_shadow(world_at));
	if (shade < .001 || main_camera_cutout(SCREEN_UV, camera_pass)) { discard; }
	ALBEDO = vec3(0.0);
	ALPHA = shade;
}
