shader_type canvas_item;
render_mode unshaded;
uniform float scene_time=0.0;
uniform float moon_visibility=1.0;
uniform float reveal=1.0;
uniform float horizon_y=.3;
uniform mat4 sky_inverse_projection=mat4(1.);
uniform mat4 sky_camera_to_world=mat4(1.);
uniform vec3 moon_direction=vec3(.4,.18,-1.);
uniform vec3 zenith_tint : source_color = vec3(.075,.078,.18);
uniform vec3 middle_sky_tint : source_color = vec3(.13,.075,.22);
uniform vec3 horizon_tint : source_color = vec3(.30,.10,.325);
uniform float distant_stars : hint_range(0.0, 1.0) = 0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 uv=UV;
 vec4 ray=sky_inverse_projection*vec4(uv.x*2.-1.,1.-uv.y*2.,1.,1.);
 vec3 direction=normalize(mat3(sky_camera_to_world)*(ray.xyz/ray.w));
 vec2 world_uv=vec2(.72+.55*(direction.x/max(-direction.z,.001)-.4),.16+.8*(.18-direction.y/max(-direction.z,.001)));
 // The colour bands belong to sky elevation, so revealing the horizon does
 // not drag a screen-space gradient across the moon and offshore silhouettes.
 float elevation=clamp(max(direction.y,0.)/.46,0.,1.);
 vec3 sky=mix(horizon_tint,middle_sky_tint,smoothstep(0.,.42,elevation));
 sky=mix(sky,zenith_tint,smoothstep(.22,.85,elevation));
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
 sky+=vec3(.20,.12,.15)*halo*moon_visibility;
 sky=mix(sky,vec3(.82,.83,.80),moon*moon_visibility);
 float field=(sin(world_uv.x*11.-scene_time*.22)+.65*sin(world_uv.x*21.+world_uv.y*30.-scene_time*.35)+.35*sin(world_uv.x*39.-world_uv.y*17.-scene_time*.18))*.5;
 float cloud=smoothstep(.1,.65,field)* (1.-smoothstep(.23,.47,world_uv.y));
 vec3 cloud_color=mix(horizon_tint*.32,zenith_tint*.65,smoothstep(0.,.55,elevation));
 cloud_color+=vec3(.008,.006,.015)*max(field,0.);
 cloud_color+=vec3(.035,.044,.056)*halo;
 sky=mix(sky,cloud_color,cloud*.97);
 if(distant_stars>0.){
  vec2 star_grid=world_uv*vec2(134.,88.);
  vec2 cell=floor(star_grid);
  vec2 offset=vec2(hash(cell+7.2),hash(cell+21.5))*.56+.22;
  float point=1.-smoothstep(.06,.20,length(fract(star_grid)-offset));
  float clear_sky=smoothstep(.04,.25,direction.y)*(1.-cloud*.88);
  sky+=vec3(.49,.58,.72)*point*clear_sky*step(.83,hash(cell))*distant_stars;
 }
 float haze=exp(-abs(uv.y-horizon_y)*45.)*(.65+.2*sin(uv.x*14.-scene_time*.07));
 sky+=horizon_tint*.22*haze*(.25+.75*moon_visibility);
 COLOR=vec4(sky*reveal,1);
}
