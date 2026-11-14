shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D finish_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D finish_normal : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D finish_roughness : filter_nearest_mipmap, repeat_enable;
uniform sampler2D finish_metalness : filter_nearest_mipmap, repeat_enable;
uniform vec4 finish_colour : source_color = vec4(1.0);
uniform vec2 repeat_metres = vec2(1.0);
uniform vec2 roughness_range = vec2(.3,.6);
uniform float normal_strength = .2;
uniform float metallic_level = 0.0;
uniform float specular_level = .5;
uniform float albedo_contrast = 1.0;
uniform vec3 albedo_midpoint = vec3(.65);
uniform float anisotropy_strength = 0.0;
uniform float wear_amount = .6;
uniform float furniture_age = 0.;
uniform vec3 exposed_substrate = vec3(.025,.018,.010);
uniform float handling_marks = 0.;
uniform bool object_space_finish = false;
instance uniform vec3 wear_bounds_center = vec3(0.0);
instance uniform vec3 wear_bounds_half = vec3(.5);
#include "res://shaders/dream3d/reception_wear.gdshaderinc"
varying vec3 point_world;
varying vec3 normal_world;
varying vec3 point_local;
varying vec3 normal_local;
void vertex(){
	point_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	normal_world=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	point_local=VERTEX;normal_local=NORMAL;
}
void fragment(){
	// Complete source maps, with a stable physical sampling scale for the game.
	vec3 mapped_position = object_space_finish ? point_local : point_world;
	vec3 n = abs(object_space_finish ? normal_local : normal_world);
	vec2 point = mapped_position.xz;
	if(n.y<.65){point=n.x>n.z?mapped_position.zy:mapped_position.xy;}
	vec2 raw_uv=point/repeat_metres;
	vec2 uv=(floor(point*32.0)+.5)/(32.0*repeat_metres);
	vec2 dx=dFdx(raw_uv);vec2 dy=dFdy(raw_uv);
	vec3 photo=textureGrad(finish_albedo,uv,dx,dy).rgb;
	vec3 edge_distance=max(wear_bounds_half-abs(point_local-wear_bounds_center),vec3(0.));
	vec3 local_n=abs(normal_local);
	vec2 face_edges=local_n.y>.65?edge_distance.xz:local_n.x>local_n.z?edge_distance.zy:edge_distance.xy;
	float edge=1.-smoothstep(.012,.055,min(face_edges.x,face_edges.y));
	float lower_edge=1.-smoothstep(.03,.15,point_local.y-wear_bounds_center.y+wear_bounds_half.y);
	float handling=n.y>.65?.75:.32;
	vec3 wear=reception_wear(point,lower_edge,handling)*wear_amount;
	float edge_rub=edge*smoothstep(.48,.79,reception_noise(point*5.3+7.))*wear_amount;
	vec3 substrate=clamp(mix(albedo_midpoint,photo,albedo_contrast),vec3(0.0),vec3(1.0));
	substrate*=1.-wear.r*.22-wear.g*.23+wear.b*.035;
	substrate=mix(substrate,substrate*1.12,edge_rub*.30);
	// Furniture-specific finish wear. The floor/wall layer and unrelated
	// metal fittings keep their own existing settings.
	vec2 age_point=(floor(point*32.)+.5)/32.;
	float chips=edge*smoothstep(.42,.78,reception_noise(age_point*9.4+3.1))*furniture_age*wear_amount;
	float scratches=reception_scuff(age_point+vec2(3.8,9.2))*handling*furniture_age*wear_amount;
	vec2 touch_local=(point_local.xz-wear_bounds_center.xz)/max(wear_bounds_half.xz,vec2(.01));
	float touch=exp(-dot(touch_local,touch_local)*1.8)*step(.65,n.y)*handling_marks;
	touch*=.45+.55*reception_noise(age_point*7.3+11.);
	substrate*=1.-scratches*.30;
	substrate=mix(substrate,substrate*1.3+exposed_substrate,chips*.55);
	substrate*=1.-touch*.055;
	ALBEDO=substrate*finish_colour.rgb;
	float source_roughness=textureGrad(finish_roughness,uv,dx,dy).r;
	// Metro keeps the original map variation inside a surface-finish range.
	ROUGHNESS=clamp(mix(roughness_range.x,roughness_range.y,source_roughness)+wear.r*.12+wear.g*.12-edge_rub*.045+scratches*.17+chips*.12-touch*.10,.18,.95);
	METALLIC=metallic_level*textureGrad(finish_metalness,uv,dx,dy).r;
	SPECULAR=specular_level;
	ANISOTROPY=anisotropy_strength;ANISOTROPY_FLOW=vec2(0.0,1.0);
	vec3 map_n=textureGrad(finish_normal,uv,dx,dy).rgb*2.0-1.0;
	vec3 dp1=dFdx(VERTEX);vec3 dp2=dFdy(VERTEX);
	vec3 p2=cross(dp2,NORMAL);vec3 p1=cross(NORMAL,dp1);
	vec3 t=p2*dx.x+p1*dy.x;vec3 b=p2*dx.y+p1*dy.y;
	float scale=inversesqrt(max(max(dot(t,t),dot(b,b)),.000001));
	NORMAL=normalize(NORMAL*max(map_n.z,.5)+(t*map_n.x+b*map_n.y)*scale*normal_strength);
}
