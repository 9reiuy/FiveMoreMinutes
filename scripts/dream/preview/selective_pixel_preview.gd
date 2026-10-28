extends Control
## One gameplay world and one full-world rendering viewport. The root retains
## the project's 640x360 canvas for crisp HUD; only the 3D world changes size.
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const DEFAULT_PIXEL_SIZE := Vector2i(640, 360)

@export var preview_seed := 42001
@export var muted := true
@export var preview_mode := true
@export var initial_selective_enabled := true
## Preview comparisons may select 960x540. Formal screens keep 640x360.
@export var pixel_size := DEFAULT_PIXEL_SIZE

var world: Node3D
var world_viewport: SubViewport
var container: SubViewportContainer
var palette_material: ShaderMaterial
var status_label: Label
var selective_enabled := true
var palette_enabled := false
## Rectangle in the root viewport's logical canvas coordinates.
var content_rect := Rect2()

var _original_canvas_viewports: Dictionary = {}
var _original_player_meta: Dictionary = {}
var _original_world_meta: Dictionary = {}
var _pointer_window := Vector2.ZERO
var _last_valid_pointer := Vector2.ZERO
var _pointer_seen := false
var _initialized := false
var _canvas_dirty := false
var _saved_mute := false
## Preparation screens keep crisp UI hidden until the journey commits.
var staging := false


func _ready() -> void:
	add_to_group(&"dream_display")
	process_priority = 1000
	selective_enabled = bool(SettingsManager.get_setting(&"pixelation_enabled", true))
	palette_enabled = SettingsManager.get_palette_enabled()
	SettingsManager.setting_changed.connect(_on_display_setting_changed)
	if not preview_mode and world == null:
		push_error("Pixelation display requires a gameplay world before entering the tree")
		return
	var master := AudioServer.get_bus_index(&"Master")
	if master >= 0 and muted and preview_mode:
		_saved_mute = AudioServer.is_bus_mute(master)
		AudioServer.set_bus_mute(master, true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.name = "OutsideDisplayBlack"
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container = SubViewportContainer.new()
	container.name = "WorldDisplayContainer"
	container.stretch = true
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(container)
	world_viewport = SubViewport.new()
	world_viewport.name = "WorldViewport"
	# A prepared floor must not appear through the live lobby's camera.
	world_viewport.own_world_3d = staging
	world_viewport.size = pixel_size
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_viewport.msaa_3d = Viewport.MSAA_DISABLED
	world_viewport.positional_shadow_atlas_size = 4096
	container.add_child(world_viewport)
	if world == null:
		world = WORLD.instantiate()
		world.generate_on_ready = false
		world.persist_profile = false
		world.enable_game_start_cab_exit = false
	world_viewport.add_child(world)

	# Occlusion Cutout is single-pass inside this WorldViewport: occluder
	# furniture discards its hole core in the transparent list (see
	# office_low_pixel*.gdshader / furniture_pixel_outline.gdshader).  No second
	# behind-camera render or full-screen composite overlay is used.
	if preview_mode:
		world.regenerate(preview_seed)
		for room in world.rooms:
			if String(room.get("archetype", "")) == "open_office":
				world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
				world.activate_room(int(room.id))
				break
		world.night_lighting.set_flashlight_enabled(false)
	_install_coordinate_mapping()
	var palette_layer := CanvasLayer.new()
	palette_layer.name = "WorldPaletteLayer"
	# Palette processes the 3D world only; empty regions are now depth-tested
	# geometry, not a later screen-space floor-footprint overlay.
	palette_layer.layer = 18
	world_viewport.add_child(palette_layer)
	var palette_rect := ColorRect.new()
	palette_rect.name = "WorldPalette"
	palette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palette_layer.add_child(palette_rect)
	palette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	palette_material = ShaderMaterial.new()
	palette_material.shader = preload("res://shaders/palette_quantize.gdshader")
	palette_material.set_shader_parameter(&"palette_scheme", SettingsManager.get_palette_scheme())
	palette_material.set_shader_parameter(&"palette_enabled", palette_enabled and not bool(world.get_meta(&"preserve_local_palette",false)))
	palette_rect.material = palette_material
	if preview_mode:
		var controls := CanvasLayer.new()
		controls.layer = 40
		add_child(controls)
		status_label = Label.new()
		status_label.position = Vector2(12, 12)
		status_label.add_theme_font_size_override("font_size", 16)
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		controls.add_child(status_label)
	_initialized = true
	_update_layout(true)
	_retarget_canvas_layers()
	get_tree().node_added.connect(_on_node_added)
	_update_status()


func _install_coordinate_mapping() -> void:
	var player: Node = world.get("player")
	if is_instance_valid(player):
		for key in [&"presentation_pointer_gate", &"presentation_pointer_position", &"presentation_world_to_hud"]:
			var present := player.has_meta(key)
			_original_player_meta[key] = {"present": present, "value": player.get_meta(key) if present else null}
		player.set_meta(&"presentation_pointer_gate", Callable(self, "_pointer_inside"))
		player.set_meta(&"presentation_pointer_position", Callable(self, "_pointer_content"))
		player.set_meta(&"presentation_world_to_hud", Callable(self, "world_to_hud"))
	var world_key := &"presentation_world_to_hud"
	var present := world.has_meta(world_key)
	_original_world_meta[world_key] = {"present": present, "value": world.get_meta(world_key) if present else null}
	world.set_meta(world_key, Callable(self, "world_to_hud"))


func _process(_delta: float) -> void:
	if not _initialized:
		return
	_update_layout()
	if _canvas_dirty:
		_canvas_dirty = false
		_retarget_canvas_layers()
	container.mouse_filter = Control.MOUSE_FILTER_STOP if _pointer_inside() else Control.MOUSE_FILTER_IGNORE



func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer_window = event.position
		_pointer_seen = true
	if preview_mode and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F6:
			set_selective_enabled(not selective_enabled)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F7:
			set_palette_enabled(not palette_enabled)
			get_viewport().set_input_as_handled()
	if _initialized and event.is_action_pressed("dash") and not _pointer_inside():
		Input.action_release("dash")
		get_viewport().set_input_as_handled()


func set_selective_enabled(value: bool) -> void:
	selective_enabled = value
	if _initialized:
		_update_layout(true)
		_update_status()


func set_preview_pixel_size(value: Vector2i) -> void:
	if not preview_mode or value not in [Vector2i(640, 360), Vector2i(960, 540)]:
		return
	pixel_size = value
	if _initialized:
		_update_layout(true)
		_update_status()


func set_palette_enabled(value: bool) -> void:
	palette_enabled = value
	if is_instance_valid(palette_material):
		palette_material.set_shader_parameter(&"palette_enabled", value and not bool(world.get_meta(&"preserve_local_palette",false)))
	_update_status()


func _on_display_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"palette_scheme" and is_instance_valid(palette_material):
		palette_material.set_shader_parameter(&"palette_scheme", int(value))
	if key == &"pixelation_enabled":
		set_selective_enabled(bool(value))
	elif key == &"palette_enabled":
		set_palette_enabled(bool(value))


func _pointer_inside() -> bool:
	return content_rect.has_point(_pointer_window)


func _pointer_content() -> Vector2:
	var local := window_to_content(_pointer_window)
	if local.is_finite():
		_last_valid_pointer = local
	return _last_valid_pointer


## Root logical input point -> active Camera3D viewport pixel point.
func window_to_content(point: Vector2) -> Vector2:
	if not content_rect.has_point(point) or not is_instance_valid(world_viewport):
		return Vector2.INF
	return (point - content_rect.position) * Vector2(world_viewport.size) / content_rect.size


## Camera3D projection point -> root logical HUD canvas point.
func world_to_hud(point: Vector2) -> Vector2:
	if not is_instance_valid(world_viewport):
		return point
	return content_rect.position + point * content_rect.size / Vector2(world_viewport.size)


func _update_layout(force := false) -> void:
	var logical_size := get_viewport_rect().size
	# canvas_items can already letterbox the root viewport before this Control
	# is laid out. Derive its actual physical display area from the viewport
	# transform rather than using the whole OS window a second time.
	var to_physical := get_viewport().get_final_transform()
	var physical_top_left := to_physical * Vector2.ZERO
	var physical_size := to_physical * logical_size - physical_top_left
	if logical_size.x <= 0.0 or logical_size.y <= 0.0 or physical_size.x <= 0.0 or physical_size.y <= 0.0:
		return
	var factor := floori(minf(physical_size.x / float(pixel_size.x), physical_size.y / float(pixel_size.y)))
	var fit := float(factor) if factor >= 1 else minf(physical_size.x / float(pixel_size.x), physical_size.y / float(pixel_size.y))
	var display_physical := Vector2(pixel_size) * fit
	var physical_origin := physical_top_left + ((physical_size - display_physical) * 0.5).floor()
	var from_physical := to_physical.affine_inverse()
	var logical_origin := from_physical * physical_origin
	var next := Rect2(logical_origin, from_physical * (physical_origin + display_physical) - logical_origin)
	var next_world_size := pixel_size if selective_enabled else Vector2i(display_physical.round())
	if not force and next == content_rect and world_viewport.size == next_world_size:
		return
	var previous_size := world_viewport.size
	content_rect = next
	container.position = next.position
	# SubViewportContainer.stretch sizes its child from the unscaled Control
	# rectangle. Scale only the final display; this permits a 1280x720
	# native world inside the project's 640x360 logical UI canvas.
	container.size = Vector2(next_world_size)
	container.scale = next.size / Vector2(next_world_size)
	if not _pointer_seen:
		_pointer_window = next.get_center()
		_last_valid_pointer = Vector2(next_world_size) * 0.5
	elif next.has_point(_pointer_window):
		_last_valid_pointer = (_pointer_window - next.position) * Vector2(next_world_size) / next.size
	elif previous_size.x > 0 and previous_size.y > 0:
		_last_valid_pointer *= Vector2(next_world_size) / Vector2(previous_size)


func _retarget_canvas_layers() -> void:
	if not is_instance_valid(world):
		return
	# Collect layers first to avoid mutation during iteration after reparent.
	var layers_to_process: Array[CanvasLayer] = []
	for item in world.find_children("*", "CanvasLayer", true, false):
		var layer := item as CanvasLayer
		if layer == null:
			continue
		# Physics/gameplay coordinates and the floor-footprint mask belong to
		# Camera3D's viewport. UI and world prompts draw on the root canvas.
		if layer == world.get("gameplay_canvas") or layer.name == &"OutsideFootprintMaskLayer" or layer.get_meta(&"world_post_effect",false):
			continue
		layers_to_process.append(layer)

	for layer in layers_to_process:
		var id := layer.get_instance_id()
		if not _original_canvas_viewports.has(id):
			_original_canvas_viewports[id] = {
				"node": weakref(layer),
				"viewport": layer.custom_viewport,
				"original_parent": weakref(layer.get_parent()),
				"staging_visible": layer.visible,
			}
		# Reparent the CanvasLayer out of the SubViewport tree into
		# SelectivePixelPreview (on the root Window canvas).  This gives
		# child Controls the native 640x360 logical size and lets them
		# receive mouse input without the SubViewportContainer distorting
		# coordinates or intercepting clicks.
		if layer.get_parent() != self:
			layer.reparent(self)
			# After reparenting, the layer naturally uses its new parent's
			# viewport (root Window). No need to set custom_viewport.
		if staging: layer.hide()

func commit_staging() -> void:
	staging = false
	_retarget_canvas_layers()
	# Previously retargeted layers no longer descend from world.
	for record in _original_canvas_viewports.values():
		var layer: CanvasLayer = record.node.get_ref()
		if is_instance_valid(layer): layer.visible = record.staging_visible
	show()


func _on_node_added(node: Node) -> void:
	if _initialized and is_instance_valid(world) and world.is_ancestor_of(node) and node is CanvasLayer:
		# world_post_effect layers are always skipped by _retarget_canvas_layers();
		# do not schedule a whole-world CanvasLayer scan for them.
		if node.get_meta(&"world_post_effect", false):
			return
		_canvas_dirty = true


func _update_status() -> void:
	if is_instance_valid(status_label):
		status_label.text = "F6: %s | F7 Palette: %s | silent" % ["%dx%d world" % [pixel_size.x, pixel_size.y] if selective_enabled else "Native world", "ON" if palette_enabled else "OFF"]


func get_stats() -> Dictionary:
	var shadow_lights := 0
	for light in world.find_children("*", "Light3D", true, false):
		if light.visible and light.shadow_enabled:
			shadow_lights += 1
	return {"selective": selective_enabled, "world_size": world_viewport.size, "content_rect": content_rect, "world_render_viewport_count": 1, "viewport_count": find_children("*", "SubViewport", true, false).size(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "shadow_lights": shadow_lights, "renderer": RenderingServer.get_video_adapter_name()}


func _exit_tree() -> void:
	if SettingsManager.setting_changed.is_connected(_on_display_setting_changed):
		SettingsManager.setting_changed.disconnect(_on_display_setting_changed)
	_initialized = false
	if is_instance_valid(world):
		var player: Node = world.get("player")
		if is_instance_valid(player):
			for key in _original_player_meta:
				var state: Dictionary = _original_player_meta[key]
				if state.present:
					player.set_meta(key, state.value)
				else:
					player.remove_meta(key)
		for key in _original_world_meta:
			var state: Dictionary = _original_world_meta[key]
			if state.present:
				world.set_meta(key, state.value)
			else:
				world.remove_meta(key)
	for id in _original_canvas_viewports:
		var state: Dictionary = _original_canvas_viewports[id]
		var layer := (state.node as WeakRef).get_ref() as CanvasLayer
		if is_instance_valid(layer):
			var orig_parent_ref: WeakRef = state.get("original_parent", WeakRef.new()) as WeakRef
			var orig_parent: Node = orig_parent_ref.get_ref() if orig_parent_ref != null else null
			if is_instance_valid(orig_parent) and orig_parent != self:
				layer.reparent(orig_parent)
			# Only restore custom_viewport if it was explicitly set originally.
			if state.viewport != null and is_instance_valid(state.viewport):
				layer.custom_viewport = state.viewport
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if muted and preview_mode:
		var master := AudioServer.get_bus_index(&"Master")
		if master >= 0:
			AudioServer.set_bus_mute(master, _saved_mute)
