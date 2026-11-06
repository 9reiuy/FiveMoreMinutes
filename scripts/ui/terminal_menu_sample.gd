extends Control
## A review-only skin for the real main and pause menus. It changes the
## instantiated controls, never the shared menu scenes or settings resources.

const PIXEL_FONT: Font = preload("res://assets/fonts/boutique_bitmap/BoutiqueBitmap9x9_Bold_1.9.ttf")
const SETTINGS_TINT: Shader = preload("res://shaders/ui/terminal_sample_tint.gdshader")
const PORTRAIT_TINT: Shader = preload("res://shaders/ui/terminal_sample_portrait_tint.gdshader")
const CRT_SHADER: Shader = preload("res://shaders/ui/terminal_sample_crt.gdshader")
const CONTOUR_SHADER: Shader = preload("res://shaders/ui/terminal_sample_contours.gdshader")
const PALE := Color("d4e8ed")
const INK := Color("9bbdc9")
const DIM := Color("638795")
const LINE := Color("416474")
const ACCENT := Color("7eb5cc")
const WARM_ACCENT := Color("eeb778")
const DEEP := Color("09151d")

var host: Node
var mode := "main"
var option_group: PixelOptionGroup
var option_buttons: Array[Button] = []
var rows: Control
var intro := 0.0
var elapsed := 0.0
var highlight_y := -1.0
var highlight_x := -1.0
var highlight_alpha := 0.0
var last_settings_open := false
var original_title: Label
var backdrop: Control
var backdrop_tick := 0.0
var character_layer: Control
var portrait_material: ShaderMaterial
var screen_glass: ColorRect
var contour_material: ShaderMaterial
var scan_elapsed := 0.0
var scan_y := -1.0
var reveal_progress := 0.0


static func install_main(menu: Control) -> Control:
	var chrome = load("res://scripts/ui/terminal_menu_sample.gd").new()
	chrome.name = "TerminalMainSample"
	chrome.host = menu
	chrome.mode = "main"
	menu.add_child(chrome)
	return chrome


static func install_pause(pause: CanvasLayer) -> Control:
	var chrome = load("res://scripts/ui/terminal_menu_sample.gd").new()
	chrome.name = "TerminalPauseSample"
	chrome.host = pause
	chrome.mode = "pause"
	pause.root.add_child(chrome)
	pause.root.move_child(chrome, 1)
	return chrome


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if mode == "main":
		_setup_main()
	else:
		_setup_pause()
	resized.connect(_layout)
	_layout.call_deferred()
	_play_intro()


func _play_intro() -> void:
	intro = 0.0
	if mode == "main":
		scan_elapsed = 0.0
		reveal_progress = 0.0
		scan_y = 0.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "intro", 1.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _setup_main() -> void:
	z_index = 2
	# The character becomes a terminal subject; the old floral banner is not
	# used as the layout grid for this variant.
	host.get_node("Background").color = Color("07151e")
	host.get_node("HomeScreenVisual/Canvas/Home_Screen_background").visible = false
	backdrop = Control.new()
	backdrop.name = "TerminalSurveyBackdrop"
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(backdrop)
	host.move_child(backdrop, host.get_node("Background").get_index() + 1)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.offset_top = 44.0
	backdrop.offset_bottom = -96.0
	backdrop.clip_contents = true
	backdrop.draw.connect(func(): _draw_survey_backdrop(backdrop))
	backdrop.resized.connect(backdrop.queue_redraw)
	var contour_field := ColorRect.new()
	contour_field.name = "AnimatedContourField"
	contour_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contour_material = ShaderMaterial.new()
	contour_material.shader = CONTOUR_SHADER
	contour_field.material = contour_material
	backdrop.add_child(contour_field)
	contour_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	character_layer = host.get_node("HomeScreenVisual/Canvas/CharacterLayer")
	character_layer.offset_top = 25.0
	character_layer.offset_bottom = 25.0
	portrait_material = ShaderMaterial.new()
	portrait_material.shader = PORTRAIT_TINT
	portrait_material.set_shader_parameter(&"reveal_progress", 0.0)
	var portrait: TextureRect = character_layer.get_node("Home_Screen_chr")
	portrait_material.set_shader_parameter(&"portrait_texture", portrait.texture)
	portrait.material = portrait_material
	# The original eye shader, texture, red iris and follow logic stay untouched.
	# Draw it above the curved portrait layer so it is not recolored or glitched.
	host.home_screen_eye.z_index = 2
	host.home_screen_eye.modulate.a = 0.0
	screen_glass = ColorRect.new()
	screen_glass.name = "TerminalCurvedGlass"
	screen_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_glass.z_index = 1
	var glass_material := ShaderMaterial.new()
	glass_material.shader = CRT_SHADER
	screen_glass.material = glass_material
	host.add_child(screen_glass)
	screen_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	option_group = host.menu_option_group
	option_buttons = [host.continue_button, host.start_button, host.settings_button, host.quit_button]
	_style_group(option_group)
	rows = Control.new()
	rows.name = "TerminalMenuRows"
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.menu_content.add_child(rows)
	for button in option_buttons:
		button.reparent(rows)
		button.custom_minimum_size = Vector2(142, 29)
		button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_style_button(button)
	host.button_list.visible = false
	original_title = host.get_node("GameTitle")
	original_title.text = "FIVE MINUTES MORE"
	original_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	original_title.add_theme_font_override("font", PIXEL_FONT)
	original_title.add_theme_font_size_override("font_size", 15)
	original_title.add_theme_color_override("font_color", PALE)
	_apply_text_glow(original_title, 2)
	for label: Label in [host.version_label, host.group_label]:
		label.add_theme_color_override("font_color", DIM)
		label.mouse_entered.connect(func(): label.add_theme_color_override("font_color", PALE))
		label.mouse_exited.connect(func(): label.add_theme_color_override("font_color", DIM))
	_setup_modal(host.overlay, host.overlay_option_group, [host.primary_button, host.back_button], host.settings_panel)
	option_group.activate_index.call_deferred(0, false)
	_animate_main_intro.call_deferred()


func _setup_pause() -> void:
	option_group = host.option_group
	option_buttons = [
		host.get_node("Root/Panel/Layout/MenuButtons/Resume"),
		host.get_node("Root/Panel/Layout/MenuButtons/Settings"),
		host.get_node("Root/Panel/Layout/MenuButtons/ExitToMenu")
	]
	_style_group(option_group)
	for button in option_buttons:
		button.custom_minimum_size = Vector2(164, 29)
		_style_button(button)
	_style_button(host.settings_back)
	host.settings_back.custom_minimum_size = Vector2(140, 30)
	host.title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	host.title.add_theme_font_override("font", PIXEL_FONT)
	host.title.add_theme_font_size_override("font_size", 20)
	host.title.add_theme_color_override("font_color", PALE)
	_apply_text_glow(host.title, 2)
	host.root.get_node("Shade").color = Color(0.015, 0.035, 0.06, 0.53)
	_tint_settings(host.settings_panel)
	host.root.visibility_changed.connect(_on_pause_visibility)


func _style_group(group: PixelOptionGroup) -> void:
	# The existing selection model, keyboard handling and sound remain intact.
	# Its old blue selection paint is replaced by the terminal's drawn rows.
	group.modulate.a = 0.0
	group.selected_text_color = PALE
	group.unselected_text_color = INK
	group.selection_changed.connect(func(_button: Button): queue_redraw())


func _style_button(button: Button) -> void:
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", PALE)
	button.add_theme_color_override("font_pressed_color", PALE)
	button.add_theme_color_override("font_focus_color", PALE)
	button.add_theme_color_override("font_disabled_color", Color("49626d"))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_apply_text_glow(button, 1)


func _apply_text_glow(control: Control, thickness: int) -> void:
	control.add_theme_color_override("font_outline_color", Color(0.22, 0.78, 0.83, 0.48))
	control.add_theme_constant_override("outline_size", thickness)


func _setup_modal(overlay: Control, group: PixelOptionGroup, buttons: Array, settings: Control) -> void:
	_style_group(group)
	for button: Button in buttons:
		_style_button(button)
	var shade: ColorRect = overlay.get_node("Shade")
	shade.color = Color(0.015, 0.035, 0.05, 0.90)
	var title: Label = overlay.get_node("Panel/Content/Title")
	title.add_theme_font_override("font", PIXEL_FONT)
	title.add_theme_color_override("font_color", PALE)
	_apply_text_glow(title, 1)
	var message: Label = overlay.get_node("Panel/Content/Message")
	message.add_theme_color_override("font_color", INK)
	var frame := Control.new()
	frame.name = "TerminalModalFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(frame)
	overlay.move_child(frame, 1)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.draw.connect(func(): _draw_modal_frame(frame))
	frame.draw.connect(func():
		var active_index := group.get_active_index()
		if active_index >= 0 and active_index < buttons.size():
			var button: Button = buttons[active_index]
			if button.is_visible_in_tree():
				var box := button.get_global_rect()
				box.position -= frame.get_global_rect().position
				frame.draw_rect(box.grow_individual(4, -3, 4, -3), Color(0.20, 0.38, 0.47, 0.72))
	)
	frame.resized.connect(frame.queue_redraw)
	group.selection_changed.connect(func(_button: Button): frame.queue_redraw())
	_tint_settings(settings)


func _tint_settings(settings: Control) -> void:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SETTINGS_TINT
	settings.material = shader_material
	_install_hatched_sliders(settings)
	_apply_parent_material(settings)
	for node in settings.find_children("*", "Label", true, false) + settings.find_children("*", "Button", true, false):
		if node is Control:
			_apply_text_glow(node, 1)
	var selection := settings.get_node_or_null("RowSelect") as CanvasItem
	if selection != null:
		selection.modulate = Color(0.55, 0.55, 0.55, 1.0)


func _install_hatched_sliders(settings: Control) -> void:
	var panel := settings as UnifiedSettingsPanel
	if panel == null:
		return
	for slider: HSlider in [panel.master_slider, panel.music_slider, panel.sfx_slider]:
		if slider == null:
			continue
		var old_track := slider.get_node_or_null("NierDashTrack") as CanvasItem
		if old_track != null:
			old_track.visible = false
		var track := Control.new()
		track.name = "TerminalHatchedTrack"
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.show_behind_parent = true
		slider.add_child(track)
		track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		track.draw.connect(func(): _draw_slider_track(track, slider))
		track.resized.connect(track.queue_redraw)
		slider.value_changed.connect(func(_value: float): track.queue_redraw())


func _draw_slider_track(canvas: Control, slider: HSlider) -> void:
	var height := 10.0
	var bounds := Rect2(0, (canvas.size.y - height) * 0.5, canvas.size.x, height)
	var amount := 0.0
	if slider.max_value > slider.min_value:
		amount = clampf((slider.value - slider.min_value) / (slider.max_value - slider.min_value), 0.0, 1.0)
	_hatched_bar(canvas, bounds, amount, ACCENT)


func _hatched_bar(canvas: Control, bounds: Rect2, amount: float, color: Color) -> void:
	canvas.draw_rect(bounds, Color(color.r, color.g, color.b, 0.8), false, 1.0)
	var inner := bounds.grow(-2.0)
	var fill_width := inner.size.x * clampf(amount, 0.0, 1.0)
	if fill_width <= 0.0:
		return
	canvas.draw_rect(Rect2(inner.position, Vector2(fill_width, inner.size.y)), Color(color.r, color.g, color.b, 0.13))
	var diagonal := -inner.size.y
	while diagonal < fill_width:
		var left := maxf(0.0, diagonal)
		var right := minf(fill_width, diagonal + inner.size.y)
		if right > left:
			var a := Vector2(inner.position.x + left, inner.end.y - (left - diagonal))
			var b := Vector2(inner.position.x + right, inner.end.y - (right - diagonal))
			canvas.draw_line(a, b, Color(color.r, color.g, color.b, 0.9), 1.0)
		diagonal += 4.0


func _apply_parent_material(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			child.use_parent_material = true
		_apply_parent_material(child)


func _on_pause_visibility() -> void:
	if host.root.visible:
		highlight_y = -1.0
		highlight_x = -1.0
		highlight_alpha = 0.0
		_play_intro()
		option_group.activate_index.call_deferred(0, false)
		_animate_pause_intro.call_deferred()


func _animate_main_intro() -> void:
	if not is_instance_valid(rows):
		return
	var illustration: CanvasItem = host.get_node("HomeScreenVisual")
	illustration.modulate.a = 1.0
	scan_elapsed = 0.0
	host.home_screen_eye.modulate.a = 0.0
	for i in option_buttons.size():
		var button := option_buttons[i]
		button.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(float(i) * 0.075)
		tween.tween_property(button, "modulate:a", 1.0, 0.22)


func _animate_pause_intro() -> void:
	if not host.root.visible or host.settings_open:
		return
	var panel: Control = host.root.get_node("Panel")
	panel.position.x = 60.0
	host.menu_buttons.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "position:x", 70.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(host.menu_buttons, "modulate:a", 1.0, 0.25)


func _layout() -> void:
	if not is_instance_valid(host):
		return
	if mode == "main":
		rows.position = Vector2.ZERO
		rows.size = size
		var cell_width := (size.x - 74.0) / 4.0
		for i in option_buttons.size():
			var button := option_buttons[i]
			button.position = Vector2(37.0 + float(i) * (cell_width + 6.0), size.y - 64.0)
			button.custom_minimum_size = Vector2(0, 0)
			button.size = Vector2(cell_width - 18.0, 24.0)
		original_title.position = Vector2(29, 15)
		original_title.size = Vector2(210, 24)
	else:
		_layout_pause()
	queue_redraw()


func _layout_pause() -> void:
	var panel: PanelContainer = host.root.get_node("Panel")
	if host.settings_open:
		panel.position = Vector2(150, 18)
		panel.size = Vector2(340, 324)
		host.title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		panel.position = Vector2(70, 72)
		panel.size = Vector2(180, 190)
		host.title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _process(delta: float) -> void:
	if mode == "pause" and not host.root.visible:
		return
	elapsed += delta
	if mode == "main" and is_instance_valid(backdrop):
		_update_projection(delta)
		backdrop_tick += delta
		if backdrop_tick >= 0.05:
			backdrop_tick = 0.0
			backdrop.queue_redraw()
	if mode == "pause" and last_settings_open != host.settings_open:
		last_settings_open = host.settings_open
		_layout_pause()
	var index := option_group.get_active_index()
	var active: Button = null
	if index >= 0 and index < option_buttons.size():
		active = option_buttons[index]
	if active != null and active.is_visible_in_tree():
		var target_y := active.get_global_rect().position.y - get_global_rect().position.y - (12.0 if mode == "main" else 0.0)
		var target_x := active.get_global_rect().position.x - get_global_rect().position.x - (9.0 if mode == "main" else 28.0)
		if highlight_y < 0.0:
			highlight_y = target_y
		if highlight_x < 0.0 or absf(highlight_x - target_x) > 80.0:
			highlight_x = target_x
			highlight_y = target_y
			highlight_alpha = 0.0
		else:
			highlight_x = lerpf(highlight_x, target_x, minf(delta * 18.0, 1.0))
		highlight_y = lerpf(highlight_y, target_y, minf(delta * 18.0, 1.0))
		highlight_alpha = move_toward(highlight_alpha, 1.0, delta * 8.0)
	else:
		highlight_alpha = move_toward(highlight_alpha, 0.0, delta * 8.0)
	queue_redraw()


func _update_projection(delta: float) -> void:
	scan_elapsed += delta
	reveal_progress = minf(scan_elapsed / 1.55, 1.03)
	if reveal_progress < 1.0:
		scan_y = reveal_progress
	else:
		var cycle := fposmod(scan_elapsed - 1.55, 5.2)
		scan_y = (cycle - 3.6) / 1.4 if cycle >= 3.6 and cycle < 5.0 else -1.0
	portrait_material.set_shader_parameter(&"reveal_progress", reveal_progress)
	portrait_material.set_shader_parameter(&"scan_y", scan_y)
	portrait_material.set_shader_parameter(&"effect_time", elapsed)
	contour_material.set_shader_parameter(&"motion_time", elapsed)
	# The original eye fades in only when the scanning edge reaches it.
	host.home_screen_eye.modulate.a = smoothstep(0.28, 0.33, reveal_progress)


func _unhandled_input(event: InputEvent) -> void:
	if mode != "main" or host.overlay.visible or host.announcement_window.visible:
		return
	if event.is_action_pressed("ui_right"):
		option_group.activate_delta(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		option_group.activate_delta(-1)
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if mode == "main":
		_draw_main()
	else:
		_draw_pause()


func _draw_main() -> void:
	var w := size.x
	var h := size.y
	# Keep the upper screen quiet and reserve the framed terminal language for
	# the bottom control strip, per the visual review.
	var bottom := Rect2(17, h - 96, w - 34, 84)
	draw_rect(Rect2(0, h - 96, w, 96), Color("07151e"))
	draw_rect(bottom, Color(0.17, 0.33, 0.42, 0.95), false, 1.0)
	draw_rect(bottom.grow(-3), Color(0.11, 0.23, 0.30, 0.85), false, 1.0)
	draw_line(Vector2(25, h - 91), Vector2(w - 25, h - 91), ACCENT)
	_text(Vector2(29, h - 79), "SELECT OPERATION   /   操作选择", 8, INK)
	_draw_rows((w - 74.0) / 4.0)
	_text(Vector2(30, 52), "[ SYS_CORE / ACTIVE ]", 8, DIM)
	_draw_simulated_code()
	_draw_curved_bezel()
	if intro < 0.999:
		_hatched_bar(self, Rect2(w - 133, h - 86, 101, 6), intro, ACCENT)


func _draw_survey_backdrop(canvas: Control) -> void:
	var center := Vector2(canvas.size.x * 0.51 + sin(elapsed * 0.27) * 5.0, canvas.size.y * 0.5 + cos(elapsed * 0.23) * 3.0)
	# The field itself is made by the contour shader; these sparse marks stay
	# deliberately quiet so the drawing remains behind the portrait.
	_draw_dashed_line(canvas, center + Vector2(-175, 64), center + Vector2(190, -70), Color(0.36, 0.63, 0.73, 0.12))
	canvas.draw_circle(center + Vector2(190, -70), 2.0, Color(WARM_ACCENT.r, WARM_ACCENT.g, WARM_ACCENT.b, 0.50))
	if scan_y >= 0.0:
		var portrait_rect := character_layer.get_global_rect()
		var y := portrait_rect.position.y + portrait_rect.size.y * scan_y - canvas.get_global_rect().position.y
		if y >= -4.0 and y <= canvas.size.y + 4.0:
			canvas.draw_rect(Rect2(0, y - 3.0, canvas.size.x, 6.0), Color(0.20, 0.70, 0.80, 0.055))
			canvas.draw_line(Vector2(0, y), Vector2(canvas.size.x, y), Color(0.49, 0.92, 0.97, 0.40), 1.0)
			canvas.draw_line(Vector2(canvas.size.x * 0.64, y - 1.0), Vector2(canvas.size.x * 0.81, y - 1.0), Color(0.67, 0.98, 1.0, 0.54), 1.0)


func _draw_simulated_code() -> void:
	var lines := ["// VISUAL SIGNAL", "> display.init();", "> trace.contours();", "> scan.portrait();", "> await input;"]
	var available := maxi(0, floori(fposmod(scan_elapsed, 15.0) * 21.0))
	var position := Vector2(size.x - 170.0, 73.0)
	for line: String in lines:
		var count := mini(available, line.length())
		if count > 0:
			var fragment := line.substr(0, count)
			draw_string(PIXEL_FONT, position, fragment, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.48, 0.76, 0.79, 0.52))
			if count < line.length() and int(elapsed * 2.0) % 2 == 0:
				var end_x := PIXEL_FONT.get_string_size(fragment, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
				draw_rect(Rect2(position.x + end_x + 2.0, position.y - 7.0, 3.0, 8.0), Color(WARM_ACCENT.r, WARM_ACCENT.g, WARM_ACCENT.b, 0.8))
		available -= count
		if available <= 0:
			break
		position.y += 12.0


func _draw_curved_bezel() -> void:
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in 33:
		var t := float(i) / 32.0
		var bow := pow(t * 2.0 - 1.0, 2.0) * 4.0
		top.append(Vector2(10.0 + (size.x - 20.0) * t, 8.0 + bow))
		bottom.append(Vector2(10.0 + (size.x - 20.0) * t, size.y - 8.0 - bow))
		left.append(Vector2(8.0 + bow, 10.0 + (size.y - 20.0) * t))
		right.append(Vector2(size.x - 8.0 - bow, 10.0 + (size.y - 20.0) * t))
	for line in [top, bottom, left, right]:
		draw_polyline(line, Color(0.27, 0.78, 0.84, 0.12), 3.0)
		draw_polyline(line, Color(0.48, 0.84, 0.87, 0.46), 1.0)


func _draw_dashed_line(canvas: Control, start: Vector2, finish: Vector2, color: Color) -> void:
	var delta := finish - start
	var count := maxi(1, int(delta.length() / 9.0))
	for i in count:
		var a := float(i) / float(count)
		var b := minf(1.0, (float(i) + 0.48) / float(count))
		canvas.draw_line(start + delta * a, start + delta * b, color, 1.0)


func _draw_technical_map(rect: Rect2) -> void:
	# Thin horizontal drafting guides and nested contours like a survey display.
	for i in 6:
		var y := rect.position.y + 12.0 + float(i) * 20.0
		if y < rect.end.y:
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.25, 0.45, 0.53, 0.38), 1.0)
	for n in 5:
		var points := PackedVector2Array()
		var base := rect.position.y + 22.0 + float(n) * 22.0
		for k in 26:
			var x := float(k) * rect.size.x / 25.0
			var y := base + sin(x * 0.045 + float(n) * 0.8) * (5.0 + float(n)) + sin(x * 0.092 + float(n)) * 3.0
			points.append(Vector2(rect.position.x + x, clampf(y, rect.position.y + 1.0, rect.end.y - 1.0)))
		draw_polyline(points, Color(0.32, 0.59, 0.68, 0.38), 1.0)
	var center := rect.get_center() + Vector2(17, 0)
	draw_arc(center, 28, 0.0, TAU, 40, Color(0.38, 0.67, 0.76, 0.62), 1.0)
	draw_arc(center, 45, 0.0, TAU, 48, Color(0.30, 0.53, 0.64, 0.42), 1.0)
	draw_line(center - Vector2(5, 0), center + Vector2(5, 0), ACCENT)
	draw_line(center - Vector2(0, 5), center + Vector2(0, 5), ACCENT)


func _draw_pause() -> void:
	var w := size.x
	var h := size.y
	if host.settings_open:
		_draw_settings_backdrop(self)
		if option_group.get_active_index() == 3 and host.settings_back.is_visible_in_tree():
			var back_rect: Rect2 = host.settings_back.get_global_rect()
			back_rect.position -= get_global_rect().position
			draw_rect(back_rect.grow_individual(4, -3, 4, -3), Color(0.20, 0.38, 0.47, 0.72))
		return
	draw_rect(Rect2(18, 16, w - 36, h - 32), Color(0.24, 0.47, 0.57, 0.8), false, 1.0)
	draw_rect(Rect2(27, 27, 252, h - 54), Color(0.025, 0.065, 0.09, 0.82))
	draw_rect(Rect2(27, 27, 252, h - 54), LINE, false, 1.0)
	draw_line(Vector2(39, 48), Vector2(267, 48), LINE)
	_text(Vector2(40, 41), "FMM  /  SESSION CONTROL", 9, INK)
	_text(Vector2(40, 67), "STATE  //  PAUSED", 9, ACCENT)
	_text(Vector2(40, h - 43), "ESC  /  RESUME", 9, DIM)
	_text(Vector2(w - 144, h - 29), "SESSION PAUSED", 9, INK)
	_draw_rows(205.0)
	draw_rect(Rect2(w - 188, 27, 151, 140), Color(0.02, 0.06, 0.09, 0.66))
	draw_rect(Rect2(w - 188, 27, 151, 140), LINE, false, 1.0)
	_text(Vector2(w - 180, 42), "SESSION / PAUSED", 8, INK)
	draw_line(Vector2(w - 180, 48), Vector2(w - 45, 48), LINE)
	_draw_technical_map(Rect2(w - 180, 55, 135, 101))
	_draw_corner(Vector2(w - 36, 35), Vector2(-1, 1), LINE)
	_draw_corner(Vector2(w - 36, h - 35), Vector2(-1, -1), LINE)
	_draw_reveal_bar(w)


func _draw_rows(width: float) -> void:
	if mode == "main":
		_draw_main_buttons(width)
		return
	for i in option_buttons.size():
		var button := option_buttons[i]
		if not button.is_visible_in_tree():
			continue
		var rect := button.get_global_rect()
		var x := rect.position.x - get_global_rect().position.x - 28.0
		var y := rect.position.y - get_global_rect().position.y
		var box := Rect2(x, y, width, rect.size.y)
		draw_rect(box, Color(0.02, 0.055, 0.08, 0.68))
		draw_rect(box, Color(0.25, 0.44, 0.52, 0.65), false, 1.0)
		draw_rect(Rect2(x + 2, y + 2, width - 4, 2), Color(0.22, 0.42, 0.52, 0.7))
	if highlight_alpha > 0.01 and highlight_y >= 0.0:
		var focus := Rect2(highlight_x, highlight_y, width, 29)
		draw_rect(focus, Color(0.13, 0.31, 0.41, 0.45 * highlight_alpha))
		draw_rect(focus, Color(WARM_ACCENT.r, WARM_ACCENT.g, WARM_ACCENT.b, 0.9 * highlight_alpha), false, 1.0)
		draw_rect(Rect2(highlight_x, highlight_y, 3, 29), Color(WARM_ACCENT.r, WARM_ACCENT.g, WARM_ACCENT.b, highlight_alpha))
	for i in option_buttons.size():
		var button := option_buttons[i]
		if not button.is_visible_in_tree():
			continue
		var rect := button.get_global_rect()
		var x := rect.position.x - get_global_rect().position.x - 28.0
		var y := rect.position.y - get_global_rect().position.y
		draw_line(Vector2(x, y + rect.size.y), Vector2(x + width, y + rect.size.y), Color(0.25, 0.44, 0.52, 0.65), 1.0)
		_text(Vector2(x + 7, y + rect.size.y * 0.5 + 3), "%02d" % (i + 1), 9, DIM)


func _draw_main_buttons(width: float) -> void:
	for i in option_buttons.size():
		var button := option_buttons[i]
		var button_rect := button.get_global_rect()
		var x := button_rect.position.x - get_global_rect().position.x - 9.0
		var y := button_rect.position.y - get_global_rect().position.y - 12.0
		var cell := Rect2(x, y, width, 42.0)
		draw_rect(cell, Color(0.02, 0.075, 0.11, 0.91))
		draw_rect(cell, Color(0.31, 0.53, 0.62, 0.78), false, 1.0)
		draw_rect(Rect2(x + 2, y + 2, width - 4, 3), Color(0.20, 0.38, 0.47, 0.75))
		_text(Vector2(x + 7, y + 12), "F%02d" % (i + 1), 8, DIM)
	if highlight_alpha > 0.01 and highlight_y >= 0.0:
		var cell := Rect2(highlight_x, highlight_y, width, 42.0)
		draw_rect(cell, Color(0.17, 0.35, 0.46, 0.50 * highlight_alpha))
		_draw_button_hatching(cell.grow(-3.0), highlight_alpha)
		draw_rect(cell.grow(1.5), Color(WARM_ACCENT.r, WARM_ACCENT.g, WARM_ACCENT.b, 0.18 * highlight_alpha), false, 3.0)
		draw_rect(cell, Color(WARM_ACCENT.r, WARM_ACCENT.g, WARM_ACCENT.b, highlight_alpha), false, 1.0)
		draw_rect(Rect2(cell.position.x + 2, cell.position.y + 2, width - 4, 3), Color(WARM_ACCENT.r, WARM_ACCENT.g, WARM_ACCENT.b, highlight_alpha))
		var index := option_group.get_active_index()
		if index >= 0:
			_text(Vector2(cell.position.x + 7, cell.position.y + 12), "F%02d" % (index + 1), 8, WARM_ACCENT)


func _draw_button_hatching(rect: Rect2, opacity: float) -> void:
	var diagonal := -rect.size.y
	while diagonal < rect.size.x:
		var left := maxf(0.0, diagonal)
		var right := minf(rect.size.x, diagonal + rect.size.y)
		if right > left:
			var a := Vector2(rect.position.x + left, rect.end.y - (left - diagonal))
			var b := Vector2(rect.position.x + right, rect.end.y - (right - diagonal))
			draw_line(a, b, Color(0.44, 0.86, 0.91, 0.34 * opacity), 1.0)
		diagonal += 4.0


func _draw_viewfinder(rect: Rect2) -> void:
	var tint := Color(0.31, 0.51, 0.60, 0.55)
	_draw_corner(rect.position, Vector2(1, 1), tint)
	_draw_corner(Vector2(rect.end.x, rect.position.y), Vector2(-1, 1), tint)
	_draw_corner(Vector2(rect.position.x, rect.end.y), Vector2(1, -1), tint)
	_draw_corner(rect.end, Vector2(-1, -1), tint)
	for x in range(1, 12):
		var px := rect.position.x + rect.size.x * float(x) / 12.0
		draw_line(Vector2(px, rect.position.y), Vector2(px, rect.position.y + 3), tint)
	for y in range(1, 6):
		var py := rect.position.y + rect.size.y * float(y) / 6.0
		draw_line(Vector2(rect.position.x, py), Vector2(rect.position.x + 3, py), tint)


func _draw_corner(at: Vector2, direction: Vector2, color: Color) -> void:
	draw_line(at, at + Vector2(11 * direction.x, 0), color, 1.0)
	draw_line(at, at + Vector2(0, 11 * direction.y), color, 1.0)


func _draw_scan(x: float, y: float, width: float, height: float) -> void:
	# Slow, subtle phosphor scan rather than a full-screen strobe.
	var sweep := fmod(elapsed * 12.0, maxf(1.0, height))
	draw_line(Vector2(x, y + sweep), Vector2(x + width, y + sweep), Color(0.47, 0.70, 0.77, 0.10), 1.0)


func _draw_reveal_bar(w: float) -> void:
	if intro < 0.999:
		draw_rect(Rect2(27, 24, (w - 54) * intro, 1), Color(0.70, 0.89, 0.94, 0.8 * (1.0 - intro)))


func _draw_modal_frame(frame: Control) -> void:
	_draw_settings_backdrop(frame)


func _draw_settings_backdrop(canvas: Control) -> void:
	var center := canvas.size * 0.5
	var rect := Rect2(center.x - 196, 13, 392, canvas.size.y - 26)
	canvas.draw_rect(rect, Color(0.025, 0.065, 0.09, 0.97))
	canvas.draw_rect(rect, LINE, false, 1.0)
	canvas.draw_line(Vector2(rect.position.x + 12, 51), Vector2(rect.end.x - 12, 51), LINE)
	canvas.draw_string(PIXEL_FONT, Vector2(rect.position.x + 14, 30), "FMM  /  CONTROL PANEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, DIM)
	canvas.draw_string(PIXEL_FONT, Vector2(rect.position.x + 14, rect.end.y - 10), "ESC  /  RETURN", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, DIM)


func _text(pos: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string_outline(PIXEL_FONT, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 1, Color(0.18, 0.72, 0.78, 0.20 * color.a))
	draw_string(PIXEL_FONT, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _line(a: Vector2, b: Vector2, color: Color) -> void:
	draw_line(a, b, color, 1.0)
