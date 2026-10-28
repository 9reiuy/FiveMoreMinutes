class_name UnifiedSettingsPanel
extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const SHADOW_QUALITIES := ["low", "standard", "high"]
const NIER_ACCENT := Color("396fe2")
const NIER_KNOCKOUT := Color("f2efe6")  # cream on #396FE2 fill
const DESC_COL_WIDTH := 128.0
const CONTROL_COL_WIDTH := 120.0

@onready var row_select: PixelOptionGroup = $RowSelect
@onready var rows: VBoxContainer = $Rows
@onready var master_slider: HSlider = $Rows/Master/Slider
@onready var master_value: Label = $Rows/Master/Value
@onready var master_desc: Button = $Rows/Master/Desc
@onready var music_slider: HSlider = $Rows/Music/Slider
@onready var music_value: Label = $Rows/Music/Value
@onready var music_desc: Button = $Rows/Music/Desc
@onready var sfx_slider: HSlider = $Rows/SFX/Slider
@onready var sfx_value: Label = $Rows/SFX/Value
@onready var sfx_desc: Button = $Rows/SFX/Desc
@onready var pixelation_check: CheckBox = $Rows/Pixelation/Check
@onready var pixelation_desc: Button = $Rows/Pixelation/Desc
@onready var palette_option: OptionButton = $Rows/PaletteScheme/Option
@onready var palette_desc: Button = $Rows/PaletteScheme/Desc
@onready var shadow_quality_option: OptionButton = $Rows/ShadowQuality/Option
@onready var shadow_quality_desc: Button = $Rows/ShadowQuality/Desc
@onready var assistance_button: Button = $Rows/AssistanceButton
@onready var assistance_options: VBoxContainer = $Rows/AssistanceOptions
@onready var auto_vault_check: CheckBox = $Rows/AssistanceOptions/AutoVault/Check
@onready var auto_vault_desc: Button = $Rows/AssistanceOptions/AutoVault/Desc
@onready var screen_shake_check: CheckBox = $Rows/AssistanceOptions/ScreenShake/Check
@onready var screen_shake_desc: Button = $Rows/AssistanceOptions/ScreenShake/Desc

var assistance_open := false
var syncing := false


func _ready() -> void:
	for slider in [master_slider, music_slider, sfx_slider]:
		slider.focus_mode = Control.FOCUS_NONE
		slider.mouse_entered.connect(_play_hover)
		slider.drag_ended.connect(_on_slider_drag_ended)
	master_slider.value_changed.connect(_on_volume_changed.bind(&"master_volume"))
	music_slider.value_changed.connect(_on_volume_changed.bind(&"music_volume"))
	sfx_slider.value_changed.connect(_on_volume_changed.bind(&"sfx_volume"))
	pixelation_check.focus_mode = Control.FOCUS_NONE
	pixelation_check.mouse_entered.connect(_play_hover)
	pixelation_check.toggled.connect(_on_pixelation_toggled)
	palette_option.focus_mode = Control.FOCUS_NONE
	palette_option.mouse_entered.connect(_play_hover)
	palette_option.clear()
	palette_option.add_item("方案 1", 0)
	palette_option.add_item("方案 2", 1)
	palette_option.add_item("关闭", 2)
	palette_option.item_selected.connect(_on_palette_selected)
	shadow_quality_option.focus_mode = Control.FOCUS_NONE
	shadow_quality_option.mouse_entered.connect(_play_hover)
	for quality_name in ["低", "默认", "高"]:
		shadow_quality_option.add_item(quality_name)
	shadow_quality_option.item_selected.connect(_on_shadow_quality_selected)
	assistance_button.pressed.connect(_toggle_assistance)
	for check in [auto_vault_check, screen_shake_check]:
		check.focus_mode = Control.FOCUS_NONE
		check.mouse_entered.connect(_play_hover)
	auto_vault_check.toggled.connect(_on_assistance_toggled.bind(&"auto_vault_enabled"))
	screen_shake_check.toggled.connect(_on_assistance_toggled.bind(&"screen_shake_enabled"))
	var sm := _get_sm()
	if sm != null and sm.has_signal("setting_changed"):
		sm.connect("setting_changed", _on_setting_changed)
	_sync_all()
	_apply_nier_control_styles()
	_wire_row_selection()
	_wire_desc_confirm_actions()
	_apply_two_column_layout()
	_ensure_rows_centered()


func _wire_row_selection() -> void:
	row_select.solid_fill = true
	row_select.show_selection_frame = false
	row_select.enable_hover_scale = false
	row_select.selected_text_color = NIER_KNOCKOUT
	row_select.unselected_text_color = NIER_ACCENT
	# Match ref progress-bar spring (empty→fill→overshoot→settle).
	row_select.option_frame_spring_duration = 0.12
	row_select.option_frame_spring_start_scale = 0.20
	row_select.option_frame_spring_overshoot = 1.20
	row_select.option_text_spring_start_scale = 0.82
	row_select.option_text_spring_overshoot = 1.12
	_reregister_row_buttons()
	if not row_select.selection_changed.is_connected(_on_row_selection_changed):
		row_select.selection_changed.connect(_on_row_selection_changed)
	# Hovering the right-hand control also highlights the left description.
	_bind_control_hover(master_slider, master_desc)
	_bind_control_hover(music_slider, music_desc)
	_bind_control_hover(sfx_slider, sfx_desc)
	_bind_control_hover(pixelation_check, pixelation_desc)
	_bind_control_hover(palette_option, palette_desc)
	_bind_control_hover(shadow_quality_option, shadow_quality_desc)
	_bind_control_hover(auto_vault_check, auto_vault_desc)
	_bind_control_hover(screen_shake_check, screen_shake_desc)


func _reregister_row_buttons() -> void:
	var buttons: Array[Button] = []
	if assistance_open:
		buttons = [auto_vault_desc, screen_shake_desc, assistance_button]
	else:
		buttons = [
			master_desc, music_desc, sfx_desc, pixelation_desc,
			palette_desc, shadow_quality_desc, assistance_button,
		]
	for button in buttons:
		_style_desc_button(button)
	row_select.register_options(buttons)


func _style_desc_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, empty)
	button.add_theme_color_override("font_color", NIER_ACCENT)
	button.add_theme_color_override("font_hover_color", NIER_ACCENT)
	button.add_theme_color_override("font_pressed_color", NIER_ACCENT)
	button.add_theme_color_override("font_focus_color", NIER_ACCENT)


func _bind_control_hover(control: Control, desc: Button) -> void:
	if control == null or desc == null:
		return
	if bool(control.get_meta(&"nier_row_hover_bound", false)):
		return
	control.mouse_entered.connect(func() -> void:
		if desc.visible and desc.is_visible_in_tree() and not desc.disabled:
			row_select.activate_option(desc, true)
	)
	control.set_meta(&"nier_row_hover_bound", true)



func _get_sm() -> Node:
	if Engine.get_main_loop() is SceneTree:
		var root_node = (Engine.get_main_loop() as SceneTree).root
		if root_node != null:
			return root_node.get_node_or_null("SettingsManager")
	return null


func _sync_all() -> void:
	syncing = true
	var sm := _get_sm()
	if sm != null:
		master_slider.value = sm.call("get_volume", &"master_volume")
		music_slider.value = sm.call("get_volume", &"music_volume")
		sfx_slider.value = sm.call("get_volume", &"sfx_volume")
		pixelation_check.set_pressed_no_signal(bool(sm.call("get_setting", &"pixelation_enabled", true)))
		palette_option.select((1 if int(sm.call("get_palette_scheme")) == 2 else 0) if bool(sm.call("get_palette_enabled")) else 2)
		var quality_index := SHADOW_QUALITIES.find(String(sm.call("get_setting", &"shadow_quality", "standard")))
		shadow_quality_option.select(quality_index if quality_index >= 0 else 1)
		auto_vault_check.set_pressed_no_signal(bool(sm.get_setting(&"auto_vault_enabled", true)))
		screen_shake_check.set_pressed_no_signal(bool(sm.get_setting(&"screen_shake_enabled", true)))
	_refresh_value_labels()
	syncing = false


func _on_volume_changed(value: float, setting_name: StringName) -> void:
	if syncing:
		return
	var sm := _get_sm()
	if sm != null:
		sm.call("set_volume", setting_name, value)
	_refresh_value_labels()
	# Volume drag: early (pre-soften) watch_tick; option hover keeps soft watch_tick.
	SFX.play_event(&"watch_tick_early")
	var slider: HSlider = null
	if setting_name == &"master_volume":
		slider = master_slider
	elif setting_name == &"music_volume":
		slider = music_slider
	elif setting_name == &"sfx_volume":
		slider = sfx_slider
	if slider != null:
		_bounce_slider_thumb(slider)


func _on_pixelation_toggled(pressed: bool) -> void:
	if syncing:
		return
	var sm := _get_sm()
	if sm != null:
		sm.call("set_setting", &"pixelation_enabled", pressed)
	SFX.play_event(&"confirm")


func _on_palette_selected(index: int) -> void:
	if syncing:
		return
	var sm := _get_sm()
	if sm != null:
		if index < 2: sm.call("set_setting", &"palette_scheme", index + 1)
		sm.call("set_setting", &"palette_enabled", index < 2)
	_refresh_one_cycle_caption(palette_option)
	SFX.play_event(&"confirm")


func _on_setting_changed(_setting_name: StringName, _value: Variant) -> void:
	_sync_all()


func _toggle_assistance() -> void:
	assistance_open = not assistance_open
	assistance_button.text = "返回常规设置" if assistance_open else "游戏辅助功能"
	SFX.play_event(&"confirm")
	# Defer row rebuild so the confirm spring on the link can finish first.
	var delay := maxf(row_select.option_frame_spring_duration, 0.08)
	get_tree().create_timer(delay).timeout.connect(_apply_assistance_page, CONNECT_ONE_SHOT)


func _apply_assistance_page() -> void:
	for section in [$Rows/Master, $Rows/Music, $Rows/SFX, $Rows/Pixelation, $Rows/PaletteScheme, $Rows/ShadowQuality]:
		section.visible = not assistance_open
	assistance_options.visible = assistance_open
	row_select.clear_highlight()
	_reregister_row_buttons()


func _on_assistance_toggled(enabled: bool, key: StringName) -> void:
	if syncing:
		return
	var manager := _get_sm()
	if manager != null:
		manager.set_setting(key, enabled)
	SFX.play_event(&"confirm")


func _on_shadow_quality_selected(index: int) -> void:
	if syncing or index < 0 or index >= SHADOW_QUALITIES.size():
		return
	var sm := _get_sm()
	if sm != null:
		sm.call("set_setting", &"shadow_quality", SHADOW_QUALITIES[index])
	_refresh_one_cycle_caption(shadow_quality_option)
	SFX.play_event(&"confirm")


func _refresh_value_labels() -> void:
	master_value.text = "%d%%" % roundi(master_slider.value)
	music_value.text = "%d%%" % roundi(music_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)
	_refresh_cycle_captions()


func _on_slider_drag_ended(_value_changed: bool) -> void:
	SFX.play_event(&"confirm")


func _play_hover() -> void:
	SFX.play_event(&"watch_tick")


func _apply_nier_control_styles() -> void:
	for node in rows.find_children("*", "Label", true, false):
		if node is Label:
			if bool(node.get_meta(&"nier_cycle_bracket", false)):
				continue
			node.add_theme_color_override("font_color", NIER_ACCENT)
	for slider in [master_slider, music_slider, sfx_slider]:
		_style_nier_slider(slider)
	for check in [pixelation_check, auto_vault_check, screen_shake_check]:
		_style_nier_checkbox(check)
	for option in [palette_option, shadow_quality_option]:
		_style_nier_cycle(option)
	_style_nier_link_button(assistance_button)
	_refresh_cycle_captions()


func _style_nier_link_button(button: Button) -> void:
	if button == null:
		return
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_color_override("font_color", NIER_ACCENT)
	button.add_theme_color_override("font_hover_color", Color("d5dde0"))
	button.add_theme_color_override("font_pressed_color", Color("d5dde0"))
	button.add_theme_color_override("font_focus_color", NIER_ACCENT)


func _style_nier_slider(slider: HSlider) -> void:
	var empty := StyleBoxEmpty.new()
	slider.add_theme_stylebox_override("slider", empty)
	slider.add_theme_stylebox_override("grabber_area", empty)
	slider.add_theme_stylebox_override("grabber_area_highlight", empty)
	var grabber := _make_ibeam_grabber(NIER_ACCENT)
	# Hover: bold white I-beam (wider stem + thicker caps), still reads as Roman I.
	var grabber_hover := _make_bold_ibeam_grabber()
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber_hover)
	slider.add_theme_icon_override("grabber_disabled", grabber)
	_bind_slider_thumb_hover(slider)
	var drawer := slider.get_node_or_null("NierDashTrack") as Control
	if drawer == null:
		drawer = Control.new()
		drawer.name = "NierDashTrack"
		drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Root cause: child Controls draw AFTER the parent by default, so the
		# dashed "ant line" was painting over HSlider's theme grabber icon.
		# show_behind_parent puts the track under the I-beam (default+hover).
		drawer.show_behind_parent = true
		drawer.draw.connect(_draw_dashed_slider_track.bind(drawer, slider))
		slider.add_child(drawer)
		slider.resized.connect(drawer.queue_redraw)
		slider.value_changed.connect(func(_v: float) -> void: drawer.queue_redraw())
	else:
		drawer.show_behind_parent = true
		drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer.queue_redraw()


func _draw_dashed_slider_track(drawer: Control, slider: HSlider) -> void:
	var mid_y := drawer.size.y * 0.5
	var dash := 4.0
	var gap := 3.0
	var x := 0.0
	var end_x := drawer.size.x
	while x < end_x:
		var seg_end := minf(x + dash, end_x)
		drawer.draw_line(Vector2(x, mid_y), Vector2(seg_end, mid_y), NIER_ACCENT, 1.0)
		x = seg_end + gap
	var ratio := 0.0
	if slider.max_value > slider.min_value:
		ratio = clampf((slider.value - slider.min_value) / (slider.max_value - slider.min_value), 0.0, 1.0)
	if ratio > 0.0:
		drawer.draw_line(
			Vector2(0.0, mid_y),
			Vector2(drawer.size.x * ratio, mid_y),
			Color(NIER_ACCENT.r, NIER_ACCENT.g, NIER_ACCENT.b, 0.35),
			1.0
		)


func _make_ibeam_grabber(color: Color = NIER_ACCENT) -> ImageTexture:
	## Default thin blue I-beam (not hovered).
	var img := Image.create(5, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(5):
		img.set_pixel(x, 0, color)
		img.set_pixel(x, 13, color)
	for y in range(14):
		img.set_pixel(2, y, color)
	return ImageTexture.create_from_image(img)


func _make_bold_ibeam_grabber() -> ImageTexture:
	## Hover thumb: bold white Roman I (stem + top/bottom serifs), not a solid slab.
	## Default thin I is 5x14 / 1px stem; hover is thicker but keeps side indents.
	const W := 9
	const H := 18
	const STEM_L := 3
	const STEM_R := 5
	const CAP_H := 2
	var white := Color(1.0, 1.0, 1.0, 1.0)
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Top + bottom serifs (full width, CAP_H thick)
	for y in range(CAP_H):
		for x in range(W):
			img.set_pixel(x, y, white)
			img.set_pixel(x, H - 1 - y, white)
	# Vertical stem (thicker than default 1px)
	for y in range(H):
		for x in range(STEM_L, STEM_R + 1):
			img.set_pixel(x, y, white)
	return ImageTexture.create_from_image(img)


func _bind_slider_thumb_hover(slider: HSlider) -> void:
	## Also whiten the trailing % label while the pointer is over the slider (ref).
	if slider == null or bool(slider.get_meta(&"nier_thumb_hover_bound", false)):
		return
	var value_label := _value_label_for_slider(slider)
	slider.mouse_entered.connect(func() -> void:
		if value_label != null:
			value_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	)
	slider.mouse_exited.connect(func() -> void:
		if value_label != null:
			value_label.add_theme_color_override("font_color", NIER_ACCENT)
	)
	slider.set_meta(&"nier_thumb_hover_bound", true)


func _value_label_for_slider(slider: HSlider) -> Label:
	if slider == master_slider:
		return master_value
	if slider == music_slider:
		return music_value
	if slider == sfx_slider:
		return sfx_value
	return null


func _style_nier_checkbox(check: CheckBox) -> void:
	# Fig2: square control only — no wide slate bar, no label text inside the box.
	check.text = ""
	var empty := StyleBoxEmpty.new()
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		check.add_theme_stylebox_override(state, empty)
	_apply_nier_checkbox_icons(check, false)
	check.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	check.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	check.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	check.add_theme_color_override("font_focus_color", Color(0, 0, 0, 0))
	if not bool(check.get_meta(&"nier_check_hover_wired", false)):
		check.mouse_entered.connect(_queue_nier_checkbox_hover_refresh)
		check.mouse_exited.connect(_queue_nier_checkbox_hover_refresh)
		check.toggled.connect(func(_pressed: bool) -> void:
			_refresh_all_nier_checkbox_hovers()
		)
		var desc := _desc_for_check(check)
		if desc != null and not bool(desc.get_meta(&"nier_check_row_hover_wired", false)):
			desc.mouse_entered.connect(_queue_nier_checkbox_hover_refresh)
			desc.mouse_exited.connect(_queue_nier_checkbox_hover_refresh)
			desc.set_meta(&"nier_check_row_hover_wired", true)
		check.set_meta(&"nier_check_hover_wired", true)


func _queue_nier_checkbox_hover_refresh() -> void:
	# Deferred so PixelOptionGroup can settle _active_option after mouse_exited.
	call_deferred("_refresh_all_nier_checkbox_hovers")


func _refresh_all_nier_checkbox_hovers() -> void:
	for check in [pixelation_check, auto_vault_check, screen_shake_check]:
		if check != null and is_instance_valid(check):
			_refresh_nier_checkbox_hover_visual(check)


func _refresh_nier_checkbox_hover_visual(check: CheckBox) -> void:
	if check == null or not is_instance_valid(check):
		return
	_apply_nier_checkbox_icons(check, _is_nier_checkbox_hovered(check))


func _is_nier_checkbox_hovered(check: CheckBox) -> bool:
	if check.is_hovered():
		return true
	var desc := _desc_for_check(check)
	if desc != null and is_instance_valid(desc) and desc.is_hovered():
		return true
	return _desc_is_row_active(desc)


func _desc_for_check(check: CheckBox) -> Button:
	if check == pixelation_check:
		return pixelation_desc
	if check == auto_vault_check:
		return auto_vault_desc
	if check == screen_shake_check:
		return screen_shake_desc
	return null


func _desc_is_row_active(desc: Button) -> bool:
	if desc == null or row_select == null:
		return false
	var idx := row_select.get_active_index()
	if idx < 0:
		return false
	var selectable := row_select.get_selectable_options()
	return idx < selectable.size() and selectable[idx] == desc


func _apply_nier_checkbox_icons(check: CheckBox, hovered: bool) -> void:
	# Hover: outer outline turns white; inner fill stays accent blue (or absent).
	var outline := Color.WHITE if hovered else NIER_ACCENT
	var fill := NIER_ACCENT
	check.add_theme_icon_override("unchecked", _make_square_check_icon(false, 1.0, outline, fill))
	check.add_theme_icon_override("checked", _make_square_check_icon(true, 1.0, outline, fill))
	check.add_theme_icon_override("unchecked_disabled", _make_square_check_icon(false, 0.4, NIER_ACCENT, NIER_ACCENT))
	check.add_theme_icon_override("checked_disabled", _make_square_check_icon(true, 0.4, NIER_ACCENT, NIER_ACCENT))


func _make_square_check_icon(
	checked: bool,
	alpha: float = 1.0,
	outline_color: Color = NIER_ACCENT,
	fill_color: Color = NIER_ACCENT
) -> ImageTexture:
	var size := 12
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var outline := Color(outline_color.r, outline_color.g, outline_color.b, outline_color.a * alpha)
	var fill := Color(fill_color.r, fill_color.g, fill_color.b, fill_color.a * alpha)
	for i in range(size):
		img.set_pixel(i, 0, outline)
		img.set_pixel(i, size - 1, outline)
		img.set_pixel(0, i, outline)
		img.set_pixel(size - 1, i, outline)
	if checked:
		for y in range(3, size - 3):
			for x in range(3, size - 3):
				img.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(img)


func _style_nier_cycle(option: OptionButton) -> void:
	var empty := StyleBoxEmpty.new()
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		option.add_theme_stylebox_override(state, empty)
	option.flat = true
	option.focus_mode = Control.FOCUS_NONE
	option.add_theme_icon_override("arrow", ImageTexture.new())
	# Stock text is hidden; NierCycleCaption draws "< value >".
	option.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	option.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	option.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	option.add_theme_color_override("font_focus_color", Color(0, 0, 0, 0))
	if not bool(option.get_meta(&"nier_cycle_wired", false)):
		option.gui_input.connect(_on_nier_cycle_gui_input.bind(option))
		var popup := option.get_popup()
		if popup != null:
			popup.about_to_popup.connect(_on_nier_cycle_about_to_popup.bind(option))
		option.set_meta(&"nier_cycle_wired", true)
	_ensure_cycle_caption(option)


func _ensure_cycle_caption(option: OptionButton) -> void:
	# Split "< value >" so brackets can turn white on hover while value stays accent.
	var existing := option.get_node_or_null("NierCycleCaption")
	if existing != null and not (existing is HBoxContainer):
		existing.free()
		existing = null
	var caption := existing as HBoxContainer
	if caption == null:
		caption = HBoxContainer.new()
		caption.name = "NierCycleCaption"
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.alignment = BoxContainer.ALIGNMENT_BEGIN
		caption.add_theme_constant_override("separation", 0)
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var left := Label.new()
		left.name = "LeftBracket"
		left.text = "< "
		left.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		left.set_meta(&"nier_cycle_bracket", true)
		left.add_theme_color_override("font_color", NIER_ACCENT)
		var mid := Label.new()
		mid.name = "Value"
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mid.add_theme_color_override("font_color", NIER_ACCENT)
		var right := Label.new()
		right.name = "RightBracket"
		right.text = " >"
		right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		right.set_meta(&"nier_cycle_bracket", true)
		right.add_theme_color_override("font_color", NIER_ACCENT)
		caption.add_child(left)
		caption.add_child(mid)
		caption.add_child(right)
		option.add_child(caption)
	if not bool(option.get_meta(&"nier_cycle_hover_wired", false)):
		# Per-bracket highlight: only the side under the cursor turns white.
		option.gui_input.connect(_on_nier_cycle_bracket_motion.bind(option))
		option.mouse_exited.connect(_on_nier_cycle_bracket_clear.bind(option))
		option.set_meta(&"nier_cycle_hover_wired", true)
	_refresh_one_cycle_caption(option)


func _on_nier_cycle_bracket_motion(event: InputEvent, option: OptionButton) -> void:
	if option == null or not (event is InputEventMouseMotion):
		return
	_update_cycle_bracket_hover_side(option, event.position)


func _on_nier_cycle_bracket_clear(option: OptionButton) -> void:
	if option == null:
		return
	option.set_meta(&"nier_cycle_hover_side", 0)
	_apply_cycle_bracket_colors(option)


func _update_cycle_bracket_hover_side(option: OptionButton, local_pos: Vector2) -> void:
	# Only the bracket under the cursor turns white; middle value lights neither.
	var side := 0
	var caption := option.get_node_or_null("NierCycleCaption") as HBoxContainer
	if caption != null:
		var left := caption.get_node_or_null("LeftBracket") as Label
		var right := caption.get_node_or_null("RightBracket") as Label
		var global_pos := option.get_global_transform() * local_pos
		# Slight grow so the thin "<" / ">" glyphs are easier to hit.
		if left != null and left.get_global_rect().grow(4.0).has_point(global_pos):
			side = -1
		elif right != null and right.get_global_rect().grow(4.0).has_point(global_pos):
			side = 1
	if int(option.get_meta(&"nier_cycle_hover_side", 0)) == side:
		return
	option.set_meta(&"nier_cycle_hover_side", side)
	_apply_cycle_bracket_colors(option)


func _apply_cycle_bracket_colors(option: OptionButton) -> void:
	var caption := option.get_node_or_null("NierCycleCaption") as HBoxContainer
	if caption == null:
		return
	var side := int(option.get_meta(&"nier_cycle_hover_side", 0))
	var hover := Color("d5dde0")
	var left := caption.get_node_or_null("LeftBracket") as Label
	var right := caption.get_node_or_null("RightBracket") as Label
	if left != null:
		left.add_theme_color_override("font_color", hover if side < 0 else NIER_ACCENT)
	if right != null:
		right.add_theme_color_override("font_color", hover if side > 0 else NIER_ACCENT)


func _refresh_cycle_captions() -> void:
	if not is_node_ready():
		return
	for option in [palette_option, shadow_quality_option]:
		if option != null:
			_refresh_one_cycle_caption(option)


func _refresh_one_cycle_caption(option: OptionButton) -> void:
	if option == null:
		return
	var caption := option.get_node_or_null("NierCycleCaption") as HBoxContainer
	if caption == null:
		return
	var idx := option.selected
	var value := option.get_item_text(idx) if idx >= 0 and idx < option.item_count else ""
	var mid := caption.get_node_or_null("Value") as Label
	if mid != null:
		mid.text = value
		mid.add_theme_color_override("font_color", NIER_ACCENT)
	_apply_cycle_bracket_colors(option)


func _on_nier_cycle_about_to_popup(option: OptionButton) -> void:
	var popup := option.get_popup()
	if popup != null:
		popup.hide()


func _on_nier_cycle_gui_input(event: InputEvent, option: OptionButton) -> void:
	if option.item_count <= 0:
		return
	var step := 0
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			step = 1 if event.position.x >= option.size.x * 0.5 else -1
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			step = -1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			step = 1
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		step = -1
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		step = 1
	if step == 0:
		return
	var next_index := posmod(option.selected + step, option.item_count)
	option.select(next_index)
	option.item_selected.emit(next_index)
	_refresh_one_cycle_caption(option)
	var popup := option.get_popup()
	if popup != null:
		popup.hide()
	option.accept_event()


func _wire_desc_confirm_actions() -> void:
	# Accept / click on left description also drives the right-hand control.
	if not bool(pixelation_desc.get_meta(&"nier_desc_confirm", false)):
		pixelation_desc.pressed.connect(func() -> void:
			pixelation_check.button_pressed = not pixelation_check.button_pressed
		)
		pixelation_desc.set_meta(&"nier_desc_confirm", true)
	if not bool(auto_vault_desc.get_meta(&"nier_desc_confirm", false)):
		auto_vault_desc.pressed.connect(func() -> void:
			auto_vault_check.button_pressed = not auto_vault_check.button_pressed
		)
		auto_vault_desc.set_meta(&"nier_desc_confirm", true)
	if not bool(screen_shake_desc.get_meta(&"nier_desc_confirm", false)):
		screen_shake_desc.pressed.connect(func() -> void:
			screen_shake_check.button_pressed = not screen_shake_check.button_pressed
		)
		screen_shake_desc.set_meta(&"nier_desc_confirm", true)
	if not bool(palette_desc.get_meta(&"nier_desc_confirm", false)):
		palette_desc.pressed.connect(func() -> void:
			_cycle_option(palette_option, 1)
		)
		palette_desc.set_meta(&"nier_desc_confirm", true)
	if not bool(shadow_quality_desc.get_meta(&"nier_desc_confirm", false)):
		shadow_quality_desc.pressed.connect(func() -> void:
			_cycle_option(shadow_quality_option, 1)
		)
		shadow_quality_desc.set_meta(&"nier_desc_confirm", true)


func _cycle_option(option: OptionButton, step: int) -> void:
	if option == null or option.item_count <= 0:
		return
	var next_index := posmod(option.selected + step, option.item_count)
	option.select(next_index)
	option.item_selected.emit(next_index)
	_refresh_one_cycle_caption(option)




func _ensure_rows_centered() -> void:
	# Wrap Rows in a CenterContainer so the two-column block sits under the
	# centered "设置" title. Keep left-desc / right-control inside each row.
	if rows == null or not is_instance_valid(rows):
		return
	if rows.get_parent() is CenterContainer:
		return
	var parent := rows.get_parent() as Control
	if parent == null:
		return
	var center := CenterContainer.new()
	center.name = "RowsCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	var idx := rows.get_index()
	parent.add_child(center)
	parent.move_child(center, idx)
	rows.reparent(center)
	# Let Rows shrink to content; CenterContainer will center it.
	rows.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rows.anchor_right = 0.0
	rows.anchor_bottom = 0.0
	rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var shared_row_w := DESC_COL_WIDTH + 12.0 + CONTROL_COL_WIDTH + 40.0
	rows.custom_minimum_size = Vector2(shared_row_w, 0.0)
	for child in rows.get_children():
		if child is Control:
			(child as Control).custom_minimum_size = Vector2(shared_row_w, (child as Control).custom_minimum_size.y)
			(child as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _apply_two_column_layout() -> void:
	# Fixed left rail (descriptions) + fixed right rail (controls) shared by every row.
	# Center the whole settings block under the pause title (not full-bleed left pack).
	if rows != null:
		rows.alignment = BoxContainer.ALIGNMENT_CENTER
		# Fill parent width; children shrink-center inside it.
		rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row_boxes: Array[Control] = []
	for child in rows.get_children() if rows != null else []:
		if child is Control:
			row_boxes.append(child)
	if assistance_options != null:
		for child in assistance_options.get_children():
			if child is Control:
				row_boxes.append(child)
	# Shared row width so short rows (checkbox / cycle) share the same centered column
	# as volume rows — avoids a left-ragged form under the centered title.
	var shared_row_w := DESC_COL_WIDTH + 12.0 + CONTROL_COL_WIDTH + 40.0
	for box in row_boxes:
		# Critical: clear EXPAND_FILL so HBox packs to content width, then centers.
		box.custom_minimum_size = Vector2(shared_row_w, box.custom_minimum_size.y)
		box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if box is HBoxContainer:
			(box as HBoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
	var desc_nodes: Array[Button] = [
		master_desc, music_desc, sfx_desc, pixelation_desc,
		palette_desc, shadow_quality_desc, auto_vault_desc, screen_shake_desc,
	]
	for desc in desc_nodes:
		if desc == null:
			continue
		desc.custom_minimum_size = Vector2(DESC_COL_WIDTH, desc.custom_minimum_size.y)
		desc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		desc.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for slider in [master_slider, music_slider, sfx_slider]:
		if slider != null:
			slider.custom_minimum_size = Vector2(CONTROL_COL_WIDTH, maxf(slider.custom_minimum_size.y, 16.0))
	for check in [pixelation_check, auto_vault_check, screen_shake_check]:
		if check != null:
			check.custom_minimum_size = Vector2(CONTROL_COL_WIDTH, maxf(check.custom_minimum_size.y, 20.0))
	for option in [palette_option, shadow_quality_option]:
		if option != null:
			option.custom_minimum_size = Vector2(CONTROL_COL_WIDTH, maxf(option.custom_minimum_size.y, 20.0))
	# Assistance link sits on the left rail only, but the row itself is centered with peers.
	if assistance_button != null:
		assistance_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		assistance_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


var _control_spring_tweens: Dictionary = {}


func _on_row_selection_changed(_option: Button) -> void:
	# Left description springs via PixelOptionGroup; checkbox outline mirrors row hover.
	_refresh_all_nier_checkbox_hovers()


func _control_for_desc(desc: Button) -> Control:
	if desc == null:
		return null
	if desc == master_desc:
		return master_slider
	if desc == music_desc:
		return music_slider
	if desc == sfx_desc:
		return sfx_slider
	if desc == pixelation_desc:
		return pixelation_check
	if desc == palette_desc:
		return palette_option
	if desc == shadow_quality_desc:
		return shadow_quality_option
	if desc == auto_vault_desc:
		return auto_vault_check
	if desc == screen_shake_desc:
		return screen_shake_check
	return null


func _spring_control(control: Control) -> void:
	## Right-column pop when the row is selected (checkbox / <value> / slider).
	if control == null or not is_instance_valid(control):
		return
	var id := control.get_instance_id()
	var existing: Variant = _control_spring_tweens.get(id)
	if existing is Tween and existing.is_valid():
		existing.kill()
	control.pivot_offset = Vector2(0.0, control.size.y * 0.5)
	control.scale = Vector2(0.85, 1.0)
	var tween := control.create_tween()
	_control_spring_tweens[id] = tween
	tween.tween_property(control, "scale", Vector2(1.10, 1.0), 0.11).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _bounce_slider_thumb(slider: HSlider) -> void:
	if slider == null or not is_instance_valid(slider):
		return
	# Brief vertical jitter on the whole slider when value changes.
	var id := slider.get_instance_id()
	var existing: Variant = _control_spring_tweens.get(id)
	if existing is Tween and existing.is_valid():
		existing.kill()
	var base_y := slider.position.y
	slider.pivot_offset = Vector2(slider.size.x * 0.5, slider.size.y * 0.5)
	var tween := slider.create_tween()
	_control_spring_tweens[id] = tween
	tween.tween_property(slider, "scale", Vector2(1.0, 1.18), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(slider, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Keep base_y referenced so analyzer stays quiet if layout changes.
	if absf(slider.position.y - base_y) > 0.01:
		slider.position.y = base_y


func activate_row_delta(delta: int) -> void:
	row_select.activate_delta(delta)


func trigger_active_row() -> bool:
	return row_select.trigger_active()
