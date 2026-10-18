extends DreamDialogueBubble
## Reception presentation only; legacy tutorial bubble remains unchanged.
var _resize: Tween
var _fade: Tween
var _prefix: String=""
var arrow_tip:=Vector2.ZERO
var _below:=false
var text_clip: Control
var _text_width:=32.0
var _hint:=false
var _tail_layer: Control

func _ready() -> void:
	super._ready()
	# The join is drawn over the frame, so its border cannot split the fill.
	_tail_layer=Control.new()
	_tail_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_tail_layer)
	move_child(_tail_layer,background.get_index()+1)
	_tail_layer.draw.connect(_draw_joined_tail)
	# Containers can exceed the animated frame's minimum size. Give text an
	# independent clipped viewport; shape at the target width during expansion.
	text_clip=Control.new()
	text_clip.name="TextClip"
	text_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	text_clip.clip_contents=true
	add_child(text_clip)
	dialogue_label.reparent(text_clip)
	dialogue_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	margin_container.hide()
	hide()

func present_hint(speaker: Vector2) -> void:
	if not visible or _is_dismissing:
		show_dialogue("...",speaker,[])
		_hint=true
		dialogue_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		set_typing_progress(0,3)
		progress_bar_container.hide()
	set_speaker_hud_position(speaker)

func _setup_options() -> void:
	_is_interrupt_mode=false
	interrupt_container.hide(); normal_options_container.hide(); options_container.hide()

func show_dialogue(text: String, speaker: Vector2, choices: Array, interrupt_text: String="") -> void:
	if _resize and _resize.is_valid(): _resize.kill()
	if _fade and _fade.is_valid(): _fade.kill()
	if _dismiss_tween and _dismiss_tween.is_valid(): _dismiss_tween.kill()
	_hint=false
	dialogue_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	super.show_dialogue(text,speaker,[],"")
	progress_bar_container.show()
	_prefix=""; dialogue_label.text=""; dialogue_label.visible_characters=-1
	for item in [["margin_left",8],["margin_right",8],["margin_top",6],["margin_bottom",12]]:
		margin_container.add_theme_constant_override(item[0],item[1])
	background.patch_margin_left=6; background.patch_margin_right=6
	background.patch_margin_top=6; background.patch_margin_bottom=6
	custom_minimum_size=Vector2.ZERO; size=Vector2(48,26)
	options_container.hide(); speaker_arrow.hide()
	modulate.a=0
	_fade=create_tween(); _fade.tween_property(self,"modulate:a",1.0,.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_layout()

func set_typing_progress(progress_ratio: float, visible_chars: int) -> void:
	_progress=clampf(progress_ratio,0,1)
	var prefix:=_current_text.substr(0,visible_chars)
	if prefix!=_prefix:
		_prefix=prefix; dialogue_label.text=prefix; dialogue_label.visible_characters=-1
		var font: Font=FONT_HELPER.get_font()
		var width:=clampf(font.get_string_size(prefix,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+16,48,220)
		_text_width=width-16
		dialogue_label.size=Vector2(_text_width,0)
		# Label's own shaping accounts for smart wrapping, fallback glyphs and
		# theme line spacing, instead of estimating with a different break mode.
		var height:=maxf(26,dialogue_label.get_minimum_size().y+(12 if _hint else 20))
		if _resize and _resize.is_valid(): _resize.kill()
		_resize=create_tween(); _resize.tween_property(self,"size",Vector2(ceilf(width),ceilf(height)),.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_layout()

func _process(_delta: float) -> void:
	if visible: _layout()

func _layout() -> void:
	_update_bubble_position()
	background.size=size
	if text_clip:
		text_clip.position=Vector2(8,14 if _below and not _hint else 6)
		text_clip.size=Vector2(maxf(1,size.x-16),maxf(1,size.y-(12 if _hint else 20)))
		dialogue_label.position=Vector2.ZERO
		dialogue_label.size=Vector2(_text_width,dialogue_label.get_minimum_size().y)
	progress_bar_container.position=Vector2(8,3 if _below else roundf(size.y-9))
	progress_bar_container.size=Vector2(maxf(1,size.x-16),5)
	_update_progress_bar(_progress)
	_update_bubble_position(); queue_redraw()

func _update_bubble_position() -> void:
	_below=_speaker_hud_pos.y-size.y-14<SCREEN_MARGIN
	var y:=_speaker_hud_pos.y+24 if _below else _speaker_hud_pos.y-size.y-14
	position=Vector2(roundf(clampf(_speaker_hud_pos.x-size.x*.5,SCREEN_MARGIN,maxf(SCREEN_MARGIN,SCREEN_SIZE.x-size.x-SCREEN_MARGIN))),roundf(clampf(y,SCREEN_MARGIN,maxf(SCREEN_MARGIN,SCREEN_SIZE.y-size.y-SCREEN_MARGIN))))
	update_speaker_position()

func update_speaker_position() -> void:
	if speaker_arrow: speaker_arrow.hide()
	arrow_tip=(_speaker_hud_pos-position+Vector2(0,4 if _below else -3)).round()
	queue_redraw()
	if _tail_layer: _tail_layer.queue_redraw()

func _draw_joined_tail() -> void:
	if not visible: return
	var x:=clampf(arrow_tip.x,9,maxf(9,size.x-9))
	var y:=1.0 if _below else size.y-1
	var outer:=PackedVector2Array([Vector2(x-7,y),Vector2(x+7,y),arrow_tip])
	var inner:=PackedVector2Array([Vector2(x-4,y),Vector2(x+4,y),arrow_tip.move_toward(Vector2(x,y),2)])
	_tail_layer.draw_colored_polygon(outer,Color("242424"))
	if _hint:
		_tail_layer.draw_colored_polygon(inner,Color("485378"))
		return
	var bar:=Rect2(progress_bar_container.position,progress_bar_container.size)
	var join_y:=bar.position.y+2 if not _below else bar.end.y-2
	var bridge:=PackedVector2Array([Vector2(x-4,join_y),Vector2(x+4,join_y),Vector2(x+4,y),Vector2(x-4,y)])
	# Tail and bridge use the same wipe boundary as the countdown strip.
	var cut:=bar.position.x+roundf(bar.size.x*_progress)
	var wipe:=PackedVector2Array([Vector2(cut,-100),Vector2(size.x,-100),Vector2(size.x,size.y+100),Vector2(cut,size.y+100)])
	for shape in [bridge,inner]:
		_tail_layer.draw_colored_polygon(shape,Color("242424"))
		if _progress<1:
			for filled in Geometry2D.intersect_polygons(shape,wipe):
				_tail_layer.draw_colored_polygon(filled,Color("485378"))

func dismiss(fade_time: float=.18) -> void:
	if _is_dismissing: return
	_is_dismissing=true
	if _fade and _fade.is_valid(): _fade.kill()
	if _resize and _resize.is_valid(): _resize.kill()
	_fade=create_tween()
	_fade.tween_property(self,"modulate:a",0.0,fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.tween_callback(func(): hide(); _is_dismissing=false)
