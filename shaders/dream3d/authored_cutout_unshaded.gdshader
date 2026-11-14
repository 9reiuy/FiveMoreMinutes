shader_type spatial;
render_mode unshaded;
#include "res://shaders/dream3d/occlusion_cutout.gdshaderinc"
uniform vec4 albedo_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool textured = false;
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
varying flat float cutout_camera_pass;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	cutout_camera_pass = float(all(equal(INV_VIEW_MATRIX[3], MAIN_CAM_INV_VIEW_MATRIX[3])));
}

void fragment() {
	if (main_camera_cutout(SCREEN_UV, cutout_camera_pass)) {
		discard;
	}
	ALBEDO = albedo_color.rgb;
	if (textured) {
		ALBEDO *= texture(albedo_texture, UV).rgb;
	}
}
