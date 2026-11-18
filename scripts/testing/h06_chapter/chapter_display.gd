extends "res://scripts/dream/preview/selective_pixel_preview.gd"

const DISTRICTS := ["H06 机库","西翼检验区","货运追逐","货运作业区","电梯大厅"]
const LOADING := preload("res://scenes/ui/loading_overlay.tscn")
var entry_loading: LoadingOverlay

func _ready() -> void:
	preview_mode = false
	muted = false
	world = preload("res://scenes/testing/H06ChapterWhitebox.tscn").instantiate()
	world.connect(&"district_entered",_show_district)
	var prepare:bool=DisplayServer.get_name()!="headless" and world.get_meta(&"h06_render_warmup",true)
	if prepare:world.process_mode=Node.PROCESS_MODE_DISABLED
	super._ready()
	if prepare:
		entry_loading=LOADING.instantiate()
		add_child(entry_loading)
		entry_loading.show_loading("正在准备第一章场景...")
		# Cover the first rendered frame before moving the loading-only Camera.
		entry_loading.root_control.modulate.a=1.0
		call_deferred("_prepare_entry")

func _prepare_entry() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not is_instance_valid(world) or not is_inside_tree():return
	var receipt:Dictionary=await world.prepare_chapter_streaming(entry_loading.set_progress)
	if not is_instance_valid(world) or not is_inside_tree() or receipt.get("cancelled",false):return
	world.process_mode=Node.PROCESS_MODE_INHERIT
	await entry_loading.hide_loading()
	if is_instance_valid(entry_loading):entry_loading.queue_free()
	entry_loading=null

func _show_district(district: int) -> void:
	get_window().title = "1-%d · %s（F5 从头重来）" % [district+1,DISTRICTS[district]]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_F5 or event.keycode==KEY_F5):
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		get_tree().call_deferred("reload_current_scene")
