extends Control
const CRT_COLORS := preload("res://scripts/ui/screen_wall_colors.gd")
## Presentation only; the native HSlider still owns dragging, stepping and value.
var slider: HSlider
var hovering := false
func bind(control: HSlider) -> void:
	slider=control
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slider.value_changed.connect(func(_value: float):queue_redraw())
	slider.resized.connect(queue_redraw)
	slider.mouse_entered.connect(func():hovering=true;queue_redraw())
	slider.mouse_exited.connect(func():hovering=false;queue_redraw())
func _draw() -> void:
	if slider==null: return
	var colour:=CRT_COLORS.primary()
	var track:=Rect2(2.5,floorf(size.y*0.5)-4.5,maxf(1.0,size.x-5.0),9.0)
	draw_rect(track,Color("03090e"))
	draw_rect(track,colour,false,1.0)
	var ratio:=clampf(inverse_lerp(slider.min_value,slider.max_value,slider.value),0.0,1.0)
	var fill_width:=maxf(0.0,track.size.x*ratio-2.0)
	var inner:=Rect2(track.position+Vector2.ONE,Vector2(fill_width,track.size.y-2.0))
	var segments:=PackedVector2Array()
	var height:=inner.size.y
	if fill_width>0.0:
		for offset in range(-int(height),int(ceilf(fill_width)),4):
			var from:=maxf(0.0,-float(offset)/height)
			var to:=minf(1.0,(fill_width-float(offset))/height)
			if from>=to: continue
			segments.append(inner.position+Vector2(offset+height*from,height-height*from))
			segments.append(inner.position+Vector2(offset+height*to,height-height*to))
	if not segments.is_empty(): draw_multiline(segments,colour,1.0)
	var cursor_x:=floorf(track.position.x+track.size.x*ratio)+0.5
	var top:=track.position.y-2.0
	var bottom:=track.end.y+2.0
	var cursor_colour:=CRT_COLORS.hover() if hovering else colour
	draw_line(Vector2(cursor_x,top),Vector2(cursor_x,bottom),cursor_colour,1.0)
	draw_line(Vector2(cursor_x-2.0,top),Vector2(cursor_x+2.0,top),cursor_colour,1.0)
	draw_line(Vector2(cursor_x-2.0,bottom),Vector2(cursor_x+2.0,bottom),cursor_colour,1.0)
