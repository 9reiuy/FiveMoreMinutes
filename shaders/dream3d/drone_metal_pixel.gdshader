shader_type spatial;
// Pixel metal for the drone model lab: the same 32-texel swatch language as
// office_pixel_surface, but with a real metal response (the office material
// pins ROUGHNESS = 1 and SPECULAR = 0, so it can never look like iron).
render_mode blend_mix, depth_draw_always, diffuse_burley, specular_schlick_ggx;

uniform sampler2D pixel_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform bool object_space = true;
uniform bool glow = false;
uniform bool face_hierarchy = true;
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.85;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.32;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.55;
// Painted accents (hazard stripes, blade tips) sit on top of metal: they keep a
// dielectric response so they read as paint, not chrome.
uniform float paint_amount : hint_range(0.0, 1.0) = 0.0;

varying vec3 pattern_position;
varying vec3 pattern_normal;

void vertex() {
	vec3 scale = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);
	pattern_position = object_space ? VERTEX * scale : (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	pattern_normal = object_space ? NORMAL : normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = abs(pattern_normal);
	vec2 uv = n.y > max(n.x, n.z) ? pattern_position.xz : (n.x > n.z ? pattern_position.zy : pattern_position.xy);
	vec3 texel = texture(pixel_texture, uv).rgb;
	vec3 albedo = base_color.rgb * texel;
	// The swatch doubles as a roughness mask: recessed texels (rivets, panel
	// seams, edge shadow) scatter more, raised faces stay tighter.  Without this
	// the sky reflection reads as one glossy white sheet instead of brushed iron.
	float texel_luma = dot(texel, vec3(0.299, 0.587, 0.114));
	float roughness_varied = clamp(roughness_amount + (1.0 - texel_luma) * 0.22, 0.05, 1.0);
	if (face_hierarchy) {
		// Same face hierarchy the furniture variant uses: top plates catch light,
		// undersides stay in shadow, vertical faces sit between.
		albedo *= pattern_normal.y > 0.55 ? 1.16 : (pattern_normal.y < -0.55 ? 0.68 : 0.82);
	}
	ALBEDO = albedo;
	METALLIC = metallic_amount * (1.0 - paint_amount);
	ROUGHNESS = mix(roughness_varied, 0.62, paint_amount);
	SPECULAR = specular_amount;
	if (glow) {
		EMISSION = albedo * 1.4;
	}
}
