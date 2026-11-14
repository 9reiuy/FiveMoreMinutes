shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/dream3d/reception_wear.gdshaderinc"

uniform vec4 upper_paint : source_color;
uniform vec4 lower_paint : source_color;
uniform vec4 skirting_paint : source_color;
uniform float wear_amount : hint_range(0.0, 1.0) = .86;

varying vec3 surface_world;
varying vec3 normal_world;
varying float wall_y;

void vertex() {
	surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	wall_y = VERTEX.y;
}

void fragment() {
#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
	// Give the painted receiver a small clearance from the coincident
	// shadow caster at grazing angles. The wall geometry still blocks light.
	LIGHT_VERTEX = VERTEX + normalize(NORMAL) * .04;
#endif
	vec3 axis = abs(normal_world);
	float horizontal = axis.x > axis.z ? surface_world.z : surface_world.x;
	vec2 point = (floor(vec2(horizontal, wall_y) * 32.0) + .5) / 32.0;
	// Company corridor proportions on the 83-texel-high tutorial walls.
	float skirting = 1.0 - step(8.0 / 32.0, point.y);
	float lower_band = 1.0 - step(28.0 / 32.0, point.y);
	vec3 paint = mix(upper_paint.rgb, lower_paint.rgb, lower_band);
	paint = mix(paint, skirting_paint.rgb, skirting);
	if (abs(point.y - 28.0 / 32.0) < .016) {
		paint *= 1.07;
	}

	float low_wall = 1.0 - smoothstep(.22, 1.42, point.y);
	float drip = smoothstep(.60, .86, reception_noise(point * vec2(4.8, .72) + vec2(21.0, 5.0)));
	vec3 wear = reception_wear(point, low_wall, lower_band) * wear_amount;
	float deposit = wear.r * .32 + drip * low_wall * wear_amount * .22;
	float scrape = wear.g * mix(.025, .19, lower_band);
	ALBEDO = paint * (1.0 - deposit - scrape + wear.b * .055);
	ROUGHNESS = clamp(mix(.86, .76, skirting) + deposit * .32, .72, .98);
	SPECULAR = .13;
	METALLIC = 0.0;
}
