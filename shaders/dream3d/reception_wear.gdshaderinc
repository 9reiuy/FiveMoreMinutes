// Deterministic surface wear, sampled in world metres. No screen-space filter,
// time noise, hatch pattern, or replacement texture is involved.
float reception_hash(vec2 p){
	p=fract(p*vec2(.1031,.11369));p+=dot(p,p.yx+19.19);return fract((p.x+p.y)*p.x);
}
float reception_noise(vec2 p){
	vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.-2.*f);
	return mix(mix(reception_hash(i),reception_hash(i+vec2(1.,0.)),u.x),mix(reception_hash(i+vec2(0.,1.)),reception_hash(i+vec2(1.)),u.x),u.y);
}
float reception_scuff(vec2 p){
	vec2 cell=floor(p/.65);vec2 q=fract(p/.65)*.65-vec2(.325);
	float seed=reception_hash(cell+vec2(17.,41.));
	float angle=(reception_hash(cell+5.)-.5)*2.4;
	vec2 axis=vec2(cos(angle),sin(angle));
	vec2 centre=vec2(reception_hash(cell+13.),reception_hash(cell+29.))*.20-.10;
	q-=centre;float half_length=.055+seed*.095;
	vec2 closest=axis*clamp(dot(q,axis),-half_length,half_length);
	float primary=1.-smoothstep(.012,.028,length(q-closest));
	// A few broken parallel rubs read as abrasion rather than single drawn lines.
	vec2 offset_q=q-vec2(-axis.y,axis.x)*.043-axis*.025;
	vec2 secondary=axis*clamp(dot(offset_q,axis),-half_length*.55,half_length*.55);
	float broken=(1.-smoothstep(.008,.022,length(offset_q-secondary)))*smoothstep(.80,.94,seed);
	return max(primary,broken*.7)*smoothstep(.61,.80,seed);
}
// R: accumulated soil; G: sparse abrasion; B: slow tonal variation.
vec3 reception_wear(vec2 position,float edge_mask,float traffic){
	vec2 p=(floor(position*32.)+.5)/32.;
	float broad=reception_noise(p*.67+vec2(3.,11.));
	float mottling=reception_noise(p*2.1+vec2(23.,7.));
	float soil=smoothstep(.40,.76,broad)*(.16+.84*edge_mask)*(.55+.45*mottling);
	float abrasion=reception_scuff(p)*(.2+.8*traffic);
	return vec3(soil,abrasion,broad-.5);
}
