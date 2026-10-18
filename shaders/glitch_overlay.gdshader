shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// 全屏 glitch 效果：水平撕裂条 + RGB 分离 + 扫描噪点。
// 用于悬停删除消息等"系统故障"瞬间，播放时间应 < 1 秒。

void fragment() {
	float opacity = COLOR.a;
	float t = TIME;
	vec2 uv = SCREEN_UV;
	// 水平撕裂条：按扫描行随机水平位移。
	float band = floor(uv.y * 20.0);
	float seed = fract(sin(band * 127.1 + t * 40.0) * 43758.5453);
	float active = step(0.55, fract(t * 7.0 + band * 0.7));
	float shift = (seed - 0.5) * 0.05 * active;
	uv.x += shift;
	// RGB 分离：红/蓝通道反向抖动。
	vec3 col;
	col.r = texture(screen_texture, uv + vec2(0.006 * sin(t * 60.0), 0.0)).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - vec2(0.006 * cos(t * 55.0), 0.0)).b;
	// 扫描噪点。
	float noise = fract(sin(dot(SCREEN_UV * 680.0 + t * 120.0, vec2(12.9898, 78.233))) * 43758.5453);
	col += (noise - 0.5) * 0.15 * active;
	COLOR = vec4(col, opacity);
}
