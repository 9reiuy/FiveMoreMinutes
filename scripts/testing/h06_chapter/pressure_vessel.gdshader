shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D trim : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D trim_normal : hint_normal, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform vec4 enamel : source_color = vec4(.87, .85, .79, 1.);
uniform vec4 collar : source_color = vec4(.22, .24, .24, 1.);
uniform vec4 yellow : source_color = vec4(.91, .73, .13, 1.);
uniform float oxide = 0.;
varying float station;
varying float radius;
varying float end_face;

void vertex() {
	// Dimensions are the native coordinates of Quaternius' Prop_Barrel_Large.
	station = (VERTEX.y - .0082) / 1.1026;
	radius = length(VERTEX.xz) / .255;
	end_face = abs(NORMAL.y);
}

void fragment() {
	float band = max(1. - smoothstep(.12, .14, station), smoothstep(.76, .79, station));
	float lip = (1. - smoothstep(.012, .020, abs(station - .18)))
			+ (1. - smoothstep(.014, .022, abs(station - .80)));
	float face = smoothstep(.60, .90, end_face);
	vec3 coating = mix(enamel.rgb, collar.rgb, band);
	coating = mix(coating, enamel.rgb, face * smoothstep(.57, .68, radius));
	float rim = face * (1. - smoothstep(.032, .070, abs(radius - .70)));
	vec3 original = texture(trim, UV).rgb;
	float wear = dot(original, vec3(.27, .55, .18));
	vec3 finish = mix(coating, yellow.rgb, clamp(lip + rim, 0., 1.));
	float stain = (1. - smoothstep(.07, .38, station)) * smoothstep(.27, .70, 1. - wear);
	finish = mix(finish, vec3(.18,.079,.032), oxide * clamp(stain + lip * .40, 0., 1.));
	ALBEDO = finish * (.73 + .35 * wear);
	NORMAL_MAP = texture(trim_normal, UV).rgb;
	NORMAL_MAP_DEPTH = .27;
	METALLIC = .14;
	ROUGHNESS = .71;
	SPECULAR = .25;
}
