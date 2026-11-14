extends SceneTree
## Embed the approved TV-static excerpt as a loopable, export-safe resource.
func _initialize() -> void:
	var stream := AudioStreamWAV.load_from_file("res://.runtime/screen_wall_static_20261108/screen_wall_static_loop.wav")
	if stream == null or absf(stream.get_length() - 4.0) > 0.001 or stream.mix_rate != 48000 or not stream.stereo:
		push_error("Expected the four-second stereo TV-static excerpt")
		quit(1)
		return
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var error := ResourceSaver.save(stream, "res://sfx/preview/screen_wall_static.res")
	print("TV_STATIC_ENCODE pid=", OS.get_process_id(), " seconds=", stream.get_length(), " error=", error)
	quit(0 if error == OK else 1)
