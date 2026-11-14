shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float glow_strength : hint_range(0.0, 1.5) = 0.68;

vec3 luminous(vec3 value) {
	float brightness = max(value.r, max(value.g, value.b));
	return value * smoothstep(0.035, 0.42, brightness);
}

void fragment() {
	vec3 rgb = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	// Add light around the bright glass while preserving crisp base pixels.
	// This canvas pass also works with the preview's Compatibility renderer.
	vec3 halo = luminous(textureLod(screen_texture, SCREEN_UV, 2.4).rgb) * 0.28;
	halo += luminous(textureLod(screen_texture, SCREEN_UV, 4.1).rgb) * 0.44;
	halo += luminous(textureLod(screen_texture, SCREEN_UV, 5.6).rgb) * 0.28;
	rgb += halo * glow_strength * (vec3(1.0) - clamp(rgb, vec3(0.0), vec3(1.0)));
	vec2 p = SCREEN_UV * 2.0 - 1.0;
	float vignette = 1.0 - smoothstep(0.42, 1.10, length(p * vec2(1.0, 0.52))) * 0.92;
	COLOR = vec4(rgb * vignette, 1.0);
}
