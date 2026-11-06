shader_type spatial;

render_mode cull_disabled, unshaded, fog_disabled, blend_mix, depth_prepass_alpha, specular_disabled;

// Keep the airborne carrier on the same reserved semantic path as the
// existing ground Blood bridge.  This is a presentation marker, not a generic
// palette candidate and not a second blood simulation.
// Match BlackBloodEffect's original brighter airborne droplets (#FF9A2E).
const vec3 BLOOD_SEMANTIC_MARKER = vec3(1.0, 0.6039216, 0.1803922);


#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
// These are authored display codes, including reserved effect identities.
// Decode once before the linear spatial output; keep alpha/depth unchanged.
vec3 r2_effect_decode(vec3 encoded) {
    return mix(encoded / 12.92, pow((encoded + vec3(0.055)) / 1.055, vec3(2.4)),
        step(vec3(0.04045), encoded));
}
#endif

void fragment() {
	ALBEDO = BLOOD_SEMANTIC_MARKER;
#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
	ALBEDO = r2_effect_decode(ALBEDO);
#endif
	ALPHA = 1.0;
}
