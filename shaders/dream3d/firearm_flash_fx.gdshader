shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 white_hot : source_color = vec4(1.0, 0.978, 0.918, 1.0);
uniform vec4 hot_gold : source_color = vec4(1.0, 0.714, 0.397, 1.0);
uniform vec4 ember : source_color = vec4(1.0, 0.354, 0.108, 1.0);

varying flat vec4 particle;

void vertex() {
	particle = INSTANCE_CUSTOM;
	vec3 center = MODELVIEW_MATRIX[3].xyz;
	vec3 forward = mat3(VIEW_MATRIX) * normalize(MODEL_MATRIX[0].xyz);
	vec2 projected = forward.xy;
	if (PROJECTION_MATRIX[3][3] < 0.5) {
		projected -= center.xy * forward.z / min(center.z, -0.01);
	}
	float foreshortening = length(projected);
	vec2 axis = foreshortening > 0.001 ? projected / foreshortening : vec2(1.0, 0.0);
	vec2 cross_axis = vec2(-axis.y, axis.x);
	vec2 size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	size.x *= clamp(foreshortening, 0.54, 1.2);
	// The flash's base, or the leading tip of a spark, sits at the particle pivot.
	float offset = particle.z < 0.5 ? 0.16 : -0.33;
	vec2 shift = axis * ((VERTEX.x + offset) * size.x) + cross_axis * (VERTEX.y * size.y);
	MODELVIEW_MATRIX = mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0), vec4(center, 1.0));
	VERTEX.xy = shift;
}

void fragment() {
	float phase = particle.x;
	float strength = particle.w;
	if (particle.z < 0.5) {
		vec2 p = vec2((UV.x - 0.34) * 2.0, (UV.y - 0.5) * 2.0);
		float slant = mix(-0.25, 0.25, particle.y);
		p.y += slant * p.x;
		float halo = max(1.0 - length((p - vec2(0.16, 0.0)) / vec2(0.84, 0.98)), 0.0);
		float base = max(1.0 - length(p / vec2(0.38, 0.62)), 0.0);
		float plume = max(1.0 - length((p - vec2(0.37, 0.0)) / vec2(0.66, 0.48)), 0.0);
		float core = max(pow(plume, 1.42), pow(base, 1.26));
		float life = pow(max(1.0 - phase, 0.0), 1.88);
		ALBEDO = mix(hot_gold.rgb, white_hot.rgb, smoothstep(0.11, 0.62, core))
			* (4.7 * core + 1.05 * pow(halo, 1.66));
		ALPHA = strength * life * smoothstep(0.0, 0.12, max(halo, core));
	} else {
		float along = smoothstep(0.02, 0.82, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x));
		float taper = mix(0.19, 0.86, UV.x);
		float cross_section = 1.0 - smoothstep(taper * 0.26, taper, abs(UV.y * 2.0 - 1.0));
		float life = pow(max(1.0 - phase, 0.0), 1.21);
		vec3 heated = mix(hot_gold.rgb, white_hot.rgb, smoothstep(0.27, 0.88, UV.x));
		ALBEDO = mix(ember.rgb, heated, clamp(life * 1.3, 0.0, 1.0)) * mix(1.50, 3.22, UV.x);
		ALPHA = along * cross_section * life * strength;
	}
	if (ALPHA < 0.003) { discard; }
}
