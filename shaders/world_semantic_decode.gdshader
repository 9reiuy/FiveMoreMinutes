shader_type canvas_item;
render_mode unshaded, blend_disabled;

// Decode the reserved effect colors emitted by gameplay materials.
// Every other pixel keeps the composited world color and alpha.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool tutorial_gate_indicators = false;

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
	int muzzle_index = muzzle_marker_index(source.rgb);
	if (tutorial_gate_indicators && distance(source.rgb, vec3(0.0, 1.0, 0.0)) < 0.005) {
		output_color = vec3(0.28, 0.90, 0.43);
	} else if (source.r>.995 && source.g<.005 && source.b>=.515 && source.b<=.605 && abs((source.b-.52)/.04-round((source.b-.52)/.04))<.15) {
		// Extinguisher red paint only; labels and hardware remain scene-lit.
		int phase=int(round((source.b-.52)/.04));
		output_color=phase==0 ? vec3(.91,.25,.26) : (phase==1 ? vec3(.72,.12,.18) : vec3(.43,.055,.095));
	} else if (source.r>.995 && source.g<.005 && source.b>=.195 && source.b<=.405 && abs((source.b-.20)/.04-round((source.b-.20)/.04))<.15) {
		// Reserved fire-only codes: resolve the reserved fire codes.
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
	} else if (muzzle_index > 0) {
		output_color = muzzle_output_color(muzzle_index);
	} else {
		output_color = source.rgb;
	}
	COLOR = vec4(output_color, source.a);
}
