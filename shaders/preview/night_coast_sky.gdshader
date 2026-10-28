shader_type canvas_item;
render_mode unshaded;
uniform float scene_time=0.0;
uniform float moon_visibility=1.0;
uniform float reveal=1.0;
uniform float horizon_y=.3;
uniform mat4 sky_inverse_projection=mat4(1.);
uniform mat4 sky_camera_to_world=mat4(1.);
uniform vec3 moon_direction=vec3(.4,.18,-1.);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 uv=UV;
 vec4 ray=sky_inverse_projection*vec4(uv.x*2.-1.,1.-uv.y*2.,1.,1.);
 vec3 direction=normalize(mat3(sky_camera_to_world)*(ray.xyz/ray.w));
 vec2 world_uv=vec2(.72+.55*(direction.x/max(-direction.z,.001)-.4),.16+.8*(.18-direction.y/max(-direction.z,.001)));
 vec3 sky=mix(vec3(.009,.016,.04),vec3(.035,.054,.077),smoothstep(0.,.55,uv.y));
 vec2 pixel=floor(world_uv*vec2(640,360));
 // Eight deliberately spaced faint stars, rather than per-pixel sky noise.
 float star=0.;
 for(int i=0;i<8;i++){
  vec2 point=vec2(.09+float(i)*.113,.055+hash(vec2(float(i),4.))*.16);
  star+=1.-step(.65,length(pixel-floor(point*vec2(640,360))));
 }
 sky+=star*vec3(.15,.18,.23)*(.8+.2*sin(scene_time*.4+pixel.x));
 float angle=sqrt(max(0.,2.*(1.-dot(direction,normalize(moon_direction)))));
 float moon=1.-step(.022,angle);
 float halo=exp(-angle*24.);
 sky+=vec3(.12,.16,.22)*halo*moon_visibility;
 sky=mix(sky,vec3(.66,.72,.76),moon*moon_visibility);
 float field=(sin(world_uv.x*11.-scene_time*.22)+.65*sin(world_uv.x*21.+world_uv.y*30.-scene_time*.35)+.35*sin(world_uv.x*39.-world_uv.y*17.-scene_time*.18))*.5;
 float cloud=smoothstep(.1,.65,field)* (1.-smoothstep(.23,.47,world_uv.y));
 vec3 cloud_color=vec3(.024,.033,.052)+vec3(.018,.021,.026)*max(field,0.);
 cloud_color+=vec3(.035,.044,.056)*halo;
 sky=mix(sky,cloud_color,cloud*.97);
 float haze=exp(-abs(uv.y-horizon_y)*45.)*(.65+.2*sin(uv.x*14.-scene_time*.07));
 sky+=vec3(.012,.016,.022)*haze*(.25+.75*moon_visibility);
 COLOR=vec4(sky*reveal,1);
}
