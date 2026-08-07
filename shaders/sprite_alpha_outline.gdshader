shader_type canvas_item;

uniform float outline_enabled : hint_range(0.0, 1.0) = 0.0;
uniform float outline_width_source_pixels : hint_range(1.0, 16.0) = 6.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 0.78);
// 仅描边模式：主体像素输出透明，只保留沿 alpha 边缘的描边（收起状态的悬停提示）。
uniform float outline_only : hint_range(0.0, 1.0) = 0.0;


void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec4 result = base;
	if (outline_enabled >= 0.5 && base.a <= 0.01) {
		vec2 offset = TEXTURE_PIXEL_SIZE * outline_width_source_pixels;
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
	} else if (outline_only >= 0.5) {
		result.a = 0.0;
	}
	COLOR = result;
}
