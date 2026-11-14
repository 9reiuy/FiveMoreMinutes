shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
uniform sampler2D camera_feed : source_color, filter_nearest, repeat_disable;
uniform bool screen_power = false;
uniform bool speech_static = false;
uniform float noise_time = 0.0;
uniform vec2 glass_size = vec2(1.4, .95);
float snow_value(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	vec2 at = UV;
	vec2 image_size = vec2(textureSize(camera_feed, 0));
	float image_aspect = image_size.x / max(image_size.y, 1.0);
	float glass_aspect = glass_size.x / glass_size.y;
	// Fit the entire gameplay camera view; do not crop it to the CRT's aspect.
	at.y = (at.y - .5) * image_aspect / glass_aspect + .5;
	vec3 colour = vec3(0.0);
	if (screen_power) {
		if (speech_static) {
			// Speech replaces the whole glass; the live camera keeps updating below.
			float frame = floor(noise_time * 24.0);
			vec2 pixel = floor(UV * glass_size * 96.0);
			float snow = snow_value(pixel + vec2(frame, frame * 7.0));
			float band = step(0.80, snow_value(vec2(floor(UV.y * 18.0), frame)));
			float raster = 0.94 + 0.06 * sin(UV.y * glass_size.y * 100.0 * 6.28318);
			colour = vec3((0.05 + snow * 0.70 + band * 0.12) * raster);
		} else if (all(greaterThanEqual(at,vec2(0.0))) && all(lessThanEqual(at,vec2(1.0)))) {
			colour = texture(camera_feed,at).rgb;
		}
	}
	ALBEDO = colour;
	EMISSION = colour * .08;
	ROUGHNESS = .85;
}
