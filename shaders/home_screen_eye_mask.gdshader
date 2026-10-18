shader_type canvas_item;

// The TextureRect itself moves in 2D. Only mask sampling is compensated so
// the irregular alpha mask stays fixed in the shared 1260x710 canvas.
uniform sampler2D mask_texture : source_color, filter_nearest, repeat_disable;
uniform vec2 mask_offset_uv = vec2(0.0);

void fragment() {
	float mask_alpha = texture(mask_texture, UV + mask_offset_uv).a;
	// COLOR already contains the unmodified eye texture and node modulation.
	// Only multiply alpha: sampling TEXTURE again and multiplying RGB by COLOR
	// would square the source color and cause the visible eye to shift darker.
	COLOR.a *= mask_alpha;
}
