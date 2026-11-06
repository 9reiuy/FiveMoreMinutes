extends Node3D
## Separate review scene: production menu, saves and renderer stay untouched.

signal menu_requested(action_id: StringName)

const BUILDER := preload("res://scripts/preview/screen_wall_builder.gd")
const DISPLAY := preload("res://scripts/preview/screen_wall_display.gd")
const FONT := preload("res://assets/fonts/boutique_bitmap/BoutiqueBitmap9x9_Bold_1.9.ttf")
const MODEL_PATH := "res://art/preview/screen_wall/screen_wall_model.tscn"
const SOURCE_SIZE := Vector2(1260.0,710.0)
const EYE_CENTER := Vector2(648.5,216.5)
const IMAGE_CROP := Rect2(0.225,0.01,0.55,0.55)
@export var preview_only := true
var model: Node3D
var camera: Camera3D
var displays: Array[Node3D] = []
var hovered: Node3D
var mouse_position := Vector2(-10000, -10000)
var keyboard_focus := -1
var last_action: StringName = &""
var settings_overlay: Control
var feedback: Label
var feedback_timer := 0.0
var eye_offset := Vector2.ZERO
var eye_last_mouse := Vector2(-10000,-10000)
var eye_idle_seconds := 3.0
var image_crop := IMAGE_CROP


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if ResourceLoader.exists(MODEL_PATH) and not "--rebuild-screen-wall" in OS.get_cmdline_user_args():
		model = load(MODEL_PATH).instantiate()
	else:
		model = BUILDER.build()
	add_child(model)
	_setup_camera_and_lights()
	for i in model.get_node("Televisions").get_child_count():
		var tv: Node3D = model.get_node("Televisions").get_child(i)
		var controller := DISPLAY.new()
		controller.name = "ScreenInteraction"
		tv.add_child(controller)
		controller.configure(tv, i)
		controller.activated.connect(_on_option)
		displays.append(controller)
	_align_image_to_eye_monitor()
	get_viewport().size_changed.connect(_align_image_to_eye_monitor)
	_setup_overlay()
	get_window().mouse_exited.connect(_mouse_left)
	if "--export-screen-wall" in OS.get_cmdline_user_args():
		_export_model.call_deferred()


func _setup_camera_and_lights() -> void:
	camera = Camera3D.new()
	camera.name = "CompositionCamera16x9"
	camera.position = Vector3(0, 4.55, 16.2)
	camera.fov = 32.5
	camera.near = 0.1
	camera.far = 50.0
	add_child(camera)
	camera.look_at(Vector3(0, 4.25, 0))
	camera.make_current()
	var world := WorldEnvironment.new()
	world.name = "ScreenRoomLighting"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("010203")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.BLACK
	environment.ambient_light_energy = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)


func _setup_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ReviewPresentation"
	add_child(layer)
	var finish := ColorRect.new()
	finish.name = "EdgeVignette"
	finish.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	finish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ui/screen_wall_finish.gdshader")
	finish.material = mat
	layer.add_child(finish)
	var hint := Label.new()
	layer.add_child(hint)
	hint.text = "靠近屏幕选择   /   方向键切换 · ENTER 确认"
	hint.add_theme_font_override("font", FONT)
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color("5e686d"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 344)
	hint.size = Vector2(640,14)
	feedback = Label.new()
	layer.add_child(feedback)
	feedback.add_theme_font_override("font", FONT)
	feedback.add_theme_font_size_override("font_size", 10)
	feedback.add_theme_color_override("font_color", Color("c3d7d3"))
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feedback.position = Vector2(420, 326)
	feedback.size = Vector2(200, 16)


func _input(event: InputEvent) -> void:
	if settings_overlay != null and settings_overlay.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			settings_overlay.hide()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		mouse_position = event.position
		keyboard_focus = -1
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hit := pick_display(event.position)
		# Approach may reveal a label beyond the glass, but clicking only works
		# on that monitor's actual visible front surface, with depth occlusion.
		if hit != null and hit == hovered and hit.is_ready_to_activate():
			hit.activate()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var actionable := _actionable_displays()
		if event.keycode in [KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_TAB]:
			var direction := -1 if event.keycode in [KEY_LEFT, KEY_UP] else 1
			keyboard_focus = posmod(keyboard_focus + direction, actionable.size())
			_set_hovered(actionable[keyboard_focus])
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and hovered != null:
			if hovered.is_ready_to_activate():
				hovered.activate()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_set_hovered(null)
			keyboard_focus = -1
			mouse_position = Vector2(-10000,-10000)


func _process(delta: float) -> void:
	_update_eye_follow(delta)
	if settings_overlay != null and settings_overlay.visible:
		_set_hovered(null)
		return
	if keyboard_focus < 0:
		_set_hovered(nearby_display(mouse_position))
	feedback_timer = maxf(0.0, feedback_timer - delta)
	if feedback_timer <= 0.0 and feedback != null:
		feedback.text = ""


func source_to_viewport(source_pixel: Vector2) -> Vector2:
	return ((source_pixel / SOURCE_SIZE - image_crop.position) / image_crop.size) * get_viewport().get_visible_rect().size


func _align_image_to_eye_monitor() -> void:
	if displays.size() <= 6:
		return
	var eye_monitor: Node3D = displays[6].chassis
	var glass_center := eye_monitor.to_global(Vector3(0,0,0.015))
	var target_uv := camera.unproject_position(glass_center) / get_viewport().get_visible_rect().size
	image_crop.position = EYE_CENTER / SOURCE_SIZE - target_uv * image_crop.size
	var crop := Vector4(image_crop.position.x,image_crop.position.y,image_crop.size.x,image_crop.size.y)
	for display in displays:
		display.effect.set_shader_parameter("image_crop",crop)


func _update_eye_follow(delta: float) -> void:
	if mouse_position.distance_squared_to(eye_last_mouse) > 0.01:
		eye_last_mouse = mouse_position
		eye_idle_seconds = 0.0
	else:
		eye_idle_seconds += delta
	var target := Vector2.ZERO
	var mouse_inside := get_viewport().get_visible_rect().has_point(mouse_position)
	var toward_mouse := mouse_position - source_to_viewport(EYE_CENTER)
	if mouse_inside and eye_idle_seconds < 3.0 and toward_mouse.length_squared() > 0.0001:
		var strength := clampf(toward_mouse.length() / 200.0, 0.0, 1.0)
		var direction := toward_mouse.normalized()
		var horizontal_limit := 6.0 if direction.x >= 0.0 else 4.0
		var x_distance := horizontal_limit / absf(direction.x) if absf(direction.x) > 0.0001 else INF
		var y_distance := 4.0 / absf(direction.y) if absf(direction.y) > 0.0001 else INF
		target = direction * minf(x_distance, y_distance) * strength
	var response_seconds := 0.28 if eye_idle_seconds >= 3.0 or not mouse_inside else 0.08
	eye_offset = eye_offset.lerp(target, 1.0 - exp(-delta / response_seconds))
	eye_offset.x = clampf(eye_offset.x,-4.0,6.0)
	eye_offset.y = clampf(eye_offset.y,-4.0,4.0)
	for display in displays:
		display.effect.set_shader_parameter("eye_offset_uv", eye_offset / SOURCE_SIZE)


func _mouse_left() -> void:
	mouse_position = Vector2(-10000,-10000)
	if keyboard_focus < 0:
		_set_hovered(null)


func _set_hovered(next: Node3D) -> void:
	if next == hovered:
		return
	if hovered != null:
		hovered.set_hovered(false)
	hovered = next
	if hovered != null:
		hovered.set_hovered(true)


func pick_display(point: Vector2) -> Node3D:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 50.0, 3)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	if not hit.collider.has_meta("display_controller"):
		return null
	var controller: Node3D = hit.collider.get_meta("display_controller", null)
	if controller == null or not controller.accepts_hit(hit.position):
		return null
	# Back and steeply reversed glass aren't clickable.
	if controller.chassis.global_basis.z.dot(direction) >= -0.05:
		return null
	return controller


func nearby_display(point: Vector2) -> Node3D:
	if not get_viewport().get_visible_rect().has_point(point):
		return null
	var direct := pick_display(point)
	if direct != null:
		return direct
	var closest: Node3D
	var distance := 11.0
	for display in displays:
		var poly: PackedVector2Array = display.visible_polygon(camera)
		for i in poly.size():
			var edge_point := Geometry2D.get_closest_point_to_segment(point, poly[i], poly[(i + 1) % poly.size()])
			var current_distance := edge_point.distance_to(point)
			if current_distance >= distance:
				continue
			# Probe slightly inside the surface to account for the rounded bezel.
			var center := camera.unproject_position(display.chassis.global_position)
			var probe := edge_point.lerp(center, 0.09)
			if pick_display(probe) == display:
				distance = current_distance
				closest = display
	return closest


func _actionable_displays() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for display in displays:
		if not display.action_id.is_empty():
			result.append(display)
	return result


func _on_option(action_id: StringName) -> void:
	last_action = action_id
	menu_requested.emit(action_id)
	if not preview_only:
		return
	if action_id == &"settings":
		_show_settings()
	elif action_id == &"quit":
		get_tree().quit()
	else:
		feedback.text = ("新游戏" if action_id == &"new_game" else "继续") + " · 交互样板"
		feedback_timer = 2.5


func _show_settings() -> void:
	if settings_overlay == null:
		settings_overlay = Control.new()
		settings_overlay.name = "SettingsOverlay"
		get_node("ReviewPresentation").add_child(settings_overlay)
		settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var shade := ColorRect.new()
		shade.color = Color(0.015,0.035,0.055,0.95)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		settings_overlay.add_child(shade)
		var panel: Control = load("res://scenes/ui/settings_panel.tscn").instantiate()
		panel.position = Vector2(150,65)
		panel.size = Vector2(340,230)
		settings_overlay.add_child(panel)
		var close := Button.new()
		close.text = "返回屏幕墙  /  ESC"
		close.position = Vector2(231,302)
		close.size = Vector2(178,26)
		close.pressed.connect(settings_overlay.hide)
		settings_overlay.add_child(close)
	settings_overlay.show()
	_set_hovered(null)


func _export_model() -> void:
	var dir := "res://art/preview/screen_wall/"
	# A clean geometry copy is editable without the runtime interaction script.
	var clean := BUILDER.build()
	add_child(clean)
	var packed := PackedScene.new()
	var packed_error := packed.pack(clean)
	if packed_error == OK:
		packed_error = ResourceSaver.save(packed, dir + "screen_wall_model.tscn")
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var glb_error := doc.append_from_scene(clean, state)
	if glb_error == OK:
		glb_error = doc.write_to_filesystem(state, dir + "screen_wall_model.glb")
	print("SCREEN_WALL_EXPORT scene=",packed_error," glb=",glb_error)
	clean.queue_free()
