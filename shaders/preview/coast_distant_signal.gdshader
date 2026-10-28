shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 signal_color : source_color=vec3(.91,.94,.79);
uniform float power=1.;
uniform bool long_signal=false;
void fragment(){
 vec2 p=UV-vec2(.5);
 float halo=exp(-dot(p*vec2(2.5,5.),p*vec2(2.5,5.))*2.);
 float core=0.;
 if(long_signal){
  for(int i=0;i<5;i++){
   vec2 q=p-vec2((float(i)-2.)*.13,0.);
   core+=exp(-dot(q*vec2(15.,12.),q*vec2(15.,12.)))*(.7+.06*float(i));
  }
 }else{core=exp(-dot(p*vec2(7.,10.),p*vec2(7.,10.)));}
 ALBEDO=signal_color*power*(core*.9+halo*.16);
 ALPHA=clamp(core+halo*.45,0.,1.);
}
