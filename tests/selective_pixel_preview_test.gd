extends SceneTree
## Structural/input regression only. GPU pixels and occlusion need visual capture.

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var original_scale := root.content_scale_size
	root.content_scale_size = Vector2i(640, 360)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	var packed := load("res://scenes/dream/preview/SelectivePixelPreview.tscn") as PackedScene
	_check(packed != null, "Independent preview scene loads")
	if packed == null:
		quit(1)
		return
	var preview: Node = packed.instantiate()
	root.add_child(preview)
	await _frames(15)
	var world: Node = preview.get("world")
	var world_viewport: SubViewport = preview.get("world_viewport")
	_check(is_instance_valid(world), "One formal gameplay world exists")
	_check(world_viewport != null, "One full-world render viewport exists")
	if world == null or world_viewport == null:
		preview.queue_free()
		root.content_scale_size = original_scale
		quit(1)
		return
	_check(world.get_viewport() == world_viewport, "Gameplay and camera use the one world viewport")
	_check(world_viewport.size == Vector2i(640, 360), "Pixelated world renders at 640 by 360")
	_check(preview.get_stats().world_render_viewport_count == 1, "The wrapper renders one full world")
	_check(root.content_scale_size == Vector2i(640, 360), "Preview preserves the UI canvas scale")
	var camera: Camera3D = world.get("camera_3d")
	_check(camera == world_viewport.get_camera_3d(), "Formal camera remains active")
	var world_id := world.get_instance_id()
	var player: Node = world.get("player")
	var player_id := player.get_instance_id()
	var bridge: Node = world.get("player_depth_bridge")
	var sprite: Sprite3D = bridge.get("actor_sprite")
	var original_layers := sprite.layers
	for enabled in [false, true, false, true]:
		preview.call("set_selective_enabled", enabled)
		await _frames(4)
		_check(bool(preview.get("selective_enabled")) == enabled, "Mode switch applies immediately")
		_check(world.get_instance_id() == world_id and player.get_instance_id() == player_id, "Mode switch preserves gameplay owners")
		_check(world_viewport.size == (Vector2i(640, 360) if enabled else Vector2i(1920, 1080)), "Mode switch changes only world render resolution")
		_check(player.get_presentation_hud_position(Vector2(world_viewport.size) * 0.5).is_equal_approx(preview.content_rect.get_center()), "World camera midpoint stays aligned with clear HUD in both modes")
	_check(sprite.layers == original_layers, "Preview preserves character light/shadow layers")
	preview.call("set_palette_enabled", true)
	_check(bool(preview.get("palette_enabled")), "Palette can enable independently")
	preview.call("set_palette_enabled", false)
	_check(not bool(preview.get("palette_enabled")), "Palette can disable independently")
	var rect: Rect2 = preview.get("content_rect")
	var local_center: Vector2 = preview.call("window_to_content", rect.get_center())
	_check(local_center.is_equal_approx(Vector2(world_viewport.size) * 0.5), "Window center maps to world camera center")
	_check(preview.call("world_to_hud", local_center).is_equal_approx(rect.get_center()), "World camera center maps back to HUD center")
	_check(player.get_presentation_hud_position(Vector2(world_viewport.size) * 0.5).is_equal_approx(rect.get_center()), "Player HUD projection uses the same world-camera mapping")
	var outside: Vector2 = preview.call("window_to_content", rect.position - Vector2.ONE)
	_check(not outside.is_finite(), "Letterbox coordinates are invalid gameplay coordinates")
	_check(rect.size.is_equal_approx(Vector2(640, 360)), "1080p uses nearest 3x world pixels in the logical UI canvas")
	var stats: Dictionary = preview.call("get_stats")
	_check(not stats.is_empty() and stats.world_render_viewport_count == 1, "Coordinator reports one-world diagnostics")
	root.size = Vector2i(1280, 720)
	await _frames(5)
	var resized: Rect2 = preview.content_rect
	_check(resized == Rect2(0, 0, 640, 360), "720p uses full logical canvas and 2x integer world pixels")
	_check(preview.window_to_content(Vector2(320, 180)) == Vector2(320, 180), "Resized mouse maps to world center")
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2(320, 180)
	preview._input(pointer)
	_check(player.get_presentation_pointer_position() == Vector2(320, 180), "Aim and held weapon use the shared world pointer")
	_check(player._presentation_pointer_input_allowed(), "Pointer inside the content permits input")
	pointer.position = resized.position - Vector2.ONE
	preview._input(pointer)
	_check(not player._presentation_pointer_input_allowed(), "Black bars reject shooting and planning")
	_check(player.get_presentation_pointer_position() == Vector2(320, 180), "Black bars retain the last valid heading")
	root.size = Vector2i(1280, 800)
	await _frames(5)
	var aspect_rect: Rect2 = preview.content_rect
	_check(aspect_rect == root.get_visible_rect(), "Non-16:9 window uses Godot's existing letterbox only once")
	_check(root.get_final_transform().origin.is_equal_approx(Vector2(0, 40)), "Window letterbox is represented by the root canvas transform")
	_check(preview.window_to_content(Vector2(0, 0)) == Vector2.ZERO, "Top-left logical pointer maps to world origin")
	_check(preview.window_to_content(Vector2(639, 359)) == Vector2(639, 359), "Bottom-right logical pointer maps to world edge")
	_check(preview.world_to_hud(Vector2(640, 360)).is_equal_approx(aspect_rect.end), "World bottom-right projects to logical HUD edge")
	preview.set_selective_enabled(false)
	await _frames(4)
	_check(world_viewport.size == Vector2i(1280, 720), "Native world uses the visible physical area in a non-16:9 window")
	_check(player.get_presentation_hud_position(Vector2(640, 360)).is_equal_approx(aspect_rect.get_center()), "Native camera midpoint stays aligned with clear HUD")
	_check(preview.window_to_content(Vector2(320, 180)) == Vector2(640, 360), "Native pointer mapping follows camera viewport pixels")
	preview.set_selective_enabled(true)
	await _frames(4)
	root.size = Vector2i(1920, 1080)
	await _frames(5)
	preview.set_preview_pixel_size(Vector2i(960, 540))
	await _frames(4)
	_check(world_viewport.size == Vector2i(960, 540), "Comparison preview can render the same world at 960 by 540")
	_check(player.get_presentation_hud_position(Vector2(480, 270)).is_equal_approx(preview.content_rect.get_center()), "Comparison preview keeps the HUD aligned")
	preview.set_preview_pixel_size(Vector2i(640, 360))
	await _frames(4)
	for floor_index in 3:
		_check(bool(world.call("regenerate", 42001 + floor_index)), "Lifecycle floor %d regenerates" % floor_index)
		await _frames(12)
		_check(world.get_viewport() == world_viewport, "Regeneration preserves input ownership")
		_check(world_viewport.size == Vector2i(640, 360), "Regeneration preserves the 640 by 360 render size")
		_check(world.get_instance_id() == world_id, "Regeneration does not duplicate world")
		print("PREVIEW_FLOOR_STATS ", floor_index, " ", preview.call("get_stats"))
	preview.queue_free()
	await _frames(12)
	_check(not is_instance_valid(preview), "Preview cleans up")
	_check(root.content_scale_size == Vector2i(640, 360), "Preview cleanup does not disturb UI scaling")
	root.content_scale_size = original_scale
	print("SELECTIVE_PIXEL_PREVIEW checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
