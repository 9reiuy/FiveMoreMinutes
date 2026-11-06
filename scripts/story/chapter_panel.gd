extends CanvasLayer
## Crisp, reusable narrative UI, independent of world palette.
signal choice_selected(id: String)
const FONT=preload("res://scripts/ui/crisp_interaction_font.gd")
var status: Label
var center: PanelContainer
var title: Label
var detail: Label
var choices: VBoxContainer
func _ready() -> void:
	layer=130; process_mode=Node.PROCESS_MODE_ALWAYS
	status=Label.new(); status.position=Vector2(16,15); status.size=Vector2(608,36)
	status.add_theme_font_override("font",FONT.get_font()); status.add_theme_font_size_override("font_size",12)
	status.add_theme_color_override("font_color",Color("c1c8da")); status.add_theme_color_override("font_shadow_color",Color("080b13")); status.add_theme_constant_override("shadow_offset_x",1); status.add_theme_constant_override("shadow_offset_y",1)
	status.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(status)
	status.hide()
	center=PanelContainer.new(); center.position=Vector2(112,94); center.size=Vector2(416,170); add_child(center)
	var skin:=StyleBoxFlat.new(); skin.bg_color=Color("101723"); skin.border_color=Color("788498"); skin.set_border_width_all(1); skin.content_margin_left=16; skin.content_margin_right=16; skin.content_margin_top=14; skin.content_margin_bottom=14; center.add_theme_stylebox_override("panel",skin)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",9); center.add_child(box)
	title=Label.new(); title.add_theme_font_size_override("font_size",16); box.add_child(title)
	detail=Label.new(); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail.custom_minimum_size.x=376; box.add_child(detail)
	choices=VBoxContainer.new(); choices.add_theme_constant_override("separation",5); box.add_child(choices)
	for label in [title,detail]: label.add_theme_font_override("font",FONT.get_font())
	detail.add_theme_font_size_override("font_size",12); center.hide()
func show_status(text: String) -> void: status.text=text
func offer(heading: String,text: String,options: Array) -> void:
	title.text=heading; detail.text=text
	var industrial:=heading.begins_with("MAINT")
	if industrial:
		center.position=Vector2(104,58); center.size=Vector2(432,244)
		var terminal_skin:=center.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		terminal_skin.bg_color=Color("102029"); terminal_skin.border_color=Color("63958f"); center.add_theme_stylebox_override("panel",terminal_skin)
	for child in choices.get_children(): child.queue_free()
	center.show(); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	status.hide()
	for option in options:
		var button:=Button.new(); button.text=option[1]; button.custom_minimum_size.y=29
		button.add_theme_font_override("font",FONT.get_font()); button.add_theme_font_size_override("font_size",12)
		if industrial:
			button.custom_minimum_size.y=42; button.alignment=HORIZONTAL_ALIGNMENT_LEFT; button.icon=_module_icon(str(option[0]))
			for mode in ["normal","hover","focus","pressed"]:
				var style:=StyleBoxFlat.new(); style.bg_color=Color("203e47") if mode!="normal" else Color("172f38")
				style.border_color=Color("88b8ad") if mode!="normal" else Color("42646c"); style.set_border_width_all(1)
				style.content_margin_left=10; style.content_margin_right=10; button.add_theme_stylebox_override(mode,style)
		button.pressed.connect(func(): choice_selected.emit(option[0])); choices.add_child(button)
		if choices.get_child_count()==1: button.grab_focus()
func dismiss() -> void:
	center.hide(); status.hide()
func _module_icon(kind: String) -> Texture2D:
	var image:=Image.create(16,16,false,Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT)
	for y in range(3,13):
		for x in range(3,13):
			var lit: bool=(x==3 or x==12 or y==3 or y==12) if kind=="damage" else (x+y in [10,11,16,17]) if kind=="tempo" else (x in [7,8] or y in [7,8])
			if lit: image.set_pixel(x,y,Color("9bc4bb"))
	return ImageTexture.create_from_image(image)
func command(text: String) -> void:
	preload("res://scripts/audio/sfx_manager.gd").play_event(&"phone_operation")
	# Non-modal tactical strip; world input and sightlines remain available.
	var banner:=PanelContainer.new(); banner.position=Vector2(16,44); banner.size=Vector2(608,62)
	banner.mouse_filter=Control.MOUSE_FILTER_IGNORE; banner.modulate.a=0; add_child(banner)
	var skin:=StyleBoxFlat.new(); skin.bg_color=Color(.11,.025,.04,.90); skin.border_color=Color("895f68")
	skin.border_width_top=1; skin.border_width_bottom=1; skin.content_margin_left=14; skin.content_margin_top=6
	banner.add_theme_stylebox_override("panel",skin)
	var box:=VBoxContainer.new(); box.mouse_filter=Control.MOUSE_FILTER_IGNORE; banner.add_child(box)
	var prefix:=Label.new(); prefix.text="[VLNK::DIRECTIVE]"; prefix.add_theme_font_override("font",FONT.get_font()); prefix.add_theme_font_size_override("font_size",12); prefix.add_theme_color_override("font_color",Color("a98691")); box.add_child(prefix)
	var caption:=Label.new(); caption.text=text; caption.add_theme_font_override("font",FONT.get_font()); caption.add_theme_font_size_override("font_size",24); caption.add_theme_color_override("font_color",Color("dfd9d9")); caption.add_theme_color_override("font_shadow_color",Color(.24,.40,.48,.5)); caption.add_theme_constant_override("shadow_offset_x",1); box.add_child(caption)
	for y in range(2,60,4):
		var scan:=ColorRect.new(); scan.position=Vector2(0,y); scan.size=Vector2(608,1); scan.color=Color(0,0,0,.10); scan.mouse_filter=Control.MOUSE_FILTER_IGNORE; banner.add_child(scan)
	var tween:=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_property(banner,"modulate:a",1.,.10); tween.tween_interval(.65); tween.tween_property(banner,"modulate:a",0.,.18)
	await tween.finished; banner.queue_free()
