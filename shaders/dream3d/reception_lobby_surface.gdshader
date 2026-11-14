shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D surface_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D surface_normal : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D surface_roughness : filter_nearest_mipmap, repeat_enable;
uniform vec4 surface_colour : source_color = vec4(.75,.75,.75,1.0);
// 0: polished stone floor/counter, 1: stone cladding, 2: walnut veneer.
uniform int surface_kind : hint_range(0,2) = 0;
uniform vec2 tile_metres = vec2(2.0);
uniform float wear_amount=.7;
instance uniform float surface_floor_y=0.;
#include "res://shaders/dream3d/reception_wear.gdshaderinc"
varying vec3 surface_world;
varying vec3 normal_world;
void vertex(){
	surface_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	normal_world=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
	vec3 n=abs(normal_world);vec2 point=surface_world.xz;
	if(n.y<.65){point=n.x>n.z?surface_world.zy:surface_world.xy;}
	vec2 raw_uv=point/tile_metres;
	vec2 uv=(floor(point*32.0)+.5)/(32.0*tile_metres);
	vec2 dx=dFdx(raw_uv);vec2 dy=dFdy(raw_uv);
	vec3 photo=textureGrad(surface_albedo,uv,dx,dy).rgb;
	// Cladding keeps the source stone's fine detail under a calm honed finish.
	if(surface_kind==1){photo=mix(vec3(.65),photo,.22+.16*wear_amount);}
	float edge=0.;float traffic=.4;
	float local_y=max(surface_world.y-surface_floor_y,0.);
	if(surface_kind==0 && n.y>.65){
		vec2 floor_p=surface_world.xz;
		float boundary=min(min(floor_p.x+.5,23.5-floor_p.x),20.5-floor_p.y);
		if(floor_p.y<=10.5){boundary=min(min(floor_p.x-5.5,18.5-floor_p.x),floor_p.y+.5);}
		else if(floor_p.x<5.5||floor_p.x>18.5){boundary=min(boundary,floor_p.y-10.5);}
		edge=exp(-max(boundary,0.)*5.);
		// Dust also settles around the original counter footprint, not in a
		// uniform film across every tile in the lobby.
		vec2 counter_delta=abs(floor_p-vec2(7.2,16.35))-vec2(3.6,1.8);
		float counter_distance=length(max(counter_delta,vec2(0.)))+min(max(counter_delta.x,counter_delta.y),0.);
		edge=max(edge,exp(-abs(counter_distance)*6.)*.85);
		float row=floor(floor_p.y);vec2 tile_id=vec2(floor(floor_p.x-mod(row,2.)*.36),row);
		photo*=1.+(reception_hash(tile_id+31.)-.5)*.10*wear_amount;
		traffic=max(1.-smoothstep(.7,2.,abs(floor_p.x-12.7)),exp(-pow((floor_p.y-19.1)/1.1,2.))*.8);
	}else if(surface_kind==1){
		edge=exp(-local_y*3.8);traffic=exp(-pow((local_y-.72)/.48,2.));
	}
	vec3 wear=reception_wear(point,edge,traffic)*wear_amount;
	float rubber=0.;
	if(surface_kind==0){
		float walked=smoothstep(.46,.78,reception_noise(point*.9+vec2(8.,22.)))*traffic*wear_amount;
		wear.r+=walked*.16;
		rubber=reception_scuff((floor(point*32.)+.5)/32.*.74+vec2(9.7,3.2))*traffic*wear_amount;
	}
	// Existing stone/wood maps remain the base. Dirt gathers at floor contact;
	// occasional scuffs mostly change the finish rather than drawing bright lines.
	photo*=1.-wear.r*(surface_kind==1?.62:.52)+wear.b*.065;
	photo=mix(photo,photo*1.22,wear.g);
	photo*=1.-rubber*.38;
	if(surface_kind==0){
		// Dirt follows the joints already present in the original stone map.
		float source_value=dot(textureGrad(surface_albedo,uv,dx,dy).rgb,vec3(.333333));
		float joint=smoothstep(.215,.29,source_value);
		photo*=1.-joint*wear.r*.26;
	}
	if(surface_kind==1){
		float streak=smoothstep(.66,.88,reception_noise(vec2(point.x*6.5,point.y*.65)+19.));
		float lower_wall=1.-smoothstep(.25,1.6,local_y);
		photo*=1.-streak*lower_wall*.14*wear_amount-wear.g*lower_wall*.27;
	}
	ALBEDO=photo*surface_colour.rgb;
	float rough=textureGrad(surface_roughness,uv,dx,dy).r;
	float original_roughness=surface_kind==0?clamp(rough,.23,.38):surface_kind==1?.74:clamp(rough,.55,.78);
	ROUGHNESS=clamp(original_roughness+wear.r*.16-wear.g*.11+rubber*.17-traffic*.025*wear_amount,.20,.95);
	SPECULAR=surface_kind==0?.35:.18;METALLIC=0.0;
	// Cotangent frame also supports the batched floor's tangent-free mesh.
	vec3 map_n=textureGrad(surface_normal,uv,dx,dy).rgb*2.0-1.0;
	vec3 dp1=dFdx(VERTEX);vec3 dp2=dFdy(VERTEX);
	vec3 p2=cross(dp2,NORMAL);vec3 p1=cross(NORMAL,dp1);
	vec3 t=p2*dx.x+p1*dy.x;vec3 b=p2*dx.y+p1*dy.y;
	float scale=inversesqrt(max(max(dot(t,t),dot(b,b)),.000001));
	NORMAL=normalize(NORMAL*max(map_n.z,.5)+(t*map_n.x+b*map_n.y)*scale*.10);
}
