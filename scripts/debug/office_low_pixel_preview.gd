extends Control

## Isolated interactive preview. No project settings or saved user settings.
## F6: resolution, F7: Palette 1, F8: legacy/new art, Esc: quit.
const ART = preload("res://scripts/dream/office_low_pixel_art.gd")
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
var game_view: SubViewport
var container: SubViewportContainer
var world: Node3D
var palette: ShaderMaterial
var low_resolution := true
var legacy := false
var rebuilding := false
var _caption: Label

func _ready() -> void:
	var window := get_window()
	window.content_scale_size = Vector2i.ZERO
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.size = Vector2i(1280, 760)
	window.min_size = Vector2i(640, 400)
	container = SubViewportContainer.new()
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(container)
	game_view = SubViewport.new()
	game_view.size = Vector2i(640, 360)
	game_view.own_world_3d = true
	game_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(game_view)
	_caption = Label.new()
	_caption.position = Vector2(12, 6)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	window.size_changed.connect(_fit)
	_fit()
	await rebuild()
	if "capture" in OS.get_cmdline_user_args():
		await capture_comparisons()
		get_tree().quit()
	elif "motion" in OS.get_cmdline_user_args():
		await motion_review()
		get_tree().quit()

func _fit() -> void:
	var available := Vector2(get_window().size) - Vector2(0, 40)
	var internal := Vector2(game_view.size)
	var factor := maxf(1.0, floorf(minf(available.x / internal.x, available.y / internal.y)))
	container.size = internal
	container.scale = Vector2.ONE * factor
	container.position = Vector2(floorf((get_window().size.x - internal.x * factor) * .5), 40 + floorf((available.y - internal.y * factor) * .5))
	_caption.text = "OPEN OFFICE | %s | %s | F6 resolution / F7 palette / F8 art / Esc quit" % ["640x360 integer" if low_resolution else "1280x720 native", "LEGACY" if legacy else "LOW PIXEL"]

func rebuild() -> void:
	rebuilding = true
	if is_instance_valid(world):
		world.queue_free()
		await get_tree().process_frame
	ART.enabled = not legacy
	world = WORLD.instantiate()
	world.set("generate_on_ready", false)
	world.set("persist_profile", false)
	game_view.add_child(world)
	assert(world.call("regenerate", 120), "Fixed seed sample generation failed")
	var office: Dictionary = {}
	for room in world.get("rooms"):
		if String(room.get("sample_key", "")) == "office":
			office = room
			break
	assert(not office.is_empty())
	var player: Node2D = world.get("player")
	player.global_position = Vector2(office.center_cell) * float(world.get("CELL_PIXELS"))
	world.call("activate_room", office.id)
	world.get("night_lighting").flashlight.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 1000
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palette = ShaderMaterial.new()
	palette.shader = preload("res://shaders/palette_quantize.gdshader")
	palette.set_shader_parameter("palette_enabled", false)
	overlay.material = palette
	layer.add_child(overlay)
	world.add_child(layer)
	rebuilding = false
	_fit()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or rebuilding:
		return
	match event.keycode:
		KEY_F6:
			set_resolution(not low_resolution)
		KEY_F7:
			palette.set_shader_parameter("palette_enabled", palette.get_shader_parameter("palette_enabled") != true)
		KEY_F8:
			legacy = not legacy
			rebuild()
		KEY_ESCAPE:
			get_tree().quit()
		_:
			return
	get_viewport().set_input_as_handled()

func set_resolution(low: bool) -> void:
	low_resolution = low
	game_view.size = Vector2i(640, 360) if low else Vector2i(1280, 720)
	_fit()

func capture_comparisons() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/low_pixel"))
	ART.texture().get_image().save_png(ProjectSettings.globalize_path("res://.runtime/low_pixel/atlas.png"))
	for old in [true, false]:
		legacy = old
		await rebuild()
		for enemy in world.get("enemy_root").get_children():
			enemy.set_physics_process(false)
		world.get("player").set_physics_process(false)
		for low in [false, true]:
			set_resolution(low)
			for frame in 60:
				await get_tree().process_frame
			world.set_process(false)
			world.set("camera_aim_offset", Vector3.ZERO)
			world.call("_update_camera_and_actor_projection", 0.0)
			for enabled in [false, true]:
				palette.set_shader_parameter("palette_enabled", enabled)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var filename := "%s_%s_%s.png" % ["before" if old else "after", "640" if low else "native", "palette1" if enabled else "off"]
				get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.runtime/low_pixel/" + filename))
				print("LOW_PIXEL_CAPTURE ", filename)
			palette.set_shader_parameter("palette_enabled", false)
			var samples: Array[float] = []
			for frame in 120:
				var started := Time.get_ticks_usec()
				await RenderingServer.frame_post_draw
				await get_tree().process_frame
				samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
			samples.sort()
			print("LOW_PIXEL_FRAME legacy=", old, " low=", low, " median_ms=", samples[60], " p95_ms=", samples[114])
			var camera: Camera3D = game_view.get_camera_3d()
			var point := Vector3(world.get("player").global_position.x / 32.0, .74, world.get("player").global_position.y / 32.0)
			var desk_width := camera.unproject_position(point + Vector3(.9,0,0)).distance_to(camera.unproject_position(point - Vector3(.9,0,0)))
			print("LOW_PIXEL_PROJECTION desk_pixels=", desk_width, " texel_pixels=", desk_width / 32.0, " fov=", camera.fov)

func _frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame

func _aim_at(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = game_view.get_camera_3d().unproject_position(Vector3(point.x / 32.0, 0, point.y / 32.0))
	game_view.push_input(event, true)

func _mouse_fire(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = container.position + game_view.get_mouse_position() * container.scale
	Input.parse_input_event(event)

func _dash_input(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = &"dash"
	event.pressed = pressed
	Input.parse_input_event(event)

func motion_review() -> void:
	# Controlled runtime exercise. Staging positions are explicit; movement,
	# shooting, pushing and the tap Dash run through production gameplay input.
	var player: Node2D = world.get("player")
	for enemy in world.get("enemy_root").get_children():
		enemy.set_physics_process(false)
	player.call("equip_weapon", "basic", world.get("config"), {})
	await _frames(30)
	var start := player.global_position
	_caption.text = "INPUT REVIEW | walk / aim / fire / tap Dash | staged office, production input"
	Input.action_press("move_right")
	for frame in 45:
		_aim_at(player.global_position + Vector2.RIGHT * 160)
		await _frames(1)
	Input.action_release("move_right")
	print("LOW_PIXEL_WALK displacement=", player.global_position.distance_to(start))
	var shots := [0]
	player.connect("weapon_fired", func(_recoil: float): shots[0] += 1)
	_mouse_fire(true)
	for frame in 180:
		_aim_at(player.global_position + Vector2.from_angle(float(frame) / 180.0 * TAU) * 180)
		await _frames(1)
	_mouse_fire(false)
	print("LOW_PIXEL_FIRE shots=", shots[0])
	Input.action_press("move_down")
	await _frames(2)
	var dash_start := player.global_position
	_dash_input(true)
	await _frames(2)
	print("LOW_PIXEL_DASH_PENDING state=", player.get("dash_input_state"), " can=", player.call("can_start_dash_aim"))
	_dash_input(false)
	await _frames(2)
	Input.action_release("move_down")
	await _frames(45)
	print("LOW_PIXEL_DASH displacement=", player.global_position.distance_to(dash_start))
	var chair: Node2D
	for item in world.get("furniture_root").get_children():
		if item.get_meta(&"office_pixel_sample", false) == true and item.get_meta(&"office_furniture_kind", "") == "chair" and item.get("destroyed") != true:
			chair = item
			break
	if is_instance_valid(chair):
		_caption.text = "INPUT REVIEW | pushing chair | gameplay collider drives the visual"
		var chair_start := chair.global_position
		player.global_position = chair_start + Vector2(0, 38)
		await _frames(10)
		Input.action_press("move_up")
		await _frames(65)
		Input.action_release("move_up")
		await _frames(25)
		print("LOW_PIXEL_PUSH chair_displacement=", chair.global_position.distance_to(chair_start))
	# Door interaction uses a neighbouring room because the office has open
	# corridor entrances. The neighbour keeps its existing art.
	for room in world.get("rooms"):
		if String(room.get("sample_key", "")) != "conference":
			continue
		world.call("activate_room", room.id)
		player.global_position = Vector2(room.center_cell) * 32.0
		await _frames(5)
		var doors: Array = world.get("door_root").get_children()
		if not doors.is_empty():
			var door: Node3D = doors[0]
			var edge: Dictionary = door.get_meta(&"door_edge", {})
			var normal := Vector2.RIGHT if String(edge.get("axis", "")) == "V" else Vector2.DOWN
			var door_pos := Vector2(door.position.x, door.position.z) * 32.0
			player.global_position = door_pos - normal * 36.0
			_caption.text = "INPUT REVIEW | walking into existing hinged door | neighbour art unchanged"
			await _frames(10)
			var action := "move_right" if normal.x > .5 else "move_down"
			Input.action_press(action)
			await _frames(90)
			Input.action_release(action)
			print("LOW_PIXEL_DOOR player_displacement=", player.global_position.distance_to(door_pos - normal * 36.0))
			if is_instance_valid(door):
				print("LOW_PIXEL_DOOR angle=", door.call("get_open_angle"))
			await _frames(30)
		break
