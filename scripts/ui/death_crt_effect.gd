class_name DeathCrtEffect
extends CanvasLayer

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const PRIMARY_FONT_FILE: FontFile = preload("res://assets/fonts/boutique_bitmap/BoutiqueBitmap9x9_Bold_1.9.ttf")
const FALLBACK_FONT_FILE: FontFile = preload("res://assets/fonts/fusion_pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const TEXT_GLITCH_SHADER: Shader = preload("res://shaders/bios_text_glitch.gdshader")

signal finished

const BIOS_LINES := [
	{
		"text": "[fw_0.82b] Emergency Reboot : 宿主生命体征归零",
		"x": -54.0,
		"y": 26.0,
		"start": 0.44,
		"end": 0.83,
		"size": 12,
		"scale": Vector2(1.42, 1.58),
		"crop_w": 505.0,
		"crop_mode": "top_overline",
		"mode": "slow_typewriter",
		"color": Color(0.88, 0.91, 0.98, 0.98),
	},
	{
		"text": "04A MITARBEITER-BETRIEBSSYSTEM (VLNK_BIOS v0.94_BETA)",
		"x": -18.0,
		"y": 66.0,
		"start": 0.335,
		"end": 0.375,
		"size": 12,
		"scale": Vector2(1.34, 1.56),
		"crop_w": 438.0,
		"crop_mode": "clean_crop",
		"mode": "burst",
		"color": Color(0.82, 0.86, 0.94, 0.96),
	},
	{
		"text": "Batch: VORSORGEUNTERSUCHUNG_Q3 [项目: 员工年度福利体检-颈椎造影]",
		"x": -36.0,
		"y": 87.0,
		"start": 0.350,
		"end": 0.392,
		"size": 12,
		"scale": Vector2(1.32, 1.54),
		"crop_w": 468.0,
		"crop_mode": "clean_crop",
		"mode": "burst",
		"color": Color(0.80, 0.85, 0.93, 0.95),
	},
	{
		"text": " Sachbearbeiter / 行政职员-Lv.2 / 6643-5114-ASSET",
		"x": -24.0,
		"y": 108.0,
		"start": 0.365,
		"end": 0.408,
		"size": 12,
		"scale": Vector2(1.28, 1.48),
		"crop_w": 392.0,
		"crop_mode": "clean_crop",
		"mode": "burst",
		"color": Color(0.78, 0.83, 0.92, 0.94),
	},
	{
		"text": "gi-9 j Starte V* Proxy-System.. [正在唤醒后颈潜伏芯片...]",
		"x": -8.0,
		"y": 142.0,
		"start": 0.382,
		"end": 0.625,
		"size": 12,
		"scale": Vector2(1.34, 1.56),
		"crop_w": 452.0,
		"crop_mode": "clean_crop",
		"mode": "proxy_wake",
		"color": Color(0.86, 0.90, 0.97, 0.97),
	},
	{
		"text": ">> 检测到原生脑电波停止 [EGO_FLATLINE]",
		"x": -12.0,
		"y": 165.0,
		"start": 0.428,
		"end": 0.472,
		"size": 12,
		"scale": Vector2(1.30, 1.50),
		"crop_w": 384.0,
		"crop_mode": "clean_crop",
		"mode": "snap",
		"color": Color(0.84, 0.88, 0.96, 0.96),
	},
	{
		"text": ">> 触发《劳动合同补充附件-███》：遗体工时补偿协议",
		"x": -20.0,
		"y": 185.0,
		"start": 0.462,
		"end": 0.605,
		"size": 12,
		"scale": Vector2(1.30, 1.50),
		"crop_w": 416.0,
		"crop_mode": "clean_crop",
		"mode": "steady",
		"color": Color(0.82, 0.87, 0.96, 0.96),
	},
	{
		"text": ">> 正在接管运动神经丛 (MOTORISCHER_KORTEX)... 98%",
		"x": -10.0,
		"y": 205.0,
		"start": 0.500,
		"end": 0.685,
		"size": 12,
		"scale": Vector2(1.30, 1.50),
		"crop_w": 428.0,
		"crop_mode": "with_sliver_below",
		"mode": "percent_count",
		"color": Color(0.82, 0.87, 0.96, 0.96),
	},
	{
		"text": ">> 屏蔽死亡痛觉反馈... 锁定声带... 强制起立...",
		"x": -26.0,
		"y": 229.0,
		"start": 0.538,
		"end": 0.745,
		"size": 12,
		"scale": Vector2(1.30, 1.50),
		"crop_w": 388.0,
		"crop_mode": "top_65_crop",
		"mode": "staccato_3",
		"color": Color(0.80, 0.85, 0.94, 0.94),
	},
	{
		"text": "工伤不予认定",
		"x": -3.0,
		"y": 258.0,
		"start": 0.575,
		"end": 0.600,
		"size": 12,
		"scale": Vector2(1.58, 1.92),
		"crop_w": 240.0,
		"crop_mode": "verdict_crop",
		"mode": "stamp",
		"color": Color(0.92, 0.88, 0.94, 0.98),
	},
	{
		"text": "ZWANGSÜBERNAHMEZWANGSÜBERNAHMEZWANGSÜBERNAHME...",
		"x": -24.0,
		"y": 281.0,
		"start": 0.440,
		"end": 0.775,
		"size": 12,
		"scale": Vector2(1.34, 1.62),
		"crop_w": 398.0,
		"crop_mode": "bottom_cut_crop",
		"mode": "overload_stream",
		"color": Color(0.82, 0.86, 0.95, 0.96),
	},
]

@onready var overlay: ColorRect = $CrtOverlay
@onready var material: ShaderMaterial = $CrtOverlay.material

var active := false
var effect_progress := 0.0
var effect_duration := 2.45
var text_viewport: SubViewport
var text_display: TextureRect
var text_shader_material: ShaderMaterial
var terminal_canvas: _BiosTerminalCanvas
var slice_pool: Array[_ClipSliceBand] = []
var bios_font: FontVariation
var drone_player: AudioStreamPlayer
var _drone_triggered := false
static var _bios_drone_streams:Dictionary={}

static func prepare_audio()->void:
	_build_bios_drone_stream(1.65)


class _ClipSliceBand extends Control:
	var font_ref: Font
	var draw_text := ""
	var font_size := 14
	var text_origin := Vector2.ZERO
	var text_scale := Vector2.ONE
	var primary_color := Color.WHITE
	var ghost_spread := 2.0
	var smear_offset := 0.0
	var cursor_bounce := false

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if font_ref == null or draw_text.is_empty():
			return
		var local_pos := text_origin - position
		var scaled_pos := Vector2(local_pos.x / maxf(text_scale.x, 0.001), local_pos.y / maxf(text_scale.y, 0.001))
		draw_set_transform(Vector2.ZERO, 0.0, text_scale)

		# Wide horizontal motion smear ONLY during the brief initial burst lock-in (like f=94..98)
		if smear_offset > 0.35:
			draw_string(
				font_ref,
				scaled_pos + Vector2(smear_offset, 0.0),
				draw_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size,
				Color(0.42, 0.62, 0.96, primary_color.a * 0.42)
			)
			draw_string(
				font_ref,
				scaled_pos + Vector2(smear_offset * 0.48, 0.0),
				draw_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size,
				Color(0.72, 0.80, 0.96, primary_color.a * 0.35)
			)
			draw_string(
				font_ref,
				scaled_pos - Vector2(smear_offset * 0.52, 0.0),
				draw_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size,
				Color(0.88, 0.28, 0.36, primary_color.a * 0.30)
			)

		# Subtle CRT double-vision shadow (keeps characters crisp and legible)
		draw_string(
			font_ref,
			scaled_pos + Vector2(ghost_spread, 0.8),
			draw_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			Color(0.26, 0.44, 0.88, primary_color.a * 0.34)
		)

		if cursor_bounce and draw_text.length() > 1:
			var head_count := mini(2, draw_text.length())
			var prefix_len := draw_text.length() - head_count
			var prefix_str := draw_text.substr(0, prefix_len)
			var head_str := draw_text.substr(prefix_len, head_count)
			draw_string(
				font_ref,
				scaled_pos,
				prefix_str,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size,
				primary_color
			)
			var prefix_w := font_ref.get_string_size(prefix_str, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
			draw_string(
				font_ref,
				scaled_pos + Vector2(prefix_w + 1.5, -2.0),
				head_str,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size,
				Color(0.55, 0.78, 1.0, primary_color.a * 0.68)
			)
			draw_string(
				font_ref,
				scaled_pos + Vector2(prefix_w, 1.8),
				head_str,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size,
				primary_color
			)
		else:
			draw_string(
				font_ref,
				scaled_pos,
				draw_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size,
				primary_color
			)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class _BiosTerminalCanvas extends Control:
	var owner_effect: DeathCrtEffect


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_font()
	_setup_terminal_pipeline()
	_setup_drone_audio()
	if is_instance_valid(material):
		material.set_shader_parameter("progress", 0.0)


func _setup_font() -> void:
	bios_font = FontVariation.new()
	bios_font.base_font = PRIMARY_FONT_FILE
	bios_font.fallbacks = [FALLBACK_FONT_FILE]


func _setup_terminal_pipeline() -> void:
	text_viewport = SubViewport.new()
	text_viewport.name = "BiosTextSubViewport"
	text_viewport.size = Vector2i(640, 360)
	text_viewport.transparent_bg = true
	text_viewport.handle_input_locally = false
	text_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	text_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(text_viewport)

	terminal_canvas = _BiosTerminalCanvas.new()
	terminal_canvas.name = "BiosTerminalCanvas"
	terminal_canvas.owner_effect = self
	terminal_canvas.custom_minimum_size = Vector2(640.0, 360.0)
	terminal_canvas.size = Vector2(640.0, 360.0)
	terminal_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_viewport.add_child(terminal_canvas)

	for _idx in 28:
		var band := _ClipSliceBand.new()
		band.visible = false
		band.font_ref = bios_font
		terminal_canvas.add_child(band)
		slice_pool.append(band)

	text_display = TextureRect.new()
	text_display.name = "BiosTextGlitchDisplay"
	text_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	text_display.stretch_mode = TextureRect.STRETCH_SCALE
	text_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_display.texture = text_viewport.get_texture()

	text_shader_material = ShaderMaterial.new()
	text_shader_material.shader = TEXT_GLITCH_SHADER
	text_shader_material.set_shader_parameter("progress", 0.0)
	text_display.material = text_shader_material
	add_child(text_display)


func _setup_drone_audio() -> void:
	drone_player = AudioStreamPlayer.new()
	drone_player.name = "BiosDronePlayer"
	drone_player.bus = &"UI"
	drone_player.volume_db = -9.0
	drone_player.stream = _build_bios_drone_stream(1.65)
	add_child(drone_player)


func play(duration: float = 2.45) -> void:
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
	else:
		_set_progress(effect_progress)


func _set_progress(value: float) -> void:
	if is_instance_valid(material):
		material.set_shader_parameter("progress", value)
	if is_instance_valid(text_shader_material):
		text_shader_material.set_shader_parameter("progress", value)
	_sync_slice_bands(value)


func _resolve_line_text(spec: Dictionary, t: float) -> String:
	var full_text := String(spec["text"])
	var start_t := float(spec["start"])
	var end_t := float(spec["end"])
	var mode := String(spec.get("mode", "steady"))
	var raw_p := clampf((t - start_t) / maxf(end_t - start_t, 0.001), 0.0, 1.0)
	var total_chars := full_text.length()

	match mode:
		"burst":
			var burst_p := 1.0 - pow(1.0 - raw_p, 2.6)
			var chars := clampi(ceili(float(total_chars) * burst_p), 1, total_chars)
			return full_text.substr(0, chars)

		"proxy_wake":
			var body_without_prefix := "     j Starte V* Proxy-System.. [正在唤醒后颈潜伏芯片...]"
			var first_part_len := 31
			var chars := 1
			if raw_p < 0.22:
				var p1 := raw_p / 0.22
				chars = clampi(ceili(float(first_part_len) * p1), 1, first_part_len)
			elif raw_p < 0.38:
				chars = first_part_len
			else:
				var p2 := (raw_p - 0.38) / 0.62
				chars = clampi(first_part_len + ceili(float(total_chars - first_part_len) * p2), first_part_len, total_chars)
			var source_str := full_text if raw_p >= 0.54 else body_without_prefix
			return source_str.substr(0, chars)

		"snap":
			var snap_p := clampf(pow(raw_p, 0.55), 0.0, 1.0)
			var chars := clampi(ceili(float(total_chars) * snap_p), 1, total_chars)
			return full_text.substr(0, chars)

		"steady":
			var split_idx := 17
			var chars := 1
			if raw_p < 0.48:
				chars = clampi(ceili(float(split_idx) * (raw_p / 0.48)), 1, split_idx)
			elif raw_p < 0.62:
				chars = split_idx
			else:
				var p2 := (raw_p - 0.62) / 0.38
				chars = clampi(split_idx + ceili(float(total_chars - split_idx) * p2), split_idx, total_chars)
			return full_text.substr(0, chars)

		"percent_count":
			var prefix := ">> 正在接管运动神经丛 (MOTORISCHER_KORTEX)... "
			var prefix_len := prefix.length()
			if raw_p < 0.42:
				var chars := clampi(ceili(float(prefix_len) * (raw_p / 0.42)), 1, prefix_len)
				return prefix.substr(0, chars)
			elif raw_p < 0.54:
				return prefix
			elif raw_p < 0.66:
				return prefix + "14%"
			elif raw_p < 0.77:
				return prefix + "39%"
			elif raw_p < 0.88:
				return prefix + "67%"
			elif raw_p < 0.96:
				return prefix + "89%"
			else:
				return full_text

		"staccato_3":
			var c1 := ">> 屏蔽死亡痛觉反馈..."
			var c2 := ">> 屏蔽死亡痛觉反馈... 锁定声带..."
			var len1 := c1.length()
			var len2 := c2.length()
			if raw_p < 0.24:
				var chars := clampi(ceili(float(len1) * (raw_p / 0.24)), 1, len1)
				return full_text.substr(0, chars)
			elif raw_p < 0.38:
				return c1
			elif raw_p < 0.60:
				var p2 := (raw_p - 0.38) / 0.22
				var chars := clampi(len1 + ceili(float(len2 - len1) * p2), len1, len2)
				return full_text.substr(0, chars)
			elif raw_p < 0.74:
				return c2
			else:
				var p3 := (raw_p - 0.74) / 0.26
				var chars := clampi(len2 + ceili(float(total_chars - len2) * p3), len2, total_chars)
				return full_text.substr(0, chars)

		"stamp":
			return full_text

		"overload_stream":
			var stream_p := clampf(pow(raw_p, 0.78), 0.0, 1.0)
			var chars := clampi(ceili(float(total_chars) * stream_p), 1, total_chars)
			return full_text.substr(0, chars)

		"slow_typewriter":
			var colon_idx := 28
			var chars := 1
			if raw_p < 0.58:
				chars = clampi(ceili(float(colon_idx) * (raw_p / 0.58)), 1, colon_idx)
			elif raw_p < 0.66:
				chars = colon_idx
			else:
				var p2 := (raw_p - 0.66) / 0.34
				chars = clampi(colon_idx + ceili(float(total_chars - colon_idx) * p2), colon_idx, total_chars)
			return full_text.substr(0, chars)

	var default_chars := clampi(ceili(float(total_chars) * raw_p), 1, total_chars)
	return full_text.substr(0, default_chars)


func _allocate_band(idx: int) -> _ClipSliceBand:
	if idx < 0 or idx >= slice_pool.size():
		return null
	var band := slice_pool[idx]
	band.visible = true
	return band


func _configure_band(
	band: _ClipSliceBand,
	clip_rect: Rect2,
	origin: Vector2,
	text: String,
	font_size: int,
	scale_vec: Vector2,
	color: Color,
	ghost_spread: float,
	smear: float,
	bounce: bool = false
) -> void:
	if band == null:
		return
	band.position = clip_rect.position
	band.size = clip_rect.size
	band.text_origin = origin
	band.draw_text = text
	band.font_size = font_size
	band.text_scale = scale_vec
	band.primary_color = color
	band.ghost_spread = ghost_spread
	band.smear_offset = smear
	band.cursor_bounce = bounce
	band.queue_redraw()


func _sync_slice_bands(progress_val: float) -> void:
	for band in slice_pool:
		band.visible = false

	var t := clampf(progress_val, 0.0, 1.0)
	if t < 0.33 or t >= 0.965 or bios_font == null:
		return

	var collapse_t := clampf((t - 0.83) / 0.135, 0.0, 1.0)
	var global_alpha := 1.0 - smoothstep(0.35, 1.0, collapse_t)
	if global_alpha <= 0.005:
		return

	var frame_step := floorf(t * 60.0)
	var pan_right_px := lerpf(0.0, 14.0, clampf((t - 0.34) / 0.46, 0.0, 1.0))
	var pool_cursor := 0

	for i in BIOS_LINES.size():
		var spec: Dictionary = BIOS_LINES[i]
		var start_t := float(spec["start"])
		var end_t := float(spec["end"])
		if t < start_t:
			continue

		var mode := String(spec.get("mode", "steady"))
		var crop_mode := String(spec.get("crop_mode", "clean_crop"))
		var sub_text := _resolve_line_text(spec, t)
		var font_size := int(spec["size"])
		var scale_vec: Vector2 = spec.get("scale", Vector2(1.05, 1.22))
		var base_x := float(spec.get("x", -16.0)) + pan_right_px
		var y_pos := float(spec["y"])
		var crop_w := float(spec.get("crop_w", 460.0))

		var lock_window := 0.065 if (mode == "burst" or mode == "snap" or mode == "stamp") else 0.04
		var lock_in := 1.0 - clampf((t - start_t) / lock_window, 0.0, 1.0)
		var hash_val := fposmod(sin(float(i * 19 + 7) * 43.17 + frame_step * 12.9898) * 43758.5453, 1.0)
		var jitter_x := (hash_val - 0.5) * (8.0 * lock_in + 24.0 * collapse_t)

		var base_color: Color = spec["color"]
		var draw_color := base_color
		draw_color.a *= global_alpha

		var line_h := float(font_size) * scale_vec.y
		var top_y := y_pos - line_h * 0.88
		var ghost_spread := 1.6 + 4.5 * lock_in + 5.0 * collapse_t
		var smear := 22.0 * lock_in if (mode == "burst" or mode == "snap" or mode == "stamp") else 0.0
		var is_slow_bounce := (mode == "slow_typewriter" and t < end_t)

		match crop_mode:
			"top_overline":
				# Clean full characters + a 3px-tall sliced overline cap above the letters (like "Emergency Reboot Device" in f=126..148)
				var b_main := _allocate_band(pool_cursor)
				pool_cursor += 1
				_configure_band(
					b_main,
					Rect2(0.0, top_y - 2.0, crop_w, line_h + 6.0),
					Vector2(base_x + jitter_x, y_pos),
					sub_text,
					font_size,
					scale_vec,
					draw_color,
					ghost_spread,
					smear,
					is_slow_bounce
				)
				var b_cap := _allocate_band(pool_cursor)
				pool_cursor += 1
				_configure_band(
					b_cap,
					Rect2(0.0, top_y - 3.5, crop_w, 3.0),
					Vector2(base_x + jitter_x + 2.0, y_pos - 3.0),
					sub_text,
					font_size,
					scale_vec,
					Color(draw_color.r, draw_color.g, draw_color.b, draw_color.a * 0.72),
					ghost_spread,
					smear,
					false
				)

			"with_sliver_below":
				# Clean line + a 4px-tall horizontally cropped glyph sliver right below it (like "512 RJ" + "T TT" in f=128..148)
				var b_main := _allocate_band(pool_cursor)
				pool_cursor += 1
				_configure_band(
					b_main,
					Rect2(0.0, top_y - 1.0, crop_w, line_h + 3.0),
					Vector2(base_x + jitter_x, y_pos),
					sub_text,
					font_size,
					scale_vec,
					draw_color,
					ghost_spread,
					smear
				)
				var b_sliver := _allocate_band(pool_cursor)
				pool_cursor += 1
				_configure_band(
					b_sliver,
					Rect2(0.0, top_y + line_h + 1.0, 120.0, 4.0),
					Vector2(base_x + jitter_x + 4.0, y_pos + 6.0),
					sub_text,
					font_size,
					scale_vec,
					Color(draw_color.r, draw_color.g, draw_color.b, draw_color.a * 0.85),
					ghost_spread,
					smear
				)

			"top_65_crop":
				# Bottom 35% of the line is cleanly cropped off by a horizontal scissor edge
				var b_crop := _allocate_band(pool_cursor)
				pool_cursor += 1
				_configure_band(
					b_crop,
					Rect2(0.0, top_y, crop_w, line_h * 0.68),
					Vector2(base_x + jitter_x, y_pos),
					sub_text,
					font_size,
					scale_vec,
					draw_color,
					ghost_spread,
					smear
				)

			"verdict_crop":
				# Matches "枉死" in f=128..150: large, tall, left stroke clipped at x=0, full vertical height
				var b_verdict := _allocate_band(pool_cursor)
				pool_cursor += 1
				_configure_band(
					b_verdict,
					Rect2(0.0, top_y - 3.0, crop_w, line_h + 6.0),
					Vector2(base_x + jitter_x, y_pos - 2.0 * lock_in),
					sub_text,
					font_size,
					scale_vec,
					draw_color,
					ghost_spread + 1.5,
					smear
				)

			"bottom_cut_crop":
				# Matches "NGANDVERMESSUNGANDVERMESSUNG" in f=108..150: left-cropped ("ZWA" cut off),
				# right-cropped mid-letter, and bottom 28% cleanly cropped off by a horizontal scissor line
				var b_stream := _allocate_band(pool_cursor)
				pool_cursor += 1
				_configure_band(
					b_stream,
					Rect2(0.0, top_y - 1.0, crop_w, line_h * 0.78),
					Vector2(base_x + jitter_x, y_pos),
					sub_text,
					font_size,
					scale_vec,
					draw_color,
					ghost_spread + 1.8,
					smear
				)

			_:
				# "clean_crop": crisp zoomed characters, cropped on the left (x < 0) and right (crop_w)
				var b_clean := _allocate_band(pool_cursor)
				pool_cursor += 1
				_configure_band(
					b_clean,
					Rect2(0.0, top_y - 2.0, crop_w, line_h + 5.0),
					Vector2(base_x + jitter_x, y_pos),
					sub_text,
					font_size,
					scale_vec,
					draw_color,
					ghost_spread,
					smear
				)


static func _build_bios_drone_stream(duration_sec: float) -> AudioStreamWAV:
	if _bios_drone_streams.has(duration_sec):return _bios_drone_streams[duration_sec]
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
		var freq := lerpf(110.0, 66.0, pow(p, 0.85))
		phase_sub += TAU * freq / float(stream.mix_rate)
		phase_harm += TAU * (freq * 2.0) / float(stream.mix_rate)
		var saw := 2.0 * (phase_sub / TAU - floorf(0.5 + phase_sub / TAU))
		var sq := 1.0 if sin(phase_sub) >= 0.0 else -1.0
		var sub_wave := sin(phase_sub) * 0.55 + saw * 0.28 + sq * 0.17 + sin(phase_harm) * 0.18

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
	if _bios_drone_streams.size()>=8:_bios_drone_streams.clear()
	_bios_drone_streams[duration_sec]=stream
	return stream
