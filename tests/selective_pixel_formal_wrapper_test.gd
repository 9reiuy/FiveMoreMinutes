extends SceneTree
## Verify that the formal wrapper accepts a preconfigured world without
## rebuilding gameplay or enabling the standalone preview controls.

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	var saved_settings: Dictionary = settings.values.duplicate(true)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	var original_scale := root.content_scale_size
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	var wrapper_script: Script = load("res://scripts/dream/preview/selective_pixel_preview.gd")
	for scene_path in ["res://scenes/dream/Dream3D_RandomDungeon.tscn", "res://scenes/dream/Dream3D_TutorialRoom.tscn"]:
		settings.values["pixelation_enabled"] = false
		var external_world: Node3D = (load(scene_path) as PackedScene).instantiate()
		if scene_path.contains("RandomDungeon"):
			external_world.generate_on_ready = false
		var wrapper := Control.new()
		wrapper.set_script(wrapper_script)
		wrapper.preview_mode = false
		wrapper.muted = false
		wrapper.initial_selective_enabled = false
		wrapper.world = external_world
		root.add_child(wrapper)
		await _frames(6)
		var name_label := "random" if scene_path.contains("RandomDungeon") else "tutorial"
		_check(wrapper.world == external_world, "%s uses the supplied world" % name_label)
		_check(external_world.get_viewport() == wrapper.world_viewport, "%s camera belongs to the world viewport" % name_label)
		_check(wrapper.status_label == null, "%s formal display has no preview status" % name_label)
		_check(wrapper.content_rect == Rect2(Vector2.ZERO, Vector2(640, 360)), "%s display fits the unchanged UI canvas" % name_label)
		_check(wrapper.world_viewport.size == Vector2i(1280, 720), "%s native mode uses output resolution" % name_label)
		_check(wrapper.get_stats().viewport_count >= 1, "%s has a world render viewport" % name_label)
		_check(root.content_scale_size == original_scale, "%s leaves window UI scaling intact" % name_label)
		var prompt := external_world.get("interaction_prompt") as Label
		_check(prompt != null, "%s creates a screen-space interaction prompt" % name_label)
		if prompt != null:
			_check(prompt.get_viewport() == root, "%s interaction text bypasses the pixelated world" % name_label)
			_check(prompt.get_theme_font_size(&"font_size") == 12, "%s uses the authored pixel font size" % name_label)
			var prompt_font := prompt.get_theme_font(&"font") as FontFile
			_check(prompt_font != null and prompt_font.antialiasing == TextServer.FONT_ANTIALIASING_NONE, "%s interaction font has no smoothing" % name_label)
		if name_label == "random":
			_check(external_world.player.suppress_local_weapon_name_label, "random hides the duplicate low-resolution weapon label")
		wrapper.set_palette_enabled(true)
		await _frames(2)
		_check(wrapper.palette_material.get_shader_parameter(&"palette_enabled") == true, "%s native Palette stays inside the world" % name_label)
		wrapper.set_selective_enabled(true)
		await _frames(4)
		_check(wrapper.content_rect == Rect2(Vector2.ZERO, Vector2(640, 360)), "%s pixelated display uses the same canvas rectangle" % name_label)
		_check(wrapper.world_viewport.size == Vector2i(640, 360), "%s pixelated world uses 640 by 360" % name_label)
		_check(wrapper.palette_material.get_shader_parameter(&"palette_enabled") == true, "%s Palette remains on the world after toggling" % name_label)
		_check(external_world.get_viewport() == wrapper.world_viewport, "%s toggle does not move gameplay to another viewport" % name_label)
		if name_label == "random":
			var next_world: Node3D = (load(scene_path) as PackedScene).instantiate()
			next_world.generate_on_ready = false
			var next_wrapper := Control.new()
			next_wrapper.set_script(wrapper_script)
			next_wrapper.preview_mode = false
			next_wrapper.muted = false
			next_wrapper.initial_selective_enabled = true
			next_wrapper.world = next_world
			wrapper.queue_free()
			root.add_child(next_wrapper)
			await _frames(5)
			_check(not is_instance_valid(wrapper), "old formal wrapper exits after replacement enters")
			_check(root.content_scale_size == original_scale, "replacement keeps the original window scale")
			next_wrapper.queue_free()
			await _frames(5)
			_check(root.content_scale_size == original_scale, "last formal wrapper leaves window scale unchanged")
		else:
			wrapper.queue_free()
			await _frames(5)
			_check(not is_instance_valid(wrapper), "%s wrapper cleans up" % name_label)
			_check(root.content_scale_size == original_scale, "%s leaves original window scale unchanged" % name_label)
	print("SELECTIVE_PIXEL_FORMAL_WRAPPER checks=", checks, " failures=", failures.size())
	settings.values = saved_settings
	quit(0 if failures.is_empty() else 1)
