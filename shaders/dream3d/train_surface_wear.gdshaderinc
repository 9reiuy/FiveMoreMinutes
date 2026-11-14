// Car-local wear stays attached to the train through travel and camera motion.
#include "res://shaders/dream3d/reception_wear.gdshaderinc"

uniform bool train_floor = false;
uniform float train_wear_amount : hint_range(0.0, 1.0) = .90;
instance uniform vec3 train_wear_origin = vec3(0.0);
instance uniform vec3 train_wear_basis_x = vec3(1.0, 0.0, 0.0);
instance uniform vec3 train_wear_basis_y = vec3(0.0, 1.0, 0.0);
instance uniform vec3 train_wear_basis_z = vec3(0.0, 0.0, 1.0);
instance uniform float train_wear_seed = 0.0;
varying vec3 train_surface_position;
varying vec3 train_surface_normal;

void apply_train_wear(inout vec3 colour, inout float rough, inout float metal, inout float shine) {
	vec3 local = train_surface_position;
	vec3 direction = abs(normalize(train_surface_normal));
	vec2 offset = vec2(train_wear_seed * 7.17, train_wear_seed * 3.31);
	float soil = 0.0;
	float abrasion = 0.0;
	float polished = 0.0;
	float tonal = 0.0;
	if (train_floor && direction.y > .70 && local.y > -.02) {
		vec2 p = (floor(local.xz * 32.0) + .5) / 32.0;
		vec2 pattern = p + offset;
		float edge = smoothstep(.75, 1.34, abs(p.y));
		float traffic = 1.0 - smoothstep(.36, 1.15, abs(p.y));
		float threshold = 1.0 - smoothstep(.18, .85, abs(abs(p.x) - 5.8));
		float deposits = reception_noise(pattern * vec2(.77, 1.83) + vec2(4.0, 17.0));
		float broken = reception_noise(pattern * 3.3 + vec2(21.0, 5.0));
		soil = smoothstep(.34, .77, deposits) * (.22 + edge * .60 + threshold * .24);
		soil *= .54 + broken * .46;
		abrasion = max(reception_scuff(pattern * .65), reception_scuff(pattern * .41 + vec2(2.0, 19.0))) * (.28 + .72 * traffic);
		polished = traffic * smoothstep(.33, .75, reception_noise(pattern * vec2(.42, 1.1)));
		tonal = (deposits - .5) * .24 + traffic * .095;
		colour *= 1.0 + (tonal - soil * .46) * train_wear_amount;
		colour = mix(colour, colour * .40, abrasion * .82 * train_wear_amount);
		float faded = reception_scuff(pattern * .69 + vec2(11.0, 3.0));
		colour += vec3(.032, .032, .029) * faded * traffic * train_wear_amount;
		rough = clamp(rough + (soil * .11 - polished * .13) * train_wear_amount, .64, 1.0);
	} else if (!train_floor && direction.y < .55) {
		vec2 face = direction.z > direction.x ? local.xy : local.zy;
		vec2 p = (floor(face * 32.0) + .5) / 32.0;
		vec2 pattern = p + offset;
		float lower = 1.0 - smoothstep(.22, 1.46, local.y);
		float patches = reception_noise(pattern * vec2(.79, 1.58) + vec2(5.0, 29.0));
		float deposits = reception_noise(pattern * vec2(2.5, .43) + vec2(16.0, 4.0));
		float runoff = smoothstep(.54, .79, deposits) * (1.0 - smoothstep(.45, 2.6, local.y));
		float joints = 1.0 - smoothstep(.05, .23, min(abs(local.x), abs(abs(local.x) - 3.3)));
		soil = smoothstep(.32, .79, patches) * (.08 + lower * .40 + joints * .08) + runoff * .10;
		abrasion = reception_scuff(pattern * vec2(.64, 1.3)) * (.26 + lower * .74);
		tonal = (patches - .5) * .07;
		colour *= 1.0 + (tonal - soil * .28) * train_wear_amount;
		colour = mix(colour, colour * .72 + vec3(.025), abrasion * .50 * train_wear_amount);
		rough = clamp(rough + (soil * .14 - abrasion * .045) * train_wear_amount, .24, 1.0);
	}
	metal *= 1.0 - clamp(soil * .18 * train_wear_amount, 0.0, .30);
	shine *= 1.0 - soil * .10 * train_wear_amount;
}
