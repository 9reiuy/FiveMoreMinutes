shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/dream3d/reception_wear.gdshaderinc"

uniform vec4 finish_colour : source_color = vec4(.6,.63,.64,1.);
// Steel, moulding, tyre, glazing, alloy, lens.
uniform int finish_kind = 0;
uniform float base_roughness = .4;
uniform float base_metallic = .8;
uniform float age : hint_range(0.,1.) = .78;
uniform sampler2D steel_colour : source_color, filter_nearest_mipmap_anisotropic;
uniform sampler2D steel_normal : hint_normal, filter_nearest_mipmap_anisotropic;
uniform sampler2D steel_roughness : filter_nearest_mipmap_anisotropic;
varying vec3 car_point;
varying vec3 car_normal;

void vertex(){
	car_point = VERTEX;
	car_normal = NORMAL;
}

float fine_scratches(vec2 p){
	vec2 cell = floor(p*vec2(2.8,14.));
	vec2 q = fract(p*vec2(2.8,14.));
	float seed = reception_hash(cell+31.);
	float line = (1.-smoothstep(.10,.29,abs(q.y-.5)));
	line *= smoothstep(.06,.20,q.x)*(1.-smoothstep(.63,.91,q.x));
	return line*smoothstep(.84,.96,seed);
}

void fragment(){
	// Fixed object-space coverage: wear cannot crawl with Camera movement.
	vec3 p = (floor(car_point*32.)+.5)/32.;
	vec3 n = abs(car_normal);
	vec2 uv = n.y>max(n.x,n.z) ? p.xz : (n.z>n.x ? p.xy : p.zy);
	float broad = reception_noise(uv*2.3+vec2(11.,4.));
	float grit = reception_hash(floor(uv*32.)+19.);
	float road = (1.-smoothstep(.28,.74,p.y))*(.32+.68*broad);
	float soot = (1.-smoothstep(-2.15,-1.64,p.x))*(1.-smoothstep(.36,.78,p.y));
	float scuff = fine_scratches(uv);
	vec3 colour = finish_colour.rgb;
	float roughness = base_roughness;
	float metallic = base_metallic;
	if(finish_kind==0){
		vec2 brushed_uv = UV*vec2(.65,1.8);
		vec3 brushed = texture(steel_colour,brushed_uv).rgb;
		colour *= mix(vec3(.84),brushed*1.4,.38);
		NORMAL_MAP = texture(steel_normal,brushed_uv).rgb;
		NORMAL_MAP_DEPTH = .16;
		roughness = .25 + texture(steel_roughness,brushed_uv).r*.26;
		float finger = (1.-smoothstep(.09,.27,length((p.xy-vec2(-.47,.755))*vec2(1.,1.6))))*n.z;
		float dirt = clamp(road*.48+soot*.36+finger*.35+smoothstep(.6,.83,broad)*.13,0.,.64)*age;
		colour = mix(colour,vec3(.19,.18,.155),dirt);
		colour += vec3(.12)*scuff*age;
		roughness = clamp(roughness+dirt*.32+scuff*.10*age,.25,.9);
		metallic *= 1.-dirt*.38;
	}else if(finish_kind==1){
		float fade = (.05+.10*broad)*age;
		colour += vec3(.10,.105,.10)*fade;
		colour = mix(colour,vec3(.105,.094,.075),road*.42*age);
		colour += scuff*.035*age;
		roughness += broad*.10*age;
	}else if(finish_kind==2){
		colour += vec3(.028,.026,.021)*age*(.25+.75*broad);
		colour = mix(colour,vec3(.085,.073,.055),road*.30*age);
		roughness = .94;
	}else if(finish_kind==3){
		float edge = smoothstep(.45,.72,broad)*.25;
		colour = mix(colour,vec3(.12,.135,.13),edge*age);
		colour += step(.975,grit)*.025*age;
		roughness += edge*.27*age;
	}else if(finish_kind==4){
		float axle = abs(p.x-1.05)<abs(p.x+1.36) ? 1.05 : -1.36;
		float wheel_y = axle>0.0 ? .302 : .332;
		float radius = length(p.xy-vec2(axle,wheel_y));
		float dust = smoothstep(.07,.26,radius)*(.28+.38*broad)*age;
		colour = mix(colour,vec3(.11,.105,.085),dust);
		roughness += dust*.28;
		metallic *= 1.-dust*.38;
	}else{
		colour *= 1.-age*(.09+.18*road);
		roughness += .08*broad*age;
	}
	ALBEDO = max(colour,vec3(.005));
	ROUGHNESS = clamp(roughness,.08,1.);
	METALLIC = metallic;
	SPECULAR = .5;
}
