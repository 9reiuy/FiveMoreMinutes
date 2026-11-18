// User-supplied Stylized Smokes tutorial: local preview only.
uniform sampler3D gas_density : filter_linear, repeat_disable;
uniform sampler3D gas_velocity : filter_linear, repeat_disable;
uniform mat4 gas_world_to_local;
uniform vec3 gas_minimum;
uniform vec3 gas_extent;
uniform bool gas_field_enabled=true;
uniform sampler2D marble_noise : filter_nearest, repeat_enable;
uniform sampler2D cell_noise : filter_nearest, repeat_enable;
uniform sampler2D detail_noise : filter_nearest, repeat_enable;
uniform float smoke_clock=0.0;
uniform float outline_width=0.0;
uniform vec4 style_light_sources[4]; // xyz: world position or direction; w: point light.
uniform int style_light_count=0;
uniform float Light_attenuation=1.3;
uniform float Shadow_roundness=1.0;
uniform bool age_dissolve_enabled=false;
varying vec3 smoke_local_point;
varying float smoke_age;
varying vec3 style_direction0;
varying vec3 style_direction1;
varying vec3 style_direction2;
varying vec3 style_direction3;

float gas_at(vec3 point) {
	vec3 uv=(point-gas_minimum)/gas_extent;
	if (any(lessThan(uv,vec3(0.0))) || any(greaterThan(uv,vec3(1.0)))) return 0.0;
	return max(0.0,textureLod(gas_density,uv,0.0).r);
}

void vertex() {
	float seed=COLOR.r*13.7;
	vec3 center_world=MODEL_MATRIX[3].xyz;
	vec3 directions[4];
	for (int i=0;i<4;i++) {
		vec3 world_direction=style_light_sources[i].w>.5 ? style_light_sources[i].xyz-center_world : style_light_sources[i].xyz;
		if (length(world_direction)<.001) world_direction=vec3(.4,.8,.6);
		directions[i]=normalize((VIEW_MATRIX*vec4(world_direction,0.0)).xyz);
	}
	style_direction0=directions[0];
	style_direction1=directions[1];
	style_direction2=directions[2];
	style_direction3=directions[3];
	vec3 p=VERTEX;
	vec3 blend=abs(NORMAL);
	blend/=max(.001,blend.x+blend.y+blend.z);
	vec3 q=p*.65+vec3(seed,seed*.37,seed*.71);
	vec2 scroll=vec2(smoke_clock*.018,-smoke_clock*.025);
	float cell=textureLod(cell_noise,q.yz+scroll,0.0).r*blend.x
		+textureLod(cell_noise,q.xz+scroll,0.0).r*blend.y
		+textureLod(cell_noise,q.xy+scroll,0.0).r*blend.z;
	float detail=textureLod(detail_noise,q.xz*.7-scroll*.55,0.0).r;
	float marble=textureLod(marble_noise,q.xy*.7+scroll*.65,0.0).r;
	VERTEX+=NORMAL*((cell-.73)*.13+(detail-.5)*.035+(marble-.5)*.02);
	smoke_local_point=p+vec3(seed);
	smoke_age=COLOR.g;
	float scale=COLOR.a;
	vec3 world_drift=vec3(0.0);
	if (gas_field_enabled) {
		vec3 center=(gas_world_to_local*MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
		vec3 uv=(center-gas_minimum)/gas_extent;
		vec3 drift=textureLod(gas_velocity,clamp(uv,vec3(0.0),vec3(1.0)),0.0).xyz*.12;
		drift*=min(1.0,.65/max(.001,length(drift)));
		scale*=smoothstep(.025,.45,gas_at(center+drift));
		world_drift=(inverse(gas_world_to_local)*vec4(drift,0.0)).xyz;
	}
	// Keep the supplied lighting/Fresnel recipe on contour WIDTH only.
	// It never paints a shade or a transition inside the white smoke.
	vec3 normal_view=normalize(transpose(inverse(mat3(VIEW_MATRIX*MODEL_MATRIX)))*NORMAL);
	vec3 view_direction=normalize(-(VIEW_MATRIX*MODEL_MATRIX*vec4(VERTEX,1.0)).xyz);
	float dot_result=dot(normal_view,directions[0]);
	float add_some_math=(clamp(dot_result,-.90,.90)+1.0)*.47*Light_attenuation;
	float fresnel=pow(clamp(dot(normal_view,view_direction),0.0,1.0),Shadow_roundness);
	float round_cell_shade=clamp(add_some_math,.04,.98)*fresnel;
	float width=outline_width*mix(.9,1.1,round_cell_shade);
	VERTEX=(VERTEX+NORMAL*width)*scale;
	VERTEX+=(inverse(MODEL_MATRIX)*vec4(world_drift,0.0)).xyz;
}

bool dissolved_fragment() {
	if (!age_dissolve_enabled || smoke_age<.58) return false;
	// The supplied tutorial noises cut hard-edged fragments out of old puffs.
	// They never tint the body or multiply it by a soft alpha gradient.
	vec3 q=smoke_local_point*.28;
	vec2 scroll=vec2(smoke_clock*.025,-smoke_clock*.018);
	float marble=texture(marble_noise,q.xy+scroll).r;
	float detail=texture(detail_noise,q.yz-scroll*.6).r;
	float sample_value=marble*.15+detail*.85;
	float threshold=smoothstep(.58,1.0,smoke_age)*.92;
	return sample_value<threshold;
}
