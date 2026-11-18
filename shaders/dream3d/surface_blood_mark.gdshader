shader_type spatial;
render_mode diffuse_burley, specular_disabled;
#include "res://shaders/dream3d/occlusion_cutout.gdshaderinc"

uniform sampler2D blood_texture : source_color, filter_nearest, repeat_disable;
uniform bool occlusion_cutout_enabled = false;
varying flat float cutout_camera_pass;

void vertex() {
	cutout_camera_pass = float(all(equal(INV_VIEW_MATRIX[3], MAIN_CAM_INV_VIEW_MATRIX[3])));
}

void fragment() {
	vec4 blood = texture(blood_texture, UV);
	if (blood.a < 0.5 || (occlusion_cutout_enabled && main_camera_cutout(SCREEN_UV, cutout_camera_pass))) {
		discard;
	}
	ALBEDO = blood.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	EMISSION = blood.rgb * 0.42;
}
