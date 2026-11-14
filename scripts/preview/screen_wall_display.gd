extends Node3D
## One independently configurable screen: idle mosaic -> static -> option.

signal activated(action: StringName)
signal disabled_activated(action: StringName)
signal power_off_started
signal power_off_finished
signal broadcast_started(style: int)
signal broadcast_finished(style: int)
signal snow_visibility_changed(active: bool)

const CRT_SHADER := preload("res://shaders/ui/screen_wall_crt.gdshader")
const CRT_COLORS := preload("res://scripts/ui/screen_wall_colors.gd")
const FONT := preload("res://assets/fonts/boutique_bitmap/BoutiqueBitmap9x9_Bold_1.9.ttf")
const POWER_OFF_SECONDS := 0.22
const SIGNAL_FLICKER := [0.16, 1.0, 0.38, 1.0]
enum BroadcastStyle { NONE, OPTION, SNOW, COLOR_BARS }
@export var ambient_signals_enabled := true
@export var action_id: StringName = &""
@export var option_text := ""
var navigation_order := 0
var option_enabled := true
var chassis: Node3D
var screen: MeshInstance3D
var hit_body: StaticBody3D
var glass_size := Vector2.ONE
var effect: ShaderMaterial
var label_viewport: SubViewport
var hovering := false
var hover_seconds := 0.0
var elapsed := 0.0
var press_flash := 0.0
var noise_amount := 0.0
var option_mix := 0.0
var phase := "idle"
var spill_light: OmniLight3D
var spill_energy := 1.0
var power_down := 0.0
var powering_off := false
var powered_off := false
var base_tint := Color.WHITE
var signal_rng := RandomNumberGenerator.new()
var signal_wait := 0.0
var signal_elapsed := 0.0
var signal_hold := 0.0
var signal_active := false
var signal_style := BroadcastStyle.NONE
var signal_mix := 0.0
var signal_option_mix := 0.0
var signal_noise := 0.0
var signal_dimmer := 1.0
var snow_visible := false


func configure(tv: Node3D, index: int) -> void:
	chassis = tv
	action_id = StringName(tv.get_meta("action_id", ""))
	option_text = tv.get_meta("option_text", "")
	navigation_order = tv.get_meta("navigation_order", index)
	glass_size = tv.get_meta("screen_size")
	var authored_tint: Color = tv.get_meta("screen_tint")
	# TV_04 is the horizontal monitor at middle right: one shared blue for
	# ordinary images and their emitted light, with the original iris intact.
	var reference_tv := tv.get_parent().get_node_or_null("TV_04")
	if ambient_signals_enabled and reference_tv != null:
		authored_tint = reference_tv.get_meta("screen_tint")
	base_tint = CRT_COLORS.vivid(authored_tint) if ambient_signals_enabled else authored_tint
	signal_rng.randomize()
	signal_wait = signal_rng.randf_range(1.2, 4.8) if ambient_signals_enabled else 0.0
	screen = tv.get_node("Screen")
	hit_body = tv.get_node("ScreenHitArea")
	hit_body.set_meta("display_controller", self)
	label_viewport = _make_option_texture(index)
	effect = ShaderMaterial.new()
	effect.shader = CRT_SHADER
	effect.set_shader_parameter("mosaic_image", load("res://art/Home Screen/Home_Screen_chr.png"))
	effect.set_shader_parameter("eye_image", load("res://art/Home Screen/Home_Screen_chr_eye.png"))
	effect.set_shader_parameter("eye_mask", load("res://art/Home Screen/Home_Screen_chr_eye_mask.png"))
	effect.set_shader_parameter("option_image", label_viewport.get_texture())
	effect.set_shader_parameter("glass_size", glass_size)
	effect.set_shader_parameter("screen_tint", base_tint)
	effect.set_shader_parameter("channel_seed", float(index))
	screen.material_override = effect
	# The screens are the room's only light sources. A short-range light at
	# the front glass approximates their diffuse spill in Compatibility mode.
	spill_light = OmniLight3D.new()
	spill_light.name = "ScreenEmissionLight"
	spill_light.position = Vector3(0, 0, 0.42)
	spill_light.light_color = base_tint
	spill_energy = clampf(glass_size.x * glass_size.y * 0.37, 0.48, 1.60)
	spill_light.light_energy = spill_energy
	spill_light.omni_range = 2.85
	spill_light.omni_attenuation = 1.5
	spill_light.shadow_enabled = not action_id.is_empty()
	add_child(spill_light)


func _make_option_texture(index: int) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "OptionTexture"
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.size = Vector2i(glass_size * 180.0)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	if option_text.is_empty():
		return viewport
	var text := Label.new()
	text.name = "Option"
	text.text = option_text
	text.add_theme_font_override("font", FONT)
	var fitted_size := minf(viewport.size.x * 0.82 / maxf(1.0, option_text.length()), viewport.size.y * 0.38)
	var font_size := maxi(54, floori(fitted_size / 9.0) * 9)
	text.add_theme_font_size_override("font_size", font_size)
	text.add_theme_color_override("font_color", Color("dcf5ed"))
	text.add_theme_color_override("font_outline_color", Color("274f58"))
	text.add_theme_constant_override("outline_size", 2)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.size = Vector2(viewport.size)
	var option_center: Vector2 = chassis.get_meta("option_center_uv", Vector2(0.5, 0.5))
	text.position = (option_center - Vector2(0.5, 0.5)) * Vector2(viewport.size)
	viewport.add_child(text)
	if not chassis.get_meta("show_option_caption", true):
		return viewport
	var english := {&"new_game": "NEW GAME", &"continue": "CONTINUE", &"settings": "SETTINGS", &"quit": "EXIT"}
	var small := Label.new()
	small.text = "%02d   /   %s" % [index + 1, english.get(action_id, "")]
	small.add_theme_font_override("font", FONT)
	small.add_theme_font_size_override("font_size", 19)
	small.add_theme_color_override("font_color", Color("8abfbe"))
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.position = Vector2(text.position.x, viewport.size.y * option_center.y - font_size * 0.56 - 36.0)
	small.size = Vector2(viewport.size.x, 22)
	viewport.add_child(small)
	return viewport


func set_hovered(value: bool) -> void:
	if value == hovering:
		return
	hovering = value
	hover_seconds = 0.0
	_reset_broadcast()
	if value:
		phase = "static"
	else:
		phase = "release"


func activate() -> void:
	if action_id.is_empty() or powering_off or powered_off:
		return
	if not option_enabled:
		disabled_activated.emit(action_id)
		return
	press_flash = 1.0
	activated.emit(action_id)


func set_option_enabled(value: bool) -> void:
	if option_enabled == value:
		return
	option_enabled = value
	for child in label_viewport.get_children():
		if child is CanvasItem:
			child.modulate = Color.WHITE if value else Color(0.35, 0.35, 0.35, 1.0)
	label_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func is_ready_to_activate() -> bool:
	return not powering_off and not powered_off and hovering and not action_id.is_empty() and hover_seconds >= 0.34


func power_off() -> void:
	if powering_off or powered_off:
		return
	powering_off = true
	hovering = false
	noise_amount = 0.0
	option_mix = 0.0
	press_flash = 0.0
	phase = "power_off"
	_reset_broadcast(false)
	spill_light.light_color = base_tint
	effect.set_shader_parameter("noise_amount", 0.0)
	effect.set_shader_parameter("option_mix", 0.0)
	effect.set_shader_parameter("press_flash", 0.0)
	if ambient_signals_enabled:
		effect.set_shader_parameter("signal_mix", 0.0)
		effect.set_shader_parameter("signal_dimmer", 1.0)
	_sync_snow_visibility()
	power_off_started.emit()


func _process(delta: float) -> void:
	if effect == null:
		return
	elapsed += delta
	if powering_off:
		power_down = minf(1.0, power_down + delta / POWER_OFF_SECONDS)
		effect.set_shader_parameter("power_down", power_down)
		effect.set_shader_parameter("effect_time", elapsed)
		spill_light.light_energy = spill_energy * (1.0 - smoothstep(0.0, 0.58, power_down))
		if power_down >= 1.0:
			powered_off = true
			powering_off = false
			phase = "off"
			spill_light.hide()
			chassis.get_node("StatusLED").hide()
			chassis.get_node("ChassisID").hide()
			set_process(false)
			power_off_finished.emit()
		return
	_update_broadcast(delta)
	hover_seconds += delta
	press_flash = move_toward(press_flash, 0.0, delta * 4.0)
	if hovering:
		noise_amount = 1.0 - smoothstep(0.12, 0.38, hover_seconds)
		option_mix = smoothstep(0.20, 0.48, hover_seconds) if not option_text.is_empty() else 0.0
		phase = "option" if hover_seconds >= 0.48 else "static"
	else:
		noise_amount = move_toward(noise_amount, 0.0, delta * 6.0)
		option_mix = move_toward(option_mix, 0.0, delta * 4.5)
		if option_mix <= 0.0 and noise_amount <= 0.0:
			phase = "idle"
	effect.set_shader_parameter("effect_time", elapsed)
	var visible_option_mix := maxf(option_mix, signal_option_mix)
	effect.set_shader_parameter("noise_amount", maxf(noise_amount, signal_noise))
	effect.set_shader_parameter("option_mix", visible_option_mix)
	if ambient_signals_enabled:
		effect.set_shader_parameter("signal_mix", signal_mix)
		effect.set_shader_parameter("signal_pattern", 2.0 if signal_style == BroadcastStyle.COLOR_BARS else 1.0)
		effect.set_shader_parameter("signal_dimmer", signal_dimmer)
	effect.set_shader_parameter("proximity", 1.0 if hovering else 0.0)
	effect.set_shader_parameter("press_flash", press_flash)
	spill_light.light_energy = spill_energy * (1.0 - visible_option_mix * 0.48) * signal_dimmer * (1.0 - signal_mix * 0.20)
	spill_light.light_color = base_tint.lerp(Color(0.64, 0.69, 0.78), signal_mix * 0.65)
	_sync_snow_visibility()


func _sync_snow_visibility() -> void:
	var strength := 0.0
	if not powering_off and not powered_off and is_visible_in_tree():
		# Match the shader composition: full-screen reception replaces hover
		# noise, and color bars do not count as a snow screen. Idle grain stays quiet.
		strength = maxf(noise_amount, signal_noise) * (1.0 - signal_mix)
		if signal_style == BroadcastStyle.SNOW:
			strength = maxf(strength, signal_mix)
	var active := strength > 0.001
	if active == snow_visible:
		return
	snow_visible = active
	snow_visibility_changed.emit(active)


func _begin_broadcast() -> void:
	if not ambient_signals_enabled or hovering or powering_off or powered_off:
		return
	signal_style = BroadcastStyle.OPTION if not action_id.is_empty() and not option_text.is_empty() else (BroadcastStyle.SNOW if signal_rng.randf() < 0.5 else BroadcastStyle.COLOR_BARS)
	signal_active = true
	signal_elapsed = 0.0
	signal_hold = signal_rng.randf_range(0.72, 1.32)
	broadcast_started.emit(signal_style)


func _reset_broadcast(reschedule: bool = true) -> void:
	var previous := signal_style
	var was_active := signal_active
	signal_active = false
	signal_style = BroadcastStyle.NONE
	signal_mix = 0.0
	signal_option_mix = 0.0
	signal_noise = 0.0
	signal_dimmer = 1.0
	if reschedule and ambient_signals_enabled:
		signal_wait = signal_rng.randf_range(2.4, 7.8)
	if was_active:
		broadcast_finished.emit(previous)


func _update_broadcast(delta: float) -> void:
	if not ambient_signals_enabled or hovering:
		return
	if not signal_active:
		signal_wait -= delta
		if signal_wait > 0.0:
			return
		_begin_broadcast()
	signal_elapsed += delta
	if signal_elapsed >= signal_hold + 0.32:
		_reset_broadcast()
		return
	var edge_time := signal_elapsed if signal_elapsed < 0.16 else signal_elapsed - (signal_hold + 0.16)
	var transitioning := signal_elapsed < 0.16 or signal_elapsed > signal_hold + 0.16
	var pulse: float = SIGNAL_FLICKER[clampi(int(edge_time / 0.04), 0, 3)] if transitioning else 1.0
	signal_dimmer = pulse
	signal_option_mix = 1.0 if signal_style == BroadcastStyle.OPTION else 0.0
	signal_mix = 0.0 if signal_style == BroadcastStyle.OPTION else 1.0
	signal_noise = 0.82 * (1.0 - pulse) if transitioning else 0.0


func visible_polygon(camera: Camera3D) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for q in [Vector2(-0.5,-0.5), Vector2(0.5,-0.5), Vector2(0.5,0.5), Vector2(-0.5,0.5)]:
		polygon.append(camera.unproject_position(chassis.to_global(Vector3(q.x * glass_size.x, q.y * glass_size.y, 0.025))))
	return polygon


func accepts_hit(world_position: Vector3) -> bool:
	var local := chassis.to_local(world_position)
	var edge := Vector2(absf(local.x), absf(local.y)) - (glass_size * 0.5 - Vector2.ONE * 0.085)
	return edge.max(Vector2.ZERO).length() + minf(maxf(edge.x, edge.y), 0.0) <= 0.085
