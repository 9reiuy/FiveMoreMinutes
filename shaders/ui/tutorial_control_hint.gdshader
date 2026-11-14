shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/ui/tutorial_control_hint_reveal.gdshaderinc"
uniform vec2 panel_size = vec2(228.0, 42.0);
uniform float sweep_phase : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 pixel = UV * panel_size;
	vec2 corner = max(abs(pixel - panel_size * 0.5) - (panel_size * 0.5 - 3.0), vec2(0.0));
	float rounded = 1.0 - smoothstep(2.5, 3.5, length(corner));
	float right_fade = 1.0 - smoothstep(0.77, 1.0, UV.x);
	float texture_weight = smoothstep(0.24, 0.94, UV.x);
	vec2 cell = fract(pixel / 3.0) - 0.5;
	float dots = 1.0 - smoothstep(0.20, 0.32, length(cell));
	float grain = fract(sin(dot(floor(pixel / 6.0), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 colour = mix(vec3(0.025, 0.036, 0.036), vec3(0.14, 0.18, 0.17), dots * texture_weight * (0.45 + grain * 0.35));
	float accent = step(0.94, grain) * step(0.70, UV.x) * dots;
	colour = mix(colour, vec3(0.18, 0.28, 0.43), accent * 0.7);
	float top_rule = (1.0 - step(1.0, pixel.y)) * (1.0 - smoothstep(0.58, 0.86, UV.x));
	colour = mix(colour, vec3(0.28, 0.35, 0.32), top_rule * 0.65);
	float sweep_center = mix(-0.10, 1.10, sweep_phase);
	float sweep = smoothstep(sweep_center - 0.22, sweep_center - 0.035, UV.x)
		* (1.0 - smoothstep(sweep_center, sweep_center + 0.055, UV.x));
	colour = mix(colour, vec3(0.96, 0.99, 1.0), top_rule * sweep);
	float alpha = mix(0.94, 0.58, texture_weight) * right_fade * rounded * tutorial_hint_reveal(pixel.x);
	COLOR *= vec4(colour, alpha);
}
