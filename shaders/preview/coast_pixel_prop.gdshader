shader_type spatial;
#include "res://shaders/dream3d/office_dither_lighting.gdshaderinc"
uniform vec4 base_color : source_color=vec4(.12,.15,.16,1.);
uniform float moon_visibility=1.;
varying vec3 prop_world;
void vertex(){
 prop_world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 office_dither_position=prop_world;
 office_dither_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 float grain=fract(sin(dot(floor(prop_world.xz*32.),vec2(127.1,311.7)))*43758.5453);
 ALBEDO=base_color.rgb*mix(.85,1.35,step(.92,grain));
 ROUGHNESS=1.; SPECULAR=0.;
 EMISSION=ALBEDO*.06*(.15+.85*moon_visibility);
}
void light(){
 float response=ATTENUATION*max(dot(NORMAL,LIGHT),0.);
 float shade=office_dither_enabled?office_dither_response(response):response;
 DIFFUSE_LIGHT+=LIGHT_COLOR*shade/PI;
}
