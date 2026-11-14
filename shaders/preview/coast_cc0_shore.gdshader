shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
#include "res://shaders/preview/coast_shape.gdshaderinc"
uniform float scene_time = 0.0;
uniform float moon_visibility = 1.0;
uniform sampler2D rock_colour : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 shore_tint : source_color = vec3(0.47,0.55,0.57);
uniform float normal_strength : hint_range(0.0,1.0) = 0.62;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	vec3 w = normalize(world_normal);
	vec3 blend = pow(abs(w),vec3(4.0));
	blend /= max(dot(blend,vec3(1.0)),0.0001);
	vec3 p = world_position/28.0;
	vec3 colour = texture(rock_colour,p.zy).rgb*blend.x+texture(rock_colour,p.xz).rgb*blend.y+texture(rock_colour,p.xy).rgb*blend.z;
	vec3 nx = texture(rock_normal,p.zy).xyz*2.0-1.0;
	vec3 ny = texture(rock_normal,p.xz).xyz*2.0-1.0;
	vec3 nz = texture(rock_normal,p.xy).xyz*2.0-1.0;
	vec3 mapped = vec3(nx.z*sign(w.x),nx.y,nx.x)*blend.x+vec3(ny.x,ny.z*sign(w.y),ny.y)*blend.y+vec3(nz.x,nz.y,nz.z*sign(w.z))*blend.z;
	NORMAL = normalize(mat3(VIEW_MATRIX)*normalize(mix(w,mapped,normal_strength)));
	float rough = texture(rock_roughness,p.zy).g*blend.x+texture(rock_roughness,p.xz).g*blend.y+texture(rock_roughness,p.xy).g*blend.z;
	float wet = (1.0-smoothstep(0.1,1.3,world_position.y))*(1.0-smoothstep(0.5,3.0,-coast_distance(world_position.xz)));
	ALBEDO = colour*shore_tint*mix(vec3(1.0),vec3(0.69,0.58,0.65),wet);
	EMISSION = ALBEDO*0.018;
	ROUGHNESS = mix(0.75,0.98,rough);
	SPECULAR = 0.0;
}
