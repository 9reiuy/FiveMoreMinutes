extends SceneTree
const SCREEN := preload("res://scripts/ui/phone_settings_screen.gd")
var checks := 0
var failures: Array[String] = []
var screen: Control
var closes := 0
var feedback: Array = []

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func frames(count: int = 3) -> void:
	for i in count: await process_frame

func home() -> void:
	screen.set_context(&"game")
	screen.navigate(&"up"); screen.navigate(&"up"); screen.navigate(&"left")

func page(id: StringName) -> void:
	home()
	if id in [&"sounds", &"graphics"]:
		screen.open_app(&"settings")
		for i in 3: screen.navigate(&"up")
		if id == &"graphics": screen.navigate(&"down")
		screen.navigate(&"confirm")
	elif id != &"home": screen.open_app(id)

func reach_footer() -> void:
	for i in 160:
		if screen.get_focus_region() == &"footer": return
		screen.navigate(&"down")
		await process_frame
	check(false, "Page footer remains reachable after scrolling complete")

func mouse(point: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point; event.relative = relative
	screen._gui_input(event)

func click(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
	screen._gui_input(event)

func _run() -> void:
	if not OS.get_user_data_dir().contains("phone_settings_sample"):
		push_error("Footer regression needs isolated phone_settings_sample profile"); quit(2); return
	screen = SCREEN.new(); root.add_child(screen)
	screen.configure_apps({"balance": 1200, "online_messages": [{"id": "long", "category": "通知", "text": "这是一段需要滚动阅读的长讯息。".repeat(65), "is_read": false}]})
	screen.close_requested.connect(func(): closes += 1)
	screen.feedback_requested.connect(func(action: StringName, pressed: bool): feedback.append([action, pressed]))
	await frames()
	home()
	check(screen.get_selected_index() == 0 and screen.get_focus_region() == &"content", "Phone starts with content selection zero")
	var grid_bottom_left: Rect2 = screen._app_rect(2)
	var grid_bottom_right: Rect2 = screen._app_rect(3)
	screen.navigate(&"down")
	check(screen.get_selected_index() == 2 and screen.get_focus_region() == &"content", "S reaches existing bottom-left application")
	screen.navigate(&"down")
	check(screen.get_focus_region() == &"footer" and screen.get_focused_softkey() == &"home" and screen.get_selected_index() == 2, "Second S focuses existing Settings softkey without adding an app index")
	screen.navigate(&"right")
	check(screen.get_focused_softkey() == &"back" and screen.get_selected_index() == 2, "D moves footer focus without changing content index")
	screen.navigate(&"up")
	check(screen.get_focus_region() == &"content" and screen.get_selected_index() == 3, "W from Back returns to bottom-right application")
	check(screen._app_rect(2) == grid_bottom_left and screen._app_rect(3) == grid_bottom_right, "Footer navigation preserves original two-by-two application layout")
	screen.navigate(&"down"); screen.navigate(&"left"); screen.navigate(&"left")
	check(screen.get_focused_softkey() == &"home", "Footer left boundary clamps")
	screen.navigate(&"confirm")
	check(screen.get_page_id() == &"settings" and screen.get_focus_region() == &"content", "E confirms focused Settings and opens inner content")
	screen.navigate(&"back")
	check(screen.get_page_id() == &"home" and screen.get_focus_region() == &"footer" and screen.get_focused_softkey() == &"home", "Back restores originating footer focus")
	screen.navigate(&"right"); screen.navigate(&"right"); screen.navigate(&"down")
	check(screen.get_focused_softkey() == &"back" and screen.get_page_id() == &"home", "Footer right/down boundaries remain within existing softkeys")
	screen.navigate(&"confirm")
	check(closes == 1, "E on focused home Back requests close once")
	screen.navigate(&"home")
	check(screen.get_page_id() == &"settings", "Q remains left-softkey shortcut even with Back selected")
	check(feedback.is_empty(), "Keyboard navigation never emits synthetic mouse feedback")
	for id in [&"settings", &"sounds", &"graphics", &"music", &"shop", &"call"]:
		page(id); await frames()
		await reach_footer()
		check(screen.get_page_id() == id and screen.get_focus_region() == &"footer", "Footer reachable from existing content: " + String(id))
		var selected: int = screen.get_selected_index()
		screen.navigate(&"right")
		check(screen.get_focused_softkey() == &"back" and screen.get_selected_index() == selected, "Footer choice leaves inner content index intact: " + String(id))
		screen.navigate(&"up")
		check(screen.get_focus_region() == &"content", "Footer W restores inner content: " + String(id))
		await reach_footer(); screen.navigate(&"right"); screen.navigate(&"confirm")
		check(screen.get_page_id() == (&"settings" if id in [&"sounds", &"graphics"] else &"home"), "E on inner footer Back performs one history return: " + String(id))
	page(&"sounds")
	var manager: Node = root.get_node("SettingsManager")
	manager.set_volume(&"master_volume", 45)
	for i in 4: screen.navigate(&"up")
	screen.navigate(&"right")
	check(manager.get_volume(&"master_volume") == 50 and screen.get_focus_region() == &"content", "Slider right still adjusts value rather than entering footer")
	await reach_footer()
	var last_volume: int = manager.get_volume(&"sfx_volume")
	screen.navigate(&"right"); screen.navigate(&"left")
	check(manager.get_volume(&"sfx_volume") == last_volume, "Footer horizontal motion never adjusts prior slider")
	page(&"chat"); await frames(6)
	check(screen._scroll.get_v_scroll_bar().max_value > screen._scroll.get_v_scroll_bar().page, "Long message fixture truly needs scrolling")
	screen.navigate(&"down")
	check(screen.get_focus_region() == &"content" and screen._scroll.scroll_vertical > 0, "Message S scrolls before leaving content")
	await reach_footer()
	check(not screen._can_scroll_down() and screen.get_focus_region() == &"footer", "Message footer reached only after actual scroll bottom")
	screen.navigate(&"up"); screen.navigate(&"up")
	check(screen.get_focus_region() == &"content" and screen._can_scroll_down(), "W returns to message and can scroll upward again")
	home()
	mouse(screen.get_control_point(&"back"), Vector2.ONE)
	check(screen.get_focus_region() == &"footer" and screen.get_focused_softkey() == &"back", "Real pointer hover shares Back footer selection")
	mouse(screen.get_control_point(&"chat"), Vector2.ZERO)
	check(screen.get_focus_region() == &"footer", "Stationary pointer cannot steal footer keyboard focus")
	mouse(screen.get_control_point(&"chat"), Vector2.ONE)
	check(screen.get_focus_region() == &"content" and screen.get_selected_index() == 0, "Real pointer returns focus to application content")
	mouse(screen.get_control_point(&"soft_left"), Vector2.ONE)
	screen.navigate(&"confirm")
	check(screen.get_page_id() == &"settings", "Mouse-selected footer is confirmed by E")
	screen.navigate(&"back")
	click(screen.get_control_point(&"back"), true); click(screen.get_control_point(&"back"), false)
	check(closes == 2, "Mouse Back footer executes once and releases normally")
	check(not screen.get_interaction_locked() and feedback.back()[1] == false, "Footer pointer release clears lock and physical feedback")
	for action in [&"home", &"back"]:
		var rect: Rect2 = screen.get_softkey_rect(action)
		check(rect.position.y >= 209 and rect.end.y <= 230 and rect.has_point(screen.get_control_point(&"soft_left" if action == &"home" else &"back")), "Selection outline occupies original footer, not a new row: " + String(action))
	# Exercise actual projection and SubViewport GUI forwarding, not just the
	# screen's direct handler. Visual GPU correctness remains a separate check.
	var shell_script: GDScript = load("res://scripts/ui/flip_phone_shell.gd")
	var shell: Control = shell_script.new()
	root.size = Vector2i(640, 360)
	shell.position = Vector2(12, -20)
	root.remove_child(screen)
	shell.set_screen_content(screen)
	root.add_child(shell)
	shell.open_phone(false)
	await frames(4)
	home()
	var motion := InputEventMouseMotion.new()
	motion.position = shell.screen_point_to_global(screen.get_control_point(&"back"))
	motion.global_position = motion.position
	motion.relative = Vector2(8, 2)
	root.push_input(motion, true); await frames(1)
	check(screen.get_focus_region() == &"footer" and screen.get_focused_softkey() == &"back", "Actual shell projection forwards real footer hover to native UI")
	screen.navigate(&"up")
	motion.position = shell.screen_point_to_global(screen.get_control_point(&"back"))
	motion.global_position = motion.position
	motion.relative = Vector2.ZERO
	root.push_input(motion, true); await frames(1)
	check(screen.get_focus_region() == &"content" and screen.get_selected_index() == 3, "Projected stationary motion cannot steal restored keyboard content focus")
	motion.position = shell.screen_point_to_global(screen.get_control_point(&"soft_left"))
	motion.global_position = motion.position
	motion.relative = Vector2(8, 2)
	root.push_input(motion, true); await frames(1)
	screen.navigate(&"confirm")
	check(screen.get_page_id() == &"settings", "Projected footer hover and keyboard E share one logical selection")
	shell.free(); await frames()
	print("PHONE_FOOTER_NAVIGATION checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
