// Same plateaus; only the subpixel transition integrates its screen footprint.
uniform bool preview_filter_enabled=true;
float preview_toon_diffuse(float response){
 if(response<=0.0){return 0.0;}
 float a=preview_filter_enabled?clamp(fwidth(response)*.65,.02,.10):.02;
 float stepped=.15*smoothstep(.06-a,.06+a,response)+.40*smoothstep(.35-a,.35+a,response)+.45*smoothstep(.71-a,.71+a,response);
 // Preserve weak incident light and the original painted details instead of
 // turning the first band into a black cutout. Zero real light stays zero.
 return max(stepped,response*.65);
}
float preview_toon_specular(float response){
 if(response<=0.0){return 0.0;}
 float a=preview_filter_enabled?clamp(fwidth(response)*.65,.005,.06):.005;
 float b=preview_filter_enabled?max(.01,a):.01;
 float c=preview_filter_enabled?max(.02,a):.02;
 return .025*smoothstep(.015-a,.015+a,response)+.075*smoothstep(.07-b,.07+b,response)+.20*smoothstep(.19-b,.19+b,response)+.28*smoothstep(.46-c,.46+c,response);
}
