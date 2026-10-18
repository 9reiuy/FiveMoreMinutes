extends SceneTree

## Run with APPDATA/LOCALAPPDATA pointing at a profile named phone_settings_sample.
## This suite deliberately uses the real SettingsManager and ConfigFile boundary.
const SHELL := preload("res://scripts/ui/flip_phone_shell.gd")
const SCREEN := preload("res://scripts/ui/phone_settings_screen.gd")
const SETTINGS := preload("res://scripts/app/settings_manager.gd")
const BACKGROUND_GPU := preload("res://tests/support/background_gpu.gd")
const KEYS := [&"master_volume", &"music_volume", &"sfx_volume", &"pixelation_enabled", &"palette_enabled", &"shadow_quality"]

class BedroomPage extends Control:
	signal interacted(action: StringName)
	var actions: Array[StringName] = []
	var retained_value := 37
	func navigate(action: StringName) -> void:
		actions.append(action)
		interacted.emit(action)

var checks := 0
var failures: Array[String] = []
var output := "res://.runtime/phone_settings_sample_test"
var manager: Node
var shell: Control
var screen: Control
var shell_actions: Array[StringName] = []
var closed: Array[bool] = []
var requested: Array[StringName] = []
var pages: Array[StringName] = []
var animations: Array[bool] = []
var changes: Array[StringName] = []

func _initialize() -> void:
	BACKGROUND_GPU.start(self)
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func frames(count: int = 2) -> void:
	for _frame in count:
		await process_frame

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="):
			output = arg.trim_prefix("--artifact-dir=")
	if not OS.get_user_data_dir().to_lower().contains("phone_settings_sample"):
		push_error("Refusing to change settings outside an isolated phone_settings_sample profile: " + OS.get_user_data_dir())
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	manager = root.get_node_or_null("SettingsManager")
	check(manager != null, "Real SettingsManager autoload is present")
	if manager == null:
		_finish()
		return
	manager.setting_changed.connect(func(key: StringName, _value: Variant): changes.append(key))
	for key in KEYS:
		if key in [&"master_volume", &"music_volume", &"sfx_volume"]:
			manager.set_volume(key, 50)
		else:
			manager.set_setting(key, "standard" if key == &"shadow_quality" else true)
	changes.clear()
	root.size = Vector2i(640, 360)
	shell = SHELL.new()
	# Latest reference places the phone on the left; camera and number-pad ends
	# may leave the frame, but the LCD and operating keys must remain usable.
	shell.position = Vector2(16, 6)
	screen = SCREEN.new()
	shell.set_screen_content(screen)
	root.add_child(shell)
	shell.action_pressed.connect(func(action: StringName):
		shell_actions.append(action)
		screen.navigate(action))
	shell.animation_finished.connect(func(opened: bool): animations.append(opened))
	screen.close_requested.connect(func(): closed.append(true))
	screen.action_requested.connect(func(action: StringName): requested.append(action))
	screen.page_changed.connect(func(page: StringName): pages.append(page))
	await frames()
	_test_navigation()
	_test_settings()
	_test_bedroom_pages()
	await _test_shell_input()
	await _test_compact_sound_pointer()
	await _test_animation_contract()
	await _test_persistence()
	shell.free()
	await frames()
	_finish()

func _select(index: int) -> void:
	for _attempt in 6:
		if screen.get_selected_index() == index:
			return
		screen.navigate(&"down")
	check(false, "Requested row is reachable: %d" % index)

func _enter(page: StringName) -> void:
	screen.set_context(&"settings")
	_select(0 if page == &"sounds" else 1)
	screen.navigate(&"confirm")
	check(screen.get_page_id() == page, "Settings opens " + String(page))

func _test_navigation() -> void:
	screen.set_context(&"invalid")
	check(screen.get_page_id() == &"settings", "Unknown context falls back to settings")
	screen.navigate(&"back")
	check(closed.size() == 1, "Back at settings root requests close exactly once")
	screen.set_context(&"pause")
	_select(0)
	screen.navigate(&"confirm")
	check(requested == [&"resume"], "Pause resume emits existing resume action")
	screen.navigate(&"down")
	screen.navigate(&"confirm")
	check(screen.get_page_id() == &"settings", "Pause can enter settings")
	_select(1)
	screen.navigate(&"confirm")
	check(screen.get_page_id() == &"graphics", "Pause can reach graphics through settings")
	screen.navigate(&"back")
	check(screen.get_page_id() == &"settings" and screen.get_selected_index() == 1, "Back restores settings page and selected row")
	screen.navigate(&"back")
	check(screen.get_page_id() == &"pause" and screen.get_selected_index() == 1, "Second back restores pause row")
	screen.navigate(&"down")
	screen.navigate(&"confirm")
	check(requested == [&"resume", &"exit_to_menu"], "Exit emits existing menu action without closing unrelated context")
	screen.navigate(&"home")
	check(screen.get_page_id() == &"pause", "Home restores current entry context")
	_select(0)
	screen.navigate(&"up")
	check(screen.get_selected_index() == 2, "Up wraps within valid pause rows")
	screen.navigate(&"down")
	check(screen.get_selected_index() == 0, "Down wraps within valid pause rows")

func _test_settings() -> void:
	_enter(&"sounds")
	for index in 3:
		var key: StringName = KEYS[index]
		_select(index)
		manager.set_volume(key, 35 + index)
		screen.navigate(&"right")
		check(manager.get_volume(key) == 40 + index, "External volume change is current before UI increment: " + String(key))
		screen.navigate(&"left")
		check(manager.get_volume(key) == 35 + index, "UI decrements correct live volume: " + String(key))
		for action in [&"left", &"right"]:
			manager.set_volume(key, 0 if action == &"left" else 100)
			var count_before := changes.size()
			screen.navigate(action)
			check(manager.get_volume(key) == (0 if action == &"left" else 100), "Volume clamps at endpoint: " + String(key) + " " + String(action))
			check(changes.size() == count_before, "Clamped volume emits no redundant save notification: " + String(key))
		var min_point: Vector2 = screen.get_control_point(StringName(String(key) + "_min"))
		var max_point: Vector2 = screen.get_control_point(StringName(String(key) + "_max"))
		check(Rect2(Vector2.ZERO, screen.size).has_point(min_point) and Rect2(Vector2.ZERO, screen.size).has_point(max_point), "Slider endpoints fit clipped phone screen: " + String(key))
		_mouse_screen(min_point, true)
		check(manager.get_volume(key) == 0, "Pointer reaches exact zero: " + String(key))
		var drag := InputEventMouseMotion.new()
		drag.position = max_point + Vector2(80, 0)
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		screen._gui_input(drag)
		check(manager.get_volume(key) == 100, "Dragging beyond right edge safely clamps: " + String(key))
		_mouse_screen(max_point, false)
		var released_value: int = manager.get_volume(key)
		drag.position = min_point
		drag.button_mask = 0
		screen._gui_input(drag)
		check(manager.get_volume(key) == released_value, "Released pointer cannot keep adjusting: " + String(key))
		manager.set_volume(key, 50)
		var bus: StringName = [&"Master", &"Music", &"SFX"][index]
		var bus_index := AudioServer.get_bus_index(bus)
		check(not AudioServer.is_bus_mute(bus_index), "Nonzero volume unmutes real audio bus: " + String(bus))
		check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus_index)), 0.5), "UI reaches actual audio bus value: " + String(bus))
	_enter(&"graphics")
	for index in 2:
		var key: StringName = KEYS[index + 3]
		_select(index)
		for incoming in [true, false]:
			manager.set_setting(key, incoming)
			screen.navigate(&"right")
			check(manager.get_setting(key) == not incoming, "Graphics toggle reads external value then changes manager: " + String(key))
			_mouse_screen(screen.get_control_point(key), true)
			_mouse_screen(screen.get_control_point(key), false)
			check(manager.get_setting(key) == incoming, "Graphics row pointer toggles same authoritative setting: " + String(key))
	_select(2)
	for index in 3:
		var qualities := ["low", "standard", "high"]
		manager.set_setting(&"shadow_quality", qualities[index])
		screen.navigate(&"right")
		check(manager.get_shadow_quality() == qualities[(index + 1) % 3], "Shadow quality advances from current external choice " + qualities[index])
		screen.navigate(&"left")
		check(manager.get_shadow_quality() == qualities[index], "Shadow quality reverse returns " + qualities[index])
		check(Rect2(Vector2.ZERO, screen.size).has_point(screen.get_control_point(&"shadow_quality")), "Final graphics row stays in screen")

func _mouse_screen(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	screen._gui_input(event)

func _test_bedroom_pages() -> void:
	var chat := BedroomPage.new()
	var shop := BedroomPage.new()
	screen.set_bedroom_pages(chat, shop)
	screen.set_context(&"bedroom")
	_select(0)
	screen.navigate(&"confirm")
	check(screen.get_page_id() == &"chat" and chat.visible and not shop.visible, "Bedroom chat mounts only chat contents")
	check(chat.size == screen.get_page_content_rect().size and chat.get_parent().clip_contents, "Bedroom page fits bounded clipped screen area")
	check(chat.size.y >= 160 and chat.size.y > chat.size.x, "Tall-screen revision gives real bedroom pages a portrait content region")
	for action in [&"down", &"up", &"confirm", &"left", &"right"]:
		screen.navigate(action)
	check(chat.actions == [&"down", &"up", &"confirm", &"left", &"right"], "External chat owns its own navigation and actions")
	screen.navigate(&"back")
	screen.navigate(&"down")
	screen.navigate(&"confirm")
	check(screen.get_page_id() == &"shop" and shop.visible and not chat.visible, "Bedroom shop mounts only shop contents")
	screen.navigate(&"confirm")
	check(shop.actions == [&"confirm"] and chat.actions.size() == 5, "Shop action never leaks into hidden chat")
	chat.retained_value = 99
	screen.navigate(&"home")
	check(screen.get_page_id() == &"bedroom" and not chat.visible and not shop.visible, "Home hides both external pages")
	_select(0)
	screen.navigate(&"confirm")
	check(chat.retained_value == 99, "Page switching preserves owner state instead of rebuilding chat")
	screen.navigate(&"back")
	_select(2)
	screen.navigate(&"confirm")
	_enter_from_current(&"sounds", 0)
	screen.navigate(&"home")
	check(screen.get_page_id() == &"bedroom", "Settings nested in bedroom returns to bedroom home")
	check(pages.has(&"chat") and pages.has(&"shop") and pages.has(&"sounds"), "Owners receive page lifecycle notifications")

func _enter_from_current(page: StringName, index: int) -> void:
	_select(index)
	screen.navigate(&"confirm")
	check(screen.get_page_id() == page, "Nested context opens " + String(page))

func _click_global(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await frames(1)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await frames(1)

func _test_shell_input() -> void:
	check(shell.screen_size == Vector2i(148, 230) and shell.screen_root.clip_contents, "User-revised shell provides a clipped 148x230 portrait screen")
	check(shell.screen_size.y > shell.screen_size.x * 1.5, "Upper screen has video-like tall rectangular proportions")
	shell.open_phone(false)
	screen.set_context(&"settings")
	_select(0)
	await frames()
	var rendered: TextureRect = shell.get_node("RenderedPhone")
	var padding: float = SHELL.RENDER_PADDING
	check(rendered.position.is_equal_approx(Vector2(-padding, 0)), "Visible 3D viewport starts at its declared transparent hinge overscan offset")
	check(rendered.size.is_equal_approx(shell.size + Vector2(padding * 2, 0)), "Actual ready-time rendered view keeps logical phone size plus hinge overscan")
	check(rendered.get_global_transform_with_canvas().origin.is_equal_approx(shell.get_global_transform_with_canvas() * Vector2(-padding, 0)), "Rendered phone origin and global pointer mapping share the same overscan transform")
	var operating_area := Rect2(Vector2.ZERO, Vector2(root.size.x * 0.5, root.size.y))
	for action in [&"up", &"down", &"left", &"right", &"confirm", &"back", &"home"]:
		check(operating_area.has_point(shell.key_point_to_global(action)), "Left phone keeps physical operating key inside left half of viewport: " + String(action))
	for point in [Vector2.ZERO, Vector2(shell.screen_size.x, 0), Vector2(shell.screen_size), Vector2(0, shell.screen_size.y)]:
		check(operating_area.has_point(shell.screen_point_to_global(point)), "All four LCD corners remain in left half despite camera/number-pad overflow")
	await _click_global(shell.key_point_to_global(&"down"))
	check(shell_actions.back() == &"down" and screen.get_selected_index() == 1, "Transformed physical down key is a real pointer target")
	await _click_global(shell.key_point_to_global(&"confirm"))
	check(screen.get_page_id() == &"graphics", "Physical confirm reaches selected page")
	await _click_global(shell.key_point_to_global(&"back"))
	check(screen.get_page_id() == &"settings", "Physical back follows page history")
	await _click_global(shell.screen_point_to_global(screen.get_control_point(&"sounds")))
	check(screen.get_page_id() == &"sounds", "Transformed live screen receives direct row clicks")
	await _click_global(shell.screen_point_to_global(screen.get_control_point(&"master_volume_min")))
	check(manager.get_volume(&"master_volume") == 0, "Transformed slider pointer writes real setting")
	await _click_global(shell.key_point_to_global(&"right"))
	check(manager.get_volume(&"master_volume") == 5 and shell_actions.back() == &"right", "Physical right adjusts selected setting")
	await _click_global(shell.key_point_to_global(&"left"))
	check(manager.get_volume(&"master_volume") == 0 and shell_actions.back() == &"left", "Physical left reverses setting adjustment")
	await _click_global(shell.key_point_to_global(&"up"))
	check(screen.get_selected_index() == 2 and shell_actions.back() == &"up", "Physical up selects previous wrapping row")
	await _click_global(shell.key_point_to_global(&"home"))
	check(screen.get_page_id() == &"settings" and shell_actions.back() == &"home", "Physical home returns to current entry homepage")
	var close_count := closed.size()
	await _click_global(shell.key_point_to_global(&"back"))
	check(closed.size() == close_count + 1, "Physical back at root emits one close request")
	_enter(&"sounds")
	shell.close_phone(false)
	var action_count := shell_actions.size()
	await _click_global(shell.key_point_to_global(&"down"))
	check(shell_actions.size() == action_count, "Closed phone cannot emit physical key actions")
	check(not shell.is_open and not shell.is_animating, "Instant close settles open and animation state")

func _test_animation_contract() -> void:
	paused = true
	shell.open_phone(true)
	check(shell.is_open and shell.is_animating, "Open animation enters guarded opening state")
	var old_actions := shell_actions.size()
	await _click_global(shell.key_point_to_global(&"down"))
	check(shell_actions.size() == old_actions, "Opening blocks physical button activation")
	await _wait_shell_state(true)
	check(shell.is_open and not shell.is_animating and animations.back(), "Opening completes while game tree is paused")
	shell.close_phone(true)
	check(not shell.is_open and shell.is_animating, "Close animation guards input immediately")
	var old_value: int = manager.get_volume(&"master_volume")
	await _click_global(shell.screen_point_to_global(screen.get_control_point(&"master_volume_max")))
	check(manager.get_volume(&"master_volume") == old_value, "Moving lid guard blocks live child screen pointer input")
	await _wait_shell_state(false)
	check(not shell.is_open and not shell.is_animating and not animations.back(), "Close completes while game tree is paused")
	var finished_before := animations.size()
	shell.open_phone(true)
	await create_timer(0.08, true).timeout
	shell.close_phone(true)
	await create_timer(0.08, true).timeout
	shell.open_phone(true)
	await _wait_shell_state(true)
	check(shell.is_open and not shell.is_animating, "Rapid open-close-open converges to last request")
	check(animations.size() == finished_before + 1 and animations.back(), "Cancelled animations cannot emit stale completion signals")
	paused = false

func _wait_shell_state(opened: bool) -> void:
	# 3D hinge motion may have a different duration from the retired flat shell.
	# Keep a bounded short-animation contract without duplicating tween timings.
	var limit := Time.get_ticks_msec() + 1500
	while (shell.is_open != opened or shell.is_animating) and Time.get_ticks_msec() < limit:
		await create_timer(0.02, true, false, true).timeout

func _drag_global(start: Vector2, finish: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.position = start
	press.global_position = start
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	await frames(1)
	for step in range(1, 5):
		var motion := InputEventMouseMotion.new()
		motion.position = start.lerp(finish, float(step) / 4.0)
		motion.global_position = motion.position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		await frames(1)
	var release := InputEventMouseButton.new()
	release.position = finish
	release.global_position = finish
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	root.push_input(release, true)
	await frames(1)

func _volume_snapshot() -> Array[int]:
	return [manager.get_volume(&"master_volume"), manager.get_volume(&"music_volume"), manager.get_volume(&"sfx_volume")]

func _test_compact_sound_pointer() -> void:
	# The latest review tightens three permanent sound rows and adds icons.
	# Check the resulting pointer behavior, not colour values or drawing commands.
	shell.open_phone(false)
	_enter(&"sounds")
	await frames()
	for index in 3:
		for other in 3:
			manager.set_volume(KEYS[other], 30 + other * 20)
		var before := _volume_snapshot()
		var row: Rect2 = screen._row_rect(index)
		for point in [row.position + Vector2(8, row.size.y * 0.3), row.position + Vector2(48, row.size.y * 0.3)]:
			_select((index + 1) % 3)
			await _click_global(shell.screen_point_to_global(point))
			check(screen.get_selected_index() == index, "Icon/label region selects intended compact sound row %d" % index)
			check(_volume_snapshot() == before, "Icon/label click selects without changing any volume %d" % index)
		var key: StringName = KEYS[index]
		var minimum: Vector2 = screen.get_control_point(StringName(String(key) + "_min"))
		var maximum: Vector2 = screen.get_control_point(StringName(String(key) + "_max"))
		await _drag_global(shell.screen_point_to_global(minimum), shell.screen_point_to_global(maximum))
		check(manager.get_volume(key) == 100, "Actual compact slider drag reaches 100: " + String(key))
		for other in 3:
			if other != index:
				check(manager.get_volume(KEYS[other]) == before[other], "Dragging %s does not adjust adjacent %s" % [key, KEYS[other]])
		await _drag_global(shell.screen_point_to_global(maximum), shell.screen_point_to_global(minimum))
		check(manager.get_volume(key) == 0, "Actual compact slider reverse drag reaches 0: " + String(key))
		var saved := ConfigFile.new()
		check(saved.load("user://game_settings.cfg") == OK and int(saved.get_value("audio", String(key), -1)) == 0, "Compact slider gesture saves immediately: " + String(key))
		for other in 3:
			if other != index:
				check(manager.get_volume(KEYS[other]) == before[other], "Reverse dragging %s leaves adjacent %s unchanged" % [key, KEYS[other]])
	var held_point: Vector2 = shell.screen_point_to_global(screen.get_control_point(&"master_volume_max"))
	var outside_point: Vector2 = shell.screen_point_to_global(Vector2(-40, screen.get_control_point(&"master_volume_max").y))
	var press := InputEventMouseButton.new()
	press.position = held_point
	press.global_position = held_point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	await frames(1)
	var motion := InputEventMouseMotion.new()
	motion.position = outside_point
	motion.global_position = outside_point
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await frames(1)
	var release := InputEventMouseButton.new()
	release.position = outside_point
	release.global_position = outside_point
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	root.push_input(release, true)
	await frames(1)
	var released_value: int = manager.get_volume(&"master_volume")
	motion.position = held_point
	motion.global_position = held_point
	motion.button_mask = 0
	root.push_input(motion, true)
	await frames(1)
	check(manager.get_volume(&"master_volume") == released_value, "Re-entering projected screen after releasing slider outside cannot keep changing volume")
	var closed_before := closed.size()
	await _click_global(shell.screen_point_to_global(screen.get_control_point(&"back")))
	check(screen.get_page_id() == &"settings" and closed.size() == closed_before, "Bottom-screen back returns one page without closing phone")
	await _click_global(shell.screen_point_to_global(screen.get_control_point(&"confirm")))
	check(screen.get_page_id() == &"sounds", "Bottom-screen confirm retains sound-page selection")
	shell.close_phone(false)

func _test_persistence() -> void:
	var expected := {&"master_volume": 23, &"music_volume": 41, &"sfx_volume": 67, &"pixelation_enabled": false, &"palette_enabled": false, &"shadow_quality": "high"}
	for key: StringName in expected:
		if key in [&"master_volume", &"music_volume", &"sfx_volume"]:
			manager.set_volume(key, expected[key])
		else:
			manager.set_setting(key, expected[key])
		var persisted := ConfigFile.new()
		check(persisted.load("user://game_settings.cfg") == OK, "Every individual setting change is already persisted: " + String(key))
		var section := "audio" if key in [&"master_volume", &"music_volume", &"sfx_volume"] else "graphics"
		check(persisted.get_value(section, String(key)) == expected[key], "Saved setting matches latest authoritative value: " + String(key))
	var reloaded := SETTINGS.new()
	reloaded._load_settings()
	for key: StringName in expected:
		check(reloaded.get_setting(key) == expected[key], "Fresh settings owner reloads " + String(key))
	reloaded.free()
	shell.set_screen_content(SCREEN.new())
	await frames()
	screen = shell.screen_root.get_children().filter(func(child: Node): return child is SCREEN)[0]
	_enter(&"sounds")
	_select(1)
	screen.navigate(&"right")
	check(manager.get_volume(&"music_volume") == 46, "Reopened screen binds persisted live state instead of resetting defaults")

func _finish() -> void:
	var report := {"suite": "phone_settings_sample", "checks": checks, "failures": failures, "user_data_dir": OS.get_user_data_dir(), "real_game_entrypoints": false, "gpu_execution": DisplayServer.get_name() != "headless", "visual_gpu_approval": false}
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("PHONE_SETTINGS_SAMPLE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
