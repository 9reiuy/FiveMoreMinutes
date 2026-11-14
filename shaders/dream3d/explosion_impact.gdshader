shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float phase = 0.0;
void fragment() {
	float radius=length(UV-.5)*2.0;
	float edge=.10+phase*.85;
	float wave=exp(-pow((radius-edge)/.025,2.0));
	ALBEDO=vec3(1.0,.50,.18);
	EMISSION=vec3(.45,.14,.025)*wave;
	ALPHA=wave*(1.0-phase)*(1.0-phase)*.24;
}
