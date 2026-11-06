shader_type spatial;
render_mode unshaded, specular_disabled, depth_draw_always;
#include "res://shaders/preview/hellkind_sample/ink_points.gdshaderinc"

uniform bool preserve_red = false;
uniform bool sample_ink_enabled = false;
varying vec3 surface_normal;
varying vec3 paint_position;

void vertex() {
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	paint_position = VERTEX;
}

void fragment() {
	// Draw the independently coloured paint after the environment inks.
	ALPHA = 1.0;
	float facing = dot(normalize(surface_normal), normalize(vec3(-0.5, 0.7, 0.45)));
	int phase = facing > 0.45 ? 0 : (facing > -0.20 ? 1 : 2);
	if (mod(floor(paint_position.y * 32.0), 8.0) == 0.0) phase = min(2, phase + 1);
	vec3 red = phase == 0 ? vec3(0.91, 0.25, 0.26) : (phase == 1 ? vec3(0.72, 0.12, 0.18) : vec3(0.43, 0.055, 0.095));
	if (sample_ink_enabled) {
		float luminance = dot(ink_linear(red), vec3(0.2126, 0.7152, 0.0722));
		float coverage = sqrt(clamp((luminance - 0.014) / 0.986, 0.0, 1.0));
		float pixel_scale = max(1.0, VIEWPORT_SIZE.y / 360.0);
		vec3 bright_ink = red * (0.90 / red.r);
		vec3 dark_ink = vec3(5.0, 6.0, 10.0) / 255.0;
		ALBEDO = ink_output(coverage >= ink_threshold(FRAGCOORD.xy / pixel_scale) ? bright_ink : dark_ink);
	} else {
		ALBEDO = ink_output(preserve_red ? vec3(1.0, 0.0, 0.52 + 0.04 * float(phase)) : red);
	}
}
