shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 signal_color : source_color=vec3(1.,.15,.065);
uniform float power=0.;
uniform float moon_visibility=1.;
uniform bool story_signal=false;
void fragment(){
 vec2 p=UV-vec2(.5);
 float core=exp(-dot(p*vec2(6.,7.),p*vec2(6.,7.)));
 float halo=exp(-dot(p*vec2(2.6,3.),p*vec2(2.6,3.))*2.);
 ALBEDO=signal_color*power*(core*1.4+halo*.14);
 EMISSION=signal_color*power*core*.30;
 ALPHA=clamp(core+halo*.24,0.,1.);
}
