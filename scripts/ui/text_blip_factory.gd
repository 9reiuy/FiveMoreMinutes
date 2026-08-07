class_name TextBlipFactory
extends RefCounted


static func create(config: DemoConfig) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 11025
	stream.stereo = false
	var sample_count := int(stream.mix_rate * 0.035)
	var bytes := PackedByteArray()
	bytes.resize(sample_count)
	for index in sample_count:
		var t := float(index) / float(stream.mix_rate)
		var square := 1.0 if sin(TAU * config.opening_text_sound_frequency_hz * t) >= 0.0 else -1.0
		var envelope := 1.0 - float(index) / float(sample_count)
		bytes[index] = clampi(int(128.0 + square * 34.0 * envelope), 0, 255)
	stream.data = bytes
	return stream
