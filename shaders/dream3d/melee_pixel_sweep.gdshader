shader_type spatial;
// Only visible arc pixels write depth. Late floor batches must stay behind
// the swing; real cover and the authoritative reach limits still occlude it.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;
uniform float reach = 80.0;
uniform float facing = 0.0;
uniform float arc = 2.792527;
uniform float sweep = 0.0;
uniform float opacity = 0.0;
uniform float band_width = 14.0;
uniform bool paper = false;
uniform float reach_limits[33];
varying vec2 ground_pixel;
void vertex() { ground_pixel = VERTEX.xz * 32.0; }
void fragment() {
	vec2 p = floor(ground_pixel) + vec2(0.5);
	float r = length(p);
	float a = atan(p.y, p.x) - facing;
	a = atan(sin(a), cos(a));
	float fraction = (a + arc * 0.5) / arc;
	if (fraction < 0.0 || fraction > sweep || r > reach || opacity < 0.01) { discard; }
	float sample_index = clamp(fraction * 32.0, 0.0, 31.999);
	int index = int(floor(sample_index));
	float allowed = min(reach_limits[index], reach_limits[index + 1]);
	if (r > allowed) { discard; }
	float age = sweep - fraction;
	float tail = clamp(1.0 - age / 0.52, 0.0, 1.0);
	if (tail <= 0.0) { discard; }
	// Connect the readable leading edge to the held weapon instead of drawing
	// only a distant ring. Real reach limits and normal depth still clip it.
	float leading = 1.0 - step(0.11, age);
	float inner = mix(reach - band_width, 10.0, leading);
	if (r < inner) { discard; }
	float rim = step(reach - 3.0, r);
	vec3 ink = paper ? vec3(0.64, 0.70, 0.75) : vec3(0.69, 0.55, 0.36);
	vec3 core = paper ? vec3(0.96, 0.95, 0.85) : vec3(1.0, 0.90, 0.67);
	float stripe = mod(floor(r) + floor(fraction * 37.0), paper ? 7.0 : 11.0);
	if (paper && rim < 0.5 && leading < 0.5 && stripe < 2.0) { discard; }
	ALBEDO = mix(ink, core, max(leading, max(rim, step(0.84, tail))));
	// Ordered pixel coverage preserves the fade without entering the transparent
	// sorting queue, where floor chunks could overwrite this effect by region.
	vec2 cell = mod(floor(FRAGCOORD.xy), 4.0);
	float threshold = (mod(cell.x*2.0+cell.y*3.0,4.0)*4.0+mod(cell.y+cell.x,4.0)+0.5)/16.0;
	float coverage = opacity * tail * mix(0.72, 1.0, max(rim, leading));
	if (coverage <= threshold) { discard; }
}
