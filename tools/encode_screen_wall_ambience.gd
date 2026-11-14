extends SceneTree
## Embed the complete Ogg stream as an export-safe resource without an editor scan.
func _initialize() -> void:
	var stream := AudioStreamOggVorbis.load_from_file("res://.runtime/screen_wall_ambience_20261108/screen_wall_ambience.ogg")
	if stream == null or absf(stream.get_length() - 607.988) > 0.01:
		push_error("Expected the complete Quasi Drone recording")
		quit(1)
		return
	stream.loop = true
	stream.loop_offset = 0.0
	var error := ResourceSaver.save(stream, "res://sfx/preview/screen_wall_ambience.res")
	print("MENU_AMBIENCE_ENCODE pid=", OS.get_process_id(), " seconds=", stream.get_length(), " loop=", stream.loop, " error=", error)
	quit(0 if error == OK else 1)
