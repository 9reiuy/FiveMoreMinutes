shader_type spatial;

render_mode cull_disabled, unshaded, fog_disabled, blend_mix, depth_prepass_alpha, specular_disabled;

// Keep the airborne carrier on the same reserved semantic path as the
// existing ground Blood bridge.  This is a presentation marker, not a generic
// palette candidate and not a second blood simulation.
// Match BlackBloodEffect's original brighter airborne droplets (#FF9A2E).
const vec3 BLOOD_SEMANTIC_MARKER = vec3(1.0, 0.6039216, 0.1803922);

void fragment() {
	ALBEDO = BLOOD_SEMANTIC_MARKER;
	ALPHA = 1.0;
}
