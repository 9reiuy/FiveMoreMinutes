shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/dream3d/passage_end_fade.gdshaderinc"
uniform vec4 concrete_colour : source_color = vec4(0.32, 0.35, 0.36, 1.0);
uniform bool floor_surface = false;
uniform float wetness : hint_range(0.0, 1.0) = 0.45;
uniform float wear_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 wear_floor_bounds = vec4(0.0);
varying vec3 surface_world;
varying vec3 normal_world;

float hash21(vec2 p) {
	// Every noise cell must agree on its shared corners. A sine/float hash
	// can round the same corner differently after GPU expression folding,
	// producing rectangular seams in dampness, roughness and highlights.
	uvec2 cell=uvec2(ivec2(p));
	uint h=cell.x*374761393u+cell.y*668265263u+2246822519u;
	h=(h^(h>>13u))*1274126177u;
	h=h^(h>>16u);
	return float(h&16777215u)/16777216.0;
}
float noise21(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}

// Short abrasions on a fixed surface grid, with no animated or screen noise.
float concrete_scuff(vec2 point) {
	vec2 cell = floor(point / .95);
	float seed = hash21(cell + vec2(17.0, 31.0));
	vec2 shift = vec2(hash21(cell + 7.0), hash21(cell + 23.0)) * .28 - .14;
	vec2 offset = mod(point, .95) - .475 - shift;
	float angle = (hash21(cell + 5.0) - .5) * 2.6;
	vec2 direction = vec2(cos(angle), sin(angle));
	float half_length = mix(.07, .23, seed);
	vec2 closest = direction * clamp(dot(offset, direction), -half_length, half_length);
	return (1.0 - smoothstep(.012, .034, distance(offset, closest))) * smoothstep(.67, .86, seed);
}
void vertex() {
	surface_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	normal_world=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	vec3 n=abs(normal_world);
	vec2 uv=surface_world.xz;
	if (n.y<0.65) { uv=(n.x>n.z) ? surface_world.zy : surface_world.xy; }
	// Same 32 texels/metre on floors, wall faces and wall caps.
	vec2 pixel=floor(uv*32.0)/32.0;
	float aggregate=hash21(floor(uv*32.0));
	float mottling=noise21(pixel*1.35);
	float fine=noise21(pixel*7.0);
	vec2 panel=abs(fract(uv/2.0)-0.5);
	float joint=max(smoothstep(0.492,0.5,panel.x),smoothstep(0.492,0.5,panel.y));
	float pits=step(0.972,aggregate);
	float damp=noise21(pixel*.73+vec2(9.2,4.1));
	damp=smoothstep(.45,.72,damp)*wetness;
	float variation=.78+mottling*.28+(fine-.5)*.09+(aggregate-.5)*.07;
	vec3 dry=concrete_colour.rgb*variation;
	ALBEDO=mix(dry,dry*vec3(.53,.60,.63),damp)*mix(1.0,.63,joint)*mix(1.0,.56,pits);
	METALLIC=0.0;
	ROUGHNESS=mix(.84,.30,damp);
	SPECULAR=mix(.18,.38,damp);
	if (floor_surface && wear_amount > 0.0) {
		float patch = smoothstep(.37, .79, noise21(pixel * 1.58 + vec2(9.0, 14.0)));
		float abrasion = concrete_scuff(pixel);
		vec2 edge_distance = min(pixel - wear_floor_bounds.xy, wear_floor_bounds.zw - pixel);
		float edge = 1.0 - smoothstep(.04, .62, min(edge_distance.x, edge_distance.y));
		float deposit = patch * mix(.24, 1.0, edge) + joint * edge * .23;
		float drag_mark = concrete_scuff(pixel * .74 + vec2(8.6, 4.1));
		ALBEDO *= 1.0 - wear_amount * (deposit * .40 + drag_mark * .33);
		ALBEDO *= 1.0 + abrasion * wear_amount * .18;
		ROUGHNESS = clamp(ROUGHNESS + wear_amount * (deposit * .19 + abrasion * .07), .27, .98);
		SPECULAR *= 1.0 - deposit * wear_amount * .22;
	}
	float height_value=(fine*.008+pits*-.012-joint*.01);
	vec3 dpdx=dFdx(VERTEX); vec3 dpdy=dFdy(VERTEX);
	vec3 r1=cross(dpdy,NORMAL); vec3 r2=cross(NORMAL,dpdx);
	float det=dot(dpdx,r1);
	vec3 gradient=(r1*dFdx(height_value)+r2*dFdy(height_value))*sign(det)/max(abs(det),.00001);
	NORMAL=normalize(NORMAL-gradient*.32);
	apply_passage_end_fade(surface_world.x, ALBEDO, ROUGHNESS, SPECULAR);
}
