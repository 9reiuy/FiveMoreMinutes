shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
uniform sampler3D source_a : filter_linear, repeat_disable;
uniform sampler3D source_b : filter_linear, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform float source_mix = 0.0;
uniform vec3 volume_size;
uniform mat4 world_to_volume;
uniform float overall_alpha = 1.0;
uniform float fire_envelope = 1.0;
uniform float smoke_envelope = 1.0;
uniform bool comic_enabled = true;

vec3 authored(vec3 rgb) {
	return mix(rgb/12.92,pow((rgb+vec3(.055))/1.055,vec3(2.4)),step(vec3(.04045),rgb));
}
vec2 source_field(vec3 uv) {
	vec2 data=mix(textureLod(source_a,uv,0.0).rg,textureLod(source_b,uv,0.0).rg,source_mix);
	return data*data*vec2(2.0,8.0);
}
vec3 fire_color(float heat) {
	float temp=clamp(heat/2.2,0.0,1.0);
	vec3 orange=authored(vec3(.93,.31,.065));
	vec3 gold=authored(vec3(1.0,.62,.20));
	vec3 core=authored(vec3(1.0,.91,.61))*1.6;
	if (comic_enabled) {
		vec3 paint=mix(orange,gold,smoothstep(.19,.29,temp));
		return mix(paint,core,smoothstep(.56,.66,temp));
	}
	return mix(mix(orange,gold,smoothstep(0.0,.4,temp)),core,smoothstep(.3,1.0,temp));
}
void fragment() {
	vec2 ndc=SCREEN_UV*2.0-1.0;
	vec4 near_view=INV_PROJECTION_MATRIX*vec4(ndc,1.0,1.0);
	vec4 far_view=INV_PROJECTION_MATRIX*vec4(ndc,0.0,1.0);
	vec3 near_world=(INV_VIEW_MATRIX*vec4(near_view.xyz/near_view.w,1.0)).xyz;
	vec3 far_world=(INV_VIEW_MATRIX*vec4(far_view.xyz/far_view.w,1.0)).xyz;
	vec3 ray_world=normalize(far_world-near_world);
	vec3 origin=(world_to_volume*vec4(near_world,1.0)).xyz;
	vec3 ray=(world_to_volume*vec4(ray_world,0.0)).xyz;
	vec3 safe_ray=sign(ray+vec3(.0000001))*max(abs(ray),vec3(.000001));
	vec3 a=(-volume_size*.5-origin)/safe_ray;
	vec3 b=(volume_size*.5-origin)/safe_ray;
	vec3 lower=min(a,b);
	vec3 upper=max(a,b);
	float enter=max(max(lower.x,lower.y),max(lower.z,0.0));
	float leave=min(min(upper.x,upper.y),upper.z);
	float depth=textureLod(scene_depth,SCREEN_UV,0.0).r;
	vec4 opaque_view=INV_PROJECTION_MATRIX*vec4(ndc,depth,1.0);
	vec3 opaque_world=(INV_VIEW_MATRIX*vec4(opaque_view.xyz/opaque_view.w,1.0)).xyz;
	leave=min(leave,dot(opaque_world-near_world,ray_world));
	if (leave<=enter) { discard; }
	float stride=(leave-enter)/64.0;
	float transmission=1.0;
	float fire_weight=0.0;
	float heat_weight=0.0;
	vec3 sum=vec3(0.0);
	vec3 key=normalize(vec3(-.5,.8,.2));
	for (int i=0;i<64;i++) {
		vec3 uv=(origin+ray*(enter+(float(i)+.5)*stride))/volume_size+.5;
		vec2 field=source_field(uv);
		float heat=field.g*fire_envelope;
		float burning=1.0-exp(-heat*1.5);
		float soot=field.r*(1.0-burning*.86)*smoke_envelope;
		if (soot+heat<.004) { continue; }
		float alpha=1.0-exp(-(soot*4.4+burning*1.25)*stride);
		float obscured=source_field(clamp(uv+key*.08,vec3(0.0),vec3(1.0))).r;
		float light=.18+.82*exp(-obscured*3.8);
		vec3 smoke=authored(vec3(.29,.30,.30))*light;
		// Source heat lights adjacent soot; there is no normal-mapped shell.
		smoke+=authored(vec3(.65,.30,.08))*min(heat,.25)*.5;
		float fiery=burning/(burning+soot*5.0+.001);
		vec3 flame=fire_color(heat);
		float weight=transmission*alpha;
		sum+=mix(smoke,flame,fiery)*weight;
		sum+=flame*transmission*heat*stride*.09;
		fire_weight+=weight*fiery;
		heat_weight+=weight*heat*fiery;
		transmission*=1.0-alpha;
		if (transmission<.012) { break; }
	}
	float opacity=1.0-transmission;
	if (opacity<.006) { discard; }
	vec3 color=sum/max(opacity,.001);
	float fiery=clamp(fire_weight/max(opacity,.001),0.0,1.0);
	if (comic_enabled) {
		// Grade the integrated moving gas, rather than painting a solid shell.
		float value=dot(color,vec3(.2126,.7152,.0722));
		float aa=max(fwidth(value)*.8,.008);
		vec3 paint=authored(vec3(.56,.18,.045));
		paint=mix(paint,authored(vec3(.96,.37,.09)),smoothstep(.10-aa,.10+aa,value));
		paint=mix(paint,authored(vec3(1.0,.66,.25)),smoothstep(.29-aa,.29+aa,value));
		paint=mix(paint,authored(vec3(1.0,.91,.63))*1.1,smoothstep(.64-aa,.64+aa,value));
		color=mix(color,paint,fiery*.82);
		vec2 grid=vec2(FRAGCOORD.x*.866025-FRAGCOORD.y*.5,FRAGCOORD.x*.5+FRAGCOORD.y*.866025)/4.5;
		float dots=1.0-smoothstep(.13,.20,length(fract(grid)-.5));
		float shadow_screen=1.0-smoothstep(.16,.46,value);
		color*=1.0-dots*((1.0-fiery)*.16+fiery*shadow_screen*.32);
	}
	ALBEDO=color;
	// Keep gas translucency and source erosion. No opaque surface or hull.
	ALPHA=opacity*overall_alpha;
}
