uniform sampler2D environment_xp : source_color, filter_linear, repeat_disable;
uniform sampler2D environment_xn : source_color, filter_linear, repeat_disable;
uniform sampler2D environment_yp : source_color, filter_linear, repeat_disable;
uniform sampler2D environment_yn : source_color, filter_linear, repeat_disable;
uniform sampler2D environment_zp : source_color, filter_linear, repeat_disable;
uniform sampler2D environment_zn : source_color, filter_linear, repeat_disable;
uniform sampler2D environment_fallback : source_color, filter_linear, repeat_disable;
uniform mat3 environment_direction_basis = mat3(1.0);
uniform bool environment_ready = false;
uniform bool environment_is_3d = false;

vec3 phone_environment_face(vec3 direction) {
	vec3 a = abs(direction);
	vec2 uv;
	// Camera bases are declared explicitly in PhoneEnvironmentBridge. The
	// texture's top is camera-up, just as for the live LCD ViewportTexture.
	if (a.x >= a.y && a.x >= a.z) {
		if (direction.x >= 0.0) {
			uv = vec2(direction.z, -direction.y) / max(a.x, 0.0001) * 0.5 + 0.5;
			return texture(environment_xp, uv).rgb;
		}
		uv = vec2(-direction.z, -direction.y) / max(a.x, 0.0001) * 0.5 + 0.5;
		return texture(environment_xn, uv).rgb;
	}
	if (a.y >= a.z) {
		if (direction.y >= 0.0) {
			uv = vec2(direction.x, -direction.z) / max(a.y, 0.0001) * 0.5 + 0.5;
			return texture(environment_yp, uv).rgb;
		}
		uv = vec2(direction.x, direction.z) / max(a.y, 0.0001) * 0.5 + 0.5;
		return texture(environment_yn, uv).rgb;
	}
	if (direction.z >= 0.0) {
		uv = vec2(-direction.x, -direction.y) / max(a.z, 0.0001) * 0.5 + 0.5;
		return texture(environment_zp, uv).rgb;
	}
	uv = vec2(direction.x, -direction.y) / max(a.z, 0.0001) * 0.5 + 0.5;
	return texture(environment_zn, uv).rgb;
}

vec3 phone_environment(vec3 shell_direction, float roughness) {
	if (!environment_ready) { return vec3(0.0); }
	vec3 direction = normalize(environment_direction_basis * shell_direction);
	if (!environment_is_3d) {
		// Explicit 2D fallback: a frozen actual background image, not a cube or
		// a claim of reconstructed 3D room lighting.
		vec2 uv = clamp(vec2(-direction.x, -direction.y) * 0.42 + 0.5, vec2(0.01), vec2(0.99));
		return texture(environment_fallback, uv).rgb;
	}
	vec3 tangent = normalize(cross(direction, abs(direction.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 bitangent = normalize(cross(direction, tangent));
	float width = 0.008 + roughness * roughness * 0.22;
	vec3 result = phone_environment_face(direction) * 0.4;
	result += phone_environment_face(normalize(direction + tangent * width)) * 0.15;
	result += phone_environment_face(normalize(direction - tangent * width)) * 0.15;
	result += phone_environment_face(normalize(direction + bitangent * width)) * 0.15;
	result += phone_environment_face(normalize(direction - bitangent * width)) * 0.15;
	return result;
}
