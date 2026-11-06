float ink_threshold(vec2 pixel) {
	vec2 p = mod(floor(pixel), 4.0);
	float rank;
	if (p.y < 1.0) rank = p.x < 1.0 ? 0.0 : (p.x < 2.0 ? 8.0 : (p.x < 3.0 ? 2.0 : 10.0));
	else if (p.y < 2.0) rank = p.x < 1.0 ? 12.0 : (p.x < 2.0 ? 4.0 : (p.x < 3.0 ? 14.0 : 6.0));
	else if (p.y < 3.0) rank = p.x < 1.0 ? 3.0 : (p.x < 2.0 ? 11.0 : (p.x < 3.0 ? 1.0 : 9.0));
	else rank = p.x < 1.0 ? 15.0 : (p.x < 2.0 ? 7.0 : (p.x < 3.0 ? 13.0 : 5.0));
	return (rank + 0.5) / 16.0;
}

vec3 ink_linear(vec3 display_rgb) {
	return mix(display_rgb / 12.92, pow((display_rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), display_rgb));
}

vec3 ink_output(vec3 display_rgb) {
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		return display_rgb;
	#else
		return ink_linear(display_rgb);
	#endif
}
