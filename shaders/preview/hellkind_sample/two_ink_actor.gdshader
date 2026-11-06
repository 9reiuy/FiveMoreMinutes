shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_always, fog_disabled;
#include "res://shaders/dream3d/character_reference_depth.gdshaderinc"
#include "res://shaders/preview/hellkind_sample/ink_points.gdshaderinc"

uniform sampler2D capture_texture : filter_nearest, repeat_disable;
uniform bool is_weapon = false;
uniform bool warm_outline = false;
uniform bool enemy_rim_enabled = true;
uniform vec4 enemy_rim_color = vec4(1.0);
uniform bool smoke_silhouette = false;
uniform bool use_room_palette = false;
uniform vec3 room_dark_ink;
uniform vec3 room_light_ink;
const vec3 DARK_INK = vec3(0.0);
const vec3 COOL_INK = vec3(236.0, 239.0, 246.0) / 255.0;
const vec3 GOLD_EDGE = vec3(249.0, 181.0, 106.0) / 255.0;
const vec3 GOLD_FALLOFF = vec3(143.0, 76.0, 45.0) / 255.0;

float silhouette_near(vec2 at, vec2 dx, vec2 dy, float radius) {
	vec2 x = dx * radius;
	vec2 y = dy * radius;
	float a = 0.0;
	a = max(a, texture(capture_texture, at + x).a);
	a = max(a, texture(capture_texture, at - x).a);
	a = max(a, texture(capture_texture, at + y).a);
	a = max(a, texture(capture_texture, at - y).a);
	a = max(a, texture(capture_texture, at + (x + y) * .707).a);
	a = max(a, texture(capture_texture, at + (x - y) * .707).a);
	a = max(a, texture(capture_texture, at + (-x + y) * .707).a);
	a = max(a, texture(capture_texture, at - (x + y) * .707).a);
	return a;
}

void fragment() {
	vec4 source = texture(capture_texture, UV);
	float pixel_scale = max(1.0, VIEWPORT_SIZE.y / 360.0);
	vec2 dx = dFdx(UV) * pixel_scale;
	vec2 dy = dFdy(UV) * pixel_scale;
	DEPTH = reference_fragment_depth(reference_view_position(VERTEX, INV_VIEW_MATRIX, VIEW_MATRIX), FRAGCOORD.z, PROJECTION_MATRIX);
	vec3 ink;
	float opacity = source.a;
	vec3 body_light = use_room_palette ? room_light_ink : COOL_INK;
	vec3 body_dark = use_room_palette ? room_dark_ink : DARK_INK;
	if (source.a > .05) {
		float tone = dot(source.rgb, vec3(.2126, .7152, .0722));
		// Body ink placement was authored in the source sprite pass.
		float coverage = is_weapon ? smoothstep(.19, .36, tone) : step(.50, tone);
		ink = coverage >= ink_threshold(UV * vec2(textureSize(capture_texture, 0))) ? body_light : body_dark;
	} else if (!smoke_silhouette && silhouette_near(UV, dx, dy, .95) > .05) {
		ink = body_light;
		opacity = 1.0;
	} else if (!is_weapon && warm_outline && enemy_rim_enabled && !smoke_silhouette
			&& silhouette_near(UV, dx, dy, 1.9) > .05) {
		ink = GOLD_EDGE;
		opacity = 1.0;
	} else if (!is_weapon && warm_outline && enemy_rim_enabled && !smoke_silhouette
			&& silhouette_near(UV, dx, dy, 2.75) > .05 && ink_threshold(FRAGCOORD.xy / pixel_scale) < .48) {
		ink = GOLD_FALLOFF;
		opacity = 1.0;
	} else {
		discard;
	}
	ALBEDO = smoke_silhouette ? DARK_INK : ink_output(ink);
	ALPHA = opacity;
}
