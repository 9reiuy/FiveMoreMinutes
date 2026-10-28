shader_type canvas_item;

// This is the final presentation pass. It samples the already composited
// screen and replaces normal pixels with the nearest entry in the 16-color
// palette. Blood carriers and warning markers are resolved by semantic
// branches; their outputs are deliberately not generic candidates.
// Palette values are written as normalized screen-space values (the same space
// returned by the screen texture), so the comparison never mixes raw sRGB
// values with linear values.
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool palette_enabled = true;
uniform int palette_scheme = 1;

const vec3 PALETTE_00 = vec3(0.0196078, 0.0235294, 0.0392157); // 01 #05060A Void / 绝对暗部
const vec3 PALETTE_01 = vec3(0.0509804, 0.0627451, 0.1254902); // 02 #0D1020 极深蓝黑
const vec3 PALETTE_02 = vec3(0.0784314, 0.0941176, 0.1764706); // 03 #14182D 深阴影
const vec3 PALETTE_03 = vec3(0.1098039, 0.1294118, 0.2509804); // 04 #1C2140 墙体深影
const vec3 PALETTE_04 = vec3(0.1490196, 0.1764706, 0.3411765); // 05 #262D57 主暗部
const vec3 PALETTE_05 = vec3(0.1921569, 0.2274510, 0.4392157); // 06 #313A70 深蓝紫
const vec3 PALETTE_06 = vec3(0.2274510, 0.2666667, 0.4823529); // 07 #3A447B 墙体主色
const vec3 PALETTE_07 = vec3(0.2745098, 0.3215686, 0.5411765); // 08 #46528A 地面主色
const vec3 PALETTE_08 = vec3(0.3254902, 0.3803922, 0.5921569); // 09 #536197 地面亮部
const vec3 PALETTE_09 = vec3(0.3843137, 0.4431373, 0.6470588); // 10 #6271A5 家具中间调
const vec3 PALETTE_10 = vec3(0.4431373, 0.5058824, 0.7019608); // 11 #7181B3 家具 / 角色亮面
const vec3 PALETTE_11 = vec3(0.5176471, 0.5803922, 0.7607843); // 12 #8494C2 边缘高光
const vec3 PALETTE_12 = vec3(0.6117647, 0.6666667, 0.8196078); // 13 #9CAAD1 冷亮部
const vec3 PALETTE_13 = vec3(0.7098039, 0.7568627, 0.8784314); // 14 #B5C1E0 高亮
const vec3 PALETTE_14 = vec3(0.8156863, 0.8509804, 0.9372549); // 15 #D0D9EF 冷白
const vec3 PALETTE_15 = vec3(0.9294118, 0.9490196, 1.0000000); // 16 #EDF2FF UI / 极亮点

// Preserve BlackBloodEffect's original ground and airborne hues in the 3D
// presentation path, including palette mode 1. The old 2D Dream is unchanged.
const vec3 BLOOD_SEMANTIC_MARKER = vec3(0.8509804, 0.4196078, 0.0941176); // #D96B18
const vec3 BLOOD_OUTPUT_COLOR = vec3(0.8509804, 0.4196078, 0.0941176);
const vec3 BLOOD_AIRBORNE_MARKER = vec3(1.0, 0.6039216, 0.1803922); // #FF9A2E
// Compatibility's framebuffer conversion can shift marker components by a
// few 8-bit steps; allow that drift without matching the pure-red charge.
const float BLOOD_MARKER_EPSILON = 0.035;
// Enemy ranged windup is another presentation-only semantic. It is kept out
// of generic palettes so the red warning remains visible instead of
// being remapped to a blue/purple palette entry. The internal marker is pure
// red so Compatibility's screen conversion cannot turn it into a near miss;
// the output remains the authored warm red used by the charge visual.
const vec3 CHARGE_SEMANTIC_MARKER = vec3(1.0, 0.0, 0.0); // #FF0000
const vec3 CHARGE_OUTPUT_COLOR = vec3(1.0, 0.1200000, 0.0800000); // #FF1F14
const float CHARGE_MARKER_EPSILON = 0.005;
// Reserved only for the centre of a WorldWeaponPickup shine band. It is
// intentionally absent from generic palettes.
const vec3 PICKUP_SHINE_SEMANTIC_MARKER = vec3(1.0, 0.0, 1.0);
const vec3 PICKUP_SHINE_OUTPUT_COLOR = vec3(1.0, 1.0, 1.0); // #FFFFFF
const float PICKUP_SHINE_MARKER_EPSILON = 0.005;
// Muzzle smoke cooling ramp. Five reserved markers live in the blue channel of an
// otherwise pure red, so they never collide with the charge marker (blue 0.0) and
// stay distinguishable from each other. Outputs are deliberately muted embers so
// the flash reads as warm light inside a cold palette instead of pasted-on neon.
const float MUZZLE_MARKER_STEP = 0.02;
const vec3 MUZZLE_OUTPUT_1 = vec3(0.7607843, 0.4431373, 0.1960784); // #C27132
const vec3 MUZZLE_OUTPUT_2 = vec3(0.9372549, 0.8039216, 0.2980392); // #EFCD4C
const vec3 MUZZLE_OUTPUT_3 = vec3(0.4313725, 0.2235294, 0.5450980); // #6E398B
const vec3 MUZZLE_OUTPUT_4 = vec3(0.2392157, 0.2039216, 0.2705882); // #3D3445
const vec3 MUZZLE_OUTPUT_5 = vec3(0.2392157, 0.2039216, 0.2705882); // #3D3445

float palette_distance_squared(vec3 source, vec3 candidate) {
	vec3 delta = source - candidate;
	return dot(delta, delta);
}

void consider_palette(vec3 source, vec3 candidate, inout vec3 best, inout float best_distance) {
	float candidate_distance = palette_distance_squared(source, candidate);
	if (candidate_distance < best_distance) {
		best_distance = candidate_distance;
		best = candidate;
	}
}

vec3 nearest_palette_color(vec3 source) {
	vec3 best = PALETTE_00;
	float best_distance = palette_distance_squared(source, best);
	consider_palette(source, PALETTE_01, best, best_distance);
	consider_palette(source, PALETTE_02, best, best_distance);
	consider_palette(source, PALETTE_03, best, best_distance);
	consider_palette(source, PALETTE_04, best, best_distance);
	consider_palette(source, PALETTE_05, best, best_distance);
	consider_palette(source, PALETTE_06, best, best_distance);
	consider_palette(source, PALETTE_07, best, best_distance);
	consider_palette(source, PALETTE_08, best, best_distance);
	consider_palette(source, PALETTE_09, best, best_distance);
	consider_palette(source, PALETTE_10, best, best_distance);
	consider_palette(source, PALETTE_11, best, best_distance);
	consider_palette(source, PALETTE_12, best, best_distance);
	consider_palette(source, PALETTE_13, best, best_distance);
	consider_palette(source, PALETTE_14, best, best_distance);
	consider_palette(source, PALETTE_15, best, best_distance);
	// The alternative extends the original palette with selected reference hues.
	if (palette_scheme == 2) {
		consider_palette(source, vec3(.25,.24,.58), best, best_distance);
		consider_palette(source, vec3(0.2078431, 0.2117647, 0.8431373), best, best_distance); // #3536D7
		consider_palette(source, vec3(.48,.20,.27), best, best_distance);
		consider_palette(source, vec3(.59,.34,.55), best, best_distance);
	}
	return best;
}

bool is_blood_semantic_marker(vec3 source) {
	// The epsilon only absorbs framebuffer precision/rounding. This is an
	// identity comparison, not a red/orange colour heuristic.
	return distance(source, BLOOD_SEMANTIC_MARKER) <= BLOOD_MARKER_EPSILON;
}

bool is_charge_semantic_marker(vec3 source) {
	return distance(source, CHARGE_SEMANTIC_MARKER) <= CHARGE_MARKER_EPSILON;
}

bool is_pickup_shine_semantic_marker(vec3 source) {
	return distance(source, PICKUP_SHINE_SEMANTIC_MARKER) <= PICKUP_SHINE_MARKER_EPSILON;
}

// Returns 1..5 for a muzzle marker, 0 for "not a muzzle marker".
int muzzle_marker_index(vec3 source) {
	if (source.r < 0.995 || source.g > 0.005) {
		return 0;
	}
	float level = source.b / MUZZLE_MARKER_STEP;
	int rounded = int(level + 0.5);
	if (rounded < 1 || rounded > 5) {
		return 0;
	}
	if (abs(level - float(rounded)) > 0.25) {
		return 0;
	}
	return rounded;
}

vec3 muzzle_output_color(int index) {
	if (index <= 1) {
		return MUZZLE_OUTPUT_1;
	}
	if (index == 2) {
		return MUZZLE_OUTPUT_2;
	}
	if (index == 3) {
		return MUZZLE_OUTPUT_3;
	}
	if (index == 4) {
		return MUZZLE_OUTPUT_4;
	}
	return MUZZLE_OUTPUT_5;
}

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	vec3 output_color;
	// Semantic presentation resolution must precede palette selection. Reserved
	// Blood/Charge outputs are intentionally absent from generic palette.
	if (distance(source.rgb, vec3(0.0, 1.0, 1.0)) < 0.05) {
		output_color = PALETTE_00;
	} else if (source.r>.995 && source.g<.005 && source.b>=.515 && source.b<=.605 && abs((source.b-.52)/.04-round((source.b-.52)/.04))<.15) {
		// Extinguisher red paint only; labels and hardware remain scene-lit.
		int phase=int(round((source.b-.52)/.04));
		output_color=phase==0 ? vec3(.91,.25,.26) : (phase==1 ? vec3(.72,.12,.18) : vec3(.43,.055,.095));
	} else if (source.r>.995 && source.g<.005 && source.b>=.195 && source.b<=.405 && abs((source.b-.20)/.04-round((source.b-.20)/.04))<.15) {
		// Reserved fire-only codes: resolve before ANY palette selection.
		int phase=int(round((source.b-.20)/.04));
		output_color=phase==0 ? vec3(1.0,.960784,.698039) : (phase==1 ? vec3(1.0,.819608,.317647) : (phase==2 ? vec3(1.0,.517647,.160784) : vec3(.772549,.243137,.152941)));
		if (phase==4) { output_color=vec3(1.0,.850980,.486275); }
		if (phase==5) { output_color=vec3(.886275,.384314,.160784); }
	} else if (is_blood_semantic_marker(source.rgb)) {
		output_color = BLOOD_OUTPUT_COLOR;
	} else if (distance(source.rgb, BLOOD_AIRBORNE_MARKER) <= BLOOD_MARKER_EPSILON) {
		output_color = BLOOD_AIRBORNE_MARKER;
	} else if (is_charge_semantic_marker(source.rgb)) {
		output_color = CHARGE_OUTPUT_COLOR;
	} else if (is_pickup_shine_semantic_marker(source.rgb)) {
		output_color = PICKUP_SHINE_OUTPUT_COLOR;
	} else if (muzzle_marker_index(source.rgb) > 0) {
		output_color = muzzle_output_color(muzzle_marker_index(source.rgb));
	} else if (palette_enabled) {
		output_color = nearest_palette_color(source.rgb);
	} else {
		output_color = source.rgb;
	}
	COLOR = vec4(output_color, source.a);
}
