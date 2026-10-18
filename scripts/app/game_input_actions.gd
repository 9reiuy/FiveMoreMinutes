extends RefCounted
## Shared idempotent bindings for Main and direct-run gameplay scenes.
static func configure() -> void:
	# Input is defined in one place so controls can later move to a settings screen.
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	# F remains the unarmed Kick action. Weapon Throw is explicitly bound to RMB;
	# E remains the explicit interaction/pickup key. Remove the legacy RMB Block
	# binding so a right click cannot trigger two gameplay actions at once.
	_ensure_mouse_action("throw_weapon", MOUSE_BUTTON_RIGHT)
	_remove_mouse_action("block", MOUSE_BUTTON_RIGHT)
	# T toggles the existing activity-driven DreamTimeController; it is sampled
	# as a just-pressed edge there, never as a hold-to-slow override.
	_add_key_action("toggle_slow_time", [KEY_T])
	_add_key_action("bullet_time", [KEY_T])
	# Space owns both the directional tap Roll/Dash and the hold-to-aim Dash.
	# Keep dialogue/UI confirmation on Enter so either gameplay path can never
	# also submit a confirmation in the same input frame.
	_add_key_action("confirm", [KEY_ENTER])
	_remove_key_action("confirm", KEY_SPACE)
	_add_key_action("restart_demo", [KEY_R])
	_add_key_action("reload_weapon", [KEY_R])
	_add_key_action("dash", [KEY_SPACE])
	_add_key_action("toggle_flashlight", [KEY_L])
	# Tab now owns the shared in-game phone. Keep the former card component,
	# but do not silently relocate it to a new key or phone application.
	_add_key_action("skill_menu", [])
	_remove_key_action("skill_menu", KEY_TAB)
	_add_key_action("toggle_phone", [KEY_TAB])
	_add_key_action("toggle_console", [KEY_QUOTELEFT, KEY_F10])


static func _add_key_action(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


static func _ensure_mouse_action(action: StringName, button_index: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = button_index
	if not InputMap.action_has_event(action, mouse_event):
		InputMap.action_add_event(action, mouse_event)


static func _remove_mouse_action(action: StringName, button_index: int) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button_index:
			InputMap.action_erase_event(action, event)


static func _remove_key_action(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event.physical_keycode == keycode or event.keycode == keycode):
			InputMap.action_erase_event(action, event)
