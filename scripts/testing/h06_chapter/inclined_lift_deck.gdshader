shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D worn_surface : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D panel_trim : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform vec2 deck_half = vec2(14.0, 10.6);
uniform float dock_half_width = 2.6;
uniform int laser_count = 0;
uniform vec4 laser_segments[6];
varying vec2 plate_position;
varying float upper_face;

float line_at(float distance_to_line, float width, float aa) {
	return 1.0 - smoothstep(width, width + aa, abs(distance_to_line));
}

float laser_spill(vec2 point) {
	float spill = 0.0;
	for (int index = 0; index < laser_count; index++) {
		vec4 segment = laser_segments[index];
		vec2 axis = segment.zw - segment.xy;
		float span = length(axis);
		if (span < .032) { continue; }
		vec2 delta = point - segment.xy;
		vec2 forward = axis / span;
		float along = dot(delta, forward);
		float lateral = dot(delta, vec2(-forward.y, forward.x)) / 1.52;
		float r2 = lateral * lateral;
		float falloff = exp2(-3.6 * r2) * (1.0 - smoothstep(.54, 1.0, r2));
		float ends = smoothstep(-.48, .16, along) * (1.0 - smoothstep(span - .50, span, along));
		spill = max(spill, falloff * ends);
	}
	return spill;
}

void vertex() {
	plate_position = VERTEX.xz;
	upper_face = NORMAL.y;
}

void fragment() {
	vec2 p = plate_position;
	vec2 edge = deck_half - abs(p);
	float aa = clamp(max(fwidth(p.x), fwidth(p.y)), .008, .11);
	float wear = dot(texture(worn_surface, p / 4.6).rgb, vec3(.27, .56, .17));
	float longer_wear = dot(texture(worn_surface, p / vec2(9.1, 4.2) + .43).rgb, vec3(.27, .56, .17));
	vec3 panel = texture(panel_trim, UV).rgb;
	float plate_detail = clamp(dot(panel, vec3(.27, .56, .17)) * 1.12, .0, .36);
	vec3 steel = vec3(.235, .242, .243) * (.68 + plate_detail + clamp(wear * 2.2, .0, .62));
	steel *= .90 + .23 * longer_wear;
	ROUGHNESS = clamp(.67 + wear * .38, .68, .91);
	METALLIC = .16;
	if (upper_face > .65) {
		vec2 pitch = vec2(3.48, 3.52);
		vec2 to_joint = abs(fract(p / pitch + .5) - .5) * pitch;
		float seam = max(line_at(to_joint.x, .016, aa), line_at(to_joint.y, .017, aa));
		float joint_wear = max(line_at(to_joint.x - .07, .035, aa), line_at(to_joint.y - .072, .035, aa));
		steel = mix(steel * (1.0 + joint_wear * .09), steel * .48, seam * .73);
		float corner_bolts = 1.0 - smoothstep(.032, .043 + aa, length(to_joint - vec2(.138, .126)));
		steel *= 1.0 - corner_bolts * .55;
		vec2 hatch = vec2(deck_half.x * .68, deck_half.y * .61) - abs(p);
		float hatch_edge = min(hatch.x, hatch.y) - max(1.1 - max(hatch.x, hatch.y), 0.);
		steel *= 1.0 - line_at(hatch_edge, .032, aa) * .61;
		steel *= 1.0 + smoothstep(-.02, .08, hatch_edge) * .065;
		float vent_banks = float(edge.x > .65 && edge.x < 1.34 && abs(abs(p.y) - deck_half.y * .51) < 2.35);
		float slot = abs(fract(p.y / .22 + .5) - .5) * .22;
		steel *= 1.0 - vent_banks * line_at(slot, .029, aa) * .68;
		float markings = line_at(min(edge.x, edge.y) - .55, .034, aa);
		float danger = float(p.y > 0. && edge.y > .22 && edge.y < .68 && abs(p.x) < dock_half_width);
		float stripes = smoothstep(.19, .22, fract((p.x - edge.y*.66) / .69));
		float rubbed_paint = smoothstep(.028, .255, wear * .65 + longer_wear * .35);
		steel = mix(steel, vec3(.40, .43, .43), markings * .44);
		steel = mix(steel, vec3(.041, .045, .046), danger * .66);
		steel = mix(steel, vec3(.58, .246, .067), danger * stripes * (.72 + rubbed_paint * .21));
	} else {
		steel *= .58;
	}
	ALBEDO = steel;
	if (upper_face > .65 && laser_count > 0) {
		EMISSION = steel * vec3(1.11, .086, .036) * laser_spill(p);
	}
}
