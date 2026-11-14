uniform vec2 city_air_ad_anchor0=vec2(72.41006,33.45109);
uniform vec2 city_air_ad_anchor1=vec2(73.15544,40.47069);
uniform vec2 city_air_ad_anchor2=vec2(73.21996,55.17027);
uniform vec2 city_air_ad_anchor3=vec2(42.32,19.36131);
// DEPTH01_SHARED_AIR_BEGIN
// Fixed city-space air: three depth ranges, no time/screen noise or extra pass.
float depth01_pool(vec2 point,vec2 center,vec2 radius) {
 vec2 q=(point-center)/radius;
 return exp(-0.5*dot(q,q));
}
vec3 city_air_color(vec3 eye, vec3 direction) {
 vec3 ray=normalize(direction);
 float denominator=max(-ray.y,0.08);
 vec2 far_xz=eye.xz+ray.xz*max(0.0,(eye.y+58.0)/denominator);
 vec2 lower_xz=eye.xz+ray.xz*max(0.0,(eye.y+41.0)/denominator);
 float layer=0.5+0.26*sin(far_xz.x*0.024+far_xz.y*0.011)
  +0.18*sin(far_xz.y*0.041-far_xz.x*0.008);
 vec3 air=mix(vec3(0.130,0.175,0.195),vec3(0.182,0.228,0.244),clamp(layer,0.0,1.0));
 // Broad weak scattered light below existing host16/5/6/own106; no new emitter.
 air+=depth01_pool(lower_xz,city_air_ad_anchor0,vec2(10.0,15.0))*vec3(0.004,0.025,0.029);
 air+=depth01_pool(lower_xz,city_air_ad_anchor1,vec2(11.0,12.0))*vec3(0.008,0.020,0.030);
 air+=depth01_pool(lower_xz,city_air_ad_anchor2,vec2(9.0,12.0))*vec3(0.020,0.005,0.005);
 air+=depth01_pool(lower_xz,city_air_ad_anchor3,vec2(10.0,13.0))*vec3(0.007,0.020,0.025);
 float corridor=exp(-0.5*pow(far_xz.y/13.0,2.0))
  *(1.0-smoothstep(17.0,38.0,abs(far_xz.x-34.0)));
 float east=exp(-0.5*pow((far_xz.x-90.0)/13.0,2.0))
  *(1.0-smoothstep(18.0,42.0,abs(far_xz.y-42.0)));
 return air*(1.0-0.055*max(corridor,east));
}
float city_air_extinction(vec3 eye,vec3 point) {
 float h=max(0.0,-point.y);
 float lower=smoothstep(14.0,28.0,h);
 float depth=max(0.0,h-6.0)/40.0;
 float depth4=depth*depth*depth*depth;
 float broad=clamp(0.5+0.26*sin(point.x*0.024+point.z*0.011)
  +0.18*sin(point.z*0.031-point.x*0.008),0.0,1.0);
 float height_mass=mix(8.0,mix(3.6,5.0,broad),lower)*depth4;
 float distance=length(point-eye);
 float old_distance=pow(max(0.0,distance-30.0)/92.0,1.3)*1.15;
 float layered_distance=pow(max(0.0,distance-30.0)/62.0,1.3)*1.10;
 // Street -42.91 and source ends -46/-48 remain fully sealed in deep air.
 float seal=smoothstep(35.0+2.0*broad,43.0,h);
 float mass=height_mass+mix(old_distance,layered_distance,lower)+12.0*seal*seal;
 return 1.0-exp(-min(20.0,mass));
}
// DEPTH01_SHARED_AIR_END
