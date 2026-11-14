extends Node

const MAIN := preload("res://scenes/app/main.tscn")
const TUTORIAL := preload("res://scenes/dream/Dream3D_TutorialRoom.tscn")
const DUNGEON := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const RECEPTION := preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")
const BEDROOM := preload("res://scenes/bedroom/bedroom.tscn")
const MENU := preload("res://scenes/ui/main_menu.tscn")

class ApplicationScreen extends Node2D:
	var pixel_calls := 0
	func set_selective_enabled(_enabled: bool) -> void:
		pass

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
	_check(not main.has_node("FinalPaletteLayer"), "Application palette overlay is removed")
	var saved_pixels: bool = SettingsManager.get_setting(&"pixelation_enabled",true)
	_check(not main.has_node("FinalPaletteLayer"), "Main menu never applies the global Palette overlay")
	var bedroom := BEDROOM.instantiate()
	bedroom.persistent_state = main.persistent_day_state
	main._set_screen(bedroom)
	await _frames(4)
	_check(main.current_screen == bedroom and main._active_pixelation_screen() == null, "Bedroom remains outside the Dream presentation wrapper")
	_check(not main.has_node("FinalPaletteLayer"), "Bedroom remains original colour with Palette enabled")
	var tutorial := TUTORIAL.instantiate()
	main._set_screen(tutorial)
	await _frames(12)
	var screen: Node = main.current_screen
	_check(screen.get("world") == tutorial, "Formal tutorial uses the supplied gameplay world")
	_check(not bool(screen.get("preview_mode")), "Formal tutorial does not use preview controls")
	_check(screen.get("selective_enabled") == SettingsManager.get_setting(&"pixelation_enabled", true), "Tutorial reads saved pixelation setting")
	_check(tutorial.get_viewport() == screen.get("world_viewport"), "Tutorial camera and gameplay share the world viewport")
	_check(root.content_scale_size == initial_scale, "Pixelation preserves the original UI canvas scale")
	SettingsManager.set_setting(&"pixelation_enabled", true)
	await _frames(4)
	_check((screen.get("world_viewport") as SubViewport).size == Vector2i(640, 360), "Pixelated tutorial renders its world at 640 by 360")
	await _frames(2)
	_check(not main.has_node("FinalPaletteLayer"), "3D mode leaves the final UI palette off")
	_check((screen.get("semantic_material") as ShaderMaterial).shader.resource_path == "res://shaders/world_semantic_decode.gdshader", "World RGB uses only reserved combat-colour resolution")
	await _capture("tutorial_selective")
	SettingsManager.set_setting(&"pixelation_enabled", false)
	await _frames(2)
	_check(screen.get("world") == tutorial and screen.get("selective_enabled") == false, "Setting OFF preserves tutorial gameplay")
	_check((screen.get("world_viewport") as SubViewport).render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Native mode keeps the same world viewport")
	_check((screen.get("world_viewport") as SubViewport).size != Vector2i(640, 360) or root.size == Vector2i(640, 360), "Native mode restores display resolution")
	await _frames(2)
	_check(not main.has_node("FinalPaletteLayer"), "Native 3D mode also keeps the final UI palette off")
	_check((screen.get("semantic_material") as ShaderMaterial).shader.resource_path == "res://shaders/world_semantic_decode.gdshader", "Native resolution preserves the same RGB resolver")
	await _capture("tutorial_native")
	SettingsManager.set_setting(&"pixelation_enabled", true)
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
		await _capture("dungeon_selective")
		SettingsManager.set_setting(&"pixelation_enabled", false)
		await _capture("dungeon_native")
	for floor_index in 3:
		_check(dungeon.regenerate(42001 + floor_index), "Dungeon floor %d rebuilds while wrapped" % floor_index)
		await _frames(10)
		_check(screen.get("world") == dungeon and dungeon.get_viewport() == screen.get("world_viewport"), "Floor rebuild preserves gameplay and display owners")
	var reception := RECEPTION.instantiate()
	main._set_screen(reception)
	await _frames(6)
	screen = main.current_screen
	_check(screen.get("world") == reception and main._active_pixelation_screen() == screen, "Reception has an explicitly supported Dream world")
	_check((screen.get("semantic_material") as ShaderMaterial).shader.resource_path == "res://shaders/world_semantic_decode.gdshader", "Reception uses the common RGB resolver")
	SettingsManager.set_setting(&"pixelation_enabled", false)
	_check(not screen.has_method("set_palette_enabled"), "Disabling pixelation cannot introduce a colour filter")
	var legacy := ApplicationScreen.new()
	main._set_screen(legacy)
	await _frames(4)
	_check(main.current_screen == legacy and main._active_pixelation_screen() == null and legacy.pixel_calls == 0, "Legacy 2D and method-compatible application screens never receive Dream Palette")
	_check(not main.has_node("FinalPaletteLayer"), "Returning from Dream leaves the application overlay disabled")
	main._set_screen(MENU.instantiate())
	await _frames(5)
	_check(not SettingsManager.has_method("get_palette_enabled"), "Leaving Dream cannot restore a retired colour filter")
	_check(not main.has_node("FinalPaletteLayer") and main._active_pixelation_screen() == null, "Returned main menu remains original colour")
	_check(root.content_scale_size == initial_scale, "Leaving the 3D game preserves window scaling")
	SettingsManager.set_setting(&"pixelation_enabled",saved_pixels)
	main.queue_free()
	await _frames(5)
	print("FORMAL_PIXELATION_MAIN checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
