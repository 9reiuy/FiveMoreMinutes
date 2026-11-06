shader_type canvas_item;
render_mode unshaded;

// Independent visual sample. This pass belongs inside the world viewport;
// the game's HUD and interaction text must be composed after this layer.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool enabled = true;
uniform bool resolve_blood_only = false;
uniform float sample_strength : hint_range(0.0, 1.0) = 1.0;
uniform float levels : hint_range(4.0, 32.0, 1.0) = 12.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.72;
uniform float exposure : hint_range(0.25, 4.0) = 1.75;
uniform bool preserve_signals = true;
uniform float vignette_strength : hint_range(0.0, 0.5) = 0.08;
uniform int palette_variant : hint_range(0, 1) = 0;

const vec3 HK_BLOOD = vec3(0.8509804, 0.4196078, 0.0941176);
const vec3 HK_BLOOD_AIRBORNE = vec3(1.0, 0.6039216, 0.1803922);
const vec3 HK_CHARGE = vec3(1.0, 0.12, 0.08);

float hk_threshold(vec2 pixel) {
	vec2 p = mod(floor(pixel), 4.0);
	float a;
	if (p.y < 1.0) a = p.x < 1.0 ? 0.0 : (p.x < 2.0 ? 8.0 : (p.x < 3.0 ? 2.0 : 10.0));
	else if (p.y < 2.0) a = p.x < 1.0 ? 12.0 : (p.x < 2.0 ? 4.0 : (p.x < 3.0 ? 14.0 : 6.0));
	else if (p.y < 3.0) a = p.x < 1.0 ? 3.0 : (p.x < 2.0 ? 11.0 : (p.x < 3.0 ? 1.0 : 9.0));
	else a = p.x < 1.0 ? 15.0 : (p.x < 2.0 ? 7.0 : (p.x < 3.0 ? 13.0 : 5.0));
	return (a + 0.5) / 16.0;
}

vec3 hk_muzzle_color(int index) {
	if (index == 1) return vec3(0.7607843, 0.4431373, 0.1960784);
	if (index == 2) return vec3(0.9372549, 0.8039216, 0.2980392);
	if (index == 3) return vec3(0.4313725, 0.2235294, 0.5450980);
	return vec3(0.2392157, 0.2039216, 0.2705882);
}

vec3 hk_fire_color(int index) {
	if (index == 0) return vec3(1.0, 0.960784, 0.698039);
	if (index == 1) return vec3(1.0, 0.819608, 0.317647);
	if (index == 2) return vec3(1.0, 0.517647, 0.160784);
	if (index == 4) return vec3(1.0, 0.850980, 0.486275);
	if (index == 5) return vec3(0.886275, 0.384314, 0.160784);
	return vec3(0.772549, 0.243137, 0.152941);
}

vec4 hk_blood(vec3 source) {
	#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
		// RD's 3D output encodes the native unshaded semantic constants to sRGB.
		// Match those exact codes too; do not classify ordinary orange surfaces.
		vec3 blood_encoded = 1.055 * pow(HK_BLOOD, vec3(1.0 / 2.4)) - 0.055;
		vec3 airborne_encoded = 1.055 * pow(HK_BLOOD_AIRBORNE, vec3(1.0 / 2.4)) - 0.055;
		if (distance(source, blood_encoded) <= 0.035) return vec4(HK_BLOOD, 1.0);
		if (distance(source, airborne_encoded) <= 0.035) return vec4(HK_BLOOD_AIRBORNE, 1.0);
	#endif
	if (distance(source, HK_BLOOD) <= 0.035) return vec4(HK_BLOOD, 1.0);
	if (distance(source, HK_BLOOD_AIRBORNE) <= 0.035) return vec4(HK_BLOOD_AIRBORNE, 1.0);
	return vec4(source, 0.0);
}

// The reserved presentation colours are independent of the purple style.
vec4 hk_signal(vec3 source) {
	vec4 blood = hk_blood(source);
	if (blood.a > 0.5) return blood;
	if (distance(source, vec3(1.0, 0.0, 0.0)) <= 0.005 || distance(source, HK_CHARGE) <= 0.012) return vec4(HK_CHARGE, 1.0);
	if (distance(source, vec3(1.0, 0.0, 1.0)) <= 0.005) return vec4(vec3(1.0), 1.0);
	if (source.r > 0.995 && source.g < 0.005) {
		float muzzle_level = source.b / 0.02;
		int muzzle_index = int(muzzle_level + 0.5);
		if (muzzle_index >= 1 && muzzle_index <= 5 && abs(muzzle_level - float(muzzle_index)) <= 0.25) return vec4(hk_muzzle_color(muzzle_index), 1.0);
		float fire_level = (source.b - 0.20) / 0.04;
		int fire_index = int(round(fire_level));
		if (source.b >= 0.195 && source.b <= 0.405 && abs(fire_level - float(fire_index)) < 0.15) return vec4(hk_fire_color(fire_index), 1.0);
		float paint_level = (source.b - 0.52) / 0.04;
		int paint_index = int(round(paint_level));
		if (source.b >= 0.515 && source.b <= 0.605 && abs(paint_level - float(paint_index)) < 0.15) {
			vec3 paint = paint_index == 0 ? vec3(0.91, 0.25, 0.26) : (paint_index == 1 ? vec3(0.72, 0.12, 0.18) : vec3(0.43, 0.055, 0.095));
			return vec4(paint, 1.0);
		}
	}
	for (int i = 1; i <= 4; i++) {
		vec3 muzzle = hk_muzzle_color(i);
		if (distance(source, muzzle) <= 0.010) return vec4(muzzle, 1.0);
	}
	for (int i = 0; i <= 5; i++) {
		vec3 fire = hk_fire_color(i);
		if (distance(source, fire) <= 0.010) return vec4(fire, 1.0);
	}
	return vec4(source, 0.0);
}

vec3 hk_palette(float value) {
	// Electric blue-violet midtones, purple-black shadows, lavender lights.
	// Anchors are authored screen RGB values, matching screen_texture's space.
	vec3 c0 = vec3(0.0078, 0.0039, 0.0196);
	vec3 c1 = vec3(0.0353, 0.0157, 0.1059);
	vec3 c2 = vec3(0.1059, 0.0471, 0.3216);
	vec3 c3 = vec3(0.2235, 0.1922, 0.8627);
	vec3 c4 = vec3(0.4118, 0.3412, 0.9725);
	vec3 c5 = vec3(0.6627, 0.5882, 1.0);
	vec3 c6 = vec3(0.9137, 0.8784, 1.0);
	if (palette_variant == 1) {
		c2 = vec3(0.1451, 0.0353, 0.3216);
		c3 = vec3(0.3216, 0.1176, 0.8314);
		c4 = vec3(0.5451, 0.2667, 0.9569);
	}
	if (value < 0.10) return mix(c0, c1, value / 0.10);
	if (value < 0.25) return mix(c1, c2, (value - 0.10) / 0.15);
	if (value < 0.50) return mix(c2, c3, (value - 0.25) / 0.25);
	if (value < 0.70) return mix(c3, c4, (value - 0.50) / 0.20);
	if (value < 0.86) return mix(c4, c5, (value - 0.70) / 0.16);
	return mix(c5, c6, (value - 0.86) / 0.14);
}

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	vec3 output_color = source.rgb;
	if (resolve_blood_only) {
		output_color = hk_blood(source.rgb).rgb;
	} else if (enabled && sample_strength > 0.0) {
		vec4 signal_color = preserve_signals ? hk_signal(source.rgb) : vec4(source.rgb, 0.0);
		if (signal_color.a > 0.5) {
			// No exposure, vignette, dithering or interpolation alters orange blood.
			output_color = signal_color.rgb;
		} else {
			float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
			float tone = pow(clamp(luminance * exposure, 0.0, 1.0), 0.82);
			tone = clamp((tone - 0.42) * 1.13 + 0.42, 0.0, 1.0);
			vec2 centered = SCREEN_UV * 2.0 - 1.0;
			tone *= 1.0 - vignette_strength * smoothstep(0.35, 1.6, dot(centered, centered));
			float steps = max(3.0, floor(levels + 0.5) - 1.0);
			float threshold = hk_threshold(SCREEN_UV / SCREEN_PIXEL_SIZE) - 0.5;
			float quantized = clamp(floor(tone * steps + 0.5 + threshold * dither_strength) / steps, 0.0, 1.0);
			vec3 stylized = hk_palette(quantized);
			// Keep dark red-brown surface stains distinct from the violet field.
			// This is a material-colour treatment, separate from exact blood codes.
			float warm = smoothstep(0.025, 0.14, source.r - max(source.g, source.b));
			warm *= step(source.g * 1.15, source.r) * step(source.b * 1.05, source.r);
			vec3 rust = vec3(0.75, 0.12, 0.25) * quantized;
			stylized = mix(stylized, rust, warm * 0.82);
			float magenta = smoothstep(0.055, 0.20, min(source.r, source.b) - source.g);
			stylized = mix(stylized, vec3(0.87, 0.13, 0.72) * quantized, magenta * 0.6);
			output_color = mix(source.rgb, stylized, sample_strength);
			if (luminance < 0.001) output_color = vec3(0.0);
		}
	}
	COLOR = vec4(output_color, source.a);
}
