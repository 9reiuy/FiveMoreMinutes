shader_type spatial;
render_mode cull_back, diffuse_burley, specular_disabled, shadows_disabled;
uniform sampler2D cloud_noise : repeat_enable, filter_nearest;
uniform sampler2D heat_noise : repeat_enable, filter_nearest;
uniform sampler2D dissolve_noise : repeat_enable, filter_nearest;
uniform float age = 0.0;
varying vec4 particle;
varying vec3 cloud_point;

void vertex() {
	particle = INSTANCE_CUSTOM;
	float t = max(0.0, age - particle.z);
	vec2 offset = vec2(particle.x * 2.1, particle.x * 5.3);
	vec3 p = VERTEX;
	vec2 flow = offset + vec2(0.0, -t * .22);
	float n = (textureLod(cloud_noise, p.xy * .4 + flow, 0.0).r + textureLod(cloud_noise, p.yz * .4 + flow, 0.0).r + textureLod(cloud_noise, p.zx * .4 + flow, 0.0).r) / 3.0;
	if (particle.w < 1.5) { VERTEX += NORMAL * (n - .42) * (particle.w > .5 ? 1.5 : 1.1); }
	cloud_point = VERTEX;
}

void fragment() {
	float t = max(0.0, age - particle.z);
	bool plume = particle.w > .5;
	bool tip = particle.w > 1.5;
	vec2 offset = vec2(particle.x * 2.1, particle.x * 5.3);
	vec2 flow = offset + vec2(0.0, -t * .14);
	float soot_noise = texture(cloud_noise, cloud_point.xy * .30 + flow).r;
	float n = texture(heat_noise, cloud_point.xy * .32 + flow).r * .65 + texture(heat_noise, cloud_point.zy * .32 + flow).r * .35;
	// The tutorial's emission is a smooth moving threshold, not fine lava grain.
	float clock = t + (plume ? (1.0 - particle.y) * .20 : 0.0);
	float amount = .10 + 1.10 * smoothstep(.08, .90, clock);
	float field = n - cloud_point.y * (plume ? .75 : 1.0);
	float thermal = smoothstep(amount, amount + .20, field);
	thermal *= 1.0 - smoothstep(.72, .94, clock);
	if (tip) { thermal = 1.0; }
	vec3 soot = mix(vec3(.065, .060, .045), vec3(.19, .17, .13), smoothstep(.20, .70, soot_noise));
	vec3 warm = mix(vec3(1.0, .20, .008), vec3(1.0, .77, .16), thermal);
	ALBEDO = mix(soot, warm, thermal);
	EMISSION = vec3(1.0, .30, .002) * (20.0 * thermal * thermal) + soot * .28;
	ROUGHNESS = 1.0;
	float dissolve = smoothstep(plume ? .87 : .78, plume ? 1.34 : 1.20, t);
	float erode = texture(dissolve_noise, cloud_point.xy * .38 + offset).r;
	float shape = smoothstep(dissolve, dissolve + .055, erode);
	if (tip) { shape = 1.0 - smoothstep(1.17, 1.50, age); }
	ALPHA = age >= particle.z ? shape : 0.0;
	ALPHA_SCISSOR_THRESHOLD = .45;
}
