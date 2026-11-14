extends "res://scripts/ui/pause_menu.gd"
## Render the interactive pause/settings controls inside the actual CRT glass.
const VIEW := preload("res://scripts/ui/screen_wall_pause_view.gd")
const FONT := preload("res://assets/fonts/boutique_bitmap/BoutiqueBitmap9x9_Bold_1.9.ttf")
const CONTENT_SIZE := Vector2i(480,360)
const CRT_COLORS := preload("res://scripts/ui/screen_wall_colors.gd")
var wall_view: Node3D
var wall_viewport: SubViewport
var content_viewport: SubViewport
var spare_content_viewport: SubViewport
var wall_texture: TextureRect
var content_root: Control
var hint: Label
var pending_action := false
var action_completed := false
var open_generation := 0
var dragging := false
var last_content_position := Vector2(-10000,-10000)
var action_buttons: Dictionary
var television_warmed := false
var warmup_msec := 0
var settings_only := false

func _ready() -> void:
	super._ready()
	action_buttons={&"resume":$Root/Panel/Layout/MenuButtons/Resume,&"settings":$Root/Panel/Layout/MenuButtons/Settings,&"exit_to_menu":$Root/Panel/Layout/MenuButtons/ExitToMenu}
	$Root/Shade.color=Color.BLACK
	content_viewport=SubViewport.new()
	content_viewport.name="TelevisionContents"
	content_viewport.size=CONTENT_SIZE
	content_viewport.disable_3d=true
	content_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	root.add_child(content_viewport)
	spare_content_viewport=SubViewport.new()
	spare_content_viewport.name="PreviousTelevisionContents"
	spare_content_viewport.size=CONTENT_SIZE
	spare_content_viewport.disable_3d=true
	spare_content_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	root.add_child(spare_content_viewport)
	content_root=Control.new()
	content_root.name="ContentRoot"
	content_root.size=Vector2(CONTENT_SIZE)
	content_root.clip_contents=true
	content_viewport.add_child(content_root)
	var black:=ColorRect.new()
	black.color=Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter=Control.MOUSE_FILTER_IGNORE
	content_root.add_child(black)
	var panel: Control=$Root/Panel
	panel.reparent(content_root)
	option_group.reparent(content_root)
	option_group.mouse_filter=Control.MOUSE_FILTER_IGNORE
	content_root.move_child(option_group,1)
	panel.position=Vector2(42,18)
	panel.size=Vector2(396,324)
	panel.get_node("Layout").add_theme_constant_override("separation",6)
	menu_buttons.custom_minimum_size=Vector2(0,230)
	var index:=0
	for button: Button in action_buttons.values():
		button.custom_minimum_size=Vector2.ZERO
		button.position=Vector2(32,12+index*72)
		button.size=Vector2(332,52)
		button.alignment=HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_override("font",FONT)
		button.add_theme_font_size_override("font_size",18)
		button.add_theme_color_override("font_color",CRT_COLORS.primary())
		button.add_theme_color_override("font_hover_color",CRT_COLORS.hover())
		index+=1
	title.add_theme_font_override("font",FONT)
	title.add_theme_font_size_override("font_size",18)
	title.add_theme_color_override("font_color",CRT_COLORS.primary())
	settings_back.custom_minimum_size=Vector2(240,26)
	settings_back.alignment=HORIZONTAL_ALIGNMENT_CENTER
	settings_back.add_theme_font_override("font",FONT)
	settings_back.add_theme_font_size_override("font_size",12)
	settings_back.text="返回主菜单 / ESC" if settings_only else "返回暂停界面 / ESC"
	option_group.solid_fill=true
	option_group.unselected_text_color=CRT_COLORS.primary()
	option_group.selected_text_color=Color.BLACK
	option_group.connect("hover_requested",_play_tv_hover)
	hint=Label.new()
	hint.text="ESC 继续游戏   ↑↓ 选择   ENTER 确认"
	hint.position=Vector2(0,337)
	hint.size=Vector2(480,15)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font",FONT)
	hint.add_theme_font_size_override("font_size",9)
	hint.add_theme_color_override("font_color",CRT_COLORS.primary())
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	content_root.add_child(hint)
	_tint_settings()
	_style_striped_sliders()
	settings_panel.assistance_button.pressed.connect(func():_tint_settings.call_deferred())
	wall_viewport=SubViewport.new()
	wall_viewport.name="PauseTelevisionViewport"
	wall_viewport.own_world_3d=true
	wall_viewport.transparent_bg=true
	wall_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	root.add_child(wall_viewport)
	wall_texture=TextureRect.new()
	wall_texture.name="PauseTelevision"
	wall_texture.texture=wall_viewport.get_texture()
	wall_texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	wall_texture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	wall_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(wall_texture)
	_resize_presentation()
	wall_view=VIEW.new()
	wall_viewport.add_child(wall_view)
	wall_view.set_content_texture(content_viewport.get_texture())
	wall_view.deactivate_view()
	content_viewport.process_mode=Node.PROCESS_MODE_DISABLED
	root.resized.connect(_resize_presentation)
	get_viewport().size_changed.connect(_resize_presentation)
	_prepare_television.call_deferred()

func _prepare_television() -> void:
	if DisplayServer.get_name()=="headless" or root.visible: return
	var began:=Time.get_ticks_msec()
	# Compile the actual CRT/UI passes while the app is starting, before ESC.
	# Offscreen viewports prepare their buffers without displaying a pause page.
	content_viewport.process_mode=Node.PROCESS_MODE_ALWAYS
	wall_view.process_mode=Node.PROCESS_MODE_ALWAYS
	wall_view.terminal.chassis.position.y=wall_view.REST_Y
	spare_content_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	for settings in [false,true,false]:
		if root.visible: return
		settings_open=settings
		_sync_page(false)
		content_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		wall_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
	if root.visible: return
	wall_view.deactivate_view()
	content_viewport.process_mode=Node.PROCESS_MODE_DISABLED
	content_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	spare_content_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	wall_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	television_warmed=true
	warmup_msec=Time.get_ticks_msec()-began

func _tint_settings() -> void:
	for node in settings_panel.find_children("*","Control",true,false):
		# The quality selector hides its stock OptionButton text under a custom
		# '< value >' caption. Recolouring the stock text would draw it twice.
		if node is OptionButton: continue
		if node is Label or node is Button:
			node.add_theme_color_override("font_color",CRT_COLORS.primary())
			node.add_theme_color_override("font_hover_color",CRT_COLORS.hover())
	settings_panel.row_select.unselected_text_color=CRT_COLORS.primary()
	settings_panel.row_select.selected_text_color=Color.BLACK
	var active: Button=settings_panel.row_select.get("_active_option")
	if active!=null: settings_panel.row_select._apply_option_text_color(active,true)

func _style_striped_sliders() -> void:
	var picture:=Image.create(5,16,false,Image.FORMAT_RGBA8)
	picture.fill(Color.TRANSPARENT)
	var invisible:=ImageTexture.create_from_image(picture)
	for slider: HSlider in [settings_panel.master_slider,settings_panel.music_slider,settings_panel.sfx_slider]:
		for state in ["grabber","grabber_highlight","grabber_disabled"]:
			slider.add_theme_icon_override(state,invisible)
		var old:=slider.get_node_or_null("NierDashTrack") as Control
		if old!=null: old.hide()
		var stripe:=preload("res://scripts/ui/crt_striped_slider.gd").new()
		stripe.name="CRTStripedTrack"
		slider.add_child(stripe)
		stripe.bind(slider)

func _resize_presentation() -> void:
	if wall_viewport==null: return
	var scale_factor:=get_viewport().get_final_transform().get_scale().abs()
	wall_viewport.size=Vector2i((root.size*scale_factor).round()).max(Vector2i(2,2))

func open_pause() -> void:
	if root.visible: return
	open_generation+=1
	pending_action=false
	action_completed=false
	dragging=false
	last_content_position=Vector2(-10000,-10000)
	content_viewport.process_mode=Node.PROCESS_MODE_ALWAYS
	super.open_pause()
	if settings_only: settings_open=true
	wall_view.activate_view()
	wall_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	content_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	_sync_page(false)

func open_settings_page() -> void:
	settings_only=true
	settings_back.text="返回主菜单 / ESC"
	open_pause()

func close_pause() -> void:
	open_generation+=1
	_kill_page_tween()
	wall_view.deactivate_view()
	wall_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	content_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	content_viewport.process_mode=Node.PROCESS_MODE_DISABLED
	spare_content_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	spare_content_viewport.process_mode=Node.PROCESS_MODE_DISABLED
	pending_action=false
	dragging=false
	super.close_pause()

func _sync_page(animate: bool=true) -> void:
	_kill_page_tween()
	_refresh_cycle_hover(Vector2(-10000,-10000))
	var scan_settings:=animate and root.visible and settings_open and wall_view!=null
	if scan_settings:
		# Freeze the previous GPU buffer and move the live controls to its pair.
		# The scan can show both pages without CPU image readback or duplicate UI.
		content_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		var previous:=content_viewport
		content_viewport=spare_content_viewport
		spare_content_viewport=previous
		content_viewport.process_mode=Node.PROCESS_MODE_ALWAYS
		content_root.reparent(content_viewport,false)
		content_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		wall_view.set_content_texture(content_viewport.get_texture())
		wall_view.begin_settings_scan(spare_content_viewport.get_texture())
	elif wall_view!=null:
		wall_view.stop_settings_scan()
	option_group.clear_highlight()
	title.text="设置 / SETTINGS" if settings_open else "暂停 / PAUSED"
	menu_buttons.visible=not settings_open
	settings_panel.visible=settings_open
	settings_back.visible=settings_open
	if hint!=null: hint.visible=not settings_open
	if animate and root.visible and not settings_open:
		var incoming: Control=settings_panel if settings_open else menu_buttons
		incoming.modulate.a=0.0
		_page_tween=create_tween()
		_page_tween.tween_property(incoming,"modulate:a",1.0,PAGE_TWEEN_SECONDS)
	else:
		settings_panel.modulate.a=1.0
		menu_buttons.modulate.a=1.0

func _play_tv_hover() -> void:
	if wall_view!=null and root.visible and not settings_open: wall_view.play_hover_cue()

func _close_settings() -> void:
	if settings_only:
		_request_resume()
	else:
		super._close_settings()

func _confirm_action(id: StringName) -> void:
	if pending_action or action_completed or not root.visible: return
	pending_action=true
	var generation:=open_generation
	await option_group.wait_confirm_spring()
	if generation!=open_generation or not root.visible: return
	pending_action=false
	match id:
		&"resume":_request_resume()
		&"exit_to_menu":_request_exit()
		&"settings":_open_settings()
		&"back":_close_settings()
func _on_resume_pressed() -> void:
	await _confirm_action(&"resume")
func _on_settings_pressed() -> void:
	await _confirm_action(&"settings")
func _on_exit_pressed() -> void:
	await _confirm_action(&"exit_to_menu")
func _on_settings_back_pressed() -> void:
	await _confirm_action(&"back")
func _request_resume() -> void:
	if not root.visible or action_completed: return
	action_completed=true
	super._request_resume()
func _request_exit() -> void:
	if not root.visible or action_completed: return
	action_completed=true
	super._request_exit()
func handle_escape() -> void:
	if pending_action: return
	super.handle_escape()

func content_screen_position(at: Vector2) -> Vector2:
	return wall_view.content_to_screen(at/Vector2(CONTENT_SIZE))/Vector2(wall_viewport.size)*root.size+root.global_position
func option_screen_position(id: StringName) -> Vector2:
	var button: Button=action_buttons[id]
	return content_screen_position(button.get_global_rect().get_center())

func _refresh_cycle_hover(at: Vector2) -> void:
	var quality: OptionButton=settings_panel.shadow_quality_option
	if settings_open and quality.get_global_rect().has_point(at):
		settings_panel._update_cycle_bracket_hover_side(quality,quality.get_global_transform().affine_inverse()*at)
	else:
		settings_panel._on_nier_cycle_bracket_clear(quality)

func _input(event: InputEvent) -> void:
	if not root.visible or wall_view==null: return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var point: Vector2=(event.position-root.global_position)*Vector2(wall_viewport.size)/root.size
		var uv: Vector2=wall_view.screen_to_content(point,dragging)
		if uv.x>-1000 and not wall_view.entering:
			var copy: InputEventMouse=event.duplicate()
			copy.position=uv*Vector2(CONTENT_SIZE)
			copy.global_position=copy.position
			if event is InputEventMouseMotion:
				copy.relative=copy.position-last_content_position if last_content_position.x>-1000 else Vector2.ZERO
			last_content_position=copy.position
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT: dragging=event.pressed
			content_viewport.push_input(copy,true)
			# Embedded OptionButton updates native hover, but consumes motion
			# before gui_input. Use the same curved-glass coordinates for its arrows.
			if event is InputEventMouseMotion: _refresh_cycle_hover(copy.position)
		elif event is InputEventMouseMotion and not wall_view.entering:
			var leave: InputEventMouseMotion=event.duplicate()
			leave.position=Vector2(-10000,-10000)
			leave.global_position=leave.position
			last_content_position=leave.position
			content_viewport.push_input(leave,true)
			_refresh_cycle_hover(leave.position)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if pending_action or (wall_view!=null and wall_view.entering): return
	super._unhandled_input(event)
