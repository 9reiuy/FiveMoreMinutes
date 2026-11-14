shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
	float along = UV.x;
	float width = abs(UV.y - .5) * 2.0;
	float broken = .70 + .30 * sin(along * 139.0 + sin(along * 53.0));
	float mask = (1.0 - smoothstep(.50, .98, width)) * smoothstep(0.0, .025, along) * (1.0 - smoothstep(.96, 1.0, along));
	float flicker = .76 + .24 * sin(TIME * 8.0 + along * 47.0 + sin(along * 83.0 - TIME * 4.0));
	ALBEDO = mix(vec3(.70,.055,.002), vec3(1.0,.43,.015), broken * flicker);
	EMISSION = ALBEDO * 1.1;
	ALPHA = mask * broken * .86;
}
