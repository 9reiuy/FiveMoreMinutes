shader_type canvas_item;
render_mode unshaded;

// HUD pixels, kept separate from the world palette and its lighting.
uniform vec2 panel_size = vec2(160.0, 36.0);

void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV);
	float fade_x = smoothstep(0.0, 0.17, edge.x);
	float fade_y = smoothstep(0.0, 0.28, edge.y);
	float fade = fade_x * fade_y;
	float background_alpha = 0.84 * fade;

	// Circular dots become larger and more visible towards the lower edge;
	// their spacing stays constant as the dialogue grows or wraps.
	float density = smoothstep(0.48, 0.91, UV.y);
	vec2 cell = fract(UV * panel_size / 5.0) - vec2(0.5);
	float radius = 0.36 * density;
	float dot_mask = 1.0 - smoothstep(radius - 0.035, radius + 0.035, length(cell));
	float dot_alpha = dot_mask * density * fade * 0.34;
	float alpha = dot_alpha + background_alpha * (1.0 - dot_alpha);
	vec3 background = vec3(0.012, 0.015, 0.020);
	vec3 dot_color = vec3(0.72, 0.76, 0.80);
	vec3 premultiplied = dot_color * dot_alpha + background * background_alpha * (1.0 - dot_alpha);
	COLOR = vec4(premultiplied / max(alpha, 0.0001), alpha);
}
