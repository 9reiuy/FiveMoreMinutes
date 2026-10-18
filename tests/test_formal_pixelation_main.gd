extends Node

const MAIN := preload("res://scenes/app/main.tscn")
const TUTORIAL := preload("res://scenes/dream/Dream3D_TutorialRoom.tscn")
const DUNGEON := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const RECEPTION := preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")
const BEDROOM := preload("res://scenes/bedroom/bedroom.tscn")
const MENU := preload("res://scenes/ui/main_menu.tscn")

class LegacyPaletteScreen extends Node2D:
	var palette_calls := 0
	func set_selective_enabled(_enabled: bool) -> void:
		pass
	func set_palette_enabled(_enabled: bool) -> void:
		palette_calls += 1

var failures: Array[String] = []
var checks := 0
@onready var root: Window = get_tree().root

func _ready() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame

func _capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("capture"):
		return
	await _frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/formal_pixelation_" + label + ".png")

func _run() -> void:
	var initial_scale := root.content_scale_size
	var master := AudioServer.get_bus_index(&"Master")
	if master >= 0: AudioServer.set_bus_mute(master, true)
	var main := MAIN.instantiate()
	root.add_child(main)
	await _frames(4)
	var global_palette := main.palette_overlay.material as ShaderMaterial
	var saved_palette: bool = SettingsManager.get_palette_enabled()
	SettingsManager.values[&"palette_enabled"] = true
	main._apply_palette_enabled(true)
	_check(global_palette.get_shader_parameter(&"palette_enabled") == false and not main.palette_overlay.visible, "Main menu never applies the global Palette overlay")
	var bedroom := BEDROOM.instantiate()
	bedroom.persistent_state = main.persistent_day_state
	main._set_screen(bedroom)
	await _frames(4)
	_check(main.current_screen == bedroom and main._active_pixelation_screen() == null, "Bedroom remains outside the Dream presentation wrapper")
	_check(global_palette.get_shader_parameter(&"palette_enabled") == false and not main.palette_overlay.visible, "Bedroom remains original colour with Palette enabled")
	var tutorial := TUTORIAL.instantiate()
	main._set_screen(tutorial)
	await _frames(12)
	var screen: Node = main.current_screen
	_check(screen.get("world") == tutorial, "Formal tutorial uses the supplied gameplay world")
	_check(not bool(screen.get("preview_mode")), "Formal tutorial does not use preview controls")
	_check(screen.get("selective_enabled") == SettingsManager.get_setting(&"pixelation_enabled", true), "Tutorial reads saved pixelation setting")
	_check(tutorial.get_viewport() == screen.get("world_viewport"), "Tutorial camera and gameplay share the world viewport")
	_check(root.content_scale_size == initial_scale, "Pixelation preserves the original UI canvas scale")
	main._on_palette_setting_changed(&"pixelation_enabled", true)
	await _frames(4)
	_check((screen.get("world_viewport") as SubViewport).size == Vector2i(640, 360), "Pixelated tutorial renders its world at 640 by 360")
	main._apply_palette_enabled(true)
	await _frames(2)
	_check(global_palette.get_shader_parameter(&"palette_enabled") == false, "3D mode leaves the final UI palette off")
	_check((screen.get("palette_material") as ShaderMaterial).get_shader_parameter(&"palette_enabled") == true, "3D world Palette is active")
	main._apply_palette_enabled(false)
	await _capture("tutorial_selective")
	main._on_palette_setting_changed(&"pixelation_enabled", false)
	await _frames(2)
	_check(screen.get("world") == tutorial and screen.get("selective_enabled") == false, "Setting OFF preserves tutorial gameplay")
	_check((screen.get("world_viewport") as SubViewport).render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Native mode keeps the same world viewport")
	_check((screen.get("world_viewport") as SubViewport).size != Vector2i(640, 360) or root.size == Vector2i(640, 360), "Native mode restores display resolution")
	main._apply_palette_enabled(true)
	await _frames(2)
	_check(global_palette.get_shader_parameter(&"palette_enabled") == false, "Native 3D mode also keeps the final UI palette off")
	_check((screen.get("palette_material") as ShaderMaterial).get_shader_parameter(&"palette_enabled") == true, "Native 3D mode applies Palette within the world")
	main._apply_palette_enabled(false)
	await _capture("tutorial_native")
	main._on_palette_setting_changed(&"pixelation_enabled", true)
	await _frames(2)
	_check(screen.get("selective_enabled") == true, "Setting ON restores the 640 by 360 world")
	var dungeon := DUNGEON.instantiate()
	dungeon.generate_on_ready = false
	dungeon.persist_profile = false
	dungeon.spawn_content = false
	main._set_screen(dungeon)
	await _frames(12)
	screen = main.current_screen
	_check(screen.get("world") == dungeon, "Formal dungeon uses the supplied gameplay world")
	_check(dungeon.get_viewport() == screen.get("world_viewport"), "Dungeon camera and gameplay share the world viewport")
	_check(root.content_scale_size == initial_scale, "Switching tutorial to dungeon preserves UI scale")
	if OS.get_cmdline_user_args().has("capture"):
		_check(dungeon.regenerate(42001), "Graphical dungeon capture builds the authored floor")
		main._apply_palette_enabled(false)
		await _capture("dungeon_selective")
		main._apply_palette_enabled(true)
		await _capture("dungeon_selective_palette1")
		main._on_palette_setting_changed(&"pixelation_enabled", false)
		main._apply_palette_enabled(false)
		await _capture("dungeon_native")
		main._apply_palette_enabled(true)
		await _capture("dungeon_native_palette1")
		main._apply_palette_enabled(false)
	for floor_index in 3:
		_check(dungeon.regenerate(42001 + floor_index), "Dungeon floor %d rebuilds while wrapped" % floor_index)
		await _frames(10)
		_check(screen.get("world") == dungeon and dungeon.get_viewport() == screen.get("world_viewport"), "Floor rebuild preserves gameplay and display owners")
	var reception := RECEPTION.instantiate()
	main._set_screen(reception)
	await _frames(6)
	screen = main.current_screen
	_check(screen.get("world") == reception and main._active_pixelation_screen() == screen, "Reception has an explicitly supported Dream world")
	_check((screen.get("palette_material") as ShaderMaterial).get_shader_parameter(&"palette_enabled") == true, "Reception restores the saved world Palette preference")
	main._on_palette_setting_changed(&"pixelation_enabled", false)
	_check(bool(screen.get("palette_enabled")), "Disabling pixelation retains reception world Palette")
	var legacy := LegacyPaletteScreen.new()
	main._set_screen(legacy)
	await _frames(4)
	main._apply_palette_enabled(true)
	_check(main.current_screen == legacy and main._active_pixelation_screen() == null and legacy.palette_calls == 0, "Legacy 2D and method-compatible application screens never receive Dream Palette")
	_check(global_palette.get_shader_parameter(&"palette_enabled") == false and not main.palette_overlay.visible, "Returning from Dream leaves the application overlay disabled")
	main._set_screen(MENU.instantiate())
	await _frames(5)
	_check(SettingsManager.get_palette_enabled(), "Leaving Dream retains the saved Palette preference")
	_check(global_palette.get_shader_parameter(&"palette_enabled") == false and main._active_pixelation_screen() == null, "Returned main menu remains original colour")
	_check(root.content_scale_size == initial_scale, "Leaving the 3D game preserves window scaling")
	SettingsManager.values[&"palette_enabled"] = saved_palette
	main.queue_free()
	await _frames(5)
	print("FORMAL_PIXELATION_MAIN checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
