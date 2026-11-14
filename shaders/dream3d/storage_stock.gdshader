shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 finish_colour : source_color = vec4(.45, .49, .46, 1.0);
uniform float finish_roughness = .72;
uniform float finish_specular = .24;
uniform float surface_wear = .34;
varying vec3 surface_world;
varying vec3 normal_world;

float grain(vec2 point) {
	uvec2 cell = uvec2(ivec2(point));
	uint h = cell.x * 374761393u + cell.y * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float((h ^ (h >> 16u)) & 16777215u) / 16777216.0;
}

void vertex() {
	surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec3 n = abs(normal_world);
	vec2 uv = n.y > max(n.x, n.z) ? surface_world.xz
		: (n.x > n.z ? surface_world.zy : surface_world.xy);
	vec2 texel = floor(uv * 32.0);
	float fine = grain(texel) - .5;
	float grain_band = grain(floor(texel / vec2(2.0, 6.0))) - .5;
	float mark = smoothstep(.80, .99, grain(floor(texel / vec2(3.0, 2.0)) + 13.0));
	float worn = surface_wear * mark;
	ALBEDO = finish_colour.rgb * (1.0 + (fine * .22 + grain_band * .51) * surface_wear - worn * .35);
	ROUGHNESS = clamp(finish_roughness + worn * .21 + fine * .06, 0.0, 1.0);
	SPECULAR = finish_specular * (1.0 - worn * .23);
}
