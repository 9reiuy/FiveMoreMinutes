uniform sampler2D coast_shape: filter_linear, repeat_disable;
uniform bool urban_coast = false;
float coast_distance(vec2 p){
 if(urban_coast){
  float edge=6.+max(-p.y,0.)*.28-14.*smoothstep(-2.,8.,p.y);
  return edge-p.x;
 }
 vec2 uv=(p-vec2(-28.,-22.))/vec2(56.,70.);
 if(uv.x<0. || uv.x>1. || uv.y<0. || uv.y>1.) return max(-p.y,abs(p.x+3.)-12.);
 return texture(coast_shape,uv).g;
}
float obstacle_distance(vec2 p){
 vec2 uv=(p-vec2(-28.,-22.))/vec2(56.,70.);
 if(uv.x<0. || uv.x>1. || uv.y<0. || uv.y>1.) return 100.;
 return texture(coast_shape,uv).b;
}
