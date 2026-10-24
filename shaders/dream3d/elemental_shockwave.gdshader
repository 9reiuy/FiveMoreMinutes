shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform float progress = 0.0;
uniform vec4 flame_color : source_color = vec4(1.0,.82,.32,1.0);
void fragment() {
	vec2 p=(floor(UV*96.0)+.5)/96.0*2.0-1.0;
	float r=length(p);
	float width=mix(.14,.025,progress);
	if(r>1.0 || r<1.0-width) discard;
	float coverage=mod(floor(FRAGCOORD.x)*2.0+floor(FRAGCOORD.y)*3.0,5.0)/5.0;
	if(progress>.45 && coverage>(1.0-progress)/.55) discard;
	ALBEDO=(r>.985 || r<1.015-width) ? vec3(.055,.045,.085) : flame_color.rgb;
}
