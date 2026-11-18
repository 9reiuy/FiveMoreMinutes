#[compute]
#version 450
layout(local_size_x=4, local_size_y=4, local_size_z=4) in;
layout(set=0,binding=0) uniform sampler3D velocity_in;
layout(rgba32f,set=0,binding=1) uniform writeonly image3D velocity_out;
layout(set=0,binding=2) uniform sampler3D density_in;
layout(r32f,set=0,binding=3) uniform writeonly image3D density_out;
layout(set=0,binding=4) uniform sampler3D pressure_in;
layout(r32f,set=0,binding=5) uniform writeonly image3D pressure_out;
layout(r32f,set=0,binding=6) uniform writeonly image3D divergence_out;
layout(set=0,binding=7) uniform sampler3D solid_field;
struct Impulse { vec4 start_radius; vec4 finish_clear; vec4 velocity_kind; };
layout(std430,set=0,binding=8) readonly buffer Impulses { Impulse items[]; } impulses;
layout(r32f,set=0,binding=9) uniform writeonly image3D visible_density;
layout(set=0,binding=10) uniform sampler3D divergence_in;
layout(push_constant,std430) uniform Options {
	vec4 origin_dt;
	vec4 extent_time;
	vec4 dimensions_pass;
	vec4 controls;
} options;

ivec3 dimensions() { return ivec3(options.dimensions_pass.xyz); }
bool solid(ivec3 p) {
	if (any(lessThan(p,ivec3(0))) || any(greaterThanEqual(p,dimensions()))) return true;
	return texelFetch(solid_field,p,0).r>.5;
}
bool solid_uv(vec3 p) { return solid(ivec3(floor(p*vec3(dimensions())))); }
vec3 velocity_at(ivec3 p) {
	return solid(p) ? vec3(0.0) : texelFetch(velocity_in,p,0).xyz;
}
vec3 backtrace(vec3 uv,vec3 velocity) {
	vec3 goal=uv-velocity*options.origin_dt.w/options.extent_time.xyz;
	vec3 previous=uv;
	for (int k=1;k<=6;k++) {
		vec3 p=mix(uv,goal,float(k)/6.0);
		if (solid_uv(p)) return previous;
		previous=p;
	}
	return goal;
}
// A smooth vector potential. Its curl adds divergence-free small-scale flow.
vec3 potential(vec3 p) {
	float time=options.extent_time.w*.24;
	return vec3(
		sin(p.y*1.7+p.z*.9+time)+.4*sin(p.x*2.3-p.z*1.8-time),
		sin(p.z*1.4+p.x*.8-time)+.4*sin(p.y*2.1-p.x*1.6+time),
		sin(p.x*1.6+p.y*.7+time)+.4*sin(p.z*2.2-p.y*1.7-time));
}
vec3 curl_flow(vec3 p) {
	float h=.08;
	vec3 dx=(potential(p+vec3(h,0,0))-potential(p-vec3(h,0,0)))/(2.0*h);
	vec3 dy=(potential(p+vec3(0,h,0))-potential(p-vec3(0,h,0)))/(2.0*h);
	vec3 dz=(potential(p+vec3(0,0,h))-potential(p-vec3(0,0,h)))/(2.0*h);
	return vec3(dy.z-dz.y,dz.x-dx.z,dx.y-dy.x);
}
float impulse_weight(vec3 p,Impulse event) {
	vec3 segment=event.finish_clear.xyz-event.start_radius.xyz;
	float along=clamp(dot(p-event.start_radius.xyz,segment)/max(dot(segment,segment),.00001),0.0,1.0);
	vec3 offset=p-event.start_radius.xyz-segment*along;
	// Body wakes act across torso height. A knee-height sphere was covered by
	// the undisturbed layer above it in the overhead Camera.
	offset.y*=event.velocity_kind.w>1.5 ? .35 : .45;
	float radius=event.start_radius.w;
	return exp(-dot(offset,offset)*2.0/(radius*radius));
}
float noise_hash(vec3 p) {
	p=fract(p*.1031);
	p+=dot(p,p.yzx+33.33);
	return fract((p.x+p.y)*p.z);
}
float density_noise(vec3 p) {
	vec3 cell=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(mix(noise_hash(cell),noise_hash(cell+vec3(1,0,0)),f.x),
		mix(noise_hash(cell+vec3(0,1,0)),noise_hash(cell+vec3(1,1,0)),f.x),f.y),
		mix(mix(noise_hash(cell+vec3(0,0,1)),noise_hash(cell+vec3(1,0,1)),f.x),
		mix(noise_hash(cell+vec3(0,1,1)),noise_hash(cell+vec3(1,1,1)),f.x),f.y),f.z);
}
float seed_density(vec3 p) {
	// Seed a lumpy mass into the simulated field, then advect those features
	// with the gas. No camera-space noise or independently sliding texture.
	vec3 q=p+vec3(density_noise(p*.8),density_noise(p*.8+17.1),density_noise(p*.8+39.7))*.8-.4;
	vec3 a=(q-vec3(.42,.34,.49)*options.extent_time.xyz)/vec3(2.6,1.02,2.1);
	vec3 b=(q-vec3(.64,.42,.47)*options.extent_time.xyz)/vec3(2.0,1.08,2.2);
	vec3 c=(q-vec3(.35,.29,.64)*options.extent_time.xyz)/vec3(1.7,.88,1.8);
	float shape=exp(-dot(a,a)*1.4)+.8*exp(-dot(b,b)*1.6)+.6*exp(-dot(c,c)*1.6);
	float detail=.35+.95*density_noise(p*1.65)+.2*density_noise(p*3.3);
	return max(0.0,shape*detail-.12);
}
void main() {
	ivec3 p=ivec3(gl_GlobalInvocationID);
	ivec3 n=dimensions();
	if (any(greaterThanEqual(p,n))) return;
	vec3 uv=(vec3(p)+.5)/vec3(n);
	vec3 spacing=options.extent_time.xyz/vec3(n);
	vec3 local=uv*options.extent_time.xyz;
	vec3 world=options.origin_dt.xyz+local;
	float dt=options.origin_dt.w;
	int stage=int(options.dimensions_pass.w);
	bool blocked=solid(p);
	if (stage==0) {
		float density=blocked ? 0.0 : seed_density(local)*2.25;
		imageStore(density_out,p,vec4(density));
		imageStore(visible_density,p,vec4(density));
		return;
	}
	if (stage==1) {
		vec3 velocity=vec3(0.0);
		if (!blocked) {
			vec3 old=texelFetch(velocity_in,p,0).xyz;
			velocity=textureLod(velocity_in,backtrace(uv,old),0.0).xyz*exp(-dt*1.8);
			velocity+=curl_flow(local)*(options.controls.z*dt);
			velocity.y+=texelFetch(density_in,p,0).r*options.controls.w*dt;
			for (int i=0;i<int(options.controls.x);i++)
				velocity+=impulses.items[i].velocity_kind.xyz*impulse_weight(world,impulses.items[i]);
			velocity=clamp(velocity,vec3(-12.0),vec3(12.0));
		}
		imageStore(velocity_out,p,vec4(velocity,0));
		return;
	}
	if (stage==2) {
		float divergence=0.0;
		if (!blocked) {
			divergence=(velocity_at(p+ivec3(1,0,0)).x-velocity_at(p-ivec3(1,0,0)).x)/(2.0*spacing.x)
				+(velocity_at(p+ivec3(0,1,0)).y-velocity_at(p-ivec3(0,1,0)).y)/(2.0*spacing.y)
				+(velocity_at(p+ivec3(0,0,1)).z-velocity_at(p-ivec3(0,0,1)).z)/(2.0*spacing.z);
		}
		imageStore(divergence_out,p,vec4(divergence));
		return;
	}
	ivec3 directions[6]=ivec3[6](ivec3(1,0,0),ivec3(-1,0,0),ivec3(0,1,0),ivec3(0,-1,0),ivec3(0,0,1),ivec3(0,0,-1));
	float weights[6]=float[6](1.0/(spacing.x*spacing.x),1.0/(spacing.x*spacing.x),
		1.0/(spacing.y*spacing.y),1.0/(spacing.y*spacing.y),1.0/(spacing.z*spacing.z),1.0/(spacing.z*spacing.z));
	if (stage==3) {
		float sum=0.0,denominator=0.0;
		if (!blocked) {
			for (int i=0;i<6;i++) {
				ivec3 neighbor=p+directions[i];
				if (!solid(neighbor)) {
					sum+=texelFetch(pressure_in,neighbor,0).r*weights[i];
					denominator+=weights[i];
				}
			}
		}
		float pressure=blocked ? 0.0 : (sum-texelFetch(divergence_in,p,0).r)/max(denominator,.00001);
		imageStore(pressure_out,p,vec4(clamp(pressure,-40.0,40.0)));
		return;
	}
	if (stage==4) {
		vec3 velocity=vec3(0.0);
		if (!blocked) {
			float center=texelFetch(pressure_in,p,0).r;
			float pressures[6];
			for (int i=0;i<6;i++)
				pressures[i]=solid(p+directions[i]) ? center : texelFetch(pressure_in,p+directions[i],0).r;
			vec3 gradient=vec3(pressures[0]-pressures[1],pressures[2]-pressures[3],pressures[4]-pressures[5])/(2.0*spacing);
			velocity=texelFetch(velocity_in,p,0).xyz-gradient;
			for (int i=0;i<3;i++) {
				if ((solid(p+directions[i*2]) && velocity[i]>0.0)
					|| (solid(p+directions[i*2+1]) && velocity[i]<0.0)) velocity[i]=0.0;
			}
		}
		imageStore(velocity_out,p,vec4(velocity,0));
		return;
	}
	if (stage==5) {
		float density=0.0;
		if (!blocked) {
			vec3 velocity=texelFetch(velocity_in,p,0).xyz;
			density=textureLod(density_in,backtrace(uv,velocity),0.0).r;
			float center=texelFetch(density_in,p,0).r;
			float mixing=0.0;
			for (int i=0;i<6;i++) {
				if (!solid(p+directions[i]))
					mixing+=(texelFetch(density_in,p+directions[i],0).r-center)*weights[i];
			}
			// Low diffusion mixes the cleared lane back into the surrounding smoke.
			density=max(0.0,density+mixing*(.035*dt));
			if (options.controls.y<.5) density*=exp(-dt*.055);
			for (int i=0;i<int(options.controls.x);i++)
				density*=exp(-impulses.items[i].finish_clear.w*impulse_weight(world,impulses.items[i]));
			// A bounded resting cloud, not a continuously accumulating smoke source.
			// Restores displaced density gradually; quiet cells remain near equilibrium.
			density=mix(density,seed_density(local)*2.25,(1.0-exp(-dt*.14))*options.controls.y);
		}
		density=clamp(density,0.0,3.0);
		imageStore(density_out,p,vec4(density));
		imageStore(visible_density,p,vec4(density));
	}
}
