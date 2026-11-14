shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/dream3d/reception_wear.gdshaderinc"
uniform vec4 finish_colour : source_color = vec4(.2,.3,.34,1.0);
uniform int finish_kind = 0;
uniform float wear_strength : hint_range(0.0,2.0) = 1.0;
uniform vec4 floor_bounds = vec4(0.0);
varying vec3 surface_world;
varying vec3 normal_world;
void vertex() {
	surface_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
	LIGHT_VERTEX = VERTEX + normalize(NORMAL)*.025;
#endif
	vec3 axis = abs(normal_world);
	vec2 uv = axis.x > axis.z ? surface_world.zy : surface_world.xy;
	if (axis.y > .65 || finish_kind >= 2) { uv = surface_world.xz; }
	vec2 p = (floor(uv*32.0)+.5)/32.0;
	float broad = reception_noise(p*1.1+vec2(7.0,19.0));
	float grain = reception_noise(p*13.0);
	float low = 1.0-smoothstep(.08,1.15,surface_world.y);
	vec3 wear = reception_wear(p,low,1.0);
	float dirt = smoothstep(.43,.77,reception_noise(p*.56+vec2(13.0,3.0)));
	float abrasion = reception_scuff(p*vec2(.75,1.15)+vec2(6.1,8.2));
	vec3 base = finish_colour.rgb;
	float relief = (grain-.5)*.007;
	ROUGHNESS = .82;
	SPECULAR = .19;
	if (finish_kind == 0) {
		// Blue-grey cast concrete, horizontal formwork seams and deposits.
		vec2 seam = abs(fract(uv/vec2(2.4,.75))-.5);
		float joint = max(smoothstep(.49,.5,seam.x),smoothstep(.485,.5,seam.y));
		float drip = smoothstep(.50,.80,reception_noise(p*vec2(4.1,.45)));
		base *= .82+broad*.25+(grain-.5)*.09;
		float boot_rub = reception_noise(p*vec2(.75,5.5)+8.0)*(1.0-smoothstep(.30,1.35,surface_world.y));
		base *= 1.0-joint*.20-wear_strength*(drip*(.12+low*.13)+low*wear.r*.40+boot_rub*.17);
		base += finish_colour.rgb*abrasion*.16*low*wear_strength;
		relief -= joint*.008;
	} else if (finish_kind == 1 || finish_kind == 2) {
		// Glazed ochre wall tiles / worn pale stone training floor.
		float spacing = finish_kind == 1 ? .25 : .5;
		vec2 tile = abs(fract(uv/spacing)-.5);
		float joint = max(smoothstep(.445,.485,tile.x),smoothstep(.445,.485,tile.y));
		float stain = (smoothstep(.43,.78,broad)*.15+wear.r*.23+joint*dirt*.20)*wear_strength;
		base *= .94+broad*.12+(grain-.5)*.035;
		base = mix(base,base*vec3(.35,.43,.45),joint*.77);
		base *= 1.0-stain;
		float chipped = smoothstep(.38,.49,max(tile.x,tile.y))*smoothstep(.60,.84,reception_noise(floor(uv/spacing)*3.7+4.0));
		base = mix(base,vec3(.12,.16,.16),chipped*.30*wear_strength);
		ROUGHNESS = clamp(.46+joint*.36+stain+wear.g*.15,.42,.94);
		SPECULAR = .28;
		relief -= joint*.012;
	} else if (finish_kind == 3) {
		// Blue epoxy circulation lane, cloudy polish and traffic scuffs.
		base *= .88+broad*.21-wear.r*.19+wear.g*.06;
		ROUGHNESS = clamp(.40+broad*.16+wear.r*.21,.38,.86);
		SPECULAR = .32;
	} else if (finish_kind == 4) {
		// Directional anti-slip chevrons are a real floor finish, not shading hatch.
		vec2 cell = floor(uv/.5);
		vec2 tile = fract(p/.5);
		float lane = mod(cell.x+cell.y,2.0) < 1.0 ? tile.x+tile.y : tile.x-tile.y;
		float tread = smoothstep(.37,.48,abs(fract(lane*4.0)-.5));
		base *= .88+broad*.17-tread*.16-wear.r*.21;
		ROUGHNESS = .79+wear.r*.15;
		relief += tread*.006;
	} else {
		base *= .92+broad*.12-wear.r*.26*wear_strength;
		ROUGHNESS = .68+wear.r*.20;
	}
	if (finish_kind >= 2 && finish_kind <= 4) {
		vec2 distances = min(p-floor_bounds.xy,floor_bounds.zw-p);
		float edge = floor_bounds.z > floor_bounds.x ? 1.0-smoothstep(.03,.70,min(distances.x,distances.y)) : 0.0;
		float traffic = finish_kind == 3 ? .85 : exp(-abs(p.y-(floor_bounds.y+floor_bounds.w)*.5)*.80);
		// Irregular tracked-in deposits and broken heel/chair rubs. The marks
		// stay attached to the surface while the camera moves or rotates.
		float deposit = dirt*(.13+edge*.37)+wear.r*.18+abrasion*traffic*.13;
		base *= 1.0-deposit*wear_strength;
		base += finish_colour.rgb*abrasion*traffic*.27*wear_strength;
		ROUGHNESS = clamp(ROUGHNESS+deposit*.28+abrasion*.13,.35,.98);
	}
	ALBEDO = base;
	METALLIC = 0.0;
	vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
	vec3 a = cross(dy,NORMAL), b = cross(NORMAL,dx);
	float determinant = dot(dx,a);
	vec3 gradient = (a*dFdx(relief)+b*dFdy(relief))*sign(determinant)/max(abs(determinant),.00001);
	NORMAL = normalize(NORMAL-gradient*.22);
}
