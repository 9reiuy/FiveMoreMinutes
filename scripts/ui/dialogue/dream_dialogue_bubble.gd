class_name DreamDialogueBubble
extends Control

## Visual dialogue bubble for the dream world, sliced from res://art/Dream/talk.png.
## Adheres strictly to retro 3D/pixel aesthetics: nearest-neighbor texture filtering,
## integer pixel coordinates, dynamic speaker-tracking arrow, content-adaptive sizing,
## integrated countdown strip disappearing from left to right,
## arrow visibility protection with inset blue layer and dark base contour,
## expanded head clearance, snappy staggered option entrance animations,
## and dual-anchor layout (speaker tracks bubble, player tracks options).

signal interrupt_pressed
signal option_pressed(index: int)

enum ArrowColor { SLATE_BLUE, DARK_GRAY }

const TALK_TEXTURE: Texture2D = preload("res://art/Dream/talk.png")
const FONT_HELPER: GDScript = preload("res://scripts/ui/crisp_interaction_font.gd")

const BUBBLE_RECT: Rect2 = Rect2(98, 12, 342, 90)
const ARROW_DARK_RECT: Rect2 = Rect2(267, 102, 19, 12)
const ARROW_SLATE_RECT: Rect2 = Rect2(266, 147, 20, 12)
const PROGRESS_RECT: Rect2 = Rect2(100, 140, 338, 7)
const OPTION_RECT: Rect2 = Rect2(191, 279, 167, 32)

const MIN_BUBBLE_SIZE: Vector2 = Vector2(160.0, 48.0)
const MAX_BUBBLE_WIDTH: float = 340.0
const SCREEN_SIZE: Vector2 = Vector2(640.0, 360.0)
const SCREEN_MARGIN: float = 10.0

const MARGIN_LEFT: float = 16.0
const MARGIN_RIGHT: float = 16.0
const MARGIN_TOP: float = 14.0
const MARGIN_BOTTOM: float = 18.0

const INTERRUPT_COLOR: Color = Color("#F80709")
const HOVER_BORDER_COLOR: Color = Color("#8090BD")
const TRACK_TINT: Color = Color(0.2, 0.22, 0.3, 0.75)

const OPTION_SEPARATION: float = 4.0
const OPTION_HEIGHT: float = 32.0
const GAP_OPTIONS_PLAYER_X: float = 28.0
const GAP_OPTIONS_PLAYER_Y: float = -16.0
const HEAD_CLEARANCE: float = 28.0

const ARROW_SIZE: Vector2 = Vector2(19.0, 12.0)
const ARROW_INSET_OFFSET: Vector2 = Vector2(2.0, 2.0)
const ARROW_INSET_SIZE: Vector2 = Vector2(15.0, 8.0)

@export var arrow_color_mode: ArrowColor = ArrowColor.SLATE_BLUE:
	set(value):
		arrow_color_mode = value
		_update_arrow_texture()

@onready var background: NinePatchRect = $Background
@onready var margin_container: MarginContainer = $MarginContainer
@onready var vbox_container: VBoxContainer = $MarginContainer/VBoxContainer
@onready var dialogue_label: Label = $MarginContainer/VBoxContainer/DialogueLabel
@onready var progress_bar_container: Control = $ProgressBarContainer
@onready var progress_track: NinePatchRect = $ProgressBarContainer/Track
@onready var progress_fill_clip: Control = $ProgressBarContainer/FillClip
@onready var progress_fill_bar: NinePatchRect = $ProgressBarContainer/FillClip/FillBar
@onready var speaker_arrow: TextureRect = $SpeakerArrow
@onready var arrow_fill_clip: Control = $SpeakerArrow/ArrowFillClip
@onready var arrow_fill_inset: TextureRect = $SpeakerArrow/ArrowFillClip/ArrowFillInset
@onready var options_container: Control = $OptionsContainer
@onready var interrupt_container: Control = $OptionsContainer/InterruptContainer
@onready var normal_options_container: VBoxContainer = $OptionsContainer/NormalOptionsContainer

var _current_text: String = ""
var _speaker_hud_pos: Vector2 = Vector2.ZERO
var _player_hud_pos: Vector2 = Vector2.ZERO
var _choices: Array = []
var _interrupt_text: String = "闭嘴"
var _progress: float = 0.0 # 0.0 at start (100% full), 1.0 at end (wiped out)
var _is_interrupt_mode: bool = true
var _is_dismissing: bool = false

var _mode_tween: Tween = null
var _dismiss_tween: Tween = null
var _interrupt_entrance_tween: Tween = null
var _normal_options_tween: Tween = null

var _bubble_atlas: AtlasTexture = null
var _arrow_dark_atlas: AtlasTexture = null
var _arrow_slate_atlas: AtlasTexture = null
var _progress_atlas: AtlasTexture = null
var _option_atlas: AtlasTexture = null
var _interrupt_button: DreamOptionButton = null


# -----------------------------------------------------------------------------
# Inner Option Button class
# -----------------------------------------------------------------------------
class DreamOptionButton extends Button:
	var is_interrupt: bool = false
	var border_color: Color = Color.TRANSPARENT
	var _border_style: StyleBoxFlat = null
	var _bg_patch: NinePatchRect = null
	
	func _init(p_text: String, p_is_interrupt: bool = false, p_option_atlas: AtlasTexture = null) -> void:
		text = p_text
		is_interrupt = p_is_interrupt
		custom_minimum_size = Vector2(167.0, 32.0)
		flat = false
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_NONE
		alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Crisp pixel font
		var font: Font = preload("res://scripts/ui/crisp_interaction_font.gd").get_font()
		add_theme_font_override(&"font", font)
		add_theme_font_size_override(&"font_size", 12)
		
		# Sliced NinePatch StyleBoxTexture background (margins 16, 16, 10, 10)
		var atlas: AtlasTexture = p_option_atlas
		if atlas == null:
			atlas = AtlasTexture.new()
			atlas.atlas = preload("res://art/Dream/talk.png")
			atlas.region = Rect2(191, 279, 167, 32)
		
		var style_tex: StyleBoxTexture = StyleBoxTexture.new()
		style_tex.texture = atlas
		style_tex.texture_margin_left = 16.0
		style_tex.texture_margin_right = 16.0
		style_tex.texture_margin_top = 10.0
		style_tex.texture_margin_bottom = 10.0
		style_tex.content_margin_left = 16.0
		style_tex.content_margin_right = 16.0
		style_tex.content_margin_top = 0.0
		style_tex.content_margin_bottom = 0.0
		
		add_theme_stylebox_override(&"normal", style_tex)
		add_theme_stylebox_override(&"hover", style_tex)
		add_theme_stylebox_override(&"pressed", style_tex)
		add_theme_stylebox_override(&"focus", style_tex)
		add_theme_stylebox_override(&"disabled", style_tex)
		
		# Also equip child NinePatchRect background for guaranteed visual capsule presence
		_bg_patch = NinePatchRect.new()
		_bg_patch.name = "Background"
		_bg_patch.texture = atlas
		_bg_patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_bg_patch.patch_margin_left = 16
		_bg_patch.patch_margin_right = 16
		_bg_patch.patch_margin_top = 10
		_bg_patch.patch_margin_bottom = 10
		_bg_patch.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bg_patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_patch.show_behind_parent = true
		add_child(_bg_patch)
		
		_border_style = StyleBoxFlat.new()
		_border_style.draw_center = false
		_border_style.border_width_left = 2
		_border_style.border_width_right = 2
		_border_style.border_width_top = 2
		_border_style.border_width_bottom = 2
		_border_style.corner_radius_top_left = 8
		_border_style.corner_radius_top_right = 8
		_border_style.corner_radius_bottom_left = 8
		_border_style.corner_radius_bottom_right = 8
		_border_style.anti_aliasing = false
		
		if is_interrupt:
			var red: Color = Color("#F80709")
			add_theme_color_override(&"font_color", red)
			add_theme_color_override(&"font_hover_color", red)
			add_theme_color_override(&"font_pressed_color", red)
			add_theme_color_override(&"font_focus_color", red)
			border_color = red
			modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			add_theme_color_override(&"font_color", Color.WHITE)
			add_theme_color_override(&"font_hover_color", Color.WHITE)
			add_theme_color_override(&"font_pressed_color", Color.WHITE)
			add_theme_color_override(&"font_focus_color", Color.WHITE)
			border_color = Color(0.0, 0.0, 0.0, 0.0)
			modulate = Color(0.5, 0.5, 0.5, 1.0)
		
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
	
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			pivot_offset = size * 0.5
	
	func _on_mouse_entered() -> void:
		if disabled:
			return
		if is_interrupt:
			# Pure red outline, subtle brightness/scale feedback, never turns #8090BD
			border_color = Color("#F80709")
			modulate.r = 1.15
			modulate.g = 1.15
			modulate.b = 1.15
			# Keep glyph pixels on their native grid; use the existing border/color feedback.
			scale = Vector2.ONE
		else:
			border_color = Color("#8090BD")
			modulate.r = 1.0
			modulate.g = 1.0
			modulate.b = 1.0
		queue_redraw()
	
	func _on_mouse_exited() -> void:
		if is_interrupt:
			border_color = Color("#F80709")
			modulate.r = 1.0
			modulate.g = 1.0
			modulate.b = 1.0
			scale = Vector2.ONE
		else:
			border_color = Color(0.0, 0.0, 0.0, 0.0)
			modulate.r = 0.5
			modulate.g = 0.5
			modulate.b = 0.5
		queue_redraw()
	
	func _draw() -> void:
		if border_color.a > 0.0 and _border_style != null:
			_border_style.border_color = border_color
			draw_style_box(_border_style, Rect2(Vector2.ZERO, size))


# -----------------------------------------------------------------------------
# Lifecycle & Initialization
# -----------------------------------------------------------------------------
func _enter_tree() -> void:
	_ensure_nodes()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_nodes()
	_setup_textures()
	_setup_font()
	_update_arrow_texture()


func _exit_tree() -> void:
	if _mode_tween and _mode_tween.is_valid():
		_mode_tween.kill()
	if _dismiss_tween and _dismiss_tween.is_valid():
		_dismiss_tween.kill()
	if _interrupt_entrance_tween and _interrupt_entrance_tween.is_valid():
		_interrupt_entrance_tween.kill()
	if _normal_options_tween and _normal_options_tween.is_valid():
		_normal_options_tween.kill()


func _process(_delta: float) -> void:
	if visible and not _is_dismissing:
		_update_bubble_position()
		_update_options_position()


func _ensure_nodes() -> void:
	if background == null:
		background = get_node_or_null("Background") as NinePatchRect
	if background == null:
		background = NinePatchRect.new()
		background.name = "Background"
		background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		background.patch_margin_left = 12
		background.patch_margin_right = 12
		background.patch_margin_top = 12
		background.patch_margin_bottom = 12
		add_child(background)
	
	if margin_container == null:
		margin_container = get_node_or_null("MarginContainer") as MarginContainer
	if margin_container == null:
		margin_container = MarginContainer.new()
		margin_container.name = "MarginContainer"
		margin_container.add_theme_constant_override(&"margin_left", int(MARGIN_LEFT))
		margin_container.add_theme_constant_override(&"margin_right", int(MARGIN_RIGHT))
		margin_container.add_theme_constant_override(&"margin_top", int(MARGIN_TOP))
		margin_container.add_theme_constant_override(&"margin_bottom", int(MARGIN_BOTTOM))
		add_child(margin_container)
	
	if vbox_container == null:
		vbox_container = margin_container.get_node_or_null("VBoxContainer") as VBoxContainer
	if vbox_container == null:
		vbox_container = VBoxContainer.new()
		vbox_container.name = "VBoxContainer"
		margin_container.add_child(vbox_container)
	
	if dialogue_label == null:
		dialogue_label = vbox_container.get_node_or_null("DialogueLabel") as Label
	if dialogue_label == null:
		dialogue_label = Label.new()
		dialogue_label.name = "DialogueLabel"
		dialogue_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dialogue_label.add_theme_color_override(&"font_color", Color.WHITE)
		vbox_container.add_child(dialogue_label)
	
	if progress_bar_container == null:
		progress_bar_container = get_node_or_null("ProgressBarContainer") as Control
	if progress_bar_container == null:
		progress_bar_container = Control.new()
		progress_bar_container.name = "ProgressBarContainer"
		progress_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progress_bar_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(progress_bar_container)
	
	if progress_track == null:
		progress_track = progress_bar_container.get_node_or_null("Track") as NinePatchRect
	if progress_track == null:
		progress_track = NinePatchRect.new()
		progress_track.name = "Track"
		progress_track.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		progress_track.patch_margin_left = 6
		progress_track.patch_margin_right = 6
		progress_track.modulate = TRACK_TINT
		progress_bar_container.add_child(progress_track)
	
	if progress_fill_clip == null:
		progress_fill_clip = progress_bar_container.get_node_or_null("FillClip") as Control
	if progress_fill_clip == null:
		progress_fill_clip = Control.new()
		progress_fill_clip.name = "FillClip"
		progress_fill_clip.clip_contents = true
		progress_fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progress_fill_clip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		progress_bar_container.add_child(progress_fill_clip)
	
	if progress_fill_bar == null:
		progress_fill_bar = progress_fill_clip.get_node_or_null("FillBar") as NinePatchRect
	if progress_fill_bar == null:
		progress_fill_bar = NinePatchRect.new()
		progress_fill_bar.name = "FillBar"
		progress_fill_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		progress_fill_bar.patch_margin_left = 6
		progress_fill_bar.patch_margin_right = 6
		progress_fill_clip.add_child(progress_fill_bar)
	
	if speaker_arrow == null:
		speaker_arrow = get_node_or_null("SpeakerArrow") as TextureRect
	if speaker_arrow == null:
		speaker_arrow = TextureRect.new()
		speaker_arrow.name = "SpeakerArrow"
		speaker_arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		speaker_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(speaker_arrow)
	
	if arrow_fill_clip == null and speaker_arrow != null:
		arrow_fill_clip = speaker_arrow.get_node_or_null("ArrowFillClip") as Control
	if arrow_fill_clip == null and speaker_arrow != null:
		arrow_fill_clip = Control.new()
		arrow_fill_clip.name = "ArrowFillClip"
		arrow_fill_clip.clip_contents = true
		arrow_fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow_fill_clip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		speaker_arrow.add_child(arrow_fill_clip)
	
	if arrow_fill_inset == null and arrow_fill_clip != null:
		arrow_fill_inset = arrow_fill_clip.get_node_or_null("ArrowFillInset") as TextureRect
	if arrow_fill_inset == null and arrow_fill_clip != null:
		arrow_fill_inset = TextureRect.new()
		arrow_fill_inset.name = "ArrowFillInset"
		arrow_fill_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow_fill_inset.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		arrow_fill_inset.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow_fill_clip.add_child(arrow_fill_inset)
	
	if options_container == null:
		options_container = get_node_or_null("OptionsContainer") as Control
	if options_container == null:
		options_container = Control.new()
		options_container.name = "OptionsContainer"
		options_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(options_container)
	options_container.top_level = true
	
	if interrupt_container == null:
		interrupt_container = options_container.get_node_or_null("InterruptContainer") as Control
	if interrupt_container == null:
		interrupt_container = Control.new()
		interrupt_container.name = "InterruptContainer"
		interrupt_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		options_container.add_child(interrupt_container)
	
	if normal_options_container == null:
		normal_options_container = options_container.get_node_or_null("NormalOptionsContainer") as VBoxContainer
	if normal_options_container == null:
		normal_options_container = VBoxContainer.new()
		normal_options_container.name = "NormalOptionsContainer"
		normal_options_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		normal_options_container.add_theme_constant_override(&"separation", int(OPTION_SEPARATION))
		options_container.add_child(normal_options_container)


func _setup_textures() -> void:
	if _bubble_atlas == null:
		_bubble_atlas = AtlasTexture.new()
		_bubble_atlas.atlas = TALK_TEXTURE
		_bubble_atlas.region = BUBBLE_RECT
	if background != null:
		background.texture = _bubble_atlas
		background.patch_margin_left = 12
		background.patch_margin_right = 12
		background.patch_margin_top = 12
		background.patch_margin_bottom = 12
	
	if _progress_atlas == null:
		_progress_atlas = AtlasTexture.new()
		_progress_atlas.atlas = TALK_TEXTURE
		_progress_atlas.region = PROGRESS_RECT
	if progress_track != null:
		progress_track.texture = _progress_atlas
		progress_track.patch_margin_left = 6
		progress_track.patch_margin_right = 6
		progress_track.modulate = TRACK_TINT
	if progress_fill_bar != null:
		progress_fill_bar.texture = _progress_atlas
		progress_fill_bar.patch_margin_left = 6
		progress_fill_bar.patch_margin_right = 6
		progress_fill_bar.modulate = Color.WHITE
	
	if _arrow_dark_atlas == null:
		_arrow_dark_atlas = AtlasTexture.new()
		_arrow_dark_atlas.atlas = TALK_TEXTURE
		_arrow_dark_atlas.region = ARROW_DARK_RECT
	if _arrow_slate_atlas == null:
		_arrow_slate_atlas = AtlasTexture.new()
		_arrow_slate_atlas.atlas = TALK_TEXTURE
		_arrow_slate_atlas.region = ARROW_SLATE_RECT
	
	if speaker_arrow != null:
		speaker_arrow.texture = _arrow_dark_atlas
		speaker_arrow.size = ARROW_SIZE
	
	if arrow_fill_inset != null:
		arrow_fill_inset.texture = _arrow_slate_atlas
		arrow_fill_inset.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow_fill_inset.size = ARROW_INSET_SIZE
	
	if _option_atlas == null:
		_option_atlas = AtlasTexture.new()
		_option_atlas.atlas = TALK_TEXTURE
		_option_atlas.region = OPTION_RECT


func _setup_font() -> void:
	var font: Font = FONT_HELPER.get_font()
	if dialogue_label != null:
		dialogue_label.add_theme_font_override(&"font", font)
		dialogue_label.add_theme_font_size_override(&"font_size", 12)
		dialogue_label.add_theme_color_override(&"font_color", Color.WHITE)


func _update_arrow_texture() -> void:
	if speaker_arrow == null:
		return
	if arrow_color_mode == ArrowColor.DARK_GRAY:
		if is_instance_valid(arrow_fill_clip):
			arrow_fill_clip.visible = false
	else:
		if is_instance_valid(arrow_fill_clip) and _progress < 1.0:
			arrow_fill_clip.visible = true
	_update_progress_bar(_progress)


# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------
func show_dialogue(
	text: String,
	speaker_hud_pos: Vector2,
	choices: Array,
	interrupt_text: String = "闭嘴"
) -> void:
	_current_text = text
	_speaker_hud_pos = speaker_hud_pos
	_choices = choices
	_interrupt_text = interrupt_text
	_is_interrupt_mode = true
	_is_dismissing = false
	_progress = 0.0 # Starts at 0.0 (100% full blue bar)
	
	if _player_hud_pos == Vector2.ZERO:
		_player_hud_pos = Vector2(SCREEN_SIZE.x * 0.5, clampf(speaker_hud_pos.y + 100.0, 160.0, SCREEN_SIZE.y - 60.0))
	
	_ensure_nodes()
	_setup_textures()
	_setup_font()
	_update_arrow_texture()
	
	# Setup label text
	dialogue_label.visible = true
	dialogue_label.text = text
	dialogue_label.visible_characters = 0
	
	# Compute adaptive bubble size
	var font: Font = FONT_HELPER.get_font()
	var single_line_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12)
	
	var bubble_w: float = 0.0
	var bubble_h: float = 0.0
	var text_padding_h: float = MARGIN_LEFT + MARGIN_RIGHT # 32.0
	var text_padding_v: float = MARGIN_TOP + MARGIN_BOTTOM # 32.0
	var max_text_width: float = MAX_BUBBLE_WIDTH - text_padding_h # 308.0
	
	if single_line_size.x <= max_text_width and not "\n" in text:
		bubble_w = maxf(MIN_BUBBLE_SIZE.x, single_line_size.x + text_padding_h)
		bubble_h = maxf(MIN_BUBBLE_SIZE.y, single_line_size.y + text_padding_v)
	else:
		bubble_w = MAX_BUBBLE_WIDTH
		var multiline_size: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, max_text_width, 12)
		bubble_h = maxf(MIN_BUBBLE_SIZE.y, multiline_size.y + text_padding_v)
	
	bubble_w = round(bubble_w)
	bubble_h = round(bubble_h)
	
	# Apply bubble dimensions
	custom_minimum_size = Vector2(bubble_w, bubble_h)
	size = Vector2(bubble_w, bubble_h)
	background.size = size
	margin_container.size = size
	
	# Layout integrated bottom strip along inner bottom edge
	var inner_width: float = bubble_w - 24.0
	progress_bar_container.position = Vector2(12.0, round(bubble_h - 11.0))
	progress_bar_container.size = Vector2(inner_width, 7.0)
	
	# Setup options & buttons (and triggers interrupt entrance animation)
	_setup_options()
	
	# Position bubble relative to speaker and options relative to player
	_update_bubble_position()
	_update_options_position()
	_update_progress_bar(0.0)
	
	modulate.a = 1.0
	visible = true
	if is_instance_valid(options_container):
		options_container.modulate.a = 1.0
		options_container.visible = true


func set_speaker_hud_position(pos: Vector2) -> void:
	_speaker_hud_pos = pos
	_update_bubble_position()


func set_player_hud_position(pos: Vector2) -> void:
	_player_hud_pos = pos
	_update_options_position()


func set_typing_progress(progress_ratio: float, visible_chars: int) -> void:
	if not is_instance_valid(dialogue_label):
		return
	
	dialogue_label.visible_characters = visible_chars
	_progress = clampf(progress_ratio, 0.0, 1.0)
	_update_progress_bar(_progress)
	
	# When progress_ratio <= 0.20: interrupt mode.
	# When progress_ratio > 0.20: transition to normal options.
	if _progress > 0.20 and _is_interrupt_mode:
		transition_to_normal_options()


func dismiss(fade_time: float = 0.15) -> void:
	if _is_dismissing:
		return
	_is_dismissing = true
	
	if _mode_tween and _mode_tween.is_valid():
		_mode_tween.kill()
	if _dismiss_tween and _dismiss_tween.is_valid():
		_dismiss_tween.kill()
	if _interrupt_entrance_tween and _interrupt_entrance_tween.is_valid():
		_interrupt_entrance_tween.kill()
	if _normal_options_tween and _normal_options_tween.is_valid():
		_normal_options_tween.kill()
	
	if fade_time <= 0.0:
		visible = false
		if is_instance_valid(options_container):
			options_container.visible = false
		_is_dismissing = false
		return
	
	_dismiss_tween = create_tween()
	_dismiss_tween.set_parallel(true)
	_dismiss_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	if is_instance_valid(options_container):
		_dismiss_tween.tween_property(options_container, "modulate:a", 0.0, fade_time)
	_dismiss_tween.chain().tween_callback(func() -> void:
		visible = false
		if is_instance_valid(options_container):
			options_container.visible = false
		_is_dismissing = false
	)


func is_dialogue_visible() -> bool:
	return visible and not _is_dismissing and modulate.a > 0.01


func get_dialogue_label() -> Label:
	return dialogue_label


func get_speaker_hud_position() -> Vector2:
	return _speaker_hud_pos


func get_player_hud_position() -> Vector2:
	return _player_hud_pos


func transition_to_normal_options() -> void:
	if not _is_interrupt_mode:
		return
	_is_interrupt_mode = false
	
	if _mode_tween and _mode_tween.is_valid():
		_mode_tween.kill()
	if _interrupt_entrance_tween and _interrupt_entrance_tween.is_valid():
		_interrupt_entrance_tween.kill()
	
	var has_choices: bool = not _choices.is_empty()
	if has_choices:
		normal_options_container.visible = true
		normal_options_container.modulate.a = 1.0
	
	_mode_tween = create_tween()
	_mode_tween.set_parallel(true)
	_mode_tween.tween_property(interrupt_container, "modulate:a", 0.0, 0.08)
	_mode_tween.chain().tween_callback(func() -> void:
		interrupt_container.visible = false
		if is_instance_valid(options_container):
			options_container.size = Vector2(options_container.size.x, _get_options_height())
			_update_options_position()
	)
	
	# Crisp, snappy entrance animation for normal options
	if has_choices:
		_play_normal_options_entrance()
	
	_update_options_position()


func update_speaker_position() -> void:
	if not is_instance_valid(speaker_arrow):
		return
	
	var arrow_w: float = speaker_arrow.size.x
	var min_x: float = 16.0
	var max_x: float = maxf(min_x, size.x - 16.0 - arrow_w)
	var target_x: float = _speaker_hud_pos.x - position.x - (arrow_w * 0.5)
	
	speaker_arrow.position.x = round(clampf(target_x, min_x, max_x))
	speaker_arrow.position.y = round(size.y - 1.0)
	
	_update_progress_bar(_progress)


# -----------------------------------------------------------------------------
# Internal helpers
# -----------------------------------------------------------------------------
func _get_options_height() -> float:
	var count: int = 0
	if _is_interrupt_mode:
		count = 1
	else:
		count = _choices.size()
	if count <= 0:
		return 0.0
	return float(count * int(OPTION_HEIGHT) + (count - 1) * int(OPTION_SEPARATION))


func _update_bubble_position() -> void:
	var bubble_w: float = size.x
	var bubble_h: float = size.y
	
	# Bubble Anchor: Tracks CURRENT SPEAKER (NPC). Bubble is positioned well above the speaker
	# using HEAD_CLEARANCE (28.0px), ensuring the NPC face, head, and counter are completely un-obscured.
	var bubble_bottom_y: float = _speaker_hud_pos.y - HEAD_CLEARANCE
	var bubble_y: float = bubble_bottom_y - bubble_h
	
	var min_y: float = SCREEN_MARGIN
	var max_y: float = maxf(min_y, SCREEN_SIZE.y - SCREEN_MARGIN - bubble_h)
	bubble_y = clampf(bubble_y, min_y, max_y)
	
	var min_x: float = SCREEN_MARGIN
	var max_x: float = maxf(min_x, SCREEN_SIZE.x - SCREEN_MARGIN - bubble_w)
	var desired_x: float = _speaker_hud_pos.x - (bubble_w * 0.5)
	var bubble_x: float = clampf(desired_x, min_x, max_x)
	
	position = Vector2(round(bubble_x), round(bubble_y))
	
	update_speaker_position()


func _update_options_position() -> void:
	if not is_instance_valid(options_container):
		return
	
	var option_width: float = options_container.size.x
	var options_height: float = _get_options_height()
	
	# Options are displayed to the RIGHT of the player character:
	# options_target_pos = player_hud_pos + Vector2(28.0, -16.0)
	var target_x: float = _player_hud_pos.x + GAP_OPTIONS_PLAYER_X
	if target_x + option_width > SCREEN_SIZE.x - SCREEN_MARGIN:
		# Flip options to the LEFT of the player:
		target_x = _player_hud_pos.x - GAP_OPTIONS_PLAYER_X - option_width
	
	target_x = clampf(target_x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, SCREEN_SIZE.x - SCREEN_MARGIN - option_width))
	
	var target_y: float = _player_hud_pos.y + GAP_OPTIONS_PLAYER_Y
	var max_y: float = maxf(SCREEN_MARGIN, SCREEN_SIZE.y - SCREEN_MARGIN - options_height)
	target_y = clampf(target_y, SCREEN_MARGIN, max_y)
	
	var final_pos: Vector2 = Vector2(round(target_x), round(target_y))
	if options_container.top_level:
		options_container.position = final_pos
	else:
		options_container.position = final_pos - position


func _update_progress_bar(progress_ratio: float) -> void:
	_progress = clampf(progress_ratio, 0.0, 1.0)
	if not is_instance_valid(progress_bar_container):
		return
	
	var inner_width: float = progress_bar_container.size.x
	if inner_width <= 0.0:
		return
	
	# Dark Base Strip: along the bubble bottom
	if is_instance_valid(progress_track):
		progress_track.position = Vector2.ZERO
		progress_track.size = Vector2(inner_width, 7.0)
		progress_track.visible = true
	
	# Blue Timer Strip: Starts 100% full, disappears from LEFT to RIGHT!
	# Initial state (_progress = 0.0): cut_x = 0, size.x = inner_width
	# As time advances (_progress = 0.0 -> 1.0):
	# cut_x moves from 0 to inner_width, wiping away the left portion.
	var cut_x: float = inner_width * _progress
	var visible_w: float = maxf(0.0, inner_width - cut_x)
	
	if is_instance_valid(progress_fill_clip) and is_instance_valid(progress_fill_bar):
		if visible_w <= 0.001 or _progress >= 1.0:
			progress_fill_clip.position.x = round(inner_width)
			progress_fill_clip.size = Vector2(0.0, 7.0)
			progress_fill_bar.position.x = -round(inner_width)
			progress_fill_bar.size = Vector2(inner_width, 7.0)
			progress_fill_clip.visible = false
		else:
			progress_fill_clip.position.x = round(cut_x)
			progress_fill_clip.size = Vector2(round(visible_w), 7.0)
			progress_fill_bar.position.x = -round(cut_x)
			progress_fill_bar.size = Vector2(inner_width, 7.0)
			progress_fill_clip.visible = true
	
	# Blue Arrow Inset: Sits inside the dark base arrow (2px inset contour),
	# and gets wiped from left to right synchronously with the countdown strip.
	if is_instance_valid(speaker_arrow) and is_instance_valid(arrow_fill_clip) and is_instance_valid(arrow_fill_inset):
		if arrow_color_mode == ArrowColor.DARK_GRAY or _progress >= 1.0 or visible_w <= 0.001:
			arrow_fill_clip.visible = false
			arrow_fill_clip.size = Vector2(0.0, ARROW_INSET_SIZE.y)
		else:
			var wipe_bubble_x: float = progress_bar_container.position.x + cut_x
			var arrow_start_x: float = speaker_arrow.position.x + ARROW_INSET_OFFSET.x
			var arrow_end_x: float = arrow_start_x + ARROW_INSET_SIZE.x
			
			if wipe_bubble_x <= arrow_start_x:
				arrow_fill_clip.position.x = round(ARROW_INSET_OFFSET.x)
				arrow_fill_clip.size = ARROW_INSET_SIZE
				arrow_fill_inset.position.x = 0.0
				arrow_fill_clip.visible = true
			elif wipe_bubble_x >= arrow_end_x:
				arrow_fill_clip.position.x = round(ARROW_INSET_OFFSET.x + ARROW_INSET_SIZE.x)
				arrow_fill_clip.size = Vector2(0.0, ARROW_INSET_SIZE.y)
				arrow_fill_clip.visible = false
			else:
				var arrow_cut_x: float = wipe_bubble_x - arrow_start_x
				var arrow_visible_w: float = maxf(0.0, ARROW_INSET_SIZE.x - arrow_cut_x)
				arrow_fill_clip.position.x = round(ARROW_INSET_OFFSET.x + arrow_cut_x)
				arrow_fill_clip.size = Vector2(round(arrow_visible_w), ARROW_INSET_SIZE.y)
				arrow_fill_inset.position.x = -round(arrow_cut_x)
				arrow_fill_clip.visible = arrow_visible_w > 0.0


func _setup_options() -> void:
	if _interrupt_entrance_tween and _interrupt_entrance_tween.is_valid():
		_interrupt_entrance_tween.kill()
	if _normal_options_tween and _normal_options_tween.is_valid():
		_normal_options_tween.kill()
	
	# Clear previous options
	for child: Node in interrupt_container.get_children():
		child.queue_free()
	for child: Node in normal_options_container.get_children():
		child.queue_free()
	
	var font: Font = FONT_HELPER.get_font()
	var max_btn_w: float = 167.0
	
	# Build interrupt button
	_interrupt_button = DreamOptionButton.new(_interrupt_text, true, _option_atlas)
	var interrupt_str_w: float = font.get_string_size(_interrupt_text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 12).x
	max_btn_w = maxf(max_btn_w, interrupt_str_w + 32.0)
	_interrupt_button.pressed.connect(_on_interrupt_pressed)
	interrupt_container.add_child(_interrupt_button)
	
	# Build normal options
	var normal_buttons: Array[DreamOptionButton] = []
	for i: int in range(_choices.size()):
		var choice: Variant = _choices[i]
		var choice_str: String = ""
		var enabled: bool = true
		if choice is Dictionary:
			var dict: Dictionary = choice as Dictionary
			choice_str = str(dict.get("text", ""))
			enabled = bool(dict.get("enabled", true))
		elif choice is String:
			choice_str = str(choice)
		else:
			choice_str = str(choice)
		
		var btn: DreamOptionButton = DreamOptionButton.new(choice_str, false, _option_atlas)
		btn.disabled = not enabled
		var str_w: float = font.get_string_size(choice_str, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 12).x
		max_btn_w = maxf(max_btn_w, str_w + 32.0)
		btn.pressed.connect(_on_option_button_pressed.bind(i))
		normal_options_container.add_child(btn)
		normal_buttons.append(btn)
	
	max_btn_w = round(minf(MAX_BUBBLE_WIDTH, max_btn_w))
	
	# Apply uniform width to all buttons
	_interrupt_button.custom_minimum_size = Vector2(max_btn_w, OPTION_HEIGHT)
	_interrupt_button.size = _interrupt_button.custom_minimum_size
	interrupt_container.custom_minimum_size = _interrupt_button.custom_minimum_size
	interrupt_container.size = interrupt_container.custom_minimum_size
	
	for btn: DreamOptionButton in normal_buttons:
		btn.custom_minimum_size = Vector2(max_btn_w, OPTION_HEIGHT)
		btn.size = btn.custom_minimum_size
	
	var opt_h: float = _get_options_height()
	options_container.custom_minimum_size = Vector2(max_btn_w, opt_h)
	options_container.size = options_container.custom_minimum_size
	
	# Initial visibility: Interrupt mode
	interrupt_container.visible = true
	interrupt_container.modulate.a = 1.0
	normal_options_container.visible = false
	normal_options_container.modulate.a = 0.0
	
	_update_options_position()
	
	# Play Red Interrupt entrance animation
	_play_interrupt_entrance()


func _play_interrupt_entrance() -> void:
	if not is_instance_valid(_interrupt_button):
		return
	if _interrupt_entrance_tween and _interrupt_entrance_tween.is_valid():
		_interrupt_entrance_tween.kill()
	
	_interrupt_button.pivot_offset = _interrupt_button.size * 0.5
	_interrupt_button.position.x = 10.0
	_interrupt_button.scale = Vector2.ONE
	_interrupt_button.modulate.a = 0.0
	
	_interrupt_entrance_tween = create_tween()
	_interrupt_entrance_tween.set_parallel(true)
	_interrupt_entrance_tween.tween_property(_interrupt_button, "position:x", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_interrupt_entrance_tween.tween_property(_interrupt_button, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_interrupt_entrance_tween.tween_property(_interrupt_button, "modulate:a", 1.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_normal_options_entrance() -> void:
	if _normal_options_tween and _normal_options_tween.is_valid():
		_normal_options_tween.kill()
	
	var children: Array[Node] = normal_options_container.get_children()
	if children.is_empty():
		return
	
	_normal_options_tween = create_tween()
	_normal_options_tween.set_parallel(true)
	
	for i: int in range(children.size()):
		var btn: DreamOptionButton = children[i] as DreamOptionButton
		if btn == null:
			continue
		
		btn.pivot_offset = btn.size * 0.5
		btn.position.x = 14.0
		btn.scale = Vector2.ONE
		# Starts with 50% RGB brightness, 0.0 alpha
		btn.modulate = Color(0.5, 0.5, 0.5, 0.0)
		
		var delay: float = float(i) * 0.03
		_normal_options_tween.tween_property(btn, "position:x", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(delay)
		_normal_options_tween.tween_property(btn, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(delay)
		_normal_options_tween.tween_property(btn, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(delay)


func _on_interrupt_pressed() -> void:
	interrupt_pressed.emit()


func _on_option_button_pressed(index: int) -> void:
	option_pressed.emit(index)
