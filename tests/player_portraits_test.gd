extends SceneTree

const PORTRAITS := preload("res://scripts/ui/dialogue/player_portraits.gd")
const LEGACY := preload("res://scenes/ui/confirmation_dialog.tscn")
const CINEMATIC := preload("res://scenes/ui/dialogue/cinematic_dialogue.tscn")
var output := "res://.runtime/player_portraits_20261117/portrait"
var checks: Array[Dictionary] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="): output = arg.trim_prefix("--artifact-dir=")
	run.call_deferred()


func check(ok: bool, description: String) -> void:
	checks.append({"pass": ok, "description": description})
	print("PASS " if ok else "FAIL ", description)


func source_of(view: Control) -> Texture2D:
	return (view.character_art.texture as AtlasTexture).atlas


func run() -> void:
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1280, 720)
	var normal := PORTRAITS.NORMAL.get_image()
	var body := normal.get_region(Rect2i(150, 800, 780, 500)).get_data()
	var faces: Array[String] = []
	for expression in [&"normal", &"mouth_open", &"eyes_closed", &"cat_eyes", &"disbelief", &"injured"]:
		var texture := PORTRAITS.texture_for(expression)
		var image := texture.get_image()
		check(image.get_size() == Vector2i(1099, 3335) and texture.resource_path.begins_with("res://art/characters/player/portraits/player_"), str(expression) + " loads a complete, consistently aligned new player portrait")
		check(image.get_region(Rect2i(150, 800, 780, 500)).get_data() == body, str(expression) + " preserves the same authored body outside the face")
		faces.append(image.get_region(Rect2i(469, 347, 350, 250)).get_data().hex_encode().sha256_text())
	var unique: Dictionary = {}
	for face in faces: unique[face] = true
	check(unique.size() == 6, "All six facial variants remain distinct after compositing and import")
	check(PORTRAITS.dialogue_texture() == PORTRAITS.dialogue_texture(&"mouth_closed") and PORTRAITS.texture_for(&"missing") == PORTRAITS.NORMAL, "Neutral crops are cached and unknown expressions safely fall back to normal")
	for scene in [LEGACY, CINEMATIC]:
		var view: Control = scene.instantiate()
		root.add_child(view)
		await view.open_data({"lines": [{"text": "对话只按状态切换立绘。", "typewriter_speed": 10.0, "blip": false}]})
		check(source_of(view) == PORTRAITS.NORMAL and (view.character_art.texture as AtlasTexture).region == PORTRAITS.DIALOGUE_REGION, str(view.name) + " starts with the new neutral upper-body portrait")
		var chosen: Texture2D = view.character_art.texture
		view._reveal_next_character()
		check(view.character_art.texture == chosen, str(view.name) + " keeps its selected portrait on the first visible letter")
		for _letter in view.full_prompt_text.length(): view._reveal_next_character()
		check(view.character_art.texture == chosen, str(view.name) + " reveals the whole sentence without cycling portraits")
		view._complete_typewriter()
		check(view.character_art.texture == chosen, str(view.name) + " preserves the selected portrait when speech finishes")
		for expression in [&"mouth_open", &"eyes_closed", &"cat_eyes", &"disbelief", &"injured"]:
			view.close_without_signal()
			await view.open_data({"lines": [{"text": "保留特殊表情。", "expression": expression, "typewriter_speed": 10.0, "blip": false}]})
			chosen = view.character_art.texture
			for _letter in view.full_prompt_text.length(): view._reveal_next_character()
			view._complete_typewriter()
			check(source_of(view) == PORTRAITS.texture_for(expression) and view.character_art.texture == chosen, str(view.name) + " retains " + str(expression) + " throughout speech and completion")
		view.close_without_signal()
		check(source_of(view) == PORTRAITS.NORMAL, str(view.name) + " clears the facial expression after closing")
		view.queue_free()
		await process_frame
	var paired: Control = CINEMATIC.instantiate()
	root.add_child(paired)
	await paired.open_data({"lines": [
		{"speaker": "right", "two_person_dialogue": true, "expression": "cat_eyes", "text": "测试双人表情。", "blip": false, "typewriter_speed": 10.0},
		{"speaker": "left", "two_person_dialogue": true, "expression": "injured", "text": "切换到下一种状态。", "blip": false, "typewriter_speed": 10.0}
	]})
	paired._reveal_next_character()
	check((paired.right_art.texture as AtlasTexture).atlas == PORTRAITS.texture_for(&"cat_eyes") and source_of(paired) == PORTRAITS.NORMAL, "A right-side speaker changes expression without replacing the listening player's neutral face")
	paired._complete_typewriter()
	paired._on_cancelled()
	check(source_of(paired) == PORTRAITS.texture_for(&"injured") and (paired.right_art.texture as AtlasTexture).atlas == PORTRAITS.NORMAL, "The next line can explicitly change the speaking character's expression state")
	paired.close_without_signal()
	paired.queue_free()
	await process_frame
	var failures := checks.filter(func(row: Dictionary): return not row.pass).size()
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"pid": OS.get_process_id(), "audio": AudioServer.get_driver_name(), "checks": checks, "failures": failures}, "\t"))
	print("PLAYER_PORTRAITS checks=", checks.size(), " failures=", failures)
	quit(1 if failures else 0)
