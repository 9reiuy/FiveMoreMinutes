// Furniture finish data follows the existing face UVs. The colour atlas,
// geometry normal, and contact shadow keep their existing roles.
uniform bool furniture_finish_enabled = true;
uniform bool furniture_finish_atlas_enabled = false;
uniform sampler2D furniture_finish_atlas : filter_nearest_mipmap, repeat_disable;
uniform vec2 furniture_finish_uniform = vec2(1.0, 0.0);
varying vec3 furniture_direct_normal;
varying vec2 furniture_direct_finish;

vec3 furniture_finish_normal(vec3 normal, vec3 point, vec2 uv, vec2 slope) {
	vec3 dx = dFdx(point);
	vec3 dy = dFdy(point);
	vec2 ux = dFdx(uv);
	vec2 uy = dFdy(uv);
	float orientation = sign(ux.x * uy.y - ux.y * uy.x);
	vec3 tangent = (dx * uy.y - dy * ux.y) * orientation;
	vec3 bitangent = (dy * ux.x - dx * uy.x) * orientation;
	tangent *= inversesqrt(max(dot(tangent, tangent), 1e-16));
	bitangent *= inversesqrt(max(dot(bitangent, bitangent), 1e-16));
	return normalize(normal + tangent * slope.x + bitangent * slope.y);
}

// The finish represents a small direct-light lobe. R4 fixtures deliberately
// suppress the engine's standard specular lobe; use their actual colour,
// direction and attenuation here, without changing the fixtures or the IBL.
float furniture_finish_lobe(vec3 light, vec3 view, vec3 normal, vec2 finish) {
	vec3 halfway = light + view;
	halfway *= inversesqrt(max(dot(halfway, halfway), 0.000001));
	float light_facing = max(dot(normal, light), 0.0);
	float half_facing = clamp(dot(normal, halfway), 0.0, 1.0);
	float shoulder = mix(0.86, 0.38, finish.x);
	return finish.y * light_facing * smoothstep(shoulder, 1.0, half_facing);
}
