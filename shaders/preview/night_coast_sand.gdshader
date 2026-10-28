shader_type spatial;
#include "res://shaders/dream3d/office_dither_lighting.gdshaderinc"
uniform float scene_time=0.0;
uniform float moon_visibility=1.0;
#include "res://shaders/preview/coast_shape.gdshaderinc"
varying vec3 world_position;
varying vec3 world_normal;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz; world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); office_dither_position=world_position; office_dither_normal=world_normal;}
void fragment(){
 vec2 p=floor(world_position.xz*32.)/32.;
 float grain=hash(p*32.);
 float wind=sin(p.x*2.4+p.y*.62+sin(p.y*.7)*.8);
 vec3 sand=mix(vec3(.085,.10,.105),vec3(.15,.17,.17),step(.94,grain));
 sand+=vec3(.016,.02,.021)*step(.91,wind);
 float path=1.-smoothstep(1.0,2.5,abs(p.x+3.+sin(p.y*.26)*.55));
 sand=mix(sand,sand*1.15,path);
 float wet=1.-smoothstep(2.8,5.5,p.y);
 ALBEDO=sand*mix(1.,.50,wet);
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
 vec3 rock=mix(vec3(.025,.034,.042),vec3(.14,.17,.19),strata*.65);
 ALBEDO=mix(ALBEDO,rock,steep);
 // Only rock strata, no painted contours around the ground or mound bases.
 EMISSION+=vec3(.025,.03,.035)*(strata*steep)*moon_visibility;
 EMISSION+=(vec3(.035,.040,.045)+ALBEDO*.06)*(.15+.85*moon_visibility);
 ROUGHNESS=1.;
}
void light(){
 float response=ATTENUATION*max(dot(NORMAL,LIGHT),0.);
 float shade=office_dither_enabled?office_dither_response(response):response;
 DIFFUSE_LIGHT+=LIGHT_COLOR*shade/PI;
}
