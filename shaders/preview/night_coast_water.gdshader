shader_type spatial;
#include "res://shaders/dream3d/office_dither_lighting.gdshaderinc"
render_mode unshaded, cull_disabled;
uniform sampler2D flow_state: filter_linear, repeat_disable;
uniform sampler2D surface_foam: filter_linear, repeat_disable;
uniform sampler2D near_foam: filter_linear, repeat_disable;
uniform sampler2D near_state: filter_linear, repeat_disable;
uniform vec2 near_origin=vec2(-120.,-112.);
uniform vec2 near_size=vec2(240.,210.);
uniform vec2 near_grid=vec2(64.,56.);
uniform float scene_time=0.0;
uniform float moon_visibility=1.0;
uniform bool ripples_enabled=true;
uniform float whitecap_strength : hint_range(0.,1.)=.90;
#include "res://shaders/preview/coast_shape.gdshaderinc"
varying vec3 world_position;
varying float actual_depth;
varying float dye_amount;
varying float speed;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
float shore(float x){return 3.0+sin(x*.38)*.65+sin(x*1.1)*.25;}
float foam_lip(sampler2D field,vec2 uv,vec2 cell){
 if(uv.x<=0. || uv.x>=1. || uv.y<=0. || uv.y>=1.) return 0.;
 vec4 tracer=texture(field,uv);
 vec2 transport=normalize(tracer.ba+vec2(.0001,.001));
 float behind=texture(field,uv-transport*cell*.7).r;
 float ahead=texture(field,uv+transport*cell*.7).r;
 float leading=smoothstep(.012,.055,behind-ahead);
 float lip=1.-smoothstep(.025,.085,abs(tracer.r-.30));
 float edge_fade=smoothstep(0.,.09,min(min(uv.x,1.-uv.x),min(uv.y,1.-uv.y)));
 float envelope=1.-smoothstep(.65,1.0,length((uv-.5)*vec2(1.8,1.6)));
 return lip*leading*edge_fade*envelope;
}
float wave_height(vec2 p,float t){
 vec2 warp=vec2(noise(p*.13+vec2(t*.016,0.)),noise(p*.17+vec2(0.,-t*.021)))-.5;
 vec2 q=p+warp*1.6;
 return .052*sin(dot(q,vec2(.42,.91))*1.35-t*.93)
      +.029*sin(dot(q,vec2(-.84,.54))*2.17+t*1.31)
      +.019*sin(dot(q,vec2(.72,-.69))*3.71-t*1.83)
      +.011*sin(dot(q,vec2(-.20,-.98))*5.11+t*2.37);
}
void vertex(){
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 office_dither_position=world;
 office_dither_normal=vec3(0,1,0);
 vec2 flow_uv=(world.xz-vec2(-12,-16))/vec2(24,20);
 float inside=step(0.,flow_uv.x)*step(flow_uv.x,1.)*step(0.,flow_uv.y)*step(flow_uv.y,1.);
 vec4 state=texture(flow_state,clamp(flow_uv,vec2(0),vec2(1)));
 float wave=wave_height(world.xz,scene_time);
 VERTEX.y=mix(wave,state.g+wave*.28,inside);
 vec2 near_uv=(world.xz-near_origin)/near_size;
 vec4 side_state=texture(near_state,clamp(near_uv,vec2(0),vec2(1)));
 float side_inside=step(0.,near_uv.x)*step(near_uv.x,1.)*step(0.,near_uv.y)*step(near_uv.y,1.)*(1.-inside);
 VERTEX.y=mix(VERTEX.y,side_state.g+wave*.28,side_inside);
 actual_depth=mix(max(.0,coast_distance(world.xz)*.22),state.r,inside);
 dye_amount=state.b*inside;
 speed=state.a*inside;
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
}
void fragment(){
 vec2 p=floor(world_position.xz*32.)/32.;
 float coast=coast_distance(p);
 float t=scene_time;
 float drift=noise(p*vec2(2.1,3.8)+vec2(t*.14,-t*.21));
 float detail=noise(p*vec2(6.7,8.5)+vec2(-t*.19,t*.27));
 float swell=.38*sin(t*1.15+p.x*.28)+.14*sin(t*1.73+p.x*1.1);
 float edge=coast-swell+(drift-.5)*.65;
 if(edge<-.15 || coast < -1.) discard;
 // Deep crimson remains crimson in moonlight; cloud cover reduces its value.
 float body=noise(p*.37+vec2(-t*.035,t*.05));
 vec3 sea=mix(vec3(.23,.008,.031),vec3(.30,.014,.043),floor(body*4.)/3.);
 float whitecaps=0.;
 float crest_wash=0.;
 if(ripples_enabled){
  // Draw local crest ridges, NOT constant-height contour loops.
  vec2 direction=normalize(vec2(.42,.91)+(vec2(noise(p*.11),noise(p*.14+9.))-.5)*.9);
  float h=wave_height(p,t);
  float ahead=wave_height(p+direction*.18,t);
  float behind=wave_height(p-direction*.18,t);
  float slope=ahead-behind;
  float curvature=2.*h-ahead-behind;
  float crest=(1.-smoothstep(.002,.008,abs(slope)))*smoothstep(.0003,.0024,curvature);
  float packet=.5*noise(p*.47+vec2(-t*.032,t*.014))+.5*noise(p*.17+vec2(t*.021,0.));
  float broken=crest*smoothstep(.29,.51,packet)*smoothstep(-.025,.035,h);
  // Pale breaking lips, not red-on-red highlights. Interfering swell directions
  // and slowly changing packets break the crests into uneven open arcs.
  // Keep far water quiet. Visible foam is a transported, decaying tracer of
  // compression and pressure crests in the actual 24x20m simulation patch.
  vec2 foam_uv=(p-vec2(-12.,-16.))/vec2(24.,20.);
  float lip=foam_lip(surface_foam,foam_uv,vec2(1./48.,1./40.));
  float broad_lip=foam_lip(near_foam,(p-near_origin)/near_size,vec2(1.)/near_grid);
  broad_lip*=1.-smoothstep(75.,115.,length(world_position-CAMERA_POSITION_WORLD));
  lip=max(lip,broad_lip);
  float fray=smoothstep(.28,.47,noise(p*vec2(.45,.65)));
  whitecaps=lip*fray*smoothstep(.15,.75,coast);
  crest_wash=whitecaps*.25;
  sea+=broken*vec3(.035,.009,.014);
  float stone=obstacle_distance(p);
  float ring=1.-smoothstep(.06,.16,abs(sin((stone*5.2-t*2.1)*.5)));
  ring*=smoothstep(.25,.65,stone)*(1.-smoothstep(1.1,1.8,stone));
  sea+=vec3(.04,.018,.025)*ring*smoothstep(.48,.70,detail);
  // Near-field pressure waves from actual solver height differences.
  vec2 uv=(p-vec2(-12,-16))/vec2(24,20);
  if(uv.x>0.02 && uv.x<.98 && uv.y>.02 && uv.y<.98 && actual_depth>.04){
   vec2 cell=vec2(1./48.,1./40.);
   float h=texture(flow_state,uv).g;
   float curvature=abs(2.*h-texture(flow_state,uv+vec2(cell.x,0)).g-texture(flow_state,uv-vec2(cell.x,0)).g);
   sea+=vec3(.10,.06,.065)*smoothstep(.012,.06,curvature);
  }
 }
 sea*=mix(.24,1.0,moon_visibility);
 sea=mix(sea,vec3(.39,.29,.33)*mix(.22,1.,moon_visibility),crest_wash*.42*whitecap_strength);
 sea=mix(sea,vec3(.84,.79,.80)*mix(.22,1.,moon_visibility),whitecaps*whitecap_strength);
 // Broken thin flecks rather than the former regular sine/checker pattern.
 float road_center=5.+p.y*(-.08);
 float road_width=1.4+max(p.y+80.,0.)*.034;
 float road=exp(-pow((p.x-road_center+(drift-.5)*1.8)/road_width,2.));
 float glint=step(.46,wave_height(p,t)/.12)*step(.53,detail);
 sea+=vec3(.30,.25,.25)*road*glint*moon_visibility;
 // Thick, perforated wave front and a narrow older foam contour behind it.
 float foam_width=.42+noise(vec2(p.x*3.1,t*.39))*.55;
 float foam=(1.-step(foam_width,abs(edge-.34)))*step(.32,detail+drift*.16);
 float old=(1.-step(.055,abs(edge-1.35+(detail-.5)*.5)))*step(.49,drift);
 sea=mix(sea,vec3(.43,.27,.32)*mix(.24,1.,moon_visibility),old*.7);
 vec3 cream=mix(vec3(.53,.41,.46),vec3(.86,.80,.81),step(.48,detail));
 float stone_distance=obstacle_distance(p);
 float impact=(1.-smoothstep(.1,.6,stone_distance))*step(-.08,stone_distance);
 impact*=step(.4,detail)*smoothstep(-.7,.4,sin(t*1.5+p.x*.8+p.y*.6));
 foam=max(foam,impact*.9);
 sea=mix(sea,cream*mix(.20,1.,moon_visibility),foam);
 float fragments=(1.-smoothstep(1.,2.5,edge))*smoothstep(.6,.95,edge)*step(.94,hash(floor(p*32.)));
 sea=mix(sea,vec3(.68,.61,.65)*mix(.2,1.,moon_visibility),fragments);
 sea=mix(sea,vec3(.38,.022,.044)*mix(.24,1.,moon_visibility),min(dye_amount*.7,.7));
 sea+=min(speed*.012,.025)*vec3(.17,.08,.11);
 if(office_dither_enabled){
  float threshold=office_dither_threshold(p/office_dither_step);
  sea=floor(sea*31.+vec3(threshold))/31.;
 }
 float distance_haze=1.-exp(-max(length(world_position-CAMERA_POSITION_WORLD)-30.,0.)*.005);
 sea=mix(sea,vec3(.008,.012,.016)*mix(.35,1.,moon_visibility),distance_haze*.78);
 ALBEDO=sea;
}
