shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// Adapted Wind Flows 02 recipe using Vefects' original mask/cutout/noise.
// See art/Dream/VFX/VefectsWind/LICENSE.txt. For use inside finished products.
uniform sampler2D wind_mask : filter_nearest, repeat_enable;
uniform sampler2D cutout_mask : filter_nearest, repeat_enable;
uniform sampler2D flow_noise : filter_nearest, repeat_enable;
uniform vec4 wind_color : source_color = vec4(0.88, 0.95, 1.0, 0.56);
uniform float strength = 0.0;
uniform float flow_time = 0.0;
uniform float layer_offset = 0.0;
uniform float tail_stretch = 1.0;

void vertex() {
	// Keep the nose fitted to the forks while the trailing end grows with speed.
	VERTEX.x -= smoothstep(0.25, 1.0, UV.x) * (tail_stretch - 1.0) * 1.4;
}

void fragment() {
	vec2 noise_uv = vec2(UV.x * 1.8 - flow_time * 0.3, UV.y * 3.0 + layer_offset);
	float wobble = texture(flow_noise, noise_uv).g - 0.5;
	vec2 streak_uv = vec2(UV.x * 0.85 - flow_time * 1.25 + layer_offset,
		UV.y * 6.0 + wobble * 0.035 + layer_offset);
	float streak = texture(wind_mask, streak_uv).g;
	streak = smoothstep(0.18, 0.82, streak) * streak;
	float cutout = texture(cutout_mask, vec2(UV.x - flow_time * 0.28, UV.y * 2.0 + layer_offset)).b;
	// Keep only the body-length band, with soft starts at both ends.
	float front_fade = smoothstep(0.27, 0.40, UV.x);
	float rear_fade = 1.0 - smoothstep(0.53, 0.73, UV.x);
	float ends = front_fade * rear_fade;
	float edge = 0.45 + 0.55 * pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 0.6);
	ALBEDO = wind_color.rgb;
	ALPHA = streak * mix(0.38, 1.0, cutout) * ends * edge * strength * wind_color.a;
}
