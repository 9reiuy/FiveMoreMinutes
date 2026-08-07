shader_type canvas_item;

// 门口交互半圆白光：真正按距离计算的径向渐变，从屏幕底部中央向上扩散。
// 承载 ColorRect 只覆盖底部中间三分之一（door_interaction.gd 布局），
// 圆心为矩形底边中心（局部 UV (0.5, 1.0) 即屏幕底边中央）。
//
// 关键：ColorRect 无纹理，TEXTURE_PIXEL_SIZE 不可靠（恒为 1），
// 因此由脚本传入 rect_size 重建像素坐标，避免 UV 未换算导致整块矩形
// 均匀发光显示成"方块"。像素空间距离天然 aspect 正确（圆是真圆）。
// alpha 在 [inner_radius, outer_radius] 内 smoothstep 衰减，
// dist >= outer_radius 强制归零，半圆外保证完全透明。
// vertical_scale 只拉伸垂直方向距离（椭圆距离）：水平半径仍为 outer_radius，
// 左右边界处 alpha 仍为 0，光效向上延伸但水平范围不变。
// dist 按 pixel_step_size 像素步长量化出像素风同心环，<=0 时不量化。

uniform vec2 rect_size = vec2(213.3, 106.7);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float inner_radius = 0.0;
uniform float outer_radius = 106.7;
uniform float vertical_scale = 1.0;
uniform float pixel_step_size = 4.0;
uniform vec3 glow_color : source_color = vec3(0.9, 0.96, 1.0);

void fragment() {
	vec2 pixel = UV * rect_size;
	vec2 center = vec2(rect_size.x * 0.5, rect_size.y);
	vec2 offset = pixel - center;
	offset.y /= max(vertical_scale, 0.001);
	float dist = length(offset);
	if (pixel_step_size > 0.0) {
		dist = floor(dist / pixel_step_size) * pixel_step_size;
	}
	float alpha = 1.0 - smoothstep(inner_radius, outer_radius, dist);
	if (dist >= outer_radius) {
		alpha = 0.0;
	}
	COLOR = vec4(glow_color, strength * alpha);
}
