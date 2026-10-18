extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var FXScript = load("res://scripts/ui/dialogue/dream_dialogue_glyph_fall_fx.gd")
	if FXScript == null:
		push_error("Failed to load FX script")
		quit(1)
		return

	var label := Label.new()
	label.text = "Hello World"
	root.add_child(label)
	await process_frame
	await process_frame

	var fx = FXScript.spawn_from_label(root, label, 5)
	if fx == null:
		push_error("spawn_from_label returned null")
		quit(1)
		return

	if fx.get_child_count() == 0:
		push_error("Expected child glyph labels")
		quit(1)
		return

	print("Spawned FX with glyph children: ", fx.get_child_count())

	# Process 0.2 seconds
	fx._process(0.2)
	if fx.elapsed < 0.19:
		push_error("Elapsed time not updated")
		quit(1)
		return

	# Process to 0.4 seconds (should be fading: time > 0.35)
	fx._process(0.2)
	print("Modulate alpha at 0.4s: ", fx.modulate.a)
	if fx.modulate.a >= 1.0 or fx.modulate.a <= 0.0:
		push_error("Modulate alpha not fading correctly: %f" % fx.modulate.a)
		quit(1)
		return

	# Process to 0.5s (should queue_free)
	fx._process(0.1)
	await process_frame

	label.queue_free()
	print("DREAM DIALOGUE GLYPH FALL FX TEST PASSED")
	quit(0)
