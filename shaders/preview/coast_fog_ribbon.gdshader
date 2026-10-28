shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float scene_time=0.;
uniform float moon_visibility=1.;
void fragment(){
 vec2 p=UV;
 float body=exp(-pow((p.y-.5)*4.5,2.));
 float edge=smoothstep(0.,.2,p.x)*(1.-smoothstep(.8,1.,p.x));
 float drift=.55+.25*sin(p.x*13.-scene_time*.11)+.20*sin(p.x*29.+p.y*5.+scene_time*.07);
 ALBEDO=vec3(.065,.075,.09);
 ALPHA=body*edge*drift*.14*(.3+.7*moon_visibility);
}
