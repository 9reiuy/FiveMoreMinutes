shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_never, shadows_disabled;

uniform float field_time = 0.0;
// Each impact stores its sphere direction and start time.
uniform vec4 impacts[4];
varying vec3 unit_position;

float hash_corner(vec3 cell) {
	vec3 value = fract(cell * vec3(0.1031, 0.11369, 0.13787));
	value += dot(value, value.yzx + 19.19);
	return fract((value.x + value.y) * value.z);
}

float cloud(vec3 point) {
	vec3 cell = floor(point);
	vec3 fraction = fract(point);
	fraction = fraction * fraction * (3.0 - 2.0 * fraction);
	float low = mix(
		mix(hash_corner(cell), hash_corner(cell + vec3(1, 0, 0)), fraction.x),
		mix(hash_corner(cell + vec3(0, 1, 0)), hash_corner(cell + vec3(1, 1, 0)), fraction.x), fraction.y);
	float high = mix(
		mix(hash_corner(cell + vec3(0, 0, 1)), hash_corner(cell + vec3(1, 0, 1)), fraction.x),
		mix(hash_corner(cell + vec3(0, 1, 1)), hash_corner(cell + vec3(1, 1, 1)), fraction.x), fraction.y);
	return mix(low, high, fraction.z);
}

void vertex() {
	unit_position = VERTEX;
}

void fragment() {
	vec3 surface = normalize(unit_position);
	float edge = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = smoothstep(0.43, 0.96, edge);
	vec3 flow = surface * vec3(4.3, 5.8, 4.3) + vec3(field_time * 0.24, -field_time * 0.33, 2.0);
	float billow = cloud(flow);
	float curl = cloud(flow * 2.46 + vec3(billow * 2.1, billow * 1.4, field_time * 0.22));
	float veins = smoothstep(0.44, 0.79, (1.0 - abs(curl * 2.0 - 1.0)) * billow + curl * 0.32);
	float belt_distance = abs(surface.y - 0.13 + (billow - 0.5) * 0.034);
	float belt_width = max(0.008, fwidth(surface.y) * 0.72);
	float belt = 1.0 - smoothstep(belt_width, belt_width + 0.015, belt_distance);

	float waves = 0.0;
	float flashes = 0.0;
	for (int i = 0; i < 4; i++) {
		float age = field_time - impacts[i].w;
		if (age >= 0.0 && age < 0.56) {
			float progress = age / 0.56;
			float distance = length(surface - impacts[i].xyz);
			float wave_radius = mix(0.028, 0.62, progress);
			float wave_width = mix(0.018, 0.038, progress);
			float ripple = 1.0 - smoothstep(wave_width, wave_width * 1.8, abs(distance - wave_radius));
			float echo = 1.0 - smoothstep(0.017, 0.039, abs(distance - max(0.024, wave_radius - 0.09)));
			waves += (ripple + echo * 0.42 * smoothstep(0.13, 0.27, progress)) * (1.0 - progress);
			flashes += (1.0 - smoothstep(0.01, 0.066, distance)) * (1.0 - smoothstep(0.01, 0.20, progress));
		}
	}
	waves = min(waves, 1.4);
	flashes = min(flashes, 1.35);

	// Expose the rear vent and let the field dissolve into the deck.
	float aperture = smoothstep(-0.89, -0.71, surface.z);
	float base = smoothstep(-0.36, -0.26, surface.y);
	float charge = smoothstep(0.0, 0.22, field_time);
	float plasma = rim * (0.22 + veins * 1.9) + veins * 0.055;
	vec3 blue = vec3(0.018, 0.23, 0.95);
	vec3 electric = vec3(0.18, 0.70, 1.0);
	ALBEDO = mix(blue, electric, rim * 0.55 + veins * 0.20);
	EMISSION = blue * (0.08 + plasma * 1.45)
		+ electric * (rim * 0.46 + belt * (0.55 + rim * 1.04) + waves * 2.5)
		+ vec3(0.95, 1.20, 1.55) * flashes * 5.8;
	ALPHA = aperture * base * charge * min(0.83, 0.018 + plasma * 0.32
		+ belt * (0.13 + rim * 0.22) + waves * 0.54 + flashes * 0.66);
}
