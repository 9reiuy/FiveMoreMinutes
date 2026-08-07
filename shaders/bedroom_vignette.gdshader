shader_type canvas_item;

// 像素风动态暗角：边缘压暗、中心透明，颜色偏深蓝黑（非纯黑）。
// 先把 UV 按像素块取整再计算距离，并对 alpha 做分段量化，
// 得到低分辨率/分段的像素感暗角，而不是平滑的现代摄影暗角。

uniform vec3 vignette_color : source_color = vec3(0.063, 0.09, 0.133);
// 强度不设人为上限（hint_range 仅是编辑器滑条提示，不截断运行时值）；
// 超过 1.0 的 alpha 由 GPU 渲染时自然限制，不在 Shader 内 clamp。
uniform float strength : hint_range(0.0, 4.0) = 0.1;
uniform float inner_radius : hint_range(0.0, 1.0) = 0.42;
uniform float softness : hint_range(0.05, 1.0) = 0.62;
uniform float bands : hint_range(2.0, 16.0) = 6.0;
uniform float pixel_size : hint_range(1.0, 8.0) = 3.0;
uniform vec2 resolution = vec2(640.0, 360.0);

void fragment() {
	vec2 block = max(vec2(1.0), vec2(pixel_size));
	vec2 quantized_uv = (floor(UV * resolution / block) + vec2(0.5)) * block / resolution;
	vec2 centered = (quantized_uv - vec2(0.5)) * 2.0;
	float dist = length(centered) * 0.70710678;
	float raw_alpha = smoothstep(inner_radius, inner_radius + softness, dist) * strength;
	float quantized_alpha = floor(raw_alpha * bands + 0.5) / bands;
	COLOR = vec4(vignette_color, quantized_alpha);
}
