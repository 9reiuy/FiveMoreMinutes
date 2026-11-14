extends Control
## Standalone six-level chapter. The formal game's main scene remains separate.

const DISPLAY := preload("res://scenes/testing/LinkedMaintenanceGarageDisplay.tscn")
const PAUSE_MENU := preload("res://scenes/ui/pause_menu.tscn")
const PAUSE_REASON := &"PROLOGUE_MENU"
const END_REASON := &"PROLOGUE_COMPLETE"
const STAGE_NAMES := ["维修通道", "地下车库", "仓储区", "地下通道", "下港站台", "末班列车"]

var display: Control
var world: Node3D
var pause_menu: GlobalPauseMenu
var completion_panel: Control
var _stage := 0
var _complete := false
var _restarting := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	preload("res://scripts/app/game_input_actions.gd").configure()
	display = DISPLAY.instantiate()
	display.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(display)
	world = display.world
	world.train_chapter_completed.connect(_on_completed)
	pause_menu = PAUSE_MENU.instantiate() as GlobalPauseMenu
	add_child(pause_menu)
	pause_menu.resume_requested.connect(_resume)
	pause_menu.exit_to_main_menu_requested.connect(_quit)
	(pause_menu.menu_buttons.get_node("ExitToMenu") as Button).text = "退出试玩"
	_build_completion_panel()
	_update_stage_title()
	print("PROLOGUE_BOOT main=", get_tree().current_scene.scene_file_path if get_tree().current_scene != null else scene_file_path,
		" user_data=", OS.get_user_data_dir(), " renderer=", RenderingServer.get_current_rendering_method(),
		" driver=", RenderingServer.get_current_rendering_driver_name(), " pixelation=", display.selective_enabled)
	if OS.get_cmdline_user_args().has("--background-gpu") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		get_tree().process_frame.connect(func(): RenderingServer.force_draw(false))
	if OS.has_feature("prologue_validation") and OS.get_cmdline_user_args().has("--prologue-validation") and not get_tree().has_meta(&"prologue_validation_started"):
		get_tree().set_meta(&"prologue_validation_started", true)
		_start_validation.call_deferred()


func _start_validation() -> void:
	var validation: Node = load("res://scripts/testing/prologue_package_validation.gd").new()
	get_tree().root.add_child(validation)
	validation.call_deferred("run", self)


func _process(_delta: float) -> void:
	if not _complete and not _restarting:
		_update_stage_title()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F5 or event.keycode == KEY_F5:
		get_viewport().set_input_as_handled()
		_restart.call_deferred()
	elif event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _complete:
			return
		if pause_menu.is_open():
			pause_menu.handle_escape()
		else:
			PauseManager.request_pause(PAUSE_REASON)
			pause_menu.open_pause()


func _update_stage_title() -> void:
	var next := 6 if world._train != null else (5 if world.transit_finished else (
		4 if world.storage_finished else (3 if world.garage_exit_reached else (2 if world.garage_visible else 1))))
	if next != _stage:
		_stage = next
		get_window().title = "再多五分钟 · 序章试玩 | 0-%d %s" % [_stage, STAGE_NAMES[_stage - 1]]


func _resume() -> void:
	pause_menu.close_pause()
	PauseManager.release_pause(PAUSE_REASON)


func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	PauseManager.clear_all()
	get_tree().reload_current_scene()


func _quit() -> void:
	PauseManager.clear_all()
	get_tree().quit()


func _on_completed() -> void:
	_complete = true
	pause_menu.close_pause()
	PauseManager.release_pause(PAUSE_REASON)
	PauseManager.request_pause(END_REASON)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	completion_panel.show()
	get_window().title = "再多五分钟 · 序章试玩 | 已通关"


func _build_completion_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 300
	add_child(layer)
	completion_panel = ColorRect.new()
	completion_panel.color = Color.BLACK
	layer.add_child(completion_panel)
	completion_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	completion_panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	var title := Label.new()
	title.text = "序章完成"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	for item in [["再玩一次", _restart], ["退出试玩", _quit]]:
		var button := Button.new()
		button.text = item[0]
		button.custom_minimum_size = Vector2(180, 32)
		button.pressed.connect(item[1])
		column.add_child(button)
	completion_panel.hide()
