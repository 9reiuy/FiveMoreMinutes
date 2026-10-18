shader_type spatial;
// Aim feedback only. This pass is the locked-on outline, so it stays white and
// unlit. The door body keeps its own material, lighting and shadow casting.
// 历史根因一：gdshader 只支持 // 注释，旧文件的 ## 使整段 shader 编译失败，
// material_overlay 从未渲染过任何轮廓。
// 历史根因二：depth_test_disabled + inverted hull 会把整个门面涂白（背面壳
// 覆盖内部）。改为深度测试：基线 pass 写下的门面深度剔除内部壳片元，只留轮廓。
render_mode unshaded, cull_front, shadows_disabled, depth_draw_never;
// 正式宽度 = base_world_width（世界空间径向外扩）+ extra_screen_pixels（屏幕像素，含已批准的 +2px）。
uniform float base_world_width = 0.025;
uniform float extra_screen_pixels = 2.0;
// 朝相机整体前推量（< 门厚 0.1）：与门框/墙齐平时轮廓不被深度吃掉。
uniform float extra_depth_bias = 0.05;
// 兼容渲染器下 vertex 阶段拿不到可靠 VIEWPORT_SIZE，由 PhysicalDoor3D 下发实际值。
uniform vec2 viewport_size = vec2(1280.0, 720.0);

void vertex() {
	// 世界空间径向外扩：从门体世界中心向外推出固定宽度，不受门板非均匀缩放、
	// 法线朝向与视线角度影响，轮廓四面均匀增长。
	vec3 world_center = (MODEL_MATRIX * vec4(vec3(0.0), 1.0)).xyz;
	vec3 world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 shifted = world_vertex + normalize(world_vertex - world_center + vec3(0.00001)) * base_world_width;
	// 朝相机前推（沿视线方向，与深度约定无关）：内部壳片元仍比门面深 0.05、
	// 会被门面深度剔除；外缘则稳定盖过齐平的门框与墙。
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - shifted);
	shifted += to_camera * extra_depth_bias;
	vec4 expanded = PROJECTION_MATRIX * VIEW_MATRIX * vec4(shifted, 1.0);
	vec4 original = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_vertex, 1.0);
	vec2 pixel_direction = (expanded.xy / expanded.w - original.xy / original.w) * viewport_size;
	if (length(pixel_direction) > 0.00001) {
		expanded.xy += normalize(pixel_direction) * (2.0 * extra_screen_pixels / viewport_size) * expanded.w;
	}
	POSITION = expanded;
}
void fragment() { ALBEDO = vec3(1.0); }
