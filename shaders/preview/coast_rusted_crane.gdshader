shader_type spatial;
#include "res://shaders/dream3d/office_dither_lighting.gdshaderinc"
uniform float moon_visibility=1.;
uniform vec4 painted_steel : source_color=vec4(.46,.30,.15,1.);
varying vec3 steel_world;
void vertex(){
 steel_world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 office_dither_position=steel_world;
 office_dither_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
float grain(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,73.2)))*43758.5453);}
void fragment(){
 vec3 p=floor(steel_world*32.);
 float patch=grain(floor(p/9.));
 float rust=step(.47,patch)*step(.24,grain(p));
 vec3 color=mix(painted_steel.rgb,vec3(.30,.12,.055),rust*.78);
 color=mix(color,vec3(.12,.14,.16),step(.94,grain(p+13.)));
 ALBEDO=color; ROUGHNESS=1.; SPECULAR=0.;
 EMISSION=color*.30*mix(.18,1.,moon_visibility);
}
void light(){
 float response=ATTENUATION*max(dot(NORMAL,LIGHT),0.);
 DIFFUSE_LIGHT+=LIGHT_COLOR*(office_dither_enabled?office_dither_response(response):response)/PI;
}
