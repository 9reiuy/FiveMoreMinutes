shader_type canvas_item;
render_mode unshaded;
uniform float coast_time = 0.0;
uniform vec2 terrain_size = vec2(2400.0, 1800.0);
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float shore(float y) { return 850.0+65.0*sin(y*.005)+26.0*sin(y*.013); }
void fragment() {
 vec2 p=floor(UV*terrain_size);
 float t=coast_time;
 float grain=hash(p);
 float n=noise(p*.034+vec2(t*.14,-t*.12));
 float fine=noise(p*.12+vec2(t*.25,t*.10));
 float d=p.x-shore(p.y);
 float tide=19.0*sin(t*1.12+p.y*.003)+7.0*sin(t*1.7+p.y*.019);
 float edge=d-tide+(n-.5)*20.0;
 // Dark wet sand, with tiny mineral flecks held in world coordinates.
 vec3 land=mix(vec3(.016,.041,.043),vec3(.029,.067,.066),noise(p*.018));
 land+=step(.994,grain)*.035;
 float wet=1.0-smoothstep(0.0,100.0,max(edge,0.0));
 land*=mix(1.0,.65,wet);
 // Layered current: broad red troughs, stretched broken wave crests.
 float flow=noise(vec2(p.x*.025+t*.21,p.y*.065-t*.18));
 float band=sin(p.x*.08+p.y*.021+flow*5.0-t*1.7);
 float broad=noise(p*.009+vec2(t*.025,0.0));
 vec3 sea=mix(vec3(.27,.009,.032),vec3(.38,.018,.046),floor(broad*5.0)/4.0);
 sea+=vec3(.014,.003,.005)*floor(band*3.0)/3.0;
 float crest=step(.84,band)*step(.57,fine);
 sea+=crest*vec3(.065,.014,.025);
 float ripples=noise(vec2(p.x*.045+t*.17,p.y*.16-t*.26));
 sea+=step(.76,ripples)*vec3(.055,.014,.019);
 // Advancing foam contains holes; a second, older band follows its retreat.
 float foam_width=10.0+noise(vec2(p.y*.06,t*.48))*15.0;
 float foam=1.0-step(foam_width,abs(edge+4.0));
 foam*=step(.27,fine+n*.28);
 float old=1.0-smoothstep(2.0,5.0,abs(edge+29.0+(fine-.5)*18.0));
 old*=step(.53,n)*step(.38,fine);
 vec3 col=mix(land,sea,1.0-smoothstep(-1.0,1.0,edge));
 col=mix(col,vec3(.59,.36,.41),old*.63);
 col=mix(col,mix(vec3(.62,.52,.58),vec3(.91,.86,.85),step(.46,fine)),foam);
 // Sparse detached foam breaks up on the land side, never uniform snow.
 float spray_zone=smoothstep(12.0,23.0,edge)*(1.0-smoothstep(25.0,80.0,edge));
 float islands=noise(p*.16+vec2(-t*.8,t*.14));
 float spray=step(1.0-spray_zone*.11,grain)*step(.43,islands);
 col=mix(col,vec3(.73,.76,.73),spray);
 // Scalloped rock bank on the far side, with angular pixel facets.
 float rock_edge=d-305.0-24.0*sin(p.y*.04)-noise(p*.025)*62.0;
 if(rock_edge>0.0) {
   vec2 q=p/25.0;
   vec2 cell=floor(q);
   float first=10.0, second=10.0, facet=0.0;
   for(int y=-1;y<=1;y++) { for(int x=-1;x<=1;x++) {
     vec2 id=cell+vec2(float(x),float(y));
     vec2 center=id+vec2(hash(id),hash(id+81.0));
     float dist=length(q-center);
     if(dist<first) { second=first; first=dist; facet=hash(id+12.0); }
     else { second=min(second,dist); }
   }}
   col=mix(vec3(.035,.047,.053),vec3(.105,.124,.13),floor(facet*4.0)/3.0);
   col*=mix(.45,1.0,step(.055,second-first));
   col*=mix(.55,1.0,smoothstep(0.0,18.0,rock_edge));
 }
 float vignette=1.0-.12*noise(p*.001);
 COLOR=vec4(col*vignette,1.0);
}
