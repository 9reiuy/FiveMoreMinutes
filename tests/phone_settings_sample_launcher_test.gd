extends SceneTree

const SAMPLE := preload("res://scenes/ui/preview/PhoneSettingsSample.tscn")
const EXTERNAL_REASON: StringName = &"PHONE_SAMPLE_TEST_EXTERNAL"
const SAMPLE_REASON: StringName = &"PHONE_SETTINGS_SAMPLE"
var checks := 0
var failures: Array[String] = []
var deadline := 0
var output := "res://.runtime/phone_settings_sample_launcher_test"
var launcher: Node
var pauses: Node
var done := false

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count: int = 3) -> void:
	for _frame in count:
		await process_frame

func _watchdog() -> void:
	await create_timer(120.0, true, false, true).timeout
	if not done:
		check(false, "Real sample launcher exceeded 120-second total deadline")
		_finish()

func _wait_for(predicate: Callable, label: String) -> bool:
	while not bool(predicate.call()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05, true, false, true).timeout
	var passed := bool(predicate.call())
	check(passed, label)
	return passed

func _settled() -> bool:
	return is_instance_valid(launcher) and not launcher.busy and is_instance_valid(launcher.host) and launcher.host.active and launcher.host.shell.is_open and not launcher.host.shell.is_animating

func _choose(context: StringName) -> bool:
	launcher._choose(context)
	return await _wait_for(_settled, "Sample context settles: " + String(context))

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="):
			output = arg.trim_prefix("--artifact-dir=")
	if not OS.get_user_data_dir().to_lower().contains("phone_settings_sample"):
		push_error("Refusing launcher test outside isolated phone_settings_sample profile")
		quit(2)
		return
	deadline = Time.get_ticks_msec() + 115000
	_watchdog()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(640, 360)
	pauses = root.get_node("PauseManager")
	launcher = SAMPLE.instantiate()
	root.add_child(launcher)
	if not await _wait_for(_settled, "Real Main entry opens default bedroom flip phone"):
		_finish()
		return
	var host: CanvasLayer = launcher.host
	var backend: Control = launcher.main.current_screen.phone
	var old_phone: WeakRef = weakref(backend)
	var old_chat: WeakRef = weakref(backend.online_scroll)
	var old_shop: WeakRef = weakref(backend.quicklink_scroll)
	var old_wrapper: WeakRef = weakref(host.screen.get_meta(&"sample_chat_page"))
	check(host.screen.get_page_id() == &"bedroom", "Default page is bedroom homepage")
	check(host._phone == backend, "Default page mounts actual bedroom phone authority")
	check(host._mounts.size() == 2, "Both original chat and shopping scrolls are mounted")
	check(backend.online_scroll.get_parent().phone == backend and backend.quicklink_scroll.get_parent().phone == backend, "Mounted pages retain original backend authority")
	check(not pauses.has_pause_reason(SAMPLE_REASON) and not paused, "Daily bedroom phone does not pause time")
	check(not backend.visible, "Original straight phone is hidden while review phone is open")
	check(host.shell.screen_size == Vector2i(148, 230), "Actual launcher uses user-revised portrait phone screen")
	var rendered: TextureRect = host.shell.get_node("RenderedPhone")
	var padding: float = host.shell.RENDER_PADDING
	check(rendered.position.is_equal_approx(Vector2(-padding, 0)) and rendered.size.is_equal_approx(host.shell.size + Vector2(2 * padding, 0)), "Actual Main host keeps rendered phone at logical scale with declared hinge overscan")
	check(host.screen.get_page_content_rect().size.y >= 160, "Actual bedroom chat and shopping receive expanded portrait content area")
	_check_left_layout(host)
	_check_environment(host, "fallback_2d")
	host._navigate(&"confirm")
	check(host.screen.get_page_id() == &"chat" and backend.online_scroll.visible, "Actual chat page opens through phone navigation")
	host._navigate(&"back")
	host._navigate(&"down")
	host._navigate(&"confirm")
	check(host.screen.get_page_id() == &"shop" and backend.quicklink_scroll.visible, "Actual shopping page opens through phone navigation")
	if not await _choose(&"pause"):
		_finish()
		return
	check(host.screen.get_page_id() == &"pause", "Pause selector uses pause homepage")
	check(pauses.has_pause_reason(SAMPLE_REASON) and paused, "Pause selector owns its own pause reason")
	check(host._phone == null and host._mounts.is_empty(), "Changing scenes restores then detaches bedroom mounts")
	await frames(4)
	check(old_phone.get_ref() == null, "Previous bedroom phone is released after scene switch")
	check(old_chat.get_ref() == null and old_shop.get_ref() == null, "Previous bedroom pages are released with original owner")
	check(old_wrapper.get_ref() == null, "Temporary bedroom wrapper is released after scene switch")
	check(_count_shells(root) == 1, "Only one review flip-phone shell exists after scene change")
	_check_environment(host, "source_3d")
	var source_world: Node3D = launcher.main._supported_dream_world
	var first_bridge: WeakRef = weakref(host.environment_bridge)
	var first_faces := _capture_references(host.environment_bridge)
	pauses.request_pause(EXTERNAL_REASON)
	host.close_sample()
	if not await _wait_for(func(): return not host.shell.is_animating and not host.active, "Pause phone finishes closing"):
		_finish()
		return
	check(not pauses.has_pause_reason(SAMPLE_REASON), "Closing releases only phone-owned pause reason")
	check(pauses.has_pause_reason(EXTERNAL_REASON) and paused, "Closing preserves independent pause reason")
	await _check_environment_released(host, first_bridge, first_faces)
	pauses.release_pause(EXTERNAL_REASON)
	check(not paused, "Game resumes when no remaining pause owner exists")
	var source_state := _source_snapshot(source_world)
	host.show_sample(&"pause", null, false)
	await frames(4)
	_check_environment(host, "source_3d")
	_check_source_unchanged(source_state, "Opening environment presentation")
	var second_bridge: WeakRef = weakref(host.environment_bridge)
	var second_faces := _capture_references(host.environment_bridge)
	host.close_sample()
	if not await _wait_for(func(): return not host.shell.is_animating and not host.active, "Reopened source presentation closes"):
		_finish()
		return
	await _check_environment_released(host, second_bridge, second_faces)
	_check_source_unchanged(source_state, "Closing environment presentation")
	if not await _choose(&"settings"):
		_finish()
		return
	check(host.screen.get_page_id() == &"settings", "Main-menu selector opens settings homepage directly")
	check(launcher.main.current_screen.scene_file_path == "res://scenes/ui/main_menu.tscn", "Settings preview uses real main-menu background")
	check(pauses.has_pause_reason(SAMPLE_REASON) and paused, "Settings preview owns pause without stacking reasons")
	check(_count_shells(root) == 1, "Settings preview reuses existing shell")
	_check_environment(host, "fallback_2d")
	host._navigate(&"confirm")
	check(host.screen.get_page_id() == &"sounds", "Settings selector leads to actual sound settings")
	await _test_environment_source_exit(host)
	pauses.request_pause(EXTERNAL_REASON)
	var host_ref: WeakRef = weakref(host)
	var final_bridge: WeakRef = weakref(host.environment_bridge)
	host.queue_free()
	await frames(4)
	check(host_ref.get_ref() == null, "Review host can be destroyed while phone is open")
	check(final_bridge.get_ref() == null, "Destroying phone host also releases fallback environment bridge")
	check(not pauses.has_pause_reason(SAMPLE_REASON), "Destroying active host releases phone-owned pause")
	check(pauses.has_pause_reason(EXTERNAL_REASON) and paused, "Destroying host preserves unrelated pause owner")
	check(_count_shells(root) == 0, "Destroying host releases screen and shell completely")
	pauses.release_pause(EXTERNAL_REASON)
	launcher.queue_free()
	await frames(5)
	check(not paused, "Test teardown leaves pause state unowned")
	_finish()

func _count_shells(node: Node) -> int:
	var result := 1 if node.get_script() != null and node.get_script().resource_path == "res://scripts/ui/flip_phone_shell.gd" else 0
	for child in node.get_children():
		result += _count_shells(child)
	return result

func _check_left_layout(host: CanvasLayer) -> void:
	var operating_area := Rect2(Vector2.ZERO, Vector2(root.size.x * 0.5, root.size.y))
	var menu: Control = launcher.buttons[0].get_parent()
	var menu_rect := menu.get_global_rect()
	for action in [&"up", &"down", &"left", &"right", &"confirm", &"back", &"home"]:
		var point: Vector2 = host.shell.key_point_to_global(action)
		check(operating_area.has_point(point), "Real launcher keeps physical key in left half of screen: " + String(action))
		check(not menu_rect.has_point(point), "Preview controls cannot obscure physical key target: " + String(action))
	var lcd := PackedVector2Array()
	for local in [Vector2.ZERO, Vector2(host.shell.screen_size.x, 0), Vector2(host.shell.screen_size), Vector2(0, host.shell.screen_size.y)]:
		var point: Vector2 = host.shell.screen_point_to_global(local)
		lcd.append(point)
		check(operating_area.has_point(point), "Actual Main keeps every LCD corner inside left half of screen")
	var preview_polygon := PackedVector2Array([menu_rect.position, Vector2(menu_rect.end.x, menu_rect.position.y), menu_rect.end, Vector2(menu_rect.position.x, menu_rect.end.y)])
	check(Geometry2D.intersect_polygons(lcd, preview_polygon).is_empty(), "Right preview bar does not overlap actual LCD polygon, regardless of transparent overscan")

func _check_environment(host: CanvasLayer, expected_source: String) -> void:
	var bridge: Node = host.environment_bridge
	check(is_instance_valid(bridge), "Open phone owns an environment bridge")
	if not is_instance_valid(bridge):
		return
	var diagnostics: Dictionary = bridge.get_diagnostics()
	check(bool(diagnostics.active) and diagnostics.source_type == expected_source, "Environment source follows actual Main context: " + expected_source)
	var phone_viewport: SubViewport = host.shell.get_node("PhoneGeometryViewport")
	var own_world: World3D = phone_viewport.find_world_3d()
	check(int(diagnostics.own_world_id) == own_world.get_instance_id(), "Bridge target identifies actual isolated phone World3D")
	if expected_source == "fallback_2d":
		check(int(diagnostics.source_world_id) == 0 and bridge._faces.is_empty(), "2D menu/bedroom fallback creates no gameplay capture viewports")
		return
	var source: Node3D = launcher.main._supported_dream_world
	check(is_instance_valid(source) and int(diagnostics.source_world_id) == source.get_world_3d().get_instance_id(), "Reflection source is actual active reception World3D")
	check(int(diagnostics.source_world_id) != own_world.get_instance_id(), "Phone geometry never enters its own captured world")
	check(bridge._faces.size() == 6, "Bounded environment capture owns six faces")
	for face: SubViewport in bridge._faces:
		check(face.world_3d == source.get_world_3d() and face.world_3d != own_world, "Actual capture face shares gameplay world and excludes phone feedback")
		check(face.size == Vector2i(64, 64), "Capture face remains bounded to 64-square pixels")
	var actual_lights: Dictionary = {}
	for light: Light3D in source.find_children("*", "Light3D", true, false):
		actual_lights[light.get_instance_id()] = light
	check(not bridge._mirrored_lights.is_empty() and bridge._mirrored_lights.size() <= 4, "Presentation maps a bounded selection of real gameplay lights")
	for id in bridge._mirrored_lights:
		var clone: Light3D = bridge._mirrored_lights[id]
		var original := actual_lights.get(id) as Light3D
		check(is_instance_valid(original) and clone.get_class() == original.get_class(), "Mapped light identity and type resolve to a real gameplay source")
		if is_instance_valid(original):
			check(clone.light_color.is_equal_approx(original.light_color) and is_equal_approx(clone.light_energy, original.light_energy), "Mapped light retains source colour and energy")
	# Headless cannot prove frame_post_draw or reflected pixel appearance. Capture
	# readiness, face submission counts and glass-light A/B belong to the GPU run.

func _capture_references(bridge: Node) -> Array[WeakRef]:
	var result: Array[WeakRef] = []
	for face in bridge._faces:
		result.append(weakref(face))
	return result

func _check_environment_released(host: CanvasLayer, bridge: WeakRef, faces: Array[WeakRef]) -> void:
	await frames(4)
	check(host.environment_bridge == null and bridge.get_ref() == null, "Completed phone close frees its environment bridge")
	check(faces.all(func(reference: WeakRef): return reference.get_ref() == null), "Completed phone close releases all capture viewports")

func _source_snapshot(source: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in source.find_children("*", "", true, false):
		if node is Light3D:
			result.append({"node": weakref(node), "kind": "light", "mask": node.light_cull_mask})
		elif node is Camera3D:
			result.append({"node": weakref(node), "kind": "camera", "mask": node.cull_mask})
		elif node is MeshInstance3D:
			result.append({"node": weakref(node), "kind": "material", "material": node.material_override})
	return result

func _check_source_unchanged(snapshot: Array[Dictionary], label: String) -> void:
	var intact := {"light": true, "camera": true, "material": true}
	var counts := {"light": 0, "camera": 0, "material": 0}
	for record in snapshot:
		counts[record.kind] += 1
		var node: Node = record.node.get_ref()
		if not is_instance_valid(node):
			intact[record.kind] = false
		elif record.kind == "light":
			intact.light = intact.light and node.light_cull_mask == record.mask
		elif record.kind == "camera":
			intact.camera = intact.camera and node.cull_mask == record.mask
		else:
			intact.material = intact.material and node.material_override == record.material
	for kind: String in intact:
		check(counts[kind] > 0 and bool(intact[kind]), "%s preserves actual source %s resources/masks" % [label, kind])

func _test_environment_source_exit(host: CanvasLayer) -> void:
	# Keep the real Main world intact. A tiny independent lifecycle fixture proves
	# leaving the tree is handled even while the source and camera remain alive.
	var source := Node3D.new()
	var source_camera := Camera3D.new()
	source.add_child(source_camera)
	root.add_child(source)
	var target_viewport := SubViewport.new()
	target_viewport.size = Vector2i(8, 8)
	target_viewport.own_world_3d = true
	target_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var target := Node3D.new()
	var phone_camera := Camera3D.new()
	target.add_child(phone_camera)
	target_viewport.add_child(target)
	root.add_child(target_viewport)
	var bridge_script: GDScript = load("res://scripts/ui/phone_environment_bridge.gd")
	var bridge: Node = bridge_script.new()
	root.add_child(bridge)
	bridge.configure(source, source_camera, phone_camera, target, host.shell.screen_root.get_viewport().get_texture())
	bridge.start()
	var initial: Dictionary = bridge.get_diagnostics()
	check(bool(initial.active) and bridge._faces.size() == 6, "Source-exit fixture starts an actual six-face 3D capture bridge")
	check(int(initial.source_world_id) != int(initial.own_world_id), "Source-exit fixture uses isolated capture and target worlds")
	var faces := _capture_references(bridge)
	root.remove_child(source)
	check(is_instance_valid(source) and is_instance_valid(source_camera) and not source.is_inside_tree(), "Source-exit test removes live source without freeing it")
	await frames(4)
	var stopped: Dictionary = bridge.get_diagnostics()
	check(not bool(stopped.active) and not bridge.is_processing(), "Bridge automatically stops when live source leaves tree")
	check(bridge._faces.is_empty() and faces.all(func(reference: WeakRef): return reference.get_ref() == null), "Source leaving tree releases all capture viewports")
	await frames(3)
	check(int(bridge.get_diagnostics().capture_count) == int(stopped.capture_count), "Stopped source bridge cannot continue capture submissions")
	bridge.free()
	source.free()
	target_viewport.queue_free()
	await frames(3)

func _finish() -> void:
	if done:
		return
	done = true
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"suite": "phone_settings_sample_launcher", "checks": checks, "failures": failures, "user_data_dir": OS.get_user_data_dir(), "real_main_entry": true, "gpu_visual_approval": false}, "\t"))
	print("PHONE_SETTINGS_SAMPLE_LAUNCHER checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
