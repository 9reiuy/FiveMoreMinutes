shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform float progress = 0.0;
uniform vec4 flame_color : source_color = vec4(1.0,.82,.32,1.0);

#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
// These are authored display codes, including reserved effect identities.
// Decode once before the linear spatial output; keep alpha/depth unchanged.
vec3 r2_effect_decode(vec3 encoded) {
    return mix(encoded / 12.92, pow((encoded + vec3(0.055)) / 1.055, vec3(2.4)),
        step(vec3(0.04045), encoded));
}
#endif

void fragment() {
	vec2 p=(floor(UV*96.0)+.5)/96.0*2.0-1.0;
	float r=length(p);
	float width=mix(.14,.025,progress);
	if(r>1.0 || r<1.0-width) discard;
	float coverage=mod(floor(FRAGCOORD.x)*2.0+floor(FRAGCOORD.y)*3.0,5.0)/5.0;
	if(progress>.45 && coverage>(1.0-progress)/.55) discard;
	vec3 edge_colour=vec3(.055,.045,.085);
#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
    edge_colour=r2_effect_decode(edge_colour);
#endif
	// flame_color is a source_color uniform: do not decode it twice.
	ALBEDO=(r>.985 || r<1.015-width) ? edge_colour : flame_color.rgb;
}
