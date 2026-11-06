shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D mosaic_image : source_color, filter_nearest, repeat_disable;
uniform sampler2D eye_image : source_color, filter_nearest, repeat_disable;
uniform sampler2D eye_mask : source_color, filter_nearest, repeat_disable;
uniform sampler2D option_image : source_color, filter_linear, repeat_disable;
uniform vec4 screen_tint : source_color = vec4(0.40, 0.80, 0.76, 1.0);
uniform vec4 image_crop = vec4(0.225, 0.01, 0.55, 0.55);
uniform vec2 eye_offset_uv = vec2(0.0);
uniform vec2 glass_size = vec2(2.0, 1.5);
uniform float effect_time = 0.0;
uniform float noise_amount = 0.0;
uniform float option_mix = 0.0;
uniform float proximity = 0.0;
uniform float press_flash = 0.0;
uniform float channel_seed = 0.0;

float random_value(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 edge = abs((UV - 0.5) * glass_size) - (glass_size * 0.5 - 0.085);
	float rounded = length(max(edge, 0.0)) + min(max(edge.x, edge.y), 0.0) - 0.085;
	if (rounded > 0.0) discard;
	float frame = floor(effect_time * 24.0);
	float tear = (random_value(vec2(floor(UV.y * 21.0), frame + channel_seed)) - 0.5) * noise_amount;
	vec2 mosaic_uv = SCREEN_UV + vec2(tear * 0.10, 0.0);
	vec2 source_uv = image_crop.xy + mosaic_uv * image_crop.zw;
	vec4 portrait = texture(mosaic_image, source_uv);
	float luma = dot(portrait.rgb, vec3(0.2126, 0.7152, 0.0722));
	float level = smoothstep(0.018, 0.32, luma);
	vec3 tinted = mix(screen_tint.rgb * 0.055, screen_tint.rgb * 0.91, level);
	vec3 picture = mix(screen_tint.rgb * 0.15, tinted, portrait.a);
	// The iris moves under the original fixed eye opening. Both are sampled
	// from the same shared source canvas so the mosaic stays continuous.
	vec4 eye = texture(eye_image, source_uv - eye_offset_uv);
	float eye_alpha = eye.a * texture(eye_mask, source_uv).a;
	picture = mix(picture, eye.rgb, eye_alpha);
	float snow = random_value(floor(UV * glass_size * 96.0) + vec2(frame, channel_seed));
	vec3 static_rgb = mix(vec3(snow * 0.75), screen_tint.rgb * snow, 0.40);
	float band = step(0.70, random_value(vec2(floor(UV.y * 16.0), frame)));
	static_rgb += band * vec3(0.16, 0.10, 0.16);
	vec4 option = texture(option_image, UV + vec2(tear * 0.018, 0.0));
	vec3 background = mix(picture, picture * 0.13 + screen_tint.rgb * 0.055, option_mix);
	vec3 rgb = mix(background, static_rgb, noise_amount * 0.88);
	rgb = mix(rgb, option.rgb, option.a * option_mix * (1.0 - noise_amount * 0.75));
	float raster_phase = UV.y * glass_size.y * 42.0;
	float raster_weight = 1.0 - smoothstep(0.25, 0.50, fwidth(raster_phase));
	float raster = 1.0 - 0.065 * raster_weight * (0.5 + 0.5 * sin(raster_phase * 6.28318));
	float roll = exp(-pow((fract(UV.y - effect_time * 0.075 + channel_seed * 0.12) - 0.5) * 52.0, 2.0));
	rgb *= raster * (0.97 + 0.025 * sin(effect_time * 6.0 + channel_seed));
	rgb += screen_tint.rgb * (roll * 0.025 + press_flash * 0.10);
	float rim = 1.0 - smoothstep(-0.035, -0.012, rounded);
	rgb *= mix(0.60, 1.0, rim);
	ALBEDO = rgb;
	EMISSION = rgb * 0.07;
	ROUGHNESS = 0.85;
}
