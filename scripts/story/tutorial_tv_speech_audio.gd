extends AudioStreamPlayer
## Quiet tutorial-TV speech texture; the lesson/dialogue clocks own its timing.
const STATIC_STREAM := preload("res://sfx/preview/screen_wall_static.res")
const VOLUME_DB := -26.0
const EDGE_SECONDS := 0.012
var _speaking := false
var _fade: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	stream = STATIC_STREAM
	bus = &"UI"
	max_polyphony = 1
	volume_db = -70.0

func set_speaking(active: bool) -> void:
	if active == _speaking and (not active or playing):
		return
	_speaking = active
	if _fade != null and _fade.is_valid(): _fade.kill()
	if not is_inside_tree():
		_speaking = false
		stop()
		return
	if active:
		if not playing:
			volume_db = -70.0
			play()
		_fade = create_tween()
		_fade.tween_property(self, "volume_db", VOLUME_DB, EDGE_SECONDS)
	elif playing:
		_fade = create_tween()
		_fade.tween_property(self, "volume_db", -70.0, EDGE_SECONDS)
		_fade.tween_callback(stop)

func _exit_tree() -> void:
	if _fade != null and _fade.is_valid(): _fade.kill()
	_speaking = false
	stop()
