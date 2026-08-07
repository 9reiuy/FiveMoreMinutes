extends SceneTree

const MAIN := preload("res://scenes/app/main.tscn")
const MENU := preload("res://scenes/ui/main_menu.tscn")
const HUD := preload("res://scenes/ui/dream_hud.tscn")
const SAVE_STORE := preload("res://scripts/app/game_save_store.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	await process_frame
	var menu = main.current_screen
	_assert(menu.name == "MainMenu", "Startup did not show the main menu first")
	_assert(menu.continue_button.disabled, "Continue should be disabled without a save")
	_assert(_menu_texts(menu) == ["继续游戏", "开始游戏", "无尽模式", "设置", "退出游戏"], "Main menu order or labels are incorrect")
	menu._show_placeholder("无尽模式", "尚未开放")
	_assert(menu.overlay.visible and menu.overlay_message.text == "尚未开放", "Endless placeholder failed")
	menu._return_to_menu()
	menu._show_settings()
	_assert(menu.overlay.visible and menu.settings_panel.visible and not menu.overlay_message.visible, "Unified settings panel did not open")
	menu._return_to_menu()
	menu._on_start()
	await create_timer(0.8).timeout
	_assert(main.current_screen.name == "Opening", "New game did not enter the existing opening text")
	var saved := SAVE_STORE.load_game()
	_assert(int(saved.get("balance", -1)) == 1325 and int(saved.get("ram", -1)) == 0 and int(saved.get("weekday_index", -1)) == 0, "New-game save defaults are incorrect")
	main._show_main_menu()
	await process_frame
	menu = main.current_screen
	_assert(not menu.continue_button.disabled, "Continue did not enable after creating a valid save")
	main._continue_game()
	await create_timer(0.8).timeout
	var bedroom = main.current_screen
	_assert(bedroom.name == "Bedroom" and bedroom.get_node_or_null("Player") == null, "Continue did not enter a player-free bedroom")
	bedroom.highlighted = "bed"
	bedroom._unhandled_input(_mouse_click(Vector2(500, 270)))
	_assert(bedroom.confirmation_dialog.visible and bedroom.pending_confirmation == "bed", "Bed click did not open sleep confirmation")
	bedroom.confirmation_dialog.close_without_signal()
	bedroom._on_confirmation_cancelled()
	bedroom.persistent_state.melatonin_bottle_present = true
	bedroom.highlighted = "bottle"
	bedroom._unhandled_input(_mouse_click(bedroom.bottle_anchor.position))
	_assert(bedroom.confirmation_dialog.visible and bedroom.pending_confirmation == "bottle", "Bottle click did not open melatonin confirmation")
	bedroom.confirmation_dialog.close_without_signal()
	bedroom._on_confirmation_cancelled()
	bedroom.phone.state = bedroom.phone.PhoneState.EXPANDED
	bedroom.highlighted = "bed"
	bedroom._unhandled_input(_mouse_click(Vector2(500, 270)))
	_assert(not bedroom.confirmation_dialog.visible, "Expanded phone allowed a click through to the bedroom")
	var hud := HUD.instantiate()
	root.add_child(hud)
	await process_frame
	hud.set_progression(4, 235, 512, 7)
	await create_timer(0.1).timeout
	_assert(hud.level_label.text == "LV. 4" and hud.experience_value_label.text == "235 / 512", "Top experience labels are incorrect")
	_assert(hud.experience_bar.value > 0.0 and hud.experience_area.z_index > 0, "Experience bar did not animate or remain on the top HUD layer")
	var standalone_menu := MENU.instantiate()
	standalone_menu.has_save = true
	root.add_child(standalone_menu)
	await process_frame
	standalone_menu._on_start()
	_assert(standalone_menu.overlay.visible and standalone_menu.overlay_mode == "new_game" and standalone_menu.overlay_message.text.contains("覆盖现有进度"), "Existing save did not require overwrite confirmation")
	standalone_menu._return_to_menu()
	var quit_state := {"requested": false}
	standalone_menu.quit_requested.connect(func(): quit_state.requested = true)
	standalone_menu._show_confirmation("quit")
	standalone_menu._on_primary()
	_assert(quit_state.requested, "Exit confirmation did not call the quit request")
	standalone_menu.queue_free()
	hud.queue_free()
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("MENU/BEDROOM/HUD TEST PASSED: startup -> save -> continue -> mouse bedroom -> top experience HUD")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _menu_texts(menu: Control) -> Array[String]:
	var texts: Array[String] = []
	for button in [menu.continue_button, menu.start_button, menu.endless_button, menu.settings_button, menu.quit_button]:
		texts.append(button.text)
	return texts


func _mouse_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	return event


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
