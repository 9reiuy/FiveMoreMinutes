shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float moon_visibility=1.;
varying float distance_to_eye;
void vertex(){distance_to_eye=length((MODELVIEW_MATRIX*vec4(VERTEX,1.)).xyz);}
void fragment(){
 ALBEDO=vec3(.075,.085,.10);
 ALPHA=moon_visibility*exp(-distance_to_eye*.006)*.85;
}
