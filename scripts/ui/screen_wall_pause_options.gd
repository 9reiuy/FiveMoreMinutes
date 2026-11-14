extends "res://scripts/ui/pixel_option_group.gd"
signal hover_requested
func _activate(option: Button,play_sound: bool) -> void:
	var changed:=_active_option!=option
	super._activate(option,false)
	if changed and play_sound: hover_requested.emit()

func _target_rect(option: Button) -> Rect2:
	var rect:=super._target_rect(option)
	if solid_fill and option.alignment==HORIZONTAL_ALIGNMENT_CENTER:
		var leading:=CONFIG.option_frame_padding.x+CONFIG.option_triangle_size+CONFIG.option_triangle_text_gap
		var fill_width:=rect.size.x-leading
		rect.position.x=roundf(option.get_global_rect().get_center().x-fill_width*0.5-leading-get_global_rect().position.x)
	return rect
