shader_type spatial;
// Solid ground only. Keep it out of the furniture transparency/cutout queue.
render_mode depth_draw_opaque, diffuse_lambert;
#include "res://shaders/dream3d/architecture_cutaway.gdshaderinc"
#include "res://shaders/dream3d/light_noise_contour.gdshaderinc"
uniform sampler2D atlas : filter_nearest_mipmap, repeat_disable;
uniform int world_surface = 0;
uniform vec4 tile_rect = vec4(0.0, 0.0, 16.0, 16.0);
varying vec3 world_normal;
void vertex() {
	architecture_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	if (architecture_cutaway && architecture_visibility(architecture_world) < 0.5) { discard; }
	vec2 atlas_uv = UV;
	if (world_surface > 0) {
		vec2 panel;
		if (world_surface == 1) {
			panel = fract(architecture_world.xz / 2.0);
		} else {
			float along = abs(world_normal.x) > abs(world_normal.z) ? architecture_world.z : architecture_world.x;
			panel = vec2(fract(along / 2.0), clamp(1.0 - (architecture_world.y - architecture_floor_y) / architecture_wall_height, 0.0, 0.999));
		}
		vec2 atlas_size = vec2(textureSize(atlas, 0));
		atlas_uv = (tile_rect.xy + floor(panel * tile_rect.zw) + vec2(.5)) / atlas_size;
	}
	ALBEDO = texture(atlas, atlas_uv).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
void light() {
	float noisy_attenuation = apply_light_noise_contour(ATTENUATION, architecture_world);
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * noisy_attenuation * n_dot_l / PI;
}
