extends Control
## Independent GameTestLab presentation; no campaign dialogue is replaced.
const DIALOGUE := preload("res://scenes/ui/dialogue/cinematic_dialogue.tscn")
const PRESENTER := preload("res://scripts/ui/dialogue/cinematic_dialogue.gd")
const DISPLAY := preload("res://scenes/dream/preview/SelectivePixelPreview.tscn")
@export var auto_start := true
var world: Node3D
var display: Control
var dialogue: PRESENTER
var ready_world := false
var busy := false
var preview_mode := 0
var generation := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings := get_node("/root/SettingsManager")
	settings.suppress_music(self)
	preload("res://scripts/audio/sfx_manager.gd").stop_music(0.0)
	var hud := CanvasLayer.new()
	hud.layer = 246
	add_child(hud)
	dialogue = DIALOGUE.instantiate()
	hud.add_child(dialogue)
	get_window().title = "对话 UI · 点击 / E / Enter 下一句 · F5 重播 · 1 仓库 / 2 白盒 / 3 正式美术"
	if auto_start: rebuild.call_deferred(0)


func rebuild(mode: int = 0) -> void:
	if busy: return
	busy = true
	ready_world = false
	generation += 1
	preview_mode = mode
	dialogue.close_without_signal()
	if is_instance_valid(display):
		display.free()
		world = null
		await get_tree().process_frame
	world = load("res://scenes/testing/LinkedMaintenanceGarage.tscn" if mode == 0 else "res://scenes/testing/LabWorld.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	if mode != 0:
		world.lab_whitebox = mode == 1
		world.lab_enemy_count = 8
		world.lab_ai = false
		world.lab_special_units = false
		world.lab_furniture = true
		world.approved_sample_art_enabled = mode == 2
	var pause_bridge := world.get_node_or_null("Dream3DPauseBridge")
	if pause_bridge != null: pause_bridge.free()
	display = DISPLAY.instantiate()
	display.world = world
	display.preview_mode = false
	add_child(display)
	move_child(display, 0)
	await get_tree().process_frame
	if not world.regenerate(71432):
		push_error("Dialogue preview world failed to generate")
		busy = false
		return
	world.run_interface.auto_open_upgrades = false
	world.run_interface.hud.hide()
	world.ui_layer.hide()
	if mode == 0:
		world._finish_opening_time()
		world._arrive_in_storage()
		world.player.global_position = (Vector2(world.STORAGE_OFFSET) + Vector2(14.0, 3.5)) * world.CELL_PIXELS
		world.set_current_room_id(world.STORAGE_ROOM_ID)
	else:
		world._spawn_room_furniture()
		world.populate_lab()
		world.player.global_position = Vector2(7.0, 7.0) * world.CELL_PIXELS
		world.set_current_room_id(1)
	world.player.movement_enabled = false
	world.player.set_attacking_enabled(false)
	world.player.set_dash_enabled(false)
	world.player.velocity = Vector2.ZERO
	world._update_camera_and_actor_projection()
	await get_tree().process_frame
	busy = false
	ready_world = true
	if auto_start: play_sample()


func play_sample() -> void:
	if not ready_world or busy: return
	dialogue.close_without_signal()
	dialogue.open_data({"id": "cinematic_style_preview", "lines": [
		{"speaker": "left", "speaker_side": "left", "text": "先在这里停一下。\n等我确认前面的通道。", "blip": false},
		{"speaker": "right", "speaker_side": "right", "text": "好，我在这里等你。", "blip": false},
		{"speaker": "left", "speaker_side": "left", "text": "确认好了，我们走吧。", "blip": false,
			"choices": [{"text": "现在出发"}, {"text": "先看看四周"}, {"text": "再等一下"}]}
	]})


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or busy: return
	match event.physical_keycode:
		KEY_F5: play_sample()
		KEY_1: rebuild(0)
		KEY_2: rebuild(1)
		KEY_3: rebuild(2)
		_: return
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null: settings.release_music(self)
