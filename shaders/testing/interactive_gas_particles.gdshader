shader_type particles;
render_mode keep_data, disable_velocity, disable_force;

uniform sampler3D gas_density : filter_linear, repeat_disable;
uniform sampler3D gas_velocity : filter_linear, repeat_disable;
uniform sampler3D gas_solids : filter_nearest, repeat_disable;
uniform mat4 gas_to_world;
uniform mat4 world_to_gas;
uniform vec3 gas_minimum;
uniform vec3 gas_extent;
uniform vec3 gas_cell_size;
uniform vec3 spawn_center;
uniform vec3 spawn_half_extent;
uniform vec2 scale_range=vec2(1.20,1.65);
uniform float flow_gain=.8;
uniform float anchor_return=.26;
uniform float reset_generation=1.0;
uniform float model_radius=.58;

float gas_random(inout uint state) {
	state=state*1664525u+1013904223u;
	return float(state & 16777215u)/16777215.0;
}

bool gas_allowed(vec3 point) {
	vec3 uv=(point-gas_minimum)/gas_extent;
	if (any(lessThanEqual(uv,vec3(0.0))) || any(greaterThanEqual(uv,vec3(1.0)))) return false;
	return textureLod(gas_solids,uv,0.0).r<.5;
}

void gas_pose(vec3 point, vec4 custom, inout mat4 pose, inout vec4 color) {
	float size=custom.z;
	float c=cos(custom.x),s=sin(custom.x);
	mat3 rotation=mat3(vec3(c,0.0,-s),vec3(0.0,1.0,0.0),vec3(s,0.0,c));
	mat3 basis=mat3(gas_to_world)*rotation*max(.0001,size);
	pose[0]=vec4(basis[0],0.0);
	pose[1]=vec4(basis[1],0.0);
	pose[2]=vec4(basis[2],0.0);
	pose[3]=gas_to_world*vec4(point,1.0);
	vec3 uv=(point-gas_minimum)/gas_extent;
	float mass=textureLod(gas_density,clamp(uv,vec3(0.0),vec3(1.0)),0.0).r;
	float visibility=smoothstep(.01,.5,mass);
	vec3 margins=min(point-gas_minimum,gas_minimum+gas_extent-point)-gas_cell_size*.55;
	float available=max(0.0,min(margins.x,min(margins.y,margins.z)));
	visibility=min(visibility,clamp(available/max(.001,size*model_radius),0.0,1.0));
	color=vec4(1.0,1.0,1.0,visibility);
}

void gas_initialize(uint index, uint seed, inout vec4 custom, inout vec3 anchor, inout mat4 pose, inout vec4 color) {
	uint state=(index+1u)*747796405u+seed;
	vec3 point=spawn_center;
	bool found=false;
	for (int attempt=0;attempt<16;attempt++) {
		point=spawn_center+(vec3(gas_random(state),gas_random(state),gas_random(state))*2.0-1.0)*spawn_half_extent;
		if (gas_allowed(point)) {found=true;break;}
	}
	// Y is a FIXED erosion shape, not an advancing lifetime. W identifies a
	// deliberate G/reset operation. Keep both across native emission cycles.
	custom=vec4(gas_random(state)*6.283185307,mix(.20,.52,gas_random(state)),mix(scale_range.x,scale_range.y,gas_random(state)),reset_generation);
	anchor=point;
	gas_pose(point,custom,pose,color);
	if (!found) color.a=0.0;
}

void start() {
	// keep_data makes the particle buffer a persistent set of cloud parcels.
	// Native cycle boundaries do not reseed, regrow, rotate or dissolve them.
	if (CUSTOM.w!=reset_generation) gas_initialize(INDEX,RANDOM_SEED,CUSTOM,USERDATA1.xyz,TRANSFORM,COLOR);
	VELOCITY=vec3(0.0);
	ACTIVE=true;
}

void process() {
	if (CUSTOM.w!=reset_generation) gas_initialize(INDEX,RANDOM_SEED,CUSTOM,USERDATA1.xyz,TRANSFORM,COLOR);
	vec3 point=(world_to_gas*TRANSFORM[3]).xyz;
	// Render interpolation also reads VELOCITY, even with disable_velocity.
	// Keep the resting anchor in USERDATA so a quiet parcel cannot jitter.
	vec3 anchor=USERDATA1.xyz;
	VELOCITY=vec3(0.0);
	if (!gas_allowed(point) && gas_allowed(anchor)) point=anchor;
	if (gas_allowed(point)) {
		vec3 uv=(point-gas_minimum)/gas_extent;
		vec3 flow=textureLod(gas_velocity,uv,0.0).xyz;
		// Strong disturbances displace parcels freely. As that flow dies away,
		// a weak restoring drift keeps the finite cloud together.
		float quiet=exp(-length(flow)*5.0);
		vec3 rejoin=(anchor-point)*anchor_return*quiet;
		vec3 displacement=(flow*flow_gain+rejoin)*DELTA;
		float max_step=min(gas_cell_size.x,min(gas_cell_size.y,gas_cell_size.z))*3.0;
		displacement*=min(1.0,max_step/max(.00001,length(displacement)));
		vec3 step=displacement/6.0;
		for (int segment=0;segment<6;segment++) {
			vec3 goal=point+step;
			if (gas_allowed(goal)) point=goal;
			else {
				for (int axis=0;axis<3;axis++) {
					goal=point;
					goal[axis]+=step[axis];
					if (gas_allowed(goal)) point=goal;
				}
			}
		}
		CUSTOM.x+=clamp(flow.x-flow.z,-.4,.4)*DELTA*.05;
		gas_pose(point,CUSTOM,TRANSFORM,COLOR);
	}
	else COLOR.a=0.0;
	ACTIVE=true;
}
