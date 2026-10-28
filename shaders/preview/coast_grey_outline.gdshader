shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform vec4 outline_color : source_color = vec4(.36,.37,.38,1.);
uniform float outline_pixels = 1.1;
uniform float moon_visibility = 1.0;
void vertex(){
 vec4 clip=PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX,1.);
 vec3 view_normal=normalize(MODELVIEW_NORMAL_MATRIX*NORMAL);
 vec2 direction=normalize(view_normal.xy+vec2(.00001));
 clip.xy+=direction*outline_pixels*2.*clip.w/VIEWPORT_SIZE;
 POSITION=clip;
}
void fragment(){ALBEDO=outline_color.rgb*mix(.40,1.,moon_visibility);}
