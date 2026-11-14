shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D wall_colour : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wall_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 body_tint : source_color = vec3(0.38,0.47,0.49);
uniform float bay_width = 4.0;
uniform float floor_height = 4.8;
uniform float phase = 0.0;
uniform float normal_strength : hint_range(0.0,1.0) = 0.55;
varying vec3 world_position;
varying vec3 world_normal;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
	vec3 w=normalize(world_normal);
	float axis=mix(world_position.x,world_position.z,step(abs(w.z),abs(w.x)));
	vec2 p=vec2(axis,world_position.y);
	vec3 finish=texture(wall_colour,p*0.25).rgb;
	vec3 relief=texture(wall_normal,p*0.25).xyz*2.0-1.0;
	vec3 tangent=abs(w.x)>abs(w.z)?vec3(0.0,0.0,1.0):vec3(1.0,0.0,0.0);
	vec3 shaped=normalize(mix(w,normalize(w*relief.z+tangent*relief.x+vec3(0.0,1.0,0.0)*relief.y),normal_strength));
	NORMAL=normalize(mat3(VIEW_MATRIX)*shaped);
	vec2 bay=p/vec2(bay_width,floor_height)+vec2(phase,0.0);
	vec2 f=fract(bay);
	vec2 cell=floor(bay);
	float vertical=1.0-smoothstep(0.1,0.4,abs(w.y));
	float panel=step(0.18,f.x)*(1.0-step(0.81,f.x))*step(0.30,f.y)*(1.0-step(0.79,f.y))*vertical;
	float lit=step(0.83,hash(cell+phase*19.1));
	float slat=step(0.12,fract(f.y*17.0));
	vec3 cold=vec3(0.13,0.21,0.23);
	vec3 warm=vec3(0.28,0.21,0.14);
	vec3 light=mix(cold,warm,step(0.87,hash(cell+17.0)));
	float distance_fade=1.0-smoothstep(650.0,1700.0,distance(world_position,CAMERA_POSITION_WORLD));
	ALBEDO=finish*body_tint*mix(vec3(1.0),vec3(0.22,0.29,0.32),panel);
	EMISSION=light*panel*lit*slat*0.33*distance_fade;
	ROUGHNESS=0.95;
	SPECULAR=0.0;
}
