class_name BedroomWeather
extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")

@export var config: DemoConfig

var weather_type := "overcast"
var elapsed := 0.0
var thunder_left := 8.0
var flash_intensity := 0.0
var flash_phase := 0  # 0 idle, 1 main flash, 2 dim gap, 3 afterglow
var flash_timer := 0.0
var random := RandomNumberGenerator.new()

# Pre-seeded particle arrays (stable positions, animated via elapsed offset).
var rain_streaks: Array = []
var splash_points: Array = []
var cloud_bands: Array = []
var star_dots: Array = []
var wind_lines: Array = []
var lightning_path: Array[Vector2] = []

# Per-weather tint colors (RGB + base alpha).
const TINT_COLORS := {
	"rain": Color(0.28, 0.36, 0.46, 0.40),
	"thunder": Color(0.22, 0.20, 0.36, 0.48),
	"wind": Color(0.40, 0.38, 0.34, 0.30),
	"stars": Color(0.10, 0.14, 0.28, 0.42),
	"overcast": Color(0.30, 0.32, 0.38, 0.32),
}

# Rain parallax layers: [speed_x, speed_y, length, width, opacity_mult]
const RAIN_LAYERS := [
	[22.0, 48.0, 3.0, 1.0, 0.35],  # far
	[34.0, 72.0, 6.0, 1.0, 0.60],  # mid
	[48.0, 100.0, 10.0, 2.0, 1.00], # near
]

# Foreground rain layer (close to camera, fast and thick).
const FG_RAIN_SPEED := 140.0
const FG_RAIN_LENGTH := 14.0
const FG_RAIN_COUNT := 28


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	random.randomize()
	_reset_thunder_timer()
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)


func _fit_to_viewport() -> void:
	size = get_viewport_rect().size
	_seed_particles()
	queue_redraw()


func configure(type: String) -> void:
	weather_type = type if type in config.weather_types else "overcast"
	SFX.play_weather_ambience(StringName(weather_type))
	elapsed = 0.0
	flash_intensity = 0.0
	flash_phase = 0
	flash_timer = 0.0
	_reset_thunder_timer()
	_seed_particles()
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta * config.weather_animation_speed
	if weather_type == "thunder":
		thunder_left -= delta
		_update_flash(delta)
		if flash_phase == 0 and thunder_left <= 0.0:
			_trigger_thunder()
	queue_redraw()


func _reset_thunder_timer() -> void:
	thunder_left = random.randf_range(config.weather_thunder_min_interval, config.weather_thunder_max_interval)


# ── Thunder flash state machine ──────────────────────────────────────────
# Phase 1: bright main flash (0.10s) → Phase 2: brief dim (0.06s)
# → Phase 3: secondary afterglow (0.14s) → Phase 0: idle
const FLASH_MAIN_DURATION := 0.10
const FLASH_GAP_DURATION := 0.06
const FLASH_AFTERGLOW_DURATION := 0.14


func _trigger_thunder() -> void:
	flash_phase = 1
	flash_timer = 0.0
	lightning_path = _generate_lightning_path()
	# 雷声音效可由配置关闭（闪电视觉保留）。
	if config.weather_thunder_sfx_enabled:
		SFX.play_event(&"thunder")


func _update_flash(delta: float) -> void:
	if flash_phase == 0:
		return
	flash_timer += delta
	match flash_phase:
		1:
			flash_intensity = 1.0
			if flash_timer >= FLASH_MAIN_DURATION:
				flash_phase = 2
				flash_timer = 0.0
		2:
			flash_intensity = 0.15
			if flash_timer >= FLASH_GAP_DURATION:
				flash_phase = 3
				flash_timer = 0.0
		3:
			flash_intensity = lerpf(0.55, 0.0, flash_timer / FLASH_AFTERGLOW_DURATION)
			if flash_timer >= FLASH_AFTERGLOW_DURATION:
				flash_phase = 0
				flash_intensity = 0.0
				lightning_path.clear()
				_reset_thunder_timer()


# ── Particle seeding ─────────────────────────────────────────────────────

func _seed_particles() -> void:
	rain_streaks.clear()
	splash_points.clear()
	cloud_bands.clear()
	star_dots.clear()
	wind_lines.clear()

	# Distribute rain particles across parallax layers.
	var total := maxi(config.weather_rain_particle_count, 1)
	var layer_counts: Array[int] = [
		maxi(int(total * 0.35), 1),
		maxi(int(total * 0.38), 1),
		maxi(int(total * 0.27), 1),
	]
	for layer_idx in range(RAIN_LAYERS.size()):
		var count: int = layer_counts[layer_idx]
		for i in range(count):
			rain_streaks.append({
				"layer": layer_idx,
				"seed_x": random.randf() * (size.x + 40.0),
				"seed_y": random.randf() * (size.y + 40.0),
				"offset": random.randf() * 1000.0,
			})

	# Splash marks at the bottom edge.
	for i in range(config.weather_splash_count):
		splash_points.append({
			"x": random.randf() * size.x,
			"phase": random.randf() * TAU,
			"size": random.randf_range(2.0, 4.0),
		})

	# Cloud bands (layered, varying speed and depth).
	for i in range(8):
		cloud_bands.append({
			"seed_x": random.randf() * (size.x + 200.0),
			"y": 16.0 + random.randf() * (size.y * 0.55),
			"width": random.randf_range(60.0, 160.0),
			"height": random.randf_range(12.0, 28.0),
			"speed": random.randf_range(3.0, 12.0),
			"depth": random.randf_range(0.35, 1.0),
		})

	# Stars with individual pulse rates.
	for i in range(44):
		star_dots.append({
			"x": 5.0 + random.randf() * (size.x - 10.0),
			"y": 5.0 + random.randf() * (size.y * 0.65),
			"size": random.randf_range(1.0, 3.0),
			"pulse_speed": random.randf_range(0.8, 2.6),
			"pulse_offset": random.randf() * TAU,
			"base_alpha": random.randf_range(0.3, 0.85),
		})

	# Wind streaks with varying speeds and lengths.
	for i in range(16):
		wind_lines.append({
			"seed_x": random.randf() * (size.x + 80.0),
			"y": 20.0 + random.randf() * (size.y - 40.0),
			"length": random.randf_range(16.0, 40.0),
			"speed": random.randf_range(18.0, 42.0),
			"opacity": random.randf_range(0.3, 0.75),
		})


func _generate_lightning_path() -> Array[Vector2]:
	var path: Array[Vector2] = []
	var start_x := random.randf_range(size.x * 0.15, size.x * 0.85)
	var end_y := random.randf_range(size.y * 0.35, size.y * 0.65)
	var segments := 8
	for i in range(segments + 1):
		var t := float(i) / segments
		var base_x := start_x + random.randf_range(-12.0, 12.0) * (1.0 - absf(t - 0.5) * 2.0)
		var y := lerpf(0.0, end_y, t) + random.randf_range(-4.0, 4.0)
		path.append(Vector2(base_x, y))
	return path


# ── Drawing ──────────────────────────────────────────────────────────────

func _draw() -> void:
	var alpha := config.weather_opacity
	var viewport_rect := Rect2(Vector2.ZERO, size)

	# 1. Weather-specific tint overlay.
	_draw_tint(viewport_rect)

	# 2. Weather particles.
	match weather_type:
		"rain", "thunder": _draw_rain(alpha)
		"wind": _draw_wind(alpha)
		"stars": _draw_stars(alpha)
		_: _draw_clouds(alpha)

	# 3. Bottom fog gradient (all weather types for atmosphere).
	_draw_fog()

	# 4. Thunder flash + lightning bolt.
	if weather_type == "thunder" and flash_intensity > 0.0:
		_draw_thunder_flash(viewport_rect)


func _draw_tint(viewport_rect: Rect2) -> void:
	var tint: Color = TINT_COLORS.get(weather_type, TINT_COLORS["overcast"])
	tint.a *= config.weather_tint_intensity
	if tint.a > 0.001:
		draw_rect(viewport_rect, tint)


func _draw_rain(alpha: float) -> void:
	# Back-layer rain (parallax depth).
	for streak in rain_streaks:
		var layer_idx: int = streak["layer"]
		var layer: Array = RAIN_LAYERS[layer_idx]
		var speed_x: float = layer[0]
		var speed_y: float = layer[1]
		var length: float = layer[2]
		var width: float = layer[3]
		var op_mult: float = layer[4]
		var sx: float = streak["seed_x"]
		var sy: float = streak["seed_y"]
		var x := fmod(sx + elapsed * speed_x, size.x + 40.0) - 20.0
		var y := fmod(sy + elapsed * speed_y, size.y + 40.0) - 20.0
		var dx := length * 0.35
		var dy := length
		var line_alpha := alpha * op_mult
		draw_line(Vector2(x, y), Vector2(x + dx, y + dy), Color(0.55, 0.68, 0.76, line_alpha), width)

	# Foreground rain (close to camera, fast and thick).
	var fg_alpha := config.weather_foreground_rain_opacity * alpha
	for i in range(FG_RAIN_COUNT):
		var x := fmod(float(i) * 73.0 + elapsed * FG_RAIN_SPEED * 0.8, size.x + 40.0) - 20.0
		var y := fmod(float(i) * 137.0 + elapsed * FG_RAIN_SPEED, size.y + 40.0) - 20.0
		var dx := FG_RAIN_LENGTH * 0.35
		var dy := FG_RAIN_LENGTH
		var fade := 0.6 + 0.4 * sin(elapsed * 3.0 + float(i))
		draw_line(Vector2(x, y), Vector2(x + dx, y + dy), Color(0.62, 0.74, 0.82, fg_alpha * fade), 2.0)

	# Rain splashes at the bottom edge.
	var splash_alpha: float = alpha * 0.5
	for splash in splash_points:
		var sx: float = splash["x"]
		var phase: float = splash["phase"]
		var s_size_raw: float = splash["size"]
		var pulse := 0.5 + 0.5 * sin(elapsed * 4.0 + phase)
		var s_size: float = s_size_raw * (0.5 + pulse * 0.5)
		var sy: float = size.y - 4.0 - fmod(phase * 13.0, 8.0)
		# Small cross/diamond splash mark.
		draw_line(Vector2(sx - s_size, sy), Vector2(sx + s_size, sy), Color(0.60, 0.72, 0.80, splash_alpha * pulse), 1.0)
		draw_line(Vector2(sx, sy - s_size * 0.5), Vector2(sx, sy + s_size * 0.5), Color(0.60, 0.72, 0.80, splash_alpha * pulse * 0.7), 1.0)


func _draw_wind(alpha: float) -> void:
	for w in wind_lines:
		var sx: float = w["seed_x"]
		var speed: float = w["speed"]
		var x := fmod(sx + elapsed * speed, size.x + 80.0) - 40.0
		var y: float = w["y"]
		var length: float = w["length"]
		var op: float = w["opacity"]
		draw_line(Vector2(x, y), Vector2(x + length, y), Color(0.52, 0.63, 0.70, alpha * op), 2.0)
	# Also draw a few clouds for wind weather.
	_draw_clouds(alpha * 0.5)


func _draw_stars(alpha: float) -> void:
	for star in star_dots:
		var pulse_speed: float = star["pulse_speed"]
		var pulse_offset: float = star["pulse_offset"]
		var pulse := 0.35 + 0.45 * sin(elapsed * pulse_speed + pulse_offset)
		var s_size: float = star["size"]
		var base_alpha: float = star["base_alpha"]
		var s_alpha: float = alpha * base_alpha * pulse
		var px: float = star["x"]
		var py: float = star["y"]
		draw_rect(Rect2(px, py, s_size, s_size), Color(0.82, 0.85, 0.92, s_alpha))
		# Brighter core for larger stars.
		if s_size > 1.5:
			draw_rect(Rect2(px, py, 1.0, 1.0), Color(0.95, 0.97, 1.0, s_alpha * 0.8))


func _draw_clouds(alpha: float) -> void:
	for cloud in cloud_bands:
		var sx: float = cloud["seed_x"]
		var speed: float = cloud["speed"]
		var x := fmod(sx + elapsed * speed, size.x + 200.0) - 100.0
		var y: float = cloud["y"]
		var cw: float = cloud["width"]
		var ch: float = cloud["height"]
		var depth: float = cloud["depth"]
		var cloud_alpha := alpha * 0.86 * depth
		# Main body.
		draw_rect(Rect2(x, y, cw, ch), Color(0.22, 0.28, 0.34, cloud_alpha))
		# Highlight band (top edge).
		draw_rect(Rect2(x + 4.0, y, cw - 8.0, 3.0), Color(0.35, 0.42, 0.48, cloud_alpha * 0.6))
		# Shadow band (bottom edge).
		draw_rect(Rect2(x + 8.0, y + ch - 3.0, cw - 16.0, 3.0), Color(0.14, 0.18, 0.24, cloud_alpha * 0.8))


func _draw_fog() -> void:
	var fog_base := config.weather_fog_opacity
	if fog_base <= 0.001:
		return
	# Determine fog color based on weather type.
	var fog_color := Color(0.30, 0.34, 0.40, 1.0)
	match weather_type:
		"thunder":
			fog_color = Color(0.20, 0.18, 0.32, 1.0)
		"stars":
			fog_color = Color(0.08, 0.12, 0.22, 1.0)
		"wind":
			fog_color = Color(0.34, 0.32, 0.28, 1.0)
	# Draw bottom-up gradient using 12 bands.
	var bands := 12
	var fog_height := size.y * 0.45
	for i in range(bands):
		var ratio := float(i) / float(bands - 1)
		var y := size.y - fog_height + fog_height * ratio
		var band_h := fog_height / float(bands) + 1.0
		var band_alpha := fog_base * (0.15 + 0.85 * ratio)
		fog_color.a = band_alpha
		draw_rect(Rect2(0.0, y, size.x, band_h), fog_color)


func _draw_thunder_flash(viewport_rect: Rect2) -> void:
	# Full-screen flash.
	draw_rect(viewport_rect, Color(0.72, 0.82, 0.88, flash_intensity * 0.52))
	# Lightning bolt.
	if lightning_path.size() >= 2:
		var bolt_color := Color(0.92, 0.95, 1.0, flash_intensity * 0.85)
		for i in range(lightning_path.size() - 1):
			draw_line(lightning_path[i], lightning_path[i + 1], bolt_color, 2.0)
		# Brighter core line.
		var core_color := Color(1.0, 1.0, 1.0, flash_intensity)
		for i in range(lightning_path.size() - 1):
			draw_line(lightning_path[i], lightning_path[i + 1], core_color, 1.0)
		# Glow halo around the bolt (thicker, lower-alpha line).
		var glow_color := Color(0.80, 0.85, 1.0, flash_intensity * 0.3)
		for i in range(lightning_path.size() - 1):
			draw_line(lightning_path[i], lightning_path[i + 1], glow_color, 4.0)
