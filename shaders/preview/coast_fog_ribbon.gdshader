shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float scene_time=0.;
uniform float moon_visibility=1.;
uniform vec3 fog_colour = vec3(.065, .075, .09);
uniform float fog_density : hint_range(0., 1.) = .14;
uniform float cloud_visibility : hint_range(0., 1.) = .3;
void fragment(){
 vec2 p=UV;
 float body=exp(-pow((p.y-.5)*4.5,2.));
 float edge=smoothstep(0.,.2,p.x)*(1.-smoothstep(.8,1.,p.x));
 float drift=.55+.25*sin(p.x*13.-scene_time*.11)+.20*sin(p.x*29.+p.y*5.+scene_time*.07);
 ALBEDO=fog_colour;
 ALPHA=body*edge*drift*fog_density*mix(cloud_visibility,1.,moon_visibility);
}
