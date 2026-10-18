class_name Dream3DPauseBridge
extends Node

## The campaign Main node already owns the single global pause/settings menu.
## Directly launched Dream3D scenes have no Main owner, so this bridge attaches
## that same formal pause_menu scene only for the standalone case.
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const MAIN_MENU_SCENE := "res://scenes/app/main.tscn"

var local_pause_menu: GlobalPauseMenu
var using_global_pause_menu := false


func _ready() -> void:
	# The bridge must still receive ui_cancel while the gameplay tree is paused;
	# all gameplay children remain inherited/paused and the menu itself is ALWAYS.
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_resolve_pause_owner")


func _resolve_pause_owner() -> void:
	if not is_inside_tree():
		return
	var main := get_tree().root.get_node_or_null("Main")
	if main != null:
		var global_menu := main.get_node_or_null("PauseMenu") as GlobalPauseMenu
		if global_menu != null and is_instance_valid(global_menu):
			using_global_pause_menu = true
			return
	if PAUSE_MENU_SCENE == null:
		return
	local_pause_menu = PAUSE_MENU_SCENE.instantiate() as GlobalPauseMenu
	if local_pause_menu == null:
		return
	local_pause_menu.name = "StandalonePauseMenu"
	get_parent().add_child(local_pause_menu)
	local_pause_menu.resume_requested.connect(_on_local_resume)
	local_pause_menu.exit_to_main_menu_requested.connect(_on_local_exit)


func _unhandled_input(event: InputEvent) -> void:
	if using_global_pause_menu or local_pause_menu == null or not is_instance_valid(local_pause_menu):
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if local_pause_menu.is_open():
		local_pause_menu.handle_escape()
	else:
		var pause_manager := get_tree().root.get_node_or_null("PauseManager")
		if pause_manager != null and pause_manager.has_method("request_pause"):
			pause_manager.call("request_pause", &"ESC_MENU")
		local_pause_menu.open_pause()
	get_viewport().set_input_as_handled()


func _on_local_resume() -> void:
	var pause_manager := get_tree().root.get_node_or_null("PauseManager")
	if pause_manager != null and pause_manager.has_method("release_pause"):
		pause_manager.call("release_pause", &"ESC_MENU")
	local_pause_menu.close_pause()


func _on_local_exit() -> void:
	var pause_manager := get_tree().root.get_node_or_null("PauseManager")
	if pause_manager != null and pause_manager.has_method("release_pause"):
		pause_manager.call("release_pause", &"ESC_MENU")
	if local_pause_menu != null and is_instance_valid(local_pause_menu):
		local_pause_menu.close_pause()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _exit_tree() -> void:
	if local_pause_menu != null and is_instance_valid(local_pause_menu):
		var pause_manager := get_tree().root.get_node_or_null("PauseManager")
		if pause_manager != null and pause_manager.has_method("release_pause"):
			pause_manager.call("release_pause", &"ESC_MENU")
