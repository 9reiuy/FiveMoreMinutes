extends RefCounted
## Timed Morse, in seconds. A dot is one unit; a dash is three.
const ALPHABET := {"S":"...", "O":"---"}
const UNIT := .24
var pulses: Array[Vector2] = []
var content_duration := 0.
var cycle_duration := 0.
func configure(message: String) -> void:
	pulses.clear()
	var cursor := 0.
	for letter in message.to_upper():
		var symbols: String = ALPHABET.get(letter, "")
		for i in symbols.length():
			var duration := UNIT * (3. if symbols[i]=="-" else 1.)
			pulses.append(Vector2(cursor,cursor+duration))
			cursor += duration + (UNIT if i < symbols.length()-1 else 0.)
		if not symbols.is_empty(): cursor += UNIT*3.
	content_duration = pulses[-1].y if not pulses.is_empty() else 0.
	cycle_duration = content_duration + UNIT*7.
func power_at(seconds: float) -> float:
	if pulses.is_empty() or seconds<0.: return 0.
	var phase := fposmod(seconds,cycle_duration)
	for pulse in pulses:
		if phase>=pulse.x and phase<pulse.y:
			return smoothstep(0.,.025,phase-pulse.x)*(1.-smoothstep(pulse.y-.025,pulse.y,phase))
	return 0.
