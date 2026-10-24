// Native effect colours. The normal final world palette also processes these.
vec3 phase_dash_ink(float band) {
	float i = mod(floor(band), 5.0);
	if (i < 1.0) return vec3(12.0,236.0,188.0)/255.0;
	if (i < 2.0) return vec3(65.0,110.0,246.0)/255.0;
	if (i < 3.0) return vec3(162.0,65.0,246.0)/255.0;
	if (i < 4.0) return vec3(245.0,62.0,149.0)/255.0;
	return vec3(245.0,191.0,62.0)/255.0;
}
float phase_dash_coverage(vec2 pixel) {
	vec2 p = mod(floor(pixel),4.0);
	// Ordered coverage keeps the pixel silhouette crisp while it fades.
	return (mod(p.x*2.0+p.y*3.0,4.0)*4.0+mod(p.y+p.x,4.0)+0.5)/16.0;
}
