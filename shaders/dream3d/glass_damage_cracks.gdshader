shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
#include "res://shaders/dream3d/architecture_cutaway.gdshaderinc"
uniform float damage = 0.0;
void vertex() { architecture_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	if (architecture_cutaway && architecture_visibility(architecture_world)<.5) { discard; }
	vec2 p = floor(UV*vec2(32.0,80.0));
	float branch = abs(p.x-16.0-sin(floor(p.y/6.0)*2.1)*min(abs(p.y-38.0)*.22,9.0));
	float cross = abs(p.y-38.0-(p.x-16.0)*1.8);
	if (damage<=0.0 || abs(p.y-38.0)>damage*60.0 || (branch>1.0 && cross>1.0)) { discard; }
	ALBEDO=vec3(.72,.84,.86);
}
