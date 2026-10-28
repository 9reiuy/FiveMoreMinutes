shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, shadows_disabled;
uniform float moon_visibility=1.;
varying float fade_distance;
void vertex(){
 vec4 view=MODELVIEW_MATRIX*vec4(VERTEX,1.);
 fade_distance=length(view.xyz);
 vec4 clip=PROJECTION_MATRIX*view;
 vec3 n=normalize(MODELVIEW_NORMAL_MATRIX*NORMAL);
 clip.xy+=normalize(n.xy+vec2(.00001))*.70*2.*clip.w/VIEWPORT_SIZE;
 POSITION=clip;
}
void fragment(){
 ALBEDO=vec3(.25,.27,.29);
 ALPHA=moon_visibility*exp(-fade_distance*.004)*.75;
}
