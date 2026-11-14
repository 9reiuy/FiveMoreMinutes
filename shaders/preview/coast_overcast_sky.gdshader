shader_type canvas_item;
render_mode unshaded;
uniform float scene_time=0.0;
uniform float moon_visibility=1.0;
uniform float reveal=1.0;
uniform float horizon_y=0.6;
uniform mat4 sky_inverse_projection=mat4(1.0);
uniform mat4 sky_camera_to_world=mat4(1.0);
uniform vec3 moon_direction=vec3(0.4,0.18,-1.0);
uniform vec3 zenith_tint : source_color = vec3(0.035,0.070,0.085);
uniform vec3 middle_sky_tint : source_color = vec3(0.070,0.125,0.145);
uniform vec3 horizon_tint : source_color = vec3(0.13,0.21,0.23);
uniform sampler2D cloud_panorama : filter_linear_mipmap, repeat_enable;
uniform float clouded_sky_gain : hint_range(0.0,1.0)=0.78;
void fragment(){
	vec4 ray=sky_inverse_projection*vec4(UV.x*2.0-1.0,1.0-UV.y*2.0,1.0,1.0);
	vec3 direction=normalize(mat3(sky_camera_to_world)*(ray.xyz/ray.w));
	float elevation=smoothstep(0.0,0.46,max(0.0,direction.y));
	vec3 sky=mix(horizon_tint,middle_sky_tint,smoothstep(0.0,0.25,elevation));
	sky=mix(sky,zenith_tint,smoothstep(0.2,1.0,elevation));
	vec2 uv=vec2(atan(direction.z,direction.x)/6.2831853+0.5+scene_time*0.000025,acos(clamp(direction.y,-1.0,1.0))/3.14159265);
	vec3 photograph=texture(cloud_panorama,uv).rgb;
	float luminance=dot(photograph,vec3(0.2126,0.7152,0.0722));
	float cloud_value=clamp((luminance-0.12)/0.55,0.0,1.0);
	sky*=mix(0.32,1.45,cloud_value);
	sky*=mix(clouded_sky_gain,1.0,moon_visibility);
	COLOR=vec4(sky*reveal,1.0);
}
