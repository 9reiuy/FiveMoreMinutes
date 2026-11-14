shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D steel_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D steel_normal : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D steel_roughness : filter_nearest_mipmap, repeat_enable;
uniform sampler2D steel_metallic : filter_nearest_mipmap, repeat_enable;
uniform vec4 steel_colour : source_color = vec4(.90,.94,.98,1.0);
varying vec3 local_point;
void vertex(){local_point=VERTEX;}
void fragment(){
	// Rotate the source grain vertically and keep it on the sliding panel.
	vec2 point=vec2(local_point.y,-local_point.x);
	vec2 uv=(floor(point*32.0)+.5)/32.0;
	vec2 dx=dFdx(point);vec2 dy=dFdy(point);
	ALBEDO=textureGrad(steel_albedo,uv,dx,dy).rgb*steel_colour.rgb;
	vec3 source_normal=textureGrad(steel_normal,uv,dx,dy).rgb*2.0-1.0;
	NORMAL_MAP=vec3(-source_normal.y,source_normal.x,source_normal.z)*.5+.5;
	NORMAL_MAP_DEPTH=.15;
	METALLIC=textureGrad(steel_metallic,uv,dx,dy).r;
	ROUGHNESS=clamp(textureGrad(steel_roughness,uv,dx,dy).r*.8,.20,.42);
	SPECULAR=.5;ANISOTROPY=.55;ANISOTROPY_FLOW=vec2(0.0,1.0);
}
