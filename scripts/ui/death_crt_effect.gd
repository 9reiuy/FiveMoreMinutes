class_name DeathCrtEffect
extends CanvasLayer

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const PRIMARY_FONT_FILE: FontFile = preload("res://assets/fonts/boutique_bitmap/BoutiqueBitmap9x9_Bold_1.9.ttf")
const FALLBACK_FONT_FILE: FontFile = preload("res://assets/fonts/fusion_pixel/fusion-pixel-12px-proportional-zh_hans.ttf")

signal finished

const BIOS_LINES := [
	{
		"text": "[fw_0.82b] Emergency Reboot : 宿主生命体征归零",
		"y": 18.0,
		"start": 0.43,
		"end": 0.79,
		"size": 12,
		"color": Color(0.84, 0.88, 0.96, 0.96),
	},
	{
		"text": "04A MITARBEITER-BETRIEBSSYSTEM (VLNK_BIOS v0.94_BETA)",
		"y": 42.0,
		"start": 0.34,
		"end": 0.50,
		"size": 11,
		"color": Color(0.76, 0.81, 0.91, 0.94),
	},
	{
		"text": "Batch: VORSORGEUNTERSUCHUNG_Q3 [项目: 员工年度福利体检-颈椎造影]",
		"y": 57.0,
		"start": 0.36,
		"end": 0.54,
		"size": 11,
		"color": Color(0.76, 0.81, 0.91, 0.94),
	},
	{
		"text": " Sachbearbeiter / 行政职员-Lv.2 / 6643-5114-ASSET",
		"y": 72.0,
		"start": 0.38,
		"end": 0.56,
		"size": 11,
		"color": Color(0.76, 0.81, 0.91, 0.94),
	},
	{
		"text": "gi-9 j Starte V* Proxy-System.. [正在唤醒后颈潜伏芯片...]",
		"y": 96.0,
		"start": 0.39,
		"end": 0.58,
		"size": 11,
		"color": Color(0.82, 0.86, 0.95, 0.95),
	},
	{
		"text": ">> 检测到原生脑电波停止 [EGO_FLATLINE]",
		"y": 112.0,
		"start": 0.42,
		"end": 0.61,
		"size": 11,
		"color": Color(0.82, 0.86, 0.95, 0.95),
	},
	{
		"text": ">> 触发《劳动合同补充附件-███》：遗体工时补偿协议",
		"y": 128.0,
		"start": 0.45,
		"end": 0.65,
		"size": 11,
		"color": Color(0.82, 0.86, 0.95, 0.95),
	},
	{
		"text": ">> 正在接管运动神经丛 (MOTORISCHER_KORTEX)... 98%",
		"y": 144.0,
		"start": 0.48,
		"end": 0.69,
		"size": 11,
		"color": Color(0.82, 0.86, 0.95, 0.95),
	},
	{
		"text": ">> 屏蔽死亡痛觉反馈... 锁定声带... 强制起立...",
		"y": 160.0,
		"start": 0.51,
		"end": 0.73,
		"size": 11,
		"color": Color(0.82, 0.86, 0.95, 0.95),
	},
	{
		"text": "工伤不予认定",
		"y": 184.0,
		"start": 0.50,
		"end": 0.68,
		"size": 12,
		"color": Color(0.90, 0.84, 0.88, 0.96),
	},
	{
		"text": "ZWANGSÜBERNAHMEZWANGSÜBERNAHMEZWANGSÜBERNAHME...",
		"y": 200.0,
		"start": 0.44,
		"end": 0.76,
		"size": 11,
		"color": Color(0.78, 0.83, 0.93, 0.95),
	},
]

@onready var overlay: ColorRect = $CrtOverlay
@onready var material: ShaderMaterial = $CrtOverlay.material

var active := false
var effect_progress := 0.0
var effect_duration := 2.2
var terminal_canvas: _BiosTerminalCanvas
var bios_font: FontVariation
var drone_player: AudioStreamPlayer
var _drone_triggered := false


class _BiosTerminalCanvas extends Control:
	var owner_effect: DeathCrtEffect

	func _draw() -> void:
		if owner_effect != null:
			owner_effect._draw_terminal_canvas(self)


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_font()
	_setup_terminal_canvas()
	_setup_drone_audio()
	if is_instance_valid(material):
		material.set_shader_parameter("progress", 0.0)


func _setup_font() -> void:
	bios_font = FontVariation.new()
	bios_font.base_font = PRIMARY_FONT_FILE
	bios_font.fallbacks = [FALLBACK_FONT_FILE]


func _setup_terminal_canvas() -> void:
	terminal_canvas = _BiosTerminalCanvas.new()
	terminal_canvas.name = "BiosTerminalCanvas"
	terminal_canvas.owner_effect = self
	terminal_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	terminal_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(terminal_canvas)


func _setup_drone_audio() -> void:
	drone_player = AudioStreamPlayer.new()
	drone_player.name = "BiosDronePlayer"
	drone_player.bus = &"UI"
	drone_player.volume_db = -9.0
	drone_player.stream = _build_bios_drone_stream(1.65)
	add_child(drone_player)


func play(duration: float = 2.2) -> void:
	if active or not is_inside_tree():
		return
	active = true
	effect_progress = 0.0
	effect_duration = maxf(duration, 0.25)
	_drone_triggered = false
	SFX.play_event(&"crt_off")
	_set_progress(0.0)


func _process(delta: float) -> void:
	if not active:
		return
	var unscaled_delta := delta / maxf(Engine.time_scale, 0.0001)
	effect_progress += unscaled_delta / effect_duration
	if not _drone_triggered and effect_progress >= 0.32:
		_drone_triggered = true
		if is_instance_valid(drone_player) and DisplayServer.get_name() != "headless":
			drone_player.play()
	if effect_progress >= 1.0:
		effect_progress = 1.0
		_set_progress(1.0)
		active = false
		finished.emit()
		# Keep the final black frame on screen so the dying game scene never
		# flashes back in.
	else:
		_set_progress(effect_progress)


func _set_progress(value: float) -> void:
	if is_instance_valid(material):
		material.set_shader_parameter("progress", value)
	if is_instance_valid(terminal_canvas):
		terminal_canvas.queue_redraw()


func _draw_terminal_canvas(canvas: Control) -> void:
	var t := clampf(effect_progress, 0.0, 1.0)
	if t < 0.33 or t >= 0.965 or bios_font == null:
		return

	# Collapse phase (0.80 -> 0.965): text shifts into deep CRT blue, slices horizontally, and fades out
	var collapse_t := clampf((t - 0.80) / 0.165, 0.0, 1.0)
	var global_alpha := 1.0 - smoothstep(0.35, 1.0, collapse_t)
	if global_alpha <= 0.005:
		return

	var base_x := 14.0
	var frame_step := floorf(t * 60.0)

	for i in BIOS_LINES.size():
		var spec: Dictionary = BIOS_LINES[i]
		var start_t := float(spec["start"])
		var end_t := float(spec["end"])
		if t < start_t:
			continue

		var full_text := String(spec["text"])
		var line_progress := clampf((t - start_t) / maxf(end_t - start_t, 0.001), 0.0, 1.0)
		var total_chars := full_text.length()
		var visible_chars := clampi(ceili(float(total_chars) * line_progress), 1, total_chars)
		var sub_text := full_text.substr(0, visible_chars)

		var font_size := int(spec["size"])
		var y_pos := float(spec["y"])

		# Horizontal CRT glitch jitter during initial lock-in and final collapse
		var lock_in := 1.0 - clampf((t - start_t) / 0.10, 0.0, 1.0)
		var hash_val := fposmod(sin(float(i * 19 + 7) * 43.17 + frame_step * 12.9898) * 43758.5453, 1.0)
		var jitter_x := (hash_val - 0.5) * (8.0 * lock_in + 26.0 * collapse_t)
		if collapse_t > 0.25 and fposmod(hash_val * 7.3, 1.0) < collapse_t * 0.55:
			# Random scanline drop-out during final CRT blue collapse
			continue

		var base_color: Color = spec["color"]
		var collapsed_blue := Color(0.14, 0.28, 0.78, base_color.a)
		var draw_color := base_color.lerp(collapsed_blue, clampf(collapse_t * 1.35, 0.0, 1.0))
		draw_color.a *= global_alpha

		# Double-vision ghost shadow (prominent when line first appears and during collapse, like video frames 93..102)
		var ghost_spread := 2.0 + 4.5 * lock_in + 5.0 * collapse_t
		var ghost_color := Color(0.24, 0.42, 0.88, draw_color.a * (0.38 + 0.28 * lock_in))
		canvas.draw_string(
			bios_font,
			Vector2(base_x + jitter_x + ghost_spread, y_pos + 1.0),
			sub_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			ghost_color
		)

		var red_ghost_color := Color(0.85, 0.20, 0.28, draw_color.a * (0.22 + 0.24 * lock_in))
		canvas.draw_string(
			bios_font,
			Vector2(base_x + jitter_x - ghost_spread * 0.65, y_pos),
			sub_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			red_ghost_color
		)

		# Primary crisp BIOS terminal text
		canvas.draw_string(
			bios_font,
			Vector2(base_x + jitter_x, y_pos),
			sub_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			draw_color
		)


func _build_bios_drone_stream(duration_sec: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var sample_count := maxi(1, int(stream.mix_rate * duration_sec))
	var bytes := PackedByteArray()
	bytes.resize(sample_count)
	var phase_sub := 0.0
	var phase_harm := 0.0
	var phase_pulse := 0.0
	for idx in sample_count:
		var p := float(idx) / float(maxi(1, sample_count - 1))
		# Descending ominous BIOS hum from 110Hz down to 66Hz (matching reference audio)
		var freq := lerpf(110.0, 66.0, pow(p, 0.85))
		phase_sub += TAU * freq / float(stream.mix_rate)
		phase_harm += TAU * (freq * 2.0) / float(stream.mix_rate)
		var saw := 2.0 * (phase_sub / TAU - floorf(0.5 + phase_sub / TAU))
		var sq := 1.0 if sin(phase_sub) >= 0.0 else -1.0
		var sub_wave := sin(phase_sub) * 0.55 + saw * 0.28 + sq * 0.17 + sin(phase_harm) * 0.18

		# Rapid data-stream ticks during text readout (0.0 -> 0.68 of drone)
		var tick_signal := 0.0
		if p < 0.68:
			var tick_slot := int(p * 38.0)
			var slot_local := fposmod(p * 38.0, 1.0)
			if slot_local < 0.32 and (tick_slot % 2 == 0 or tick_slot % 3 == 0):
				var tick_freq := 680.0 + float((tick_slot * 137) % 520)
				phase_pulse += TAU * tick_freq / float(stream.mix_rate)
				tick_signal = sin(phase_pulse) * (1.0 - slot_local / 0.32) * 0.22

		var attack := clampf(p / 0.08, 0.0, 1.0)
		var release := clampf((1.0 - p) / 0.16, 0.0, 1.0)
		var swell := lerpf(0.65, 1.0, clampf(p / 0.72, 0.0, 1.0))
		var env := attack * release * swell
		var sample := (sub_wave * 0.82 + tick_signal) * env
		bytes[idx] = clampi(int(128.0 + sample * 44.0), 0, 255)
	stream.data = bytes
	return stream


