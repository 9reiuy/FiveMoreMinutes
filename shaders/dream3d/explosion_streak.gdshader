shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform sampler2D streaks : repeat_disable, filter_nearest;
uniform float age = 0.0;
varying vec4 particle;
void vertex() { particle = INSTANCE_CUSTOM; }
void fragment() {
	float atlas = floor(particle.x * 3.999);
	float mask = texture(streaks, vec2((UV.x + atlas) * .25, 1.0 - UV.y)).r;
	float t = age - particle.y;
	float life = particle.z;
	float fade = smoothstep(0.0, .02, t) * (1.0 - smoothstep(life * .6, life, t));
	vec3 heat = mix(vec3(1.0, .18, .001), vec3(1.0, .64, .018), UV.y);
	ALBEDO = heat * 8.0;
	ALPHA = mask * fade;
}
