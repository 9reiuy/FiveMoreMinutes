extends "res://scripts/testing/game_test_lab.gd"
## Independent production-art lab. Nothing in Main references this sample.
const SAMPLE_POST = "res://shaders/preview/hellkind_sample/world_post.gdshader"
const WEATHER_INCLUDE = "res://shaders/preview/hellkind_sample/surface_weathering.gdshaderinc"
const VISIBILITY_FIELD = preload("res://scripts/preview/woo_polygon_visibility.gd")
const SHADOW_VISIBILITY_FIELD = preload("res://scripts/preview/woo_visibility_shadow.gd")
const SHADOW_VISIBILITY_SURFACES = preload("res://scripts/preview/woo_shadow_materials.gd")
const ACTOR_VISIBILITY = preload("res://scripts/preview/woo_actor_visibility.gd")
const VISIBILITY_SURFACES = preload("res://scripts/preview/woo_polygon_materials.gd")
const PRIMITIVE_VISIBILITY = preload("res://scripts/preview/woo_primitive_visibility.gd")
const CHARACTER_INKS = preload("res://scripts/preview/sample_character_inks.gd")
const EXTINGUISHER_INK = preload("res://shaders/preview/hellkind_sample/extinguisher_ink.gdshader")
const ENVIRONMENT_HALFTONE = preload("res://scripts/preview/sample_environment_halftone.gd")
const HALFTONE_CARRIERS = preload("res://scripts/preview/sample_halftone_carriers.gd")
const CHARACTER_INK_STYLE := 4
const STYLE_NAMES := {1: "2  蓝紫颗粒", 3: "4  浓紫硬调", CHARACTER_INK_STYLE: "5  半调"}
const SAMPLE_EXTERIOR_RAY := Vector3(-0.45, -0.39, -0.48)
const SAMPLE_CITY_BOUNCE_RAY := Vector3(0.54, -0.38, 0.43)
const SAMPLE_WINDOW_SPREAD_LIMIT := 3
var sample_ready := false
var style_index := CHARACTER_INK_STYLE
var character_inks: Node3D
var environment_halftone: ENVIRONMENT_HALFTONE
var halftone_carriers: Node
var scene_halftone_enabled := true
var extinguisher_paint: Array[ShaderMaterial] = []
var retro_material: ShaderMaterial
var sample_ui: CanvasLayer
var style_buttons: Dictionary[int, Button] = {}
var palette_button: CheckButton
var pixels_button: CheckButton
var sample_caption: Label
var weather_materials: Array[ShaderMaterial] = []
var weather_binding_count := 0
var _weather_cache: Dictionary = {}
var _weather_shaders: Dictionary = {}
var _weather_pairs: Array[Dictionary] = []
var _owned_materials: Dictionary = {}
var clean_floor_materials: Array[ShaderMaterial] = []
var _lamps_enabled := false
var _sample_lights: Array[WeakRef] = []
var _lamp_frame_restore: Dictionary = {}
var _sample_city_bounce: DirectionalLight3D
var _sample_window_spots: Array[SpotLight3D] = []
var _sample_window_room := -2
var original_camera_fov := 35.0
var camera_zoom_fov := 35.0
var target_body_height := 32.0
var calibrated_body_height := 0.0
var vision_enabled := true
var use_volume_visibility := true
var visibility_field
var actor_visibility
var visibility_surfaces
var primitive_visibility
var preparation_report: Dictionary = {}
var _loading_layer: CanvasLayer
var _native_monitor: Node
var _monitor_process_before := true
var _monitor_mode_before := 1

func _ready() -> void:
	output_root = "res://.runtime/hellkind_purple_sample_20261103/captures"
	recorder = preload("res://scripts/preview/woo_sample_recorder.gd").new()
	super._ready()
	_native_monitor = get_node_or_null(^"/root/PerformanceMonitor")
	if _native_monitor != null:
		_monitor_process_before = _native_monitor.is_processing()
		_monitor_mode_before = _native_monitor.current_mode
		_native_monitor.current_mode = 0
		_native_monitor._update_display_mode()
		if not _native_monitor.is_recording(): _native_monitor.set_process(false)
	RenderingServer.viewport_set_measure_render_time(get_tree().root.get_viewport_rid(), false)
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_title("FiveMinuteMore · 美术与视野合并小样")

func _build_ui() -> void:
	super._build_ui()
	mode.select(1)
	seed_box.value = 71432
	enemies.value = 8
	lab_enemy_archetypes = [&"employee", &"waitress"]
	checks.special.set_pressed_no_signal(true)
	checks.pixels.button_pressed = true
	checks.palette.button_pressed = true
	checks.tonal.button_pressed = false
	checks.uncapped.button_pressed = false
	panel.hide()
	hud.hide()
	sample_ui = CanvasLayer.new()
	sample_ui.name = "PurpleSampleControls"
	sample_ui.layer = 260
	add_child(sample_ui)
	var top := PanelContainer.new()
	top.position = Vector2(10, 9)
	top.custom_minimum_size = Vector2(620, 50)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("0c091ced")
	panel_style.border_color = Color("7664c4")
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(7)
	top.add_theme_stylebox_override("panel", panel_style)
	sample_ui.add_child(top)
	var stack := VBoxContainer.new()
	top.add_child(stack)
	var row := HBoxContainer.new()
	stack.add_child(row)
	var title := Label.new()
	title.text = "美术 + 视野 / 独立小样"
	title.add_theme_font_size_override("font_size", 12)
	title.modulate = Color("d9ccff")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	for i: int in STYLE_NAMES:
		var button := Button.new()
		button.text = STYLE_NAMES[i]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(apply_style.bind(i))
		row.add_child(button)
		style_buttons[i] = button
	palette_button = CheckButton.new()
	palette_button.text = "调色板"
	palette_button.focus_mode = Control.FOCUS_NONE
	palette_button.toggled.connect(set_sample_palette)
	row.add_child(palette_button)
	pixels_button = CheckButton.new()
	pixels_button.text = "像素化"
	pixels_button.focus_mode = Control.FOCUS_NONE
	pixels_button.toggled.connect(set_sample_pixels)
	row.add_child(pixels_button)
	sample_caption = Label.new()
	sample_caption.add_theme_font_size_override("font_size", 10)
	sample_caption.modulate = Color("aca5c9")
	stack.add_child(sample_caption)
	var help := Label.new()
	help.position = Vector2(12, 331)
	help.add_theme_font_size_override("font_size", 10)
	help.text = "WASD 移动  鼠标射击  E/F 交互  空格冲刺  |  F2 换房  F9 视野对照  F11 半调对照  F12 看巡逻机\nR 换弹  F4 烟雾  F5 室内灯对照  F6 血迹  F7 敌人行动  F8 截图  F10 重置  F1 说明"
	help.modulate = Color("c1b8dc")
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sample_ui.add_child(help)

func rebuild() -> void:
	if busy: return
	sample_ready = false
	_show_loading()
	if is_instance_valid(world): await retire_drawing()
	_disconnect_sample_draw_hooks()
	_release_visibility()
	_restore_weather_materials()
	weather_materials.clear()
	_weather_cache.clear()
	_weather_shaders.clear()
	_weather_pairs.clear()
	_owned_materials.clear()
	clean_floor_materials.clear()
	_sample_lights.clear()
	extinguisher_paint.clear()
	weather_binding_count = 0
	await super.rebuild()
	if not ready_world: return
	_set_sample_drone_patrol(checks.ai.button_pressed)
	RenderingServer.viewport_set_measure_render_time(world.get_viewport().get_viewport_rid(), false)
	var native_smoke: Node3D = world.floor_root.get_node_or_null(^"FireExtinguisherSystem")
	if native_smoke != null: preload("res://scripts/preview/woo_smoke_controller.gd").adopt(native_smoke)
	original_camera_fov = world.authoritative_camera_fov
	panel.hide()
	hud.hide()
	# Allow the production material setup to finish before cloning live materials.
	station.select(3)
	teleport(3)
	for frame in 8: await get_tree().process_frame
	_install_post()
	_install_environment_halftone()
	_collect_owned_materials()
	_scan_weather_surfaces()
	await _calibrate_camera_zoom()
	character_inks = CHARACTER_INKS.new()
	character_inks.name = "SampleCharacterInks"
	world.add_child(character_inks)
	character_inks.configure(world.player_depth_bridge, world.camera_3d)
	for extinguisher in get_tree().get_nodes_in_group(&"fire_extinguishers"):
		if not world.is_ancestor_of(extinguisher) or extinguisher.paint_material == null: continue
		var paint: ShaderMaterial = extinguisher.paint_material
		_replace_shader_preserving_parameters(paint, EXTINGUISHER_INK)
		extinguisher_paint.append(paint)
	_install_visibility()
	await _prepare_runtime_drawing()
	if environment_halftone != null:
		halftone_carriers = HALFTONE_CARRIERS.new()
		world.add_child(halftone_carriers)
		halftone_carriers.configure(world.actor_depth_bridges_root)
	for item in world.find_children("*", "Light3D", true, false):
		_track_sample_light(item)
	get_tree().node_added.connect(_track_sample_light)
	sample_ready = true
	# Connect after the world's reflection/shadow managers, so their final
	# light values remain authoritative and F5 only affects the rendered frame.
	RenderingServer.frame_pre_draw.connect(_sample_pre_draw)
	RenderingServer.frame_post_draw.connect(_sample_post_draw)
	apply_style(style_index)
	set_vision_enabled(vision_enabled)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if is_instance_valid(_loading_layer): _loading_layer.hide()

func retire_drawing() -> void:
	# Retire an old/replaced world before freeing active light/geometry pairs.
	# This runs only under loading or exit, never as a gameplay visibility gate.
	sample_ready = false
	if not is_instance_valid(world): return
	world.process_mode = Node.PROCESS_MODE_DISABLED
	if RenderingServer.get_current_rendering_method() == &"forward_plus":
		# Detach geometry while its lights still have a valid scenario. The
		# engine's regular node teardown can otherwise retire a paired light first.
		for visual: GeometryInstance3D in world.find_children("*", "GeometryInstance3D", true, false):
			RenderingServer.instance_set_scenario(visual.get_instance(), RID())
	world.hide()
	for light: Light3D in world.find_children("*", "Light3D", true, false): light.hide()
	for viewport: SubViewport in world.find_children("*", "SubViewport", true, false): viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _close_sample() -> void:
	await retire_drawing()
	get_tree().quit()

func _show_loading() -> void:
	if not is_instance_valid(_loading_layer):
		_loading_layer = CanvasLayer.new()
		_loading_layer.name = "PurpleSampleLoading"
		_loading_layer.layer = 300
		add_child(_loading_layer)
		var background := ColorRect.new()
		background.color = Color("090518")
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_loading_layer.add_child(background)
		var label := Label.new()
		label.text = "正在准备场景…"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_loading_layer.add_child(label)
	_loading_layer.show()

func _prepare_runtime_drawing() -> void:
	# This is actual launch preparation, under the same loading cover every
	# player sees. First gameplay effects remain in the performance sample.
	var old_process: int = world.process_mode
	var position_before: Vector2 = world.player.global_position
	var ammo_before: Dictionary = world.player.ammo_states.duplicate(true)
	var weapon_before: String = world.player.selected_weapon_id
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var reflections := world.get_node_or_null("FloorReflections")
	var reflection_process_mode: int = reflections.process_mode if reflections != null else 0
	var reflection_hz: float = reflections.update_hz if reflections != null else 15.0
	if reflections != null:
		# The native loader pauses the level; still prepare its actual reflection
		# viewport and material variants, which otherwise remain cold until play.
		reflections.process_mode = Node.PROCESS_MODE_ALWAYS
		reflections.update_hz = 1000000.0
	visibility_surfaces.preparing = true
	visibility_surfaces.set_enabled(false)
	RenderingServer.frame_pre_draw.connect(visibility_surfaces.update_now)
	var smoke_preparation := preload("res://scripts/preview/woo_smoke_preparation.gd").new()
	smoke_preparation.prepare(world)
	var particle_preparation := preload("res://scripts/dream/elemental_particles_3d.gd").new()
	particle_preparation.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(particle_preparation)
	particle_preparation.preserve_flame_colors = true
	particle_preparation.rng.seed = 71432
	var preparation_point: Vector3 = particle_preparation.to_local(world.get_gameplay_world_position(world.player.global_position + Vector2(24, 24), 0.8))
	particle_preparation.emit_muzzle(preparation_point, Vector3.RIGHT)
	particle_preparation.emit_smoke(preparation_point, 1)
	particle_preparation.step(0.03)
	await preload("res://scripts/preview/woo_geometry_preparation.gd").prepare_footstep_slots(get_tree(), world)
	preparation_report = await preload("res://scripts/dream/firearm_render_preparation.gd").run(get_tree(), world)
	preparation_report["blood_draw"] = await preload("res://scripts/preview/woo_blood_preparation.gd").run(get_tree(), world)
	preparation_report["resident_geometry"] = await preload("res://scripts/preview/woo_geometry_preparation.gd").run(get_tree(), world)
	smoke_preparation.queue_free()
	particle_preparation.queue_free()
	for index in 2: await get_tree().process_frame
	RenderingServer.frame_pre_draw.disconnect(visibility_surfaces.update_now)
	visibility_surfaces.prune_unused()
	visibility_surfaces.preparing = false
	visibility_surfaces.set_enabled(vision_enabled)
	if reflections != null:
		reflections.process_mode = reflection_process_mode
		reflections.update_hz = reflection_hz
	world.process_mode = old_process
	for index in 2: await get_tree().physics_frame
	preparation_report["player_position_preserved"] = world.player.global_position.is_equal_approx(position_before)
	preparation_report["ammo_preserved"] = world.player.ammo_states == ammo_before
	preparation_report["weapon_preserved"] = world.player.selected_weapon_id == weapon_before

func _install_visibility() -> void:
	visibility_field = SHADOW_VISIBILITY_FIELD.new() if use_volume_visibility else VISIBILITY_FIELD.new()
	add_child(visibility_field)
	# Woo Woo's 320 is in its own map units. Cover our Camera's whole field;
	# walls/door leaves, rather than an arbitrary small circle, delimit sight.
	visibility_field.range_pixels = 1024.0
	visibility_field.configure(world)
	actor_visibility = ACTOR_VISIBILITY.new()
	actor_visibility.name = "WooActorVisibility"
	add_child(actor_visibility)
	actor_visibility.include_furniture = true
	actor_visibility.prop_sample_offsets = PackedVector2Array([Vector2(-16,0), Vector2(16,0), Vector2(0,-16), Vector2(0,16)])
	actor_visibility.configure(world, visibility_field)
	visibility_surfaces = SHADOW_VISIBILITY_SURFACES.new() if use_volume_visibility else VISIBILITY_SURFACES.new()
	visibility_surfaces.name = "WooWorldVisibility"
	add_child(visibility_surfaces)
	visibility_surfaces.configure(world, visibility_field)
	primitive_visibility = PRIMITIVE_VISIBILITY.new()
	primitive_visibility.name = "WooPrimitiveVisibility"
	add_child(primitive_visibility)
	primitive_visibility.configure(world, visibility_field)

func set_vision_enabled(value: bool) -> void:
	vision_enabled = value
	if is_instance_valid(visibility_field): visibility_field.set_enabled(value)
	_update_sample_caption()
	if is_instance_valid(visibility_surfaces): visibility_surfaces.set_enabled(value)
	if is_instance_valid(primitive_visibility): primitive_visibility.set_enabled(value)
	if is_instance_valid(world):
		# Existing enemy reveal holes would defeat player LOS. Preserve the
		# original room cutaway, but disable those circular holes in this mode.
		world.set_lab_cutout(false if value else checks.cutout.button_pressed)
	if not value and actor_visibility != null: actor_visibility.restore()
	if not value and is_instance_valid(world): world._update_native_damage_number_projections()
	if value:
		if actor_visibility != null and not actor_visibility.enabled:
			actor_visibility.configure(world, visibility_field)
		update_visibility()

func update_visibility() -> void:
	if visibility_field == null or not is_instance_valid(world): return
	if not vision_enabled:
		if environment_halftone != null and style_index == CHARACTER_INK_STYLE: visibility_surfaces.update_now()
		return
	visibility_field.update_now()
	actor_visibility.update_now()
	visibility_surfaces.update_now()
	primitive_visibility.update_now()
	# Floating damage text belongs to the existing HUD projection. Do not let
	# that presentation reveal an enemy through an otherwise hidden wall.
	for record in world.native_damage_number_anchors:
		var holder: Node2D = record.get("holder")
		if is_instance_valid(holder) and not visibility_field.is_point_visible(record.world_position):
			holder.visible = false

func _release_visibility() -> void:
	if is_instance_valid(primitive_visibility):
		primitive_visibility.restore()
		primitive_visibility.free()
	primitive_visibility = null
	if is_instance_valid(visibility_surfaces):
		visibility_surfaces.restore()
		visibility_surfaces.free()
	visibility_surfaces = null
	if is_instance_valid(actor_visibility):
		actor_visibility.restore()
		actor_visibility.free()
	actor_visibility = null
	if is_instance_valid(visibility_field): visibility_field.free()
	visibility_field = null

func _install_post() -> void:
	# Palette is below this layer. Its disabled mode still resolves gameplay
	# semantic colors; the new pass also recognizes those exact output colors.
	var layer := CanvasLayer.new()
	layer.name = "PurpleSamplePost"
	layer.layer = 19
	layer.set_meta(&"world_post_effect", true)
	display.world_viewport.add_child(layer)
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(copy)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	retro_material = ShaderMaterial.new()
	retro_material.shader = load(SAMPLE_POST)
	rect.material = retro_material

func _install_environment_halftone() -> void:
	if RenderingServer.get_current_rendering_method() != &"forward_plus": return
	if environment_halftone == null: environment_halftone = ENVIRONMENT_HALFTONE.new()
	environment_halftone.enabled = false
	var compositor := Compositor.new()
	compositor.compositor_effects = [environment_halftone]
	world.camera_3d.compositor = compositor

func set_scene_halftone(value: bool) -> void:
	scene_halftone_enabled = value
	if environment_halftone != null:
		environment_halftone.enabled = value and style_index == CHARACTER_INK_STYLE
	if sample_ready: _apply_sample_palette()
	_update_sample_caption()

func apply_style(index: int) -> void:
	if not STYLE_NAMES.has(index): return
	# Resolution and palette are explicit comparison controls. Changing an art
	# treatment must not silently replace the requested 640x360 camera output.
	style_index = index
	if not sample_ready: return
	var character_ink_enabled := style_index == CHARACTER_INK_STYLE
	var purple_post_enabled := not character_ink_enabled
	checks.tonal.set_pressed_no_signal(not character_ink_enabled)
	retro_material.set_shader_parameter("enabled", purple_post_enabled)
	retro_material.set_shader_parameter("resolve_blood_only", character_ink_enabled)
	if environment_halftone != null:
		visibility_surfaces.set_ink_environment(character_ink_enabled)
		halftone_carriers.set_enabled(character_ink_enabled)
	_configure_sample_exterior_light()
	set_scene_halftone(scene_halftone_enabled)
	retro_material.set_shader_parameter("sample_strength", 0.88 if style_index == 1 else 1.0)
	retro_material.set_shader_parameter("levels", 12.0 if style_index == 1 else 8.0)
	retro_material.set_shader_parameter("dither_strength", 0.52 if style_index == 1 else 0.72)
	retro_material.set_shader_parameter("exposure", 1.75)
	retro_material.set_shader_parameter("preserve_signals", true)
	retro_material.set_shader_parameter("vignette_strength", 0.11)
	retro_material.set_shader_parameter("palette_variant", 0)
	character_inks.set_enabled(character_ink_enabled)
	for paint in extinguisher_paint:
		paint.set_shader_parameter("sample_ink_enabled", character_ink_enabled)
	var city: Node = world.office_art_root.get_node_or_null(^"ApprovedOfficeArt/SampleNeonCity")
	if city != null:
		for material: ShaderMaterial in city.render_materials:
			material.set_shader_parameter("facade_light_gain", 0.056 if character_ink_enabled else 1.0)
	_apply_sample_display()
	for material in weather_materials:
		material.set_shader_parameter("hk_sample_weathering", 0.0 if not purple_post_enabled else (0.50 if style_index == 1 else 0.70))
	for i: int in style_buttons: style_buttons[i].set_pressed_no_signal(i == style_index)
	if is_instance_valid(visibility_surfaces): visibility_surfaces.notify_geometry_dirty()

func _update_sample_caption() -> void:
	if sample_caption == null: return
	sample_caption.text = "640×360 · 人物约32像素" if checks.pixels.button_pressed else "原生分辨率"
	sample_caption.text += " · 调色板" + ("开" if checks.palette.button_pressed else "关")
	if style_index == CHARACTER_INK_STYLE:
		sample_caption.text = ("场景半调开" if environment_halftone != null and environment_halftone.enabled else "场景半调关") + " · " + sample_caption.text
	sample_caption.text += " · " + ("室内灯对照" if _lamps_enabled else "环境光与窗光")
	sample_caption.text += " · 墙挡视野" + ("开" if vision_enabled else "关")

func set_sample_palette(value: bool) -> void:
	checks.palette.set_pressed_no_signal(value)
	if not sample_ready: return
	_apply_sample_palette()
	_update_sample_caption()

func set_sample_pixels(value: bool) -> void:
	checks.pixels.set_pressed_no_signal(value)
	if sample_ready: _apply_sample_display()

func _apply_sample_display() -> void:
	var pixels: bool = checks.pixels.button_pressed
	display.pixel_size = Vector2i(640, 360)
	display.set_selective_enabled(pixels)
	display.set_visual_enhancement(checks.tonal.button_pressed)
	world.authoritative_camera_fov = camera_zoom_fov if pixels or style_index >= 3 else original_camera_fov
	world._update_camera_and_actor_projection(0.0)
	if is_instance_valid(world.player_depth_bridge): world.player_depth_bridge._process(0.0)
	pixels_button.set_pressed_no_signal(pixels)
	_update_sample_caption()

func _apply_sample_palette() -> void:
	var palette: bool = checks.palette.button_pressed
	var ink_pass := environment_halftone != null and environment_halftone.enabled
	var use_ink_palette := palette and ink_pass
	display.set_palette_enabled(palette and not ink_pass)
	if environment_halftone != null: environment_halftone.palette_enabled = use_ink_palette
	if is_instance_valid(visibility_surfaces): visibility_surfaces.set_ink_palette(use_ink_palette)
	character_inks.set_body_palette(use_ink_palette)
	if is_instance_valid(halftone_carriers): halftone_carriers.set_body_palette(use_ink_palette)
	palette_button.set_pressed_no_signal(palette)

func _calibrate_camera_zoom() -> void:
	# Calibrate once from the existing body's alpha footprint. This changes
	# only the main camera; no extra viewport, actor or compositing layer.
	var saved_process: int = world.process_mode
	world.process_mode = Node.PROCESS_MODE_DISABLED
	display.pixel_size = Vector2i(640, 360)
	display.set_selective_enabled(true)
	world.authoritative_camera_fov = original_camera_fov
	world._update_camera_and_actor_projection(0.0)
	world.player_depth_bridge._process(0.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var original_height := measure_player_body_pixels()
	# Preserve the whole authored silhouette: an idle/step frame can include
	# a 33rd row below its 32px art cell. Do not squeeze that row away.
	var body_image: Image = world.player_depth_bridge.actor_sprite.texture.get_image()
	var calibration_height := maxf(target_body_height, float(body_image.get_used_rect().size.y))
	camera_zoom_fov = original_camera_fov
	if original_height > 1.0:
		camera_zoom_fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(original_camera_fov) * 0.5) * original_height / calibration_height))
		camera_zoom_fov = clampf(camera_zoom_fov, 10.0, 70.0)
	world.authoritative_camera_fov = camera_zoom_fov
	world._update_camera_and_actor_projection(0.0)
	world.player_depth_bridge._process(0.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	calibrated_body_height = measure_player_body_pixels()
	world.process_mode = saved_process

func measure_player_body_pixels() -> float:
	if not is_instance_valid(world) or not is_instance_valid(world.player_depth_bridge): return 0.0
	var sprite: Sprite3D = world.player_depth_bridge.actor_sprite
	if sprite == null or sprite.texture == null: return 0.0
	var picture: Image = sprite.texture.get_image()
	if picture == null or picture.is_empty(): return 0.0
	var bounds := picture.get_used_rect()
	if not bounds.has_area(): return 0.0
	var top := INF
	var bottom := -INF
	var size := Vector2(picture.get_size())
	for point in [Vector2(bounds.position), Vector2(bounds.end.x, bounds.position.y), Vector2(bounds.end), Vector2(bounds.position.x, bounds.end.y)]:
		var local: Vector2 = point - size * 0.5 + Vector2(sprite.offset.x, -sprite.offset.y)
		var position_3d: Vector3 = sprite.to_global(Vector3(local.x, -local.y, 0.0) * sprite.pixel_size)
		var projected: Vector2 = world.camera_3d.unproject_position(position_3d)
		top = minf(top, projected.y)
		bottom = maxf(bottom, projected.y)
	return bottom - top

func _collect_owned_materials() -> void:
	# These components explicitly create world-local variants. Empty resource
	# paths alone are insufficient: raw swatches also use process-wide caches.
	for component in get_tree().get_nodes_in_group("office_dither_lighting"):
		if component.get_parent() != world: continue
		for material in component.materials.values(): _owned_materials[material] = true
		for material in component.furniture_dark_materials.values(): _owned_materials[material] = true
	var reflection: Node = world.get_node_or_null("FloorReflections")
	if reflection != null:
		# The authored floor texture remains unchanged; wear is limited to props
		# and vertical architecture, following the sample review.
		for material in reflection.floor_materials:
			clean_floor_materials.append(material)
		for material in reflection.static_variants.values(): _owned_materials[material] = true
		# The reflection component records the live owner-local door/wall
		# materials whose identity must remain stable for uniform updates.
		for record in reflection.actor_shaders:
			var material: Material = record.material.get_ref()
			if material != null: _owned_materials[material] = true
	for material in clean_floor_materials: _owned_materials.erase(material)
	# Explicitly exclude the project's process-wide authored caches too.
	var swatches = preload("res://scripts/dream/office_pixel_materials.gd")
	for material in swatches.materials.values(): _owned_materials.erase(material)
	for material in swatches.sample_furniture_materials.values(): _owned_materials.erase(material)
	var atlas_art = preload("res://scripts/dream/office_low_pixel_art.gd")
	_owned_materials.erase(atlas_art._material)
	for material in atlas_art._surfaces.values(): _owned_materials.erase(material)

func _replace_shader_preserving_parameters(material: ShaderMaterial, shader: Shader) -> void:
	var saved: Dictionary = {}
	for uniform in material.shader.get_shader_uniform_list():
		var value: Variant = material.get_shader_parameter(uniform.name)
		if value != null: saved[uniform.name] = value
	material.shader = shader
	for uniform in shader.get_shader_uniform_list():
		if saved.has(uniform.name): material.set_shader_parameter(uniform.name, saved[uniform.name])

func _weather_variant(source: Material) -> Material:
	if source == null or not source is ShaderMaterial or source.shader == null: return source
	if source.shader.code.contains("hk_sample_weathering"): return source
	if _weather_cache.has(source): return _weather_cache[source]
	if not source.resource_path.is_empty() or not _owned_materials.has(source): return source
	var code: String = source.shader.code
	# Keep actors, effects, glass, outlines and unlit signal surfaces untouched.
	if not code.contains("shader_type spatial") or not code.contains("ALBEDO") or code.contains("unshaded") or code.contains("glass_pixels") or code.contains("floor_reflection_surface.gdshaderinc"):
		return source
	if not (code.contains("office_dither") or code.contains("architecture_cutaway.gdshaderinc")):
		return source
	if not _weather_shaders.has(source.shader):
		var preamble := "\n#include \"" + WEATHER_INCLUDE + "\"\nuniform float hk_sample_weathering = 0.0;\nvarying vec3 hk_sample_world;\n"
		code = code.replace("shader_type spatial;", "shader_type spatial;" + preamble)
		var vertex := "hk_sample_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;"
		var vertex_start := code.find("void vertex()")
		if vertex_start >= 0:
			code = code.insert(code.find("{", vertex_start) + 1, "\n" + vertex + "\n")
		else:
			code += "\nvoid vertex() { " + vertex + " }\n"
		var start := code.find("void fragment()")
		if start < 0: return source
		var open := code.find("{", start)
		var end := open + 1
		var depth := 1
		while depth > 0 and end < code.length():
			if code[end] == "{": depth += 1
			elif code[end] == "}": depth -= 1
			end += 1
		code = code.insert(end - 1, "\nALBEDO = hk_weathered_albedo(ALBEDO, hk_sample_world, hk_sample_weathering);\n")
		var shader := Shader.new()
		shader.code = code
		_weather_shaders[source.shader] = shader
	# Preserve material identity: room cutaways, doors and floor reflections
	# retain references to it and keep writing their live uniforms as before.
	var installed_shader: Shader = _weather_shaders[source.shader]
	_weather_pairs.append({"material": source, "original_shader": source.shader, "installed_shader": installed_shader})
	_replace_shader_preserving_parameters(source, installed_shader)
	source.set_shader_parameter("hk_sample_weathering", 0.0 if style_index == CHARACTER_INK_STYLE else (0.50 if style_index == 1 else 0.70))
	_weather_cache[source] = source
	weather_materials.append(source)
	return source

func _restore_weather_materials() -> void:
	for pair in _weather_pairs:
		if pair.material.shader == pair.installed_shader:
			_replace_shader_preserving_parameters(pair.material, pair.original_shader)
	_weather_pairs.clear()

func _scan_weather_surfaces() -> void:
	if not is_instance_valid(world): return
	var count := 0
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		if mesh.material_override != null:
			mesh.material_override = _weather_variant(mesh.material_override)
			if mesh.material_override is ShaderMaterial and mesh.material_override.shader.code.contains("hk_sample_weathering"): count += 1
		elif mesh.mesh != null:
			for i in mesh.mesh.get_surface_count():
				var material: Material = _weather_variant(mesh.get_active_material(i))
				if material != mesh.get_active_material(i): mesh.set_surface_override_material(i, material)
				if material is ShaderMaterial and material.shader.code.contains("hk_sample_weathering"): count += 1
	weather_binding_count = count

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(_native_monitor):
		# F3 input remains active: the complete native monitor wakes on demand.
		var needed: bool = _native_monitor.current_mode != 0 or _native_monitor.is_recording() or _native_monitor.is_report_open
		if _native_monitor.is_processing() != needed:
			if needed:
				_native_monitor.prev_frame_usec = Time.get_ticks_usec()
				_native_monitor._physics_steps = 0
				_native_monitor._physics_accum_ms = 0.0
			_native_monitor.set_process(needed)

func _configure_sample_exterior_light() -> void:
	if is_instance_valid(world.sparse_lighting):
		world.sparse_lighting.set_window_spot_passthrough(style_index == CHARACTER_INK_STYLE)
	var sun: DirectionalLight3D = world.shadow_manager.sun
	if not is_instance_valid(sun): return
	# Both outdoor directions are fixed across rooms. The same roof and pane
	# blockers clip the direct light and the opposite facade's city bounce.
	sun.global_basis = Basis.looking_at(SAMPLE_EXTERIOR_RAY.normalized(), Vector3.UP)
	sun.light_energy = 0.52
	sun.light_angular_distance = 1.5
	if not is_instance_valid(_sample_city_bounce):
		_sample_city_bounce = sun.duplicate(0) as DirectionalLight3D
		# The sparse-lighting owner keeps outdoor NightLighting sources live.
		_sample_city_bounce.name = "NightLightingCityBounce"
		_sample_city_bounce.top_level = true
		sun.add_child(_sample_city_bounce)
	_sample_city_bounce.global_basis = Basis.looking_at(SAMPLE_CITY_BOUNCE_RAY.normalized(), Vector3.UP)
	_sample_city_bounce.light_energy = 0.43
	_sample_city_bounce.light_angular_distance = 2.4
	# The lab mutes its indoor key. Let both exterior lights see the native
	# player body caster on the separate layer normally owned by that key.
	world.shadow_manager._set_player_caster(sun, true)
	world.shadow_manager._set_player_caster(_sample_city_bounce, true)
	if environment_halftone != null:
		environment_halftone.configure_window_falloff(world, [sun, _sample_city_bounce])
		environment_halftone.window_falloff_enabled = not _lamps_enabled
	_sample_window_room = -2
	_update_sample_window_spread()

func _update_sample_window_spread() -> void:
	var room_id: int = world.current_room_id
	if _sample_window_room == room_id: return
	_sample_window_room = room_id
	for spot in _sample_window_spots:
		if is_instance_valid(spot): spot.hide()
	_sample_window_spots.clear()
	if style_index != CHARACTER_INK_STYLE or room_id < 0: return
	var center: Vector3 = world.get_gameplay_world_position(world._room_bounds_pixels(room_id, 0.0).get_center())
	var candidates: Array[Dictionary] = []
	for source in world.shadow_manager.window_sources:
		if is_instance_valid(source.light): candidates.append(source)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (a.room == room_id) != (b.room == room_id): return a.room == room_id
		return a.light.get_parent().global_position.distance_squared_to(center) < b.light.get_parent().global_position.distance_squared_to(center))
	for i in mini(SAMPLE_WINDOW_SPREAD_LIMIT, candidates.size()):
		var spot: SpotLight3D = candidates[i].light
		var wall := spot.get_parent_node_3d()
		var normal: Vector2 = wall.window_inward_normal
		var inward: Vector3 = (world.wall_root.global_basis * Vector3(normal.x, 0.0, normal.y)).normalized()
		var ray := SAMPLE_EXTERIOR_RAY if inward.dot(SAMPLE_EXTERIOR_RAY) > 0.0 else SAMPLE_CITY_BOUNCE_RAY
		var sideways := Vector3(ray.x, 0.0, ray.z).slide(inward)
		# The sky fill starts behind the window so its cone is clipped by the same
		# aperture, frames and furniture as the direct outdoor light.
		spot.global_position = wall.global_position - inward * 0.38 + Vector3.UP * wall.wall_height * 0.73
		spot.look_at(wall.global_position + inward * 3.2 + sideways + Vector3.UP * 0.10)
		spot.spot_range = 8.5
		spot.spot_angle = 72.0
		spot.spot_angle_attenuation = 1.4
		spot.spot_attenuation = 0.22
		spot.light_energy = 0.38
		spot.light_specular = 0.0
		spot.shadow_enabled = true
		spot.shadow_opacity = 1.0
		spot.shadow_caster_mask = world.shadow_manager.sun.shadow_caster_mask
		_sample_window_spots.append(spot)
		spot.show()

func _sample_pre_draw() -> void:
	if not sample_ready: return
	_update_sample_window_spread()
	update_visibility()
	if _lamps_enabled: return
	for reference in _sample_lights:
		var light: Light3D = reference.get_ref()
		if light != null and light.is_visible_in_tree() and light.light_energy > 0.0 and not _is_exterior_light(light):
			_lamp_frame_restore[light] = light.light_energy
			light.light_energy = 0.0

func _track_sample_light(node: Node) -> void:
	if node is Light3D and is_instance_valid(world) and world.is_ancestor_of(node):
		_sample_lights.append(weakref(node))

func _is_exterior_light(light: Light3D) -> bool:
	return light == world.shadow_manager.sun or light == _sample_city_bounce \
		or (light is SpotLight3D and _sample_window_spots.has(light))

func _sample_post_draw() -> void:
	for light in _lamp_frame_restore:
		if is_instance_valid(light): light.light_energy = _lamp_frame_restore[light]
	_lamp_frame_restore.clear()

func _disconnect_sample_draw_hooks() -> void:
	_sample_post_draw()
	if get_tree().node_added.is_connected(_track_sample_light): get_tree().node_added.disconnect(_track_sample_light)
	if RenderingServer.frame_pre_draw.is_connected(_sample_pre_draw): RenderingServer.frame_pre_draw.disconnect(_sample_pre_draw)
	if RenderingServer.frame_post_draw.is_connected(_sample_post_draw): RenderingServer.frame_post_draw.disconnect(_sample_post_draw)

func cycle_station() -> void:
	if not sample_ready: return
	var index := (station.selected + 1) % station.item_count
	station.select(index)
	teleport(index)

func _set_sample_drone_patrol(active: bool) -> void:
	var drones: Node3D = world.get_node_or_null(^"ExteriorPatrolDrones")
	if drones == null: return
	for drone in drones.get_children():
		drone.set_physics_process(active)

func _view_sample_drone() -> void:
	if recorder.active: return
	var drones: Node3D = world.get_node_or_null(^"ExteriorPatrolDrones")
	if drones == null: return
	var target: Node3D
	for drone: Node3D in drones.get_children():
		if drone._dead: continue
		target = drone
		# Prefer a window facing the gameplay camera.
		if drone.inward_normal.x < 0.0 or drone.inward_normal.y < 0.0: break
	if target == null: return
	station.select(int(target.get_meta(&"dream_room_id")))
	world.player.global_position = target.boundary_2d + target.inward_normal * 40.0
	world.player.velocity = Vector2.ZERO
	world._update_camera_and_actor_projection(0.0)

func toggle_lamps() -> void:
	if not sample_ready: return
	_lamps_enabled = not _lamps_enabled
	if environment_halftone != null: environment_halftone.window_falloff_enabled = not _lamps_enabled
	_update_sample_caption()

func _pointer_allowed() -> bool:
	if automation: return true
	if is_instance_valid(sample_ui) and sample_ui.visible and is_instance_valid(display) and Rect2(10, 9, 620, 60).has_point(display._pointer_window):
		return false
	return super._pointer_allowed()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_ESCAPE:
		_close_sample.call_deferred()
		return
	if not sample_ready: return
	match key:
		KEY_2: apply_style(1)
		KEY_4: apply_style(3)
		KEY_5: apply_style(CHARACTER_INK_STYLE)
		KEY_F1: sample_ui.visible = not sample_ui.visible
		KEY_F2: cycle_station()
		KEY_F9: set_vision_enabled(not vision_enabled)
		KEY_F4: trigger("smoke")
		KEY_F5: toggle_lamps()
		KEY_F6: trigger("blood")
		KEY_F7:
			checks.ai.button_pressed = not checks.ai.button_pressed
			for enemy in world.enemy_root.get_children(): enemy.process_mode = Node.PROCESS_MODE_INHERIT if checks.ai.button_pressed else Node.PROCESS_MODE_DISABLED
			_set_sample_drone_patrol(checks.ai.button_pressed)
		KEY_F8: capture()
		KEY_F10: rebuild()
		KEY_F11: set_scene_halftone(not scene_halftone_enabled)
		KEY_F12: _view_sample_drone()
		KEY_ESCAPE: get_tree().quit()
		_: return
	get_viewport().set_input_as_handled()

func capture() -> void:
	if not sample_ready: return
	var visible_before := sample_ui.visible
	sample_ui.hide()
	await super.capture()
	sample_ui.visible = visible_before

func configuration() -> Dictionary:
	var result := super.configuration()
	result.merge({"sample": "hellkind_purple", "style": style_index, "style_name": STYLE_NAMES[style_index], "weathered_bindings": weather_binding_count, "lamps_enabled": _lamps_enabled, "orange_blood_preserved": true, "camera_fov": world.camera_3d.fov, "camera_zoom_fov": camera_zoom_fov, "calibrated_body_height": calibrated_body_height, "target_body_height": target_body_height, "actor_composite": false})
	result["wall_visibility_enabled"] = vision_enabled
	result["visibility_path"] = "player_omnidirectional_depth_shadow" if use_volume_visibility else "convex_wall_silhouettes"
	result["scene_halftone"] = environment_halftone != null and environment_halftone.enabled
	result["startup_preparation"] = preparation_report
	if visibility_field != null:
		result["visibility_casters"] = visibility_field.caster_count
		result["visibility_shadow_triangles"] = visibility_field.shadow_triangles
	if visibility_surfaces != null:
		result["visibility_materials"] = visibility_surfaces.managed_count
		result["visibility_unsupported"] = visibility_surfaces.unsupported_names
	return result

func _exit_tree() -> void:
	sample_ready = false
	if is_instance_valid(_native_monitor):
		_native_monitor.current_mode = _monitor_mode_before
		_native_monitor._update_display_mode()
		_native_monitor.set_process(_monitor_process_before)
	_disconnect_sample_draw_hooks()
	_release_visibility()
	_restore_weather_materials()
	_weather_cache.clear()
	_weather_shaders.clear()
	weather_materials.clear()
	_owned_materials.clear()
	clean_floor_materials.clear()
	_sample_lights.clear()
	extinguisher_paint.clear()
	super._exit_tree()
