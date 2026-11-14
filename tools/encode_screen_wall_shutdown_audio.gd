extends SceneTree
## Save the authored PCM as an export-safe AudioStream resource, without an editor scan.
func _initialize() -> void:
	var bytes := FileAccess.get_file_as_bytes("res://sfx/preview/screen_wall_power_off.wav")
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(36, 40).get_string_from_ascii() != "data":
		quit(1)
		return
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 48000
	stream.stereo = true
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = bytes.slice(44)
	var error := ResourceSaver.save(stream, "res://sfx/preview/screen_wall_power_off.res")
	print("CRT_AUDIO_ENCODE pid=", OS.get_process_id(), " error=", error)
	quit(0 if error == OK else 1)
