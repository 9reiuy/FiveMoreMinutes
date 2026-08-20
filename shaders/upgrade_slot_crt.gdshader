shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float barrel_distortion : hint_range(0.0, 0.2) = 0.075;
uniform vec2 overlay_screen_scale = vec2(0.80625, 0.619444);
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.10;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.025;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.14;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radius_squared = dot(centered, centered);
	vec2 warped_uv = centered * (1.0 + barrel_distortion * radius_squared) * 0.5 + 0.5;
	// Barrel distortion pushes the four edges outside the local CRT rectangle.
	// Keep those pixels transparent: the old opaque overscan color formed an
	// unwanted large rectangular bezel around the entire slot machine.
	bool outside_crt = any(lessThan(warped_uv, vec2(0.0))) || any(greaterThan(warped_uv, vec2(1.0)));
	if (outside_crt) {
		COLOR = vec4(0.0);
	} else {
		vec2 screen_sample_uv = SCREEN_UV + (warped_uv - UV) * overlay_screen_scale;
		vec4 screen_color = texture(screen_texture, screen_sample_uv);
		float scanline = step(0.5, fract(UV.y * 180.0));
		float noise = hash(floor(UV * vec2(320.0, 180.0)) + floor(TIME * 12.0));
		vec2 edge = abs(UV - vec2(0.5)) * 2.0;
		float vignette = smoothstep(0.58, 1.0, max(edge.x, edge.y));
		float darkness = scanline * scanline_strength + noise * noise_strength + vignette * vignette_strength;
		float overlay_alpha = clamp(darkness, 0.0, 0.32);
		COLOR = vec4(mix(screen_color.rgb, vec3(0.015, 0.035, 0.055), overlay_alpha), 1.0);
	}
}
