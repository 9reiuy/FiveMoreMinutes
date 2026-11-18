shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

// Ray-integrate the actual 3D simulation at Camera resolution. The previous
// native fog froxels smoothed narrow openings into broad, weak light pools.
uniform sampler3D gas_density : filter_linear, repeat_disable;
uniform sampler3D gas_solids : filter_nearest, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 volume_extent=vec3(14.0,2.8,14.0);
uniform float extinction=2.0;
uniform vec4 light_positions[4]; // Local position, real scene light range.
uniform vec4 light_colors[4]; // Linear light color, real scene light energy.
uniform int light_count=0;
varying mat4 view_to_local;

void vertex() {
	view_to_local=inverse(VIEW_MATRIX*MODEL_MATRIX);
}

bool outside(vec3 uv) {
	return any(lessThan(uv,vec3(0.0))) || any(greaterThan(uv,vec3(1.0)));
}

float density_at(vec3 point) {
	vec3 uv=point/volume_extent+.5;
	if (outside(uv)) return 0.0;
	float value=max(0.0,textureLod(gas_density,uv,0.0).r);
	return value*smoothstep(.015,.14,value);
}

float light_transmittance(vec3 point,vec3 source) {
	vec3 ray=source-point;
	float stride=length(ray)/6.0;
	vec3 direction=ray/max(length(ray),.001)*stride;
	float optical_depth=0.0;
	for (int i=0;i<6;i++) {
		vec3 sample_point=point+direction*(float(i)+.5);
		vec3 uv=sample_point/volume_extent+.5;
		if (outside(uv)) break;
		if (textureLod(gas_solids,uv,0.0).r>.5) return 0.0;
		optical_depth+=density_at(sample_point)*stride;
	}
	return exp(-optical_depth*1.25);
}

vec3 scattering_at(vec3 point) {
	vec3 light=vec3(.16,.19,.23); // Bounded multiple-bounce approximation.
	for (int i=0;i<4;i++) {
		if (i>=light_count) break;
		float distance_to_light=length(light_positions[i].xyz-point);
		float falloff=max(0.0,1.0-distance_to_light/max(.01,light_positions[i].w));
		if (falloff<=0.0) continue;
		light+=light_colors[i].rgb*light_colors[i].w*falloff*falloff*.75
			*light_transmittance(point,light_positions[i].xyz);
	}
	return light*vec3(.88,.93,.98);
}

void fragment() {
	// Reversed-Z Forward+ depth. Reconstructing near and surface positions
	// also supports the lab's orthographic Camera option without a fake slab.
	vec2 ndc=SCREEN_UV*2.0-1.0;
	vec4 near_view=INV_PROJECTION_MATRIX*vec4(ndc,1.0,1.0);
	near_view/=near_view.w;
	vec4 surface_view=INV_PROJECTION_MATRIX*vec4(ndc,texture(scene_depth,SCREEN_UV).r,1.0);
	surface_view/=surface_view.w;
	vec3 origin=(view_to_local*near_view).xyz;
	vec3 surface=(view_to_local*surface_view).xyz;
	vec3 ray=normalize(surface-origin);
	vec3 safe_ray=vec3(abs(ray.x)<.00001 ? .00001 : ray.x,
		abs(ray.y)<.00001 ? .00001 : ray.y,abs(ray.z)<.00001 ? .00001 : ray.z);
	vec3 hit_a=(-volume_extent*.5-origin)/safe_ray;
	vec3 hit_b=(volume_extent*.5-origin)/safe_ray;
	vec3 entry_axis=min(hit_a,hit_b);
	vec3 exit_axis=max(hit_a,hit_b);
	float entry=max(0.0,max(entry_axis.x,max(entry_axis.y,entry_axis.z)));
	float exit=min(length(surface-origin)-.015,min(exit_axis.x,min(exit_axis.y,exit_axis.z)));
	if (exit<=entry) discard;
	float stride=(exit-entry)/40.0;
	float transmittance=1.0;
	vec3 radiance=vec3(0.0);
	for (int i=0;i<40;i++) {
		vec3 point=origin+ray*(entry+(float(i)+.5)*stride);
		float density=density_at(point);
		if (density<.003) continue;
		float alpha=1.0-exp(-density*extinction*stride);
		radiance+=transmittance*alpha*scattering_at(point);
		transmittance*=1.0-alpha;
		if (transmittance<.02) break;
	}
	float opacity=1.0-transmittance;
	if (opacity<.002) discard;
	ALBEDO=radiance/max(opacity,.002);
	ALPHA=opacity;
}
