shader_type spatial;
// Bounded air scattering for Compatibility. Surface illumination/shadows are
// provided by the real SpotLight3D. This mesh never paints a light onto a floor.
render_mode unshaded, blend_add, cull_front, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 light_tint : source_color = vec4(1.0);
uniform float beam_length = 6.0;
uniform float visible_length = 6.0;
uniform float cone_tangent = 0.364;
uniform float density = 0.03;
varying vec3 local_surface;
void vertex() { local_surface = VERTEX; }
void fragment() {
	mat4 world_to_local = inverse(MODEL_MATRIX);
	vec3 origin = (world_to_local * vec4(CAMERA_POSITION_WORLD,1.0)).xyz;
	vec3 direction = normalize(local_surface-origin);
	vec3 half_box = vec3(beam_length*cone_tangent,beam_length*cone_tangent,beam_length*0.5);
	vec3 a = (-half_box-origin)/(direction+vec3(0.000001));
	vec3 b = (half_box-origin)/(direction+vec3(0.000001));
	vec3 lower = min(a,b), upper = max(a,b);
	float enter = max(max(lower.x,lower.y),lower.z);
	float leave = min(min(upper.x,upper.y),upper.z);
	float depth = texture(scene_depth,SCREEN_UV).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV,depth)*2.0-1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV*2.0-1.0,depth);
	#endif
	vec4 depth_world = INV_VIEW_MATRIX*INV_PROJECTION_MATRIX*vec4(ndc,1.0);
	vec3 opaque = (world_to_local*vec4(depth_world.xyz/depth_world.w,1.0)).xyz;
	leave = min(leave,dot(opaque-origin,direction));
	enter = max(enter,0.0);
	float step_length = max(leave-enter,0.0)/8.0;
	float scattering = 0.0;
	for (int i=0; i<8; i++) {
		vec3 point = origin+direction*(enter+(float(i)+0.5)*step_length);
		float along = beam_length*0.5-point.z;
		float radius = max(0.025,along*cone_tangent);
		float edge = 1.0-smoothstep(0.12,1.0,length(point.xy)/radius);
		float ends = smoothstep(0.0,0.10,along)*(1.0-smoothstep(max(visible_length-0.4,0.0),visible_length,along));
		scattering += edge*ends*step_length/(1.0+along*along*0.12);
	}
	ALBEDO = light_tint.rgb;
	ALPHA = clamp(scattering*density,0.0,0.14);
}
