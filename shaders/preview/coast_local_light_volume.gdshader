shader_type spatial;
// Small local scattering volumes for Compatibility. This is a bounded depth-
// clipped 12-step integral, not a fullscreen fog layer or native FogVolume.
render_mode unshaded, blend_add, cull_front, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 light_tint : source_color = vec3(.95,.65,.32);
uniform float beam_height = 3.;
uniform float beam_radius = 1.65;
uniform float density : hint_range(0.,.2) = .055;
uniform float scene_time = 0.;
uniform float moon_visibility = 1.;
varying vec3 local_surface;
void vertex(){local_surface=VERTEX;}
void fragment(){
 mat4 world_to_local=inverse(MODEL_MATRIX);
 vec3 origin=(world_to_local*vec4(CAMERA_POSITION_WORLD,1.)).xyz;
 vec3 direction=normalize(local_surface-origin);
 vec3 safe_direction=direction+vec3(.000001);
 vec3 half_box=vec3(beam_radius,beam_height*.5,beam_radius);
 vec3 a=(-half_box-origin)/safe_direction;
 vec3 b=(half_box-origin)/safe_direction;
 vec3 lower=min(a,b),upper=max(a,b);
 float enter=max(max(lower.x,lower.y),lower.z);
 float leave=min(min(upper.x,upper.y),upper.z);
 float depth=texture(scene_depth,SCREEN_UV).r;
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 vec3 ndc=vec3(SCREEN_UV,depth)*2.-1.;
 #else
 vec3 ndc=vec3(SCREEN_UV*2.-1.,depth);
 #endif
 vec4 depth_world=INV_VIEW_MATRIX*INV_PROJECTION_MATRIX*vec4(ndc,1.);
 vec3 opaque=(world_to_local*vec4(depth_world.xyz/depth_world.w,1.)).xyz;
 leave=min(leave,dot(opaque-origin,direction));
 enter=max(enter,0.);
 float distance=max(leave-enter,0.);
 float step_length=distance/12.;
 float scattered=0.;
 for(int i=0;i<12;i++){
  vec3 point=origin+direction*(enter+(float(i)+.5)*step_length);
  float along=clamp((beam_height*.5-point.y)/beam_height,0.,1.);
  float radius=max(.06,beam_radius*along);
  float edge=1.-smoothstep(.35,1.,length(point.xz)/radius);
  float ends=smoothstep(0.,.06,along)*(1.-smoothstep(.78,1.,along));
  float haze=.84+.10*sin(point.x*1.3+point.z*.7+scene_time*.12);
  scattered+=edge*ends*haze*step_length;
 }
 ALBEDO=light_tint;
 ALPHA=clamp(scattered*density*mix(.65,1.,moon_visibility),0.,.12);
}
