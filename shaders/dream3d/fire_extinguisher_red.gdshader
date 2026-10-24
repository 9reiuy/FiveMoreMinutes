shader_type spatial;
render_mode unshaded, specular_disabled;
uniform bool preserve_red = false;
varying vec3 surface_normal;
varying vec3 paint_position;
void vertex() {
	surface_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	paint_position=VERTEX;
}
void fragment() {
	float facing=dot(normalize(surface_normal),normalize(vec3(-.5,.7,.45)));
	int phase=facing>.45 ? 0 : (facing>-.20 ? 1 : 2);
	if(mod(floor(paint_position.y*32.0),8.0)==0.0)phase=min(2,phase+1);
	vec3 red=phase==0 ? vec3(.91,.25,.26) : (phase==1 ? vec3(.72,.12,.18) : vec3(.43,.055,.095));
	ALBEDO=preserve_red ? vec3(1.0,0.0,.52+.04*float(phase)) : red;
}
