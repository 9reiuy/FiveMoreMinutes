shader_type canvas_item;
render_mode unshaded, blend_mul;

// Multiplicative arterial absorption pass: stains bright screen edges and
// outer blood droplets into deep crimson without milky bright washout.

uniform sampler2D vignette_texture : source_color, filter_linear, repeat_disable;
uniform sampler2D splat_texture : source_color, filter_linear, repeat_disable;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float severity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_phase = 0.0;

uniform vec3 absorb_tint : source_color = vec3(0.58, 0.06, 0.09);

void fragment() {
	if (intensity <= 0.0005) {
		COLOR = vec4(1.0);
	} else {
		vec4 vig = texture(vignette_texture, UV);
		vec4 splat = texture(splat_texture, UV);

		vec2 centered = (UV - vec2(0.5)) * 2.0;
		float radial = length(centered * vec2(0.92, 1.06));
		float safe_ring = smoothstep(mix(0.54, 0.36, severity), 1.02, radial);
		float splat_ring = smoothstep(mix(0.68, 0.52, severity), 1.02, radial);
		float center_guard = smoothstep(0.38, 0.60, radial);

		float cycle = fract(pulse_phase);
		float lub = exp(-pow((cycle - 0.14) / 0.075, 2.0));
		float dub = 0.62 * exp(-pow((cycle - 0.32) / 0.095, 2.0));
		float heartbeat = clamp(lub + dub, 0.0, 1.0);

		float smooth_edge = smoothstep(0.76, 1.22, radial) * mix(0.45, 0.80, severity);
		float vig_mask = max(vig.a, smooth_edge) * safe_ring;
		float drop_mask = splat.a * splat_ring * mix(0.65, 0.95, severity);

		float mask = max(vig_mask * mix(0.56, 0.90, severity), drop_mask) * center_guard;
		mask *= (0.82 + 0.18 * heartbeat) * intensity;

		vec3 tint = mix(vec3(1.0), absorb_tint, clamp(mask, 0.0, 1.0));
		COLOR = vec4(tint, 1.0);
	}
}
