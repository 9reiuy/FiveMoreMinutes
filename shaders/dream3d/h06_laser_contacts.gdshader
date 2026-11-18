shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Age, variation, kind (emitter, strike, smoke, ember), strength.
varying flat vec4 detail;

void vertex() {
	detail = INSTANCE_CUSTOM;
	vec3 center = MODELVIEW_MATRIX[3].xyz;
	vec3 direction = normalize(MODELVIEW_MATRIX[0].xyz);
	vec2 forward = direction.xy;
	if (PROJECTION_MATRIX[3][3] < 0.5) {
		forward -= center.xy * direction.z / min(center.z, -0.01);
	}
	forward = length(forward) > 0.001 ? normalize(forward) : vec2(1.0, 0.0);
	vec2 across = vec2(-forward.y, forward.x);
	vec2 offset = forward * (VERTEX.x * length(MODEL_MATRIX[0].xyz))
		+ across * (VERTEX.y * length(MODEL_MATRIX[1].xyz));
	POSITION = PROJECTION_MATRIX * vec4(center + vec3(offset, 0.0), 1.0);
}

float profile(float value, float width) {
	float v = value / width;
	return exp2(-v*v);
}

float spur(vec2 point, float angle, float width) {
	vec2 axis = vec2(cos(angle), sin(angle));
	float along = dot(point, axis);
	float side = dot(point, vec2(-axis.y, axis.x));
	return smoothstep(-0.06, 0.16, along) * (1.0 - smoothstep(0.08, 0.92, along))
		* profile(side, width * (1.0 - 0.62 * clamp(along, 0.0, 1.0)));
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float r = length(p);
	float turn = detail.y * 6.283185;
	float t = detail.x;
	float border = 1.0 - smoothstep(0.74, 1.0, r);
	if (detail.z < 1.5) {
		float beat = 0.88 + 0.12 * sin(t * 43.0 + turn);
		float pin = profile(r, 0.119 + 0.021 * beat);
		float heart = profile(r, 0.30);
		float red = profile(r, 0.59);
		float sprays = spur(p, -0.83 + 0.34 * sin(t * 22.0 + turn), 0.11)
			+ spur(p, 0.92 + 0.27 * sin(t * 18.0 + turn), 0.095)
			+ 0.64 * spur(p, 2.38 + 0.46 * sin(t * 17.0 + turn), 0.075);
		float arcs = 0.0;
		if (detail.z < 0.5) {
			float orbit = t * 24.0 + turn;
			float tilt = t * 13.0 + turn * 0.5;
			vec2 axis = vec2(cos(orbit), sin(orbit));
			vec2 plume = p - vec2(0.20, 0.0);
			vec2 tilted = vec2(dot(plume, axis), dot(plume, vec2(-axis.y, axis.x)) / (0.62 + 0.32 * abs(cos(tilt))));
			float angle = atan(tilted.y, tilted.x + 0.0001);
			arcs = profile(length(tilted) - 0.64, 0.034)
				* smoothstep(0.04, 0.87, cos(angle * 2.0 + tilt));
		}
		ALBEDO = vec3(4.0, 2.50, 1.99) * pin + vec3(1.40, 0.27, 0.115) * heart
			+ vec3(1.10, 0.047, 0.016) * red + vec3(1.86, 0.27, 0.101) * sprays
			+ vec3(2.1, 0.53, 0.19) * arcs;
		ALPHA = detail.w * beat * border;
	} else if (detail.z < 2.5) {
		// Roll the thin, broken edge of the hot smoke as the puff opens up.
		float spin = turn + t * (1.45 + 1.0 * sin(turn));
		vec2 q = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * p;
		q += vec2(sin(q.y * 6.6 + spin), cos(q.x * 7.8 - spin)) * (0.09 + 0.14 * t);
		float curl = length(q * vec2(1.0, 0.84)) - 0.47
			+ 0.075 * sin(q.x * 12.0 + q.y * 8.0 + spin);
		float wisps = profile(curl, 0.081) * smoothstep(-0.57, 0.73, q.y + 0.32 * cos(q.x * 6.8 - spin));
		float body = profile(length(q), 0.51);
		ALBEDO = vec3(1.38, 0.105, 0.039) * wisps + vec3(0.49, 0.034, 0.014) * body;
		ALPHA = detail.w * smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.21, 1.0, t)) * border;
	} else {
		float streak = profile(p.y, 0.38) * smoothstep(-1.0, 0.46, p.x)
			* (1.0 - smoothstep(0.53, 1.0, p.x));
		ALBEDO = mix(vec3(1.32, 0.115, 0.037), vec3(3.16, 1.53, 0.82), smoothstep(-0.25, 0.74, p.x));
		ALPHA = detail.w * streak * (1.0 - smoothstep(0.11, 1.0, t));
	}
}
