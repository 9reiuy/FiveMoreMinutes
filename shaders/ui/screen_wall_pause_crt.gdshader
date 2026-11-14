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
uniform vec4 glass_axes_uv = vec4(0.2, 0.0, 0.0, 0.2);
uniform float effect_time = 0.0;
uniform float noise_amount = 0.0;
uniform float option_mix = 0.0;
uniform float proximity = 0.0;
uniform float press_flash = 0.0;
uniform float channel_seed = 0.0;
uniform float idle_snow_strength : hint_range(0.0, 0.25) = 0.085;
uniform float tube_curvature : hint_range(0.0, 0.12) = 0.060;
uniform sampler2D previous_page : source_color, filter_linear, repeat_disable;
uniform float page_scan_active = 0.0;
uniform float page_scan = 1.0;
uniform float power_down : hint_range(0.0, 1.0) = 0.0;

float random_value(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 edge = abs((UV - 0.5) * glass_size) - (glass_size * 0.5 - 0.085);
	float rounded = length(max(edge, 0.0)) + min(max(edge.x, edge.y), 0.0) - 0.085;
	if (rounded > 0.0) discard;
	// A curved electron-beam raster inside the existing convex glass mesh.
	// The projected axes preserve the shared portrait on angled televisions.
	vec2 centered = UV * 2.0 - 1.0;
	vec2 curve_offset = centered * dot(centered, centered) * tube_curvature * 0.5;
	vec2 beam_uv = UV + curve_offset;
	// The raster collapses vertically to a line, then horizontally to a dot.
	vec2 beam_scale = vec2(mix(1.0, 0.012, smoothstep(0.58, 0.86, power_down)),
		mix(1.0, 0.008, smoothstep(0.0, 0.58, power_down)));
	vec2 sample_beam_uv = (beam_uv - 0.5) / beam_scale + 0.5;
	vec2 projected_offset = sample_beam_uv - UV;
	vec2 curved_screen_uv = SCREEN_UV + glass_axes_uv.xy * projected_offset.x + glass_axes_uv.zw * projected_offset.y;
	vec2 beam_edge = smoothstep(vec2(0.0), vec2(0.009), sample_beam_uv) * (vec2(1.0) - smoothstep(vec2(0.991), vec2(1.0), sample_beam_uv));
	float tube_mask = beam_edge.x * beam_edge.y;
	float frame = floor(effect_time * 24.0);
	float tear = (random_value(vec2(floor(beam_uv.y * 21.0), frame + channel_seed)) - 0.5) * noise_amount;
	vec2 mosaic_uv = curved_screen_uv + vec2(tear * 0.10, 0.0);
	vec2 source_uv = image_crop.xy + mosaic_uv * image_crop.zw;
	vec4 portrait = texture(mosaic_image, source_uv);
	float luma = dot(portrait.rgb, vec3(0.2126, 0.7152, 0.0722));
	float level = smoothstep(0.018, 0.32, luma);
	vec3 tinted = mix(screen_tint.rgb * 0.045, screen_tint.rgb * 0.98, level);
	vec3 picture = mix(screen_tint.rgb * 0.15, tinted, portrait.a);
	// The iris moves under the original fixed eye opening. Both are sampled
	// from the same shared source canvas so the mosaic stays continuous.
	vec4 eye = texture(eye_image, source_uv - eye_offset_uv);
	float eye_alpha = eye.a * texture(eye_mask, source_uv).a;
	picture = mix(picture, eye.rgb, eye_alpha);
	float snow = random_value(floor(beam_uv * glass_size * 96.0) + vec2(frame, channel_seed));
	vec3 static_rgb = mix(vec3(snow * 0.75), screen_tint.rgb * snow, 0.40);
	float band = step(0.70, random_value(vec2(floor(beam_uv.y * 16.0), frame)));
	static_rgb += band * vec3(0.16, 0.10, 0.16);
	vec4 option = texture(option_image, sample_beam_uv + vec2(tear * 0.018, 0.0));
	if (page_scan_active > 0.5) {
		vec4 old_page = texture(previous_page, sample_beam_uv);
		float revealed = 1.0-smoothstep(page_scan-0.012,page_scan+0.012,sample_beam_uv.y);
		option = mix(old_page,option,revealed);
		float sweep = exp(-pow((sample_beam_uv.y-page_scan)*110.0,2.0));
		option.rgb += vec3(0.35,0.85,1.0)*sweep*0.7;
	}
	vec3 background = mix(picture, picture * 0.13 + screen_tint.rgb * 0.055, option_mix);
	vec3 rgb = mix(background, static_rgb, noise_amount * 0.88);
	rgb = mix(rgb, option.rgb, option.a * option_mix * (1.0 - noise_amount * 0.75));
	rgb += screen_tint.rgb * 0.045;
	float raster_phase = beam_uv.y * glass_size.y * 31.0;
	float raster_weight = 1.0 - smoothstep(0.25, 0.50, fwidth(raster_phase));
	float raster = 1.0 - 0.14 * raster_weight * (0.5 + 0.5 * sin(raster_phase * 6.28318));
	float roll = exp(-pow((fract(beam_uv.y - effect_time * 0.075 + channel_seed * 0.12) - 0.5) * 52.0, 2.0));
	rgb *= raster * (0.97 + 0.025 * sin(effect_time * 6.0 + channel_seed));
	// Subtle RGB phosphor columns; the original iris bypasses this tinting.
	float phosphor_phase = beam_uv.x * glass_size.x * 78.0;
	float phosphor_weight = (1.0 - smoothstep(0.22, 0.52, fwidth(phosphor_phase))) * (1.0 - eye_alpha);
	vec3 phosphor = 0.98 + 0.02 * cos(phosphor_phase * 6.28318 + vec3(0.0, 2.0944, 4.1888));
	rgb *= mix(vec3(1.0), phosphor, phosphor_weight);
	// Fine monochrome reception noise remains visible between hover transitions.
	// Keep the option lettering legible and retain the iris's original palette.
	float fine_snow = random_value(floor(beam_uv * glass_size * 132.0) + vec2(frame * 7.0, channel_seed * 13.0));
	float row_snow = random_value(vec2(floor(beam_uv.y * glass_size.y * 84.0), frame + channel_seed));
	float idle_grain = (fine_snow - 0.5) + (row_snow - 0.5) * 0.24;
	rgb += vec3(idle_grain * idle_snow_strength * (1.0 - option_mix * 0.72) * (1.0 - noise_amount * 0.60));
	rgb += screen_tint.rgb * (roll * 0.025 + press_flash * 0.10);
	float glass_glare = pow(max(0.0, 1.0 - length((UV - vec2(0.35, 0.20)) * vec2(1.25, 2.0))), 5.0) * 0.024;
	rgb += vec3(glass_glare);
	float collapse_hot = smoothstep(0.08, 0.50, power_down) * (1.0 - smoothstep(0.84, 0.98, power_down));
	rgb += mix(screen_tint.rgb, vec3(1.0), 0.55) * collapse_hot * 0.28;
	rgb = mix(screen_tint.rgb * 0.012, rgb, tube_mask);
	float rim = 1.0 - smoothstep(-0.035, -0.012, rounded);
	rgb *= mix(0.60, 1.0, rim);
	rgb *= 1.0 - smoothstep(0.82, 1.0, power_down);
	// Default phosphor stays blue. Explicit neutral UI highlights (thumbs,
	// checkbox outlines and cycle arrows) retain white through the CRT pass.
	float peak = max(rgb.r,max(rgb.g,rgb.b));
	vec3 phosphor_colour = screen_tint.rgb / max(max(screen_tint.r,max(screen_tint.g,screen_tint.b)),0.001);
	float ui_peak = max(option.r,max(option.g,option.b));
	float ui_neutral = min(option.r,min(option.g,option.b)) / max(ui_peak,0.001);
	float white_highlight = smoothstep(0.70,0.85,ui_neutral) * smoothstep(0.02,0.08,ui_peak);
	white_highlight *= option.a * option_mix * (1.0-noise_amount*0.75);
	rgb = mix(phosphor_colour,vec3(1.0),white_highlight) * peak;
	ALBEDO = max(rgb, vec3(0.0));
	EMISSION = max(rgb, vec3(0.0)) * 0.07;
	ROUGHNESS = 0.85;
}
