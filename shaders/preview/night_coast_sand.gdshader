shader_type spatial;
#include "res://shaders/dream3d/office_dither_lighting.gdshaderinc"
uniform float scene_time=0.0;
uniform float moon_visibility=1.0;
uniform vec3 sand_lit_tint : source_color = vec3(.169,.075,.114);
uniform vec3 sand_cool_tint : source_color = vec3(.071,.035,.063);
#include "res://shaders/preview/coast_shape.gdshaderinc"
varying vec3 world_position;
varying vec3 world_normal;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz; world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); office_dither_position=world_position; office_dither_normal=world_normal;}
void fragment(){
 vec2 p=floor(world_position.xz*32.)/32.;
 float grain=hash(p*32.);
 float wind=sin(p.x*2.4+p.y*.62+sin(p.y*.7)*.8);
 vec3 sand=mix(sand_cool_tint,sand_lit_tint,smoothstep(.5,.95,world_normal.y));
 sand*=mix(.96,1.025,step(.94,grain));
 sand+=vec3(.012,.010,.017)*step(.91,wind);
 float path=1.-smoothstep(1.0,2.5,abs(p.x+3.+sin(p.y*.26)*.55));
 sand=mix(sand,sand*1.035,path);
 float wet=1.-smoothstep(2.8,5.5,p.y);
 ALBEDO=sand*mix(vec3(1.),vec3(.80,.72,.88),wet);
 float shore=3.+sin(p.x*.38)*.65+sin(p.x*1.1)*.25;
 float coast=coast_distance(p);
 float swell=.38*sin(scene_time*1.15+p.x*.28)+.14*sin(scene_time*1.73+p.x*1.1);
 float front=coast-swell;
 float spray=(1.-smoothstep(.05,1.2,abs(front+.55)))*step(.955,grain);
 spray*=step(.1,sin(scene_time*1.3+p.x*5.+p.y*4.));
 ALBEDO=mix(ALBEDO,vec3(.58,.53,.57),spray);
 EMISSION=vec3(.38,.33,.36)*spray*mix(.1,1.,moon_visibility);
 float steep=1.-smoothstep(.32,.82,world_normal.y);
 float strata=1.-smoothstep(.02,.065,abs(fract(world_position.y*.85+sin(p.x*.5+p.y*.7)*.13)-.5));
 vec3 rock=mix(vec3(.071,.035,.063),vec3(.169,.075,.114),strata*.65);
 ALBEDO=mix(ALBEDO,rock,steep);
 // Only rock strata, no painted contours around the ground or mound bases.
 EMISSION+=vec3(.016,.007,.010)*(strata*steep)*moon_visibility;
 // Restrained dark-rock fill; direct moon shading and sparse strata carry form.
 EMISSION+=ALBEDO*.018;
 float facet=step(.88,world_normal.y)*step(.78,grain)*step(.65,wind);
 EMISSION+=vec3(.028,.016,.022)*facet*moon_visibility;
 ROUGHNESS=1.;
}
void light(){
 float response=ATTENUATION*max(dot(NORMAL,LIGHT),0.);
 float threshold=office_dither_threshold(world_position.xz*32.);
 float shade=(floor(response*3.)+step(threshold,fract(response*3.)))/3.;
 DIFFUSE_LIGHT+=LIGHT_COLOR*shade/PI;
}
