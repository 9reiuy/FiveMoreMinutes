extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var theme: Theme = load("res://assets/fonts/pixel_theme.tres")
	var font: Font = theme.default_font
	for fs in [12, 14, 16, 17]:
		var h := font.get_height(fs)
		var ss := font.get_string_size("配色滤镜", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var ss2 := font.get_string_size("继续", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		print("fs=%d get_height=%.2f str_h=%.2f 配色滤镜=%.1fx%.1f 继续=%.1fx%.1f" % [fs, h, ss.y, ss.x, ss.y, ss2.x, ss2.y])
	var pad: Vector2 = load("res://resources/demo_config.tres").option_frame_padding
	var tri: float = load("res://resources/demo_config.tres").option_triangle_size
	print("pad=", pad, " tri=", tri, " frame_h@17=", ceilf(maxf(font.get_height(17), tri) + pad.y * 2.0))
	print("frame_h@14=", ceilf(maxf(font.get_height(14), tri) + pad.y * 2.0))
	quit(0)
