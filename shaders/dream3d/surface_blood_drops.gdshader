shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform sampler2D frames : filter_nearest, repeat_disable;
uniform vec4 large_colour : source_color = vec4(.8745,.4549,.1176,1.0);
varying float age;
varying float large_drop;
void vertex() { age = INSTANCE_CUSTOM.r; large_drop = INSTANCE_CUSTOM.g; }
void fragment() {
	vec2 uv = vec2((UV.x + floor(min(age,.999)*5.0))/5.0,(UV.y+large_drop)*.5);
	float mask = texture(frames,uv).a;
	ALPHA = mask;
	ALPHA_SCISSOR_THRESHOLD = .1;
	ALBEDO = mix(vec3(.8745,.4549,.1176),large_colour.rgb,large_drop);
	ROUGHNESS = .9;
	EMISSION = ALBEDO*.42;
}
