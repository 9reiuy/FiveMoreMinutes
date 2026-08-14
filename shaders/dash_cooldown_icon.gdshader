shader_type canvas_item;

// 0 = 冲刺可用，1 = 完全冷却中。灰色只覆盖图标自身的非透明像素，
// 因此不会在图标外生成一条独立矩形进度条。
uniform float cooldown_ratio : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cooldown_color : source_color = vec4(0.29, 0.33, 0.37, 1.0);
uniform float cooldown_mix : hint_range(0.0, 1.0) = 0.88;


void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float covered = step(1.0 - cooldown_ratio, UV.y) * step(0.01, base.a);
	vec3 gray = vec3(dot(base.rgb, vec3(0.299, 0.587, 0.114)));
	vec3 cooled = mix(gray, cooldown_color.rgb, 0.58);
	base.rgb = mix(base.rgb, cooled, covered * cooldown_mix);
	COLOR = base;
}
