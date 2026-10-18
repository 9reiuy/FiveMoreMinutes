extends Node

const MAIN_SCENE := preload("res://scenes/app/main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	# Bypass menu/tutorial input while still using Main's real Dream entry path.
	var state: Dictionary = main.get("persistent_day_state")
	state["calendar_day_id"] = 1
	state["tutorial_completed"] = true
	main.set("persistent_day_state", state)
	seed(1337)
	var entry_started_usec := Time.get_ticks_usec()
	main.call("_show_dream", "basic")
	var dream: Node = null
	for _frame in range(600):
		await get_tree().process_frame
		var candidate: Variant = main.get("current_screen")
		if candidate is Node and String(candidate.name) == "Dream3D_BuildingLayout":
			dream = candidate
			if int(dream.get("current_room_id")) >= 0:
				break
	var entry_elapsed_ms := float(Time.get_ticks_usec() - entry_started_usec) / 1000.0
	print("[StartupPerfRunner] normal_entry_ms=%.3f dream_ready=%s" % [entry_elapsed_ms, dream != null])
	get_tree().quit(0)
