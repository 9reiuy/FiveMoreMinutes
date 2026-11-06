shader_type spatial;
render_mode unshaded, specular_disabled;
uniform bool preserve_red = false;
varying vec3 surface_normal;
varying vec3 paint_position;
#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
vec3 paint_srgb_to_linear(vec3 encoded) {
	return mix(encoded / 12.92, pow((encoded + 0.055) / 1.055, vec3(2.4)),
		step(vec3(0.04045), encoded));
}
#endif
void vertex() {
	surface_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	paint_position=VERTEX;
}
void fragment() {
	float facing=dot(normalize(surface_normal),normalize(vec3(-.5,.7,.45)));
	int phase=facing>.45 ? 0 : (facing>-.20 ? 1 : 2);
	if(mod(floor(paint_position.y*32.0),8.0)==0.0)phase=min(2,phase+1);
	vec3 red=phase==0 ? vec3(.91,.25,.26) : (phase==1 ? vec3(.72,.12,.18) : vec3(.43,.055,.095));
	bool use_marker = preserve_red;
	#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
		// FloorReflections reserves CAPTURE_FLAG (bit 18) for its camera
		// and EXCLUDED (bit 19) for the main camera. The mirror has no
		// WorldPaletteLayer to decode a paint marker.
		bool mirror_capture = (CAMERA_VISIBLE_LAYERS & 262144u) != 0u
			&& (CAMERA_VISIBLE_LAYERS & 524288u) == 0u;
		use_marker = use_marker && !mirror_capture;
	#endif
	vec3 encoded = use_marker ? vec3(1.0,0.0,.52+.04*float(phase)) : red;
	#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
		// The world CanvasLayer expects the reserved codes after LDR
		// encoding. Preserve the same codes instead of widening its matcher.
		if (!OUTPUT_IS_SRGB) { encoded = paint_srgb_to_linear(encoded); }
	#endif
	ALBEDO = encoded;
}
