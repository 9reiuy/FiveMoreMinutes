shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 signal_color : source_color=vec3(1.0,0.70,0.31);
uniform float power=0.0;
uniform float moon_visibility=1.0;
uniform bool story_signal=true;
uniform float signal_length=1.0;
void fragment(){
	vec2 p=(UV-vec2(0.5))*vec2(signal_length,1.0);
	p.x=max(abs(p.x)-(signal_length-1.0)*0.2973,0.0);
	float core=exp(-dot(p*vec2(2.8,3.5),p*vec2(2.8,3.5)));
	ALBEDO=signal_color*power*core*5.5;
	ALPHA=core;
}
