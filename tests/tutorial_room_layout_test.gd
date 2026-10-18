extends SceneTree

const TUTORIAL_SCENE: PackedScene = preload("res://scenes/dream/Dream3D_TutorialRoom.tscn")
const CELL_PIXELS := 32.0
const EXPECTED_MIN_TRAVEL_PIXELS := 1296.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("TUTORIAL LAYOUT TEST: %s" % message)


func _run() -> void:
	var tutorial := TUTORIAL_SCENE.instantiate()
	root.add_child(tutorial)
	await process_frame
	await physics_frame
	await process_frame

	var max_x := -1
	var max_y := -1
	for cell_variant in tutorial.floor_cells.keys():
		var cell := Vector2i(cell_variant)
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)
	_check(max_x == 21, "tutorial width must stay 22 cells")
	_check(max_y >= 47, "tutorial length must be at least 48 cells")
	_check(tutorial.floor_cells.size() == 22 * 48, "floor cell count must match the authored 22x48 room")
	_check(tutorial.floor_root.get_child_count() <= 36, "floor must remain MultiMesh-batched")
	_check(tutorial.wall_root.get_child_count() == 138, "wall perimeter must match a 22x48 room with a two-cell door opening")
	_check(tutorial.door_root.get_child_count() == 1, "tutorial must contain one exit door")

	var door := tutorial.door_root.get_child(0) as Node3D
	var spawn: Vector2 = tutorial.player.global_position
	var door_ground := Vector2(door.global_position.x, door.global_position.z) * CELL_PIXELS
	var travel_pixels := spawn.distance_to(door_ground)
	_check(travel_pixels >= EXPECTED_MIN_TRAVEL_PIXELS, "Spawn -> Door distance must be >= 1296px, got %.1f" % travel_pixels)
	_check(is_equal_approx(float(door.global_position.z), -0.5), "exit door must stay on the north wall")
	_check(tutorial.guide_spawn_trigger.position.y > tutorial.guide.global_position.y, "Guide trigger must be before Guide")
	_check(tutorial.guide.global_position.y > tutorial.exit_trigger.position.y, "Guide must be before Exit trigger")
	_check(tutorial.exit_trigger.position.y > door_ground.y, "Exit trigger must be inside the room before the Door")

	var floor_prompt := tutorial.get_node("TutorialGeometry/TutorialFloorPrompt") as Label3D
	_check(floor_prompt.position.z > tutorial.guide_spawn_trigger.position.y / CELL_PIXELS, "WASD prompt must appear before Guide trigger")

	var lights := tutorial.tutorial_ceiling_lights as Node3D
	_check(lights != null, "TutorialCeilingLightRoot must exist")
	if lights != null:
		_check(lights.get_child_count() == 2, "tutorial must contain exactly two ceiling lights")
		var z_positions: Array[float] = []
		for holder in lights.get_children():
			z_positions.append(float(holder.position.z))
			var spot := holder.get_node_or_null("RoomLight") as SpotLight3D
			_check(spot != null, "ceiling holder must contain a SpotLight3D")
			if spot != null:
				_check(spot.shadow_enabled, "tutorial ceiling SpotLight3D must cast shadows")
				_check(is_equal_approx(spot.light_energy, lights.light_energy), "tutorial light must reuse formal energy")
			_check(is_equal_approx(float(holder.position.x), 10.5), "ceiling light must be centered on room X")
		z_positions.sort()
		if z_positions.size() == 2:
			var axis_start := float(tutorial.player.global_position.y / CELL_PIXELS)
			var axis_end := float(door.global_position.z)
			var axis_length := axis_start - axis_end
			_check(absf(z_positions[0] - lerpf(axis_start, axis_end, 2.0 / 3.0)) <= 1.0, "Light 2 must be near two-thirds of travel axis")
			_check(absf(z_positions[1] - lerpf(axis_start, axis_end, 1.0 / 3.0)) <= 1.0, "Light 1 must be near one-third of travel axis")
			_check(axis_length > 40.5, "authored travel axis must exceed 40.5 world units")

	var dialogue: BedroomConfirmationDialog = tutorial.dialogue_dialog
	_check(dialogue.prompt_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "dialogue must enable smart wrapping")
	_check(dialogue.prompt_label.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "dialogue text must fill only the finite content width")
	var long_cjk := "教程文字需要在固定聊天框内自动换行，不能因为文本很长就越过左右边界或从底部溢出。".repeat(8)
	var cjk_pages: Array = dialogue.call("_prepare_dialogue_lines", [{"text": long_cjk, "typewriter_speed": 0.0}])
	_check(cjk_pages.size() > 1, "long CJK dialogue must paginate")
	_check(_pages_fit(dialogue, cjk_pages), "long CJK pages must fit the dialogue box")
	var english_pages: Array = dialogue.call("_prepare_dialogue_lines", [{"text": "This is a deliberately long English tutorial sentence that must wrap inside the fixed dialogue panel without horizontal overflow. ".repeat(8), "typewriter_speed": 0.0}])
	_check(english_pages.size() > 1, "long English dialogue must paginate")
	_check(_pages_fit(dialogue, english_pages), "long English pages must fit the dialogue box")
	var mixed_pages: Array = dialogue.call("_prepare_dialogue_lines", [{"text": "按下 WASD 移动，靠近角色以后按 E 与他交谈。 This mixed tutorial sentence is intentionally long. ".repeat(6), "typewriter_speed": 0.0}])
	_check(mixed_pages.size() > 1, "mixed CJK/English dialogue must paginate")
	_check(_pages_fit(dialogue, mixed_pages), "mixed CJK/English pages must fit the dialogue box")

	tutorial.queue_free()
	await process_frame
	if failures.is_empty():
		print("TUTORIAL_ROOM_LAYOUT_TEST: PASS")
		quit(0)
	else:
		print("TUTORIAL_ROOM_LAYOUT_TEST: FAIL (%d)" % failures.size())
		quit(1)


func _pages_fit(dialogue: Control, pages: Array) -> bool:
	var font_size := 18
	for page_variant in pages:
		var page: Dictionary = page_variant if page_variant is Dictionary else {}
		var text := str(page.get("text", ""))
		var count := int(dialogue.call("_wrapped_line_count", text, font_size))
		var capacity := int(dialogue.call("_dialogue_page_line_capacity", font_size, 0))
		if count > capacity:
			return false
	return true
