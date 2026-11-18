shader_type canvas_item;
render_mode unshaded;

// Screen-edge low-health blood overlay backed by CC0 OpenGameArt textures.
// Combines a smooth peripheral crimson glow, deep corner pooling, and crisp
// outer blood droplets that pulse gently with a systolic heartbeat.

uniform sampler2D blotch_texture : source_color, filter_linear, repeat_disable;
uniform sampler2D vignette_texture : source_color, filter_linear, repeat_disable;
uniform sampler2D splat_texture : source_color, filter_linear, repeat_disable;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float severity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_phase = 0.0;

uniform vec3 outer_blood_color : source_color = vec3(0.14, 0.008, 0.018);
uniform vec3 inner_blood_color : source_color = vec3(0.32, 0.018, 0.036);

void fragment() {
	if (intensity <= 0.0005) {
		COLOR = vec4(0.0);
	} else {
		vec4 blotch = texture(blotch_texture, UV);
		vec4 vig = texture(vignette_texture, UV);
		vec4 splat = texture(splat_texture, UV);

		vec2 centered = (UV - vec2(0.5)) * 2.0;
		float radial = length(centered * vec2(0.92, 1.06));
		float safe_ring = smoothstep(mix(0.58, 0.40, severity), 1.04, radial);
		float splat_ring = smoothstep(mix(0.68, 0.52, severity), 1.02, radial);
		float corner_ring = smoothstep(0.86, 1.24, radial);
		float center_guard = smoothstep(0.40, 0.62, radial);

		// Biological lub-dub double heartbeat pulse.
		float cycle = fract(pulse_phase);
		float lub = exp(-pow((cycle - 0.14) / 0.075, 2.0));
		float dub = 0.62 * exp(-pow((cycle - 0.32) / 0.095, 2.0));
		float heartbeat = clamp(lub + dub, 0.0, 1.0);

		float smooth_rim = max(vig.a, smoothstep(0.80, 1.24, radial)) * mix(0.34, 0.58, severity);
		float corner_blotch = smoothstep(0.28, 0.92, blotch.a) * corner_ring * mix(0.34, 0.62, severity);
		float edge_haze = (smooth_rim + corner_blotch * (1.0 - smooth_rim * 0.5)) * safe_ring;

		float drops = smoothstep(0.18, 0.85, splat.a) * splat_ring * mix(0.62, 0.92, severity);

		float base_layer = edge_haze * (0.78 + 0.22 * heartbeat);
		float drop_layer = drops * (0.88 + 0.12 * heartbeat);
		float combined = clamp(base_layer + drop_layer * (1.0 - base_layer * 0.45), 0.0, 0.84);
		float alpha = combined * center_guard * intensity;

		float density_mix = clamp(drops * 0.60 + corner_ring * 0.55, 0.0, 1.0);
		vec3 color = mix(inner_blood_color, outer_blood_color, density_mix);
		color *= 1.0 + 0.16 * heartbeat * (1.0 - density_mix * 0.5);

		COLOR = vec4(color, alpha);
	}
}
