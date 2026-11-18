shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, fog_disabled, cull_disabled;

uniform float Light_attenuation=1.3;
uniform float Shadow_roundness=1.0;
uniform sampler2D Color_1D_Gradient : source_color, filter_nearest, repeat_disable;
uniform sampler2D Dissolve_Texture : filter_linear, repeat_enable;
uniform bool dissolve_enabled=false;
uniform vec2 Texture_Scale=vec2(.5);
uniform bool particle_age_from_custom=false;
uniform bool gas_field_enabled=false;
uniform sampler3D gas_solids : filter_nearest, repeat_disable;
uniform mat4 world_to_gas;
uniform vec3 gas_minimum;
uniform vec3 gas_extent;
varying float age;
varying float gas_visibility;
varying vec3 smoke_world_position;

void vertex() {
	age=particle_age_from_custom ? INSTANCE_CUSTOM.y : COLOR.g;
	gas_visibility=gas_field_enabled ? COLOR.a : 1.0;
	if (gas_field_enabled) VERTEX*=max(.0001,gas_visibility);
	smoke_world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	if (gas_field_enabled) {
		if (gas_visibility<.005) discard;
		vec3 local=(world_to_gas*vec4(smoke_world_position,1.0)).xyz;
		vec3 uv=(local-gas_minimum)/gas_extent;
		if (any(lessThan(uv,vec3(0.0))) || any(greaterThan(uv,vec3(1.0)))) discard;
		if (texture(gas_solids,uv).r>.5) discard;
	}
	// Keep the exposed inner shell facing away from VIEW in the tutorial's
	// Fresnel calculation; an intact front surface still hides it by depth.
	if (!FRONT_FACING) NORMAL=-NORMAL;
	ALBEDO=vec3(1.0);
	ROUGHNESS=1.0;
	METALLIC=0.0;
	SPECULAR=0.0;
	ALPHA=1.0;
	ALPHA_SCISSOR_THRESHOLD=.001;
	if (dissolve_enabled) {
		ALPHA=texture(Dissolve_Texture,UV*Texture_Scale).r;
		ALPHA_SCISSOR_THRESHOLD=max(.001,min(smoothstep(.2,1.0,age),age*.96));
	}
}

// The supplied tutorial's actual per-fragment light function, unchanged.
void light() {
	if (!gas_field_enabled || LIGHT_IS_DIRECTIONAL) {
	float dot_result=dot(NORMAL,LIGHT);
	float add_some_math=(clamp(dot_result,-.90,.90)+1.0)*.47*Light_attenuation;
	float fresnel=pow(clamp(dot(NORMAL,VIEW),0.0,1.0),Shadow_roundness);
	float round_cell_shade=clamp(add_some_math,.04,.98)*fresnel;
	vec4 color_1D_gradient=texture(Color_1D_Gradient,vec2(round_cell_shade));
	DIFFUSE_LIGHT=clamp(LIGHT_COLOR*vec3(color_1D_gradient.xyz),vec3(0.0),vec3(1.0));
	}
}
