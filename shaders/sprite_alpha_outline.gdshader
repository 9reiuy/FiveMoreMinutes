shader_type canvas_item;

uniform float outline_enabled : hint_range(0.0, 1.0) = 0.0;
uniform float outline_width_source_pixels : hint_range(1.0, 16.0) = 6.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 0.78);
// 仅描边模式：主体像素输出透明，只保留沿 alpha 边缘的描边（收起状态的悬停提示）。
uniform float outline_only : hint_range(0.0, 1.0) = 0.0;
// 当源PNG的非透明像素贴到画布边缘时，用等宽内描边补偿无法向纹理外采样的部分。
// 默认关闭；对话立绘开启，避免为补Padding而移动、缩放或修改源图。
uniform float outline_inner_at_texture_edge : hint_range(0.0, 1.0) = 0.0;
// 受击白色闪烁：命中瞬间将主体像素混向纯白（保留原 alpha），
// 与白描边/死亡动画/伤害数字兼容，由 basic_enemy 短暂驱动后归零。
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
// 可选的整体色调校。默认强度为0，不影响敌人、玩家等共用此Shader的节点；
// 对话立绘单独开启轻度冷蓝滤镜，描边分支仍保持原outline_color。
uniform vec4 color_filter : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float color_filter_strength : hint_range(0.0, 1.0) = 0.0;


void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec4 result = base;
	vec2 offset = TEXTURE_PIXEL_SIZE * outline_width_source_pixels;
	result.rgb = mix(result.rgb, result.rgb * color_filter.rgb, color_filter_strength);
	result.rgb = mix(result.rgb, vec3(1.0), flash_amount);
	if (outline_enabled >= 0.5 && base.a <= 0.01) {
		float nearby_alpha = 0.0;
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(offset.x, 0.0)).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(offset.x, 0.0)).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, offset.y)).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(0.0, offset.y)).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + offset).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - offset).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(offset.x, -offset.y)).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-offset.x, offset.y)).a);
		result = vec4(outline_color.rgb, outline_color.a * nearby_alpha);
	} else if (outline_enabled >= 0.5 && outline_inner_at_texture_edge >= 0.5 && base.a > 0.01) {
		bool touches_texture_edge = UV.x <= offset.x || UV.x >= 1.0 - offset.x || UV.y <= offset.y || UV.y >= 1.0 - offset.y;
		if (touches_texture_edge) {
			result = vec4(outline_color.rgb, max(base.a, outline_color.a));
		}
	} else if (outline_only >= 0.5) {
		result.a = 0.0;
	}
	COLOR = result;
}
