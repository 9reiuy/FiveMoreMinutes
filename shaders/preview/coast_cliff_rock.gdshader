shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
#include "res://shaders/dream3d/office_dither_lighting.gdshaderinc"
#include "res://shaders/preview/coast_shape.gdshaderinc"
uniform float scene_time=0.0;
uniform float moon_visibility=1.0;
uniform vec3 sand_lit_tint : source_color = vec3(.72,.57,.42);
uniform vec3 sand_cool_tint : source_color = vec3(.46,.35,.29);
varying vec3 world_position;
varying vec3 world_normal;
float rock_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
vec2 rock_site(vec2 p) { return vec2(rock_hash(p),rock_hash(p+vec2(73.2,41.7))); }
void vertex() {
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 office_dither_position=world_position; office_dither_normal=world_normal;
}
void fragment() {
 // Use the saved triangles' actual face normals, rather than smooth mound
 // normals. Vertex positions and the gameplay height grid remain identical.
 vec3 facet_normal=normalize(cross(dFdx(VERTEX),dFdy(VERTEX)));
 if (dot(facet_normal,NORMAL)<0.) { facet_normal=-facet_normal; }
 NORMAL=facet_normal;
 vec3 pixel=floor(world_position*32.)/32.;
 float top=step(.72,world_normal.y);
 vec2 plane=mix(vec2(pixel.x+pixel.z*.37,pixel.y),pixel.xz,top);
 vec2 p=plane*vec2(.38,.62);
 vec2 cell=floor(p);
 float nearest=100.; float second=100.; float block=0.;
 for(int y=-1;y<=1;y++) {
  for(int x=-1;x<=1;x++) {
   vec2 id=cell+vec2(float(x),float(y));
   vec2 delta=id+rock_site(id)*.72+vec2(.14)-p;
   float distance=dot(delta,delta);
   if(distance<nearest) { second=nearest; nearest=distance; block=rock_hash(id+vec2(9.,17.)); }
   else { second=min(second,distance); }
  }
 }
 // Sparse irregular fractures and broad strata, locked to world texels.
 float crack=(1.-step(.012,second-nearest))*step(.42,rock_hash(floor(plane*1.5)));
 float seam=1.-step(.04,fract(pixel.y*1.7+floor(pixel.x*.4)*.13));
 float band=floor(block*3.)/2.;
 vec3 stone=mix(sand_cool_tint,sand_lit_tint,.45+.45*top);
 stone*=mix(.94,1.06,band);
 stone*=1.-crack*.28;
 stone*=1.-seam*(1.-top)*.32;
 float grain=rock_hash(floor(world_position.xz*32.));
 stone*=mix(.96,1.04,step(.88,grain));
 ALBEDO=stone;
 // Restrained sky/sea bounce keeps grey-ochre rock legible during cloud cover.
 EMISSION=stone*mix(.32,.22,moon_visibility);
 float swell=.38*sin(scene_time*1.15+pixel.x*.28)+.14*sin(scene_time*1.73+pixel.x*1.1);
 float front=coast_distance(pixel.xz)-swell;
 float spray=(1.-smoothstep(.05,1.2,abs(front+.55)))*step(.955,grain);
 spray*=step(.1,sin(scene_time*1.3+pixel.x*5.+pixel.z*4.));
 ALBEDO=mix(ALBEDO,vec3(.58,.53,.57),spray);
 EMISSION+=vec3(.38,.33,.36)*spray*mix(.1,1.,moon_visibility);
 ROUGHNESS=1.; SPECULAR=0.; METALLIC=0.;
}
void light() {
 float response=ATTENUATION*max(dot(NORMAL,LIGHT),0.);
 DIFFUSE_LIGHT+=LIGHT_COLOR*response/PI;
}
