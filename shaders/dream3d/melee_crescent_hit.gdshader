shader_type spatial;
// Only ink pixels write depth: late floor batches cannot erase the effect,
// while the empty quad never hides actors and real foreground cover wins.
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_opaque;
#include "res://shaders/dream3d/character_reference_depth.gdshaderinc"
uniform float progress = 0.0;
uniform float visual_scale = 1.0;
uniform float facing = 0.0;
uniform int line_count = 1;
// xy unit direction; z full line length; w perpendicular offset.
uniform vec4 cut_0 = vec4(1.0, 0.0, 80.0, 0.0);
uniform vec4 cut_1 = vec4(0.0, 1.0, 72.0, 0.0);
uniform vec4 cut_2 = vec4(0.707, 0.707, 64.0, 0.0);
varying vec2 art_pixel;
void vertex() { art_pixel = VERTEX.xy * vec2(32.0, -32.0); }
float cut_ink(vec2 p, vec4 cut, float growth) {
	float along = dot(p, cut.xy);
	float across = abs(dot(p, vec2(-cut.y, cut.x)) - cut.w);
	// World effects are downsampled by the game's pixelation pass. Keep cuts
	// at least one render pixel wide, or subpixel diagonals vanish by angle.
	vec2 raster_pixel = fwidth(art_pixel) / visual_scale;
	float half_width = max(0.72, max(raster_pixel.x, raster_pixel.y) * 0.6);
	return step(abs(along), cut.z * 0.5 * growth) * (1.0 - step(half_width, across));
}
void fragment() {
	if (progress >= 1.0) { discard; }
	// Enlarge the whole motif, not the world texel grid or depth plane.
	vec2 p = (floor(art_pixel) + vec2(0.5)) / visual_scale;
	float growth = mix(0.70, 1.0, smoothstep(0.0, 0.20, progress));
	float angle = facing + mix(-0.24, 0.15, progress);
	vec2 q = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * p;
	float radius = mix(13.0, 19.0, smoothstep(0.0, 0.5, progress));
	float ink = (1.0 - step(radius, length(q))) * step(radius * 0.94, length(q + vec2(radius * 0.27, 0.0)));
	if (line_count > 0) { ink = max(ink, cut_ink(p, cut_0, growth)); }
	if (line_count > 1) { ink = max(ink, cut_ink(p, cut_1, growth)); }
	if (line_count > 2) { ink = max(ink, cut_ink(p, cut_2, growth)); }
	if (ink < 0.5) { discard; }
	// Pixel-hard fade, never transparent sorting or a blurred halo.
	float coverage = 1.0 - smoothstep(0.63, 1.0, progress);
	vec2 cell = mod(floor(art_pixel), 4.0);
	float threshold = (mod(cell.x * 2.0 + cell.y * 3.0, 4.0) * 4.0 + mod(cell.y + cell.x, 4.0) + 0.5) / 16.0;
	if (coverage <= threshold) { discard; }
	DEPTH = reference_fragment_depth(reference_view_position(VERTEX, INV_VIEW_MATRIX, VIEW_MATRIX), FRAGCOORD.z, PROJECTION_MATRIX);
	ALBEDO = vec3(1.0);
}
