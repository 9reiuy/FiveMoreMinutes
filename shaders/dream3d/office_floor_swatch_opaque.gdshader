shader_type spatial;
// Shared floor swatches; furniture retains office_pixel_surface unchanged.
render_mode depth_draw_opaque, diffuse_lambert;
#include "res://shaders/dream3d/architecture_cutaway.gdshaderinc"
#include "res://shaders/dream3d/light_noise_contour.gdshaderinc"
uniform sampler2D pixel_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform bool object_space = false;
uniform bool glow = false;
uniform bool wall_surface = false;
uniform bool sample_furniture_surface = false;
varying vec3 pattern_position;
varying vec3 pattern_normal;
void vertex() {
	architecture_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	pattern_position = object_space ? VERTEX * scale : architecture_world;
	pattern_normal = object_space ? NORMAL : normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	if (architecture_cutaway && architecture_visibility(architecture_world) < 0.5) { discard; }
	vec3 n = abs(pattern_normal);
	vec2 uv = n.y > max(n.x, n.z) ? pattern_position.xz : (n.x > n.z ? pattern_position.zy : pattern_position.xy);
	ALBEDO = base_color.rgb * texture(pixel_texture, uv).rgb;
	if (sample_furniture_surface) {
		ALBEDO *= pattern_normal.y > 0.55 ? 1.16 : (pattern_normal.y < -0.55 ? 0.68 : 0.82);
	}
	if (wall_surface) {
		float y = floor(architecture_world.y * 32.0) / 32.0;
		if (y < .125) { ALBEDO *= .42; }
		else if (y < .75) { ALBEDO *= .78; }
		else if (y < .8125) { ALBEDO = min(base_color.rgb * 1.18, vec3(.85)); }
		if (y >= architecture_wall_height - .0625) { ALBEDO = min(base_color.rgb * 1.18, vec3(.85)); }
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (glow) { EMISSION = ALBEDO * 0.6; }
}
void light() {
	float noisy_attenuation = apply_light_noise_contour(ATTENUATION, architecture_world);
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * noisy_attenuation * n_dot_l / PI;
}
