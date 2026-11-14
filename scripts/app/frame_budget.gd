extends Node
## Shared resource budget for ordinary game and preview entry points.
const FOREGROUND_FPS := 60
const BACKGROUND_FPS := 30
var enabled := false
var startup_limit := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var scripted := "--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args()
	# Diagnostics retain their deliberately chosen measurement conditions.
	enabled = not scripted or "--enforce-frame-budget" in OS.get_cmdline_user_args()
	if not enabled:
		return
	startup_limit = Engine.max_fps
	get_window().focus_entered.connect(apply_window_focus.bind(true))
	get_window().focus_exited.connect(apply_window_focus.bind(false))
	apply_window_focus(get_window().has_focus())

func apply_window_focus(focused: bool) -> void:
	if not enabled:
		return
	var limit := FOREGROUND_FPS if focused else BACKGROUND_FPS
	Engine.max_fps = mini(limit, startup_limit) if startup_limit > 0 else limit
