shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D atlas : source_color, filter_nearest_mipmap, repeat_disable;
uniform sampler2D fabric_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D fabric_normal : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D fabric_roughness : filter_nearest_mipmap, repeat_enable;
uniform vec4 upholstery_tint : source_color = vec4(.4,.43,.41,1.);
uniform vec2 fabric_metres = vec2(4.);
uniform float detail_amount = 1.;
uniform float wear_amount = .85;
#include "res://shaders/dream3d/reception_wear.gdshaderinc"
varying vec3 point_world;
varying vec3 point_local;
varying vec3 normal_world;
void vertex(){
	point_world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	point_local=VERTEX;
	normal_world=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
	vec3 n=abs(normal_world);vec2 point=point_world.xz;
	if(n.y<.65){point=n.x>n.z?point_world.zy:point_world.xy;}
	vec2 raw_uv=point/fabric_metres;
	vec2 sample_uv=(floor(point*32.)+.5)/(32.*fabric_metres);
	vec2 dx=dFdx(raw_uv);vec2 dy=dFdy(raw_uv);
	vec3 cloth=textureGrad(fabric_albedo,sample_uv,dx,dy).rgb;
	// Retain the authored atlas colours. Only the existing cloth photograph's
	// neutral nap variation is added; its orange dye is not applied to the sofa.
	float nap=clamp((cloth.r/.616-1.)*2.2,-.18,.18);
	vec3 base=texture(atlas,UV).rgb*upholstery_tint.rgb;
	vec3 p=(floor(point_local*32.)+.5)/32.;
	vec2 cushion=p.xz-vec2(p.x<0.?-.49:.49,.06);
	vec2 margin=vec2(.47,.31)-abs(cushion);
	float inside=step(0.,min(margin.x,margin.y));
	float seat=step(.65,n.y)*step(.50,p.y)*(1.-step(.59,p.y))*inside;
	float seam=(1.-smoothstep(.012,.055,min(margin.x,margin.y)))*seat;
	vec2 pressure_axis=cushion*vec2(.9,1.4);
	float pressure=exp(-dot(pressure_axis,pressure_axis)*12.)*seat*(1.-seam);
	float patch=.55+.45*reception_noise(p.xz*7.+vec2(11.,3.));
	float arm=step(.65,n.y)*step(.92,abs(p.x))*step(.56,p.y);
	float headrest=step(.80,p.y)*step(.65,n.y);
	float rubbed=(pressure*.9+arm*.65+headrest*.35)*patch;
	float lower=(1.-smoothstep(.18,.43,p.y))*(.4+.6*reception_noise(p.xz*5.));
	base*=1.+nap*detail_amount+(rubbed*.45-seam*.24-lower*.18)*wear_amount;
	ALBEDO=base;
	float rough=textureGrad(fabric_roughness,sample_uv,dx,dy).r;
	ROUGHNESS=clamp(mix(1.,clamp(rough,.82,.98),detail_amount)-rubbed*.065*wear_amount,.76,1.);
	SPECULAR=.08*detail_amount;METALLIC=0.;
	vec3 map_n=textureGrad(fabric_normal,sample_uv,dx,dy).rgb*2.-1.;
	// A shallow change in fibre direction reads as a pressed cushion surface.
	map_n.xy+=pressure_axis*pressure*.32*wear_amount;
	vec3 dp1=dFdx(VERTEX);vec3 dp2=dFdy(VERTEX);
	vec3 p2=cross(dp2,NORMAL);vec3 p1=cross(NORMAL,dp1);
	vec3 t=p2*dx.x+p1*dy.x;vec3 b=p2*dx.y+p1*dy.y;
	float scale=inversesqrt(max(max(dot(t,t),dot(b,b)),.000001));
	NORMAL=normalize(NORMAL*max(map_n.z,.5)+(t*map_n.x+b*map_n.y)*scale*.20*detail_amount);
}
