extends CanvasLayer
## Presentation-only cut-in. Own it beside a scene's root HUD, then call
## play_cue("背后"). Repeated calls replace the current card, never stack it.
signal cue_started(message: String)
signal cue_presented(message: String)
signal cue_finished(message: String, completed: bool)

@export_range(0.15, 1.5, 0.01) var duration := 0.46
@export var ink_color := Color.WHITE
@export var glow_color := Color.WHITE
@export var title_font: Font

@onready var cover: Control = $Cover
@onready var backdrop: ColorRect = $Cover/Vignette
@onready var title: Control = $Cover/Title
@onready var glow: Control = $Cover/Title/Glow
@onready var ink: Control = $Cover/Title/Ink

var current_message := ""
var active := false
var presented := false
var _started_usec := 0
var _duration := 0.46
var _time_controller: Node
var _cue_serial := 0
var _render_warmed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cover.resized.connect(_layout)
	cover.hide()
	set_process(false)
	_layout()


func play_cue(message: String, seconds := -1.0) -> bool:
	var text := message.strip_edges()
	if not is_inside_tree() or not is_node_ready() or title_font == null or text.is_empty() or get_tree().paused:
		return false
	if active:
		cancel()
	_time_controller = get_node_or_null("/root/DreamTimeController")
	if _time_controller == null or not _time_controller.has_method("request_fullscreen_cue_time"):
		return false
	if not _time_controller.request_fullscreen_cue_time(self):
		return false
	current_message = text
	_duration = duration if seconds < 0.0 else clampf(seconds, 0.15, 1.5)
	_started_usec = 0
	presented = false
	_cue_serial += 1
	active = true
	_layout()
	cover.modulate.a = 1.0
	cover.show()
	set_process(true)
	_present(0.0)
	cue_started.emit(current_message)
	_begin_visible_lifetime.call_deferred(_cue_serial)
	return true


func _begin_visible_lifetime(serial: int) -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
		if not active or serial != _cue_serial:
			return
		# First-use shader/font uploads can finish after frame_post_draw. Fence
		# that first frame once; never read back a texture on ordinary cue frames.
		if not _render_warmed:
			get_viewport().get_texture().get_image()
			_render_warmed = true
	if not active or serial != _cue_serial:
		return
	if get_tree().paused or not is_instance_valid(_time_controller) or not _time_controller.has_fullscreen_cue_time(self):
		cancel()
		return
	_started_usec = Time.get_ticks_usec()
	presented = true
	var audio := get_node_or_null("/root/SFXManager")
	if audio != null:
		audio.play(&"fullscreen_cue")
	cue_presented.emit(current_message)


func cancel() -> void:
	_finish(false)


func _process(_delta: float) -> void:
	if get_tree().paused or not is_instance_valid(_time_controller) or not _time_controller.has_fullscreen_cue_time(self):
		cancel()
		return
	if not presented:
		return
	# The game is held at an absolute 0.05x by the existing time authority.
	# The card itself keeps its short real-time screen duration.
	var elapsed := float(Time.get_ticks_usec() - _started_usec) / 1000000.0
	if elapsed >= _duration:
		_finish(true)
		return
	_present(elapsed)


func _present(elapsed: float) -> void:
	var punch := pow(1.0 - clampf(elapsed / 0.075, 0.0, 1.0), 3.0)
	title.scale = Vector2.ONE * (1.0 + punch * 0.085)
	var tail := 1.0 - smoothstep(_duration - 0.035, _duration, elapsed)
	cover.modulate.a = tail
	backdrop.material.set_shader_parameter(&"strength", tail)
	backdrop.material.set_shader_parameter(&"flash", punch)
	var light_gain := 1.20 + punch * 0.50
	glow.modulate = Color(light_gain, light_gain, light_gain, 1.0)


func _finish(completed: bool) -> void:
	if not active:
		return
	var previous := current_message
	active = false
	presented = false
	_cue_serial += 1
	current_message = ""
	cover.hide()
	set_process(false)
	if is_instance_valid(_time_controller):
		_time_controller.release_fullscreen_cue_time(self)
	cue_finished.emit(previous, completed)


func _layout() -> void:
	if not is_node_ready():
		return
	title.pivot_offset = cover.size * 0.5
	if current_message.is_empty() or title_font == null:
		return
	var lines := current_message.split("\n")
	var font_size := maxi(8, roundi(cover.size.y * 0.49 / float(maxi(lines.size(), 1))))
	var widest := 0.0
	for line in lines:
		widest = maxf(widest, title_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	if widest > cover.size.x * 0.80:
		font_size = maxi(8, floori(font_size * cover.size.x * 0.80 / widest))
	glow.configure(title_font, current_message, font_size, glow_color, true)
	ink.configure(title_font, current_message, font_size, ink_color, false)


func _exit_tree() -> void:
	_cue_serial += 1
	if is_instance_valid(_time_controller):
		_time_controller.release_fullscreen_cue_time(self)
	active = false
