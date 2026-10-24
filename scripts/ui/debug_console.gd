extends CanvasLayer

signal dream_jump_requested(weapon_id: String)

const STATE_RULES := preload("res://scripts/app/game_state_rules.gd")

@export var config: DemoConfig

@onready var blocker: Control = $Blocker
@onready var panel: PanelContainer = $Blocker/Panel
@onready var output_label: Label = $Blocker/Panel/Margin/Content/Output
@onready var command_line: LineEdit = $Blocker/Panel/Margin/Content/Command

var persistent_state: Dictionary = {}
var state_changed_callback: Callable
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = OS.is_debug_build()
	blocker.visible = false
	panel.custom_minimum_size = config.console_panel_size
	output_label.add_theme_font_size_override("font_size", config.console_font_size)
	command_line.add_theme_font_size_override("font_size", config.console_font_size)
	command_line.text_submitted.connect(_execute_command)


func configure(state: Dictionary, on_state_changed: Callable) -> void:
	persistent_state = state
	state_changed_callback = on_state_changed


func is_open() -> bool:
	return blocker.visible


func close_console() -> void:
	if not blocker.visible:
		return
	blocker.visible = false
	PauseManager.release_pause(&"DEBUG_CONSOLE")
	Input.mouse_mode = previous_mouse_mode


func _open_console() -> void:
	if not enabled or blocker.visible:
		return
	previous_mouse_mode = Input.mouse_mode
	PauseManager.request_pause(&"DEBUG_CONSOLE")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	blocker.visible = true
	command_line.clear()
	command_line.call_deferred("grab_focus")


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event.is_action_pressed("toggle_console"):
		if blocker.visible:
			close_console()
		else:
			_open_console()
		get_viewport().set_input_as_handled()
	elif blocker.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_console()
		get_viewport().set_input_as_handled()


func _execute_command(raw_command: String) -> void:
	var trimmed := raw_command.strip_edges()
	var command := trimmed.to_upper()
	var clean_cmd := command.replace("_", " ")
	if command == "RAMMAX":
		persistent_state.ram = 999
		output_label.text = "RAM SET TO 999"
	elif command == "UNLOCK":
		persistent_state.basic_weapon_unlocked = true
		persistent_state.shotgun_unlocked = true
		output_label.text = "ALL WEAPONS UNLOCKED"
	elif command == "MONEY":
		STATE_RULES.change_balance(persistent_state, 10000)
		output_label.text = "BALANCE +¥10,000"
	elif clean_cmd == "GOTODREAM" or clean_cmd == "GOTO DREAM" or clean_cmd.begins_with("GOTODREAM ") or clean_cmd.begins_with("GOTO DREAM "):
		var target_weapon := ""
		if clean_cmd.begins_with("GOTODREAM "):
			target_weapon = trimmed.substr(10).strip_edges()
		elif clean_cmd.begins_with("GOTO DREAM "):
			target_weapon = trimmed.substr(11).strip_edges()
		output_label.text = "ENTERING DREAM..."
		command_line.clear()
		close_console()
		dream_jump_requested.emit(target_weapon)
		return
	elif clean_cmd == "PERF" or clean_cmd == "FPS":
		var perf: Node = get_node_or_null("/root/PerformanceMonitor")
		if perf != null and perf.has_method("cycle_display_mode"):
			perf.call("cycle_display_mode")
			output_label.text = "PERF HUD MODE CYCLED (F3)"
		else:
			output_label.text = "PERFORMANCE MONITOR NOT FOUND"
	elif clean_cmd == "REPORT" or clean_cmd == "DIAGNOSIS":
		var perf: Node = get_node_or_null("/root/PerformanceMonitor")
		if perf != null and perf.has_method("open_report_dialog"):
			close_console()
			perf.call("open_report_dialog")
			return
		else:
			output_label.text = "PERFORMANCE MONITOR NOT FOUND"
	else:
		output_label.text = "UNKNOWN COMMAND"
	if command in ["RAMMAX", "UNLOCK", "MONEY"] and state_changed_callback.is_valid():
		state_changed_callback.call()
	command_line.clear()
	command_line.grab_focus()
