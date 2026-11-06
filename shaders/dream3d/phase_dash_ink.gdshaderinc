const vec3 PHASE_DASH_WHITE = vec3(1.0);

float phase_dash_coverage(vec2 pixel) {
	vec2 p = mod(floor(pixel),4.0);
	// Ordered coverage keeps the pixel silhouette crisp while it fades.
	return (mod(p.x*2.0+p.y*3.0,4.0)*4.0+mod(p.y+p.x,4.0)+0.5)/16.0;
}
