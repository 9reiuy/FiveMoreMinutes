extends Node3D
## One independently configurable screen: idle mosaic -> static -> option.

signal activated(action: StringName)

const CRT_SHADER := preload("res://shaders/ui/screen_wall_crt.gdshader")
const FONT := preload("res://assets/fonts/boutique_bitmap/BoutiqueBitmap9x9_Bold_1.9.ttf")
@export var action_id: StringName = &""
@export var option_text := ""
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


func configure(tv: Node3D, index: int) -> void:
	chassis = tv
	action_id = StringName(tv.get_meta("action_id", ""))
	option_text = tv.get_meta("option_text", "")
	glass_size = tv.get_meta("screen_size")
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
	effect.set_shader_parameter("screen_tint", tv.get_meta("screen_tint"))
	effect.set_shader_parameter("channel_seed", float(index))
	screen.material_override = effect
	# The screens are the room's only light sources. A short-range light at
	# the front glass approximates their diffuse spill in Compatibility mode.
	spill_light = OmniLight3D.new()
	spill_light.name = "ScreenEmissionLight"
	spill_light.position = Vector3(0, 0, 0.42)
	spill_light.light_color = Color.WHITE.lerp(tv.get_meta("screen_tint"), 0.35)
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
	text.add_theme_font_size_override("font_size", 72 if option_text.length() <= 3 else 62)
	text.add_theme_color_override("font_color", Color("dcf5ed"))
	text.add_theme_color_override("font_outline_color", Color("274f58"))
	text.add_theme_constant_override("outline_size", 2)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.size = Vector2(viewport.size)
	viewport.add_child(text)
	var english := {&"new_game": "NEW GAME", &"continue": "CONTINUE", &"settings": "SETTINGS", &"quit": "EXIT"}
	var small := Label.new()
	small.text = "%02d   /   %s" % [index + 1, english.get(action_id, "")]
	small.add_theme_font_override("font", FONT)
	small.add_theme_font_size_override("font_size", 19)
	small.add_theme_color_override("font_color", Color("8abfbe"))
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.position = Vector2(0, viewport.size.y * 0.5 - 76)
	small.size = Vector2(viewport.size.x, 22)
	viewport.add_child(small)
	return viewport


func set_hovered(value: bool) -> void:
	if value == hovering:
		return
	hovering = value
	hover_seconds = 0.0
	if value:
		phase = "static"
	else:
		phase = "release"


func activate() -> void:
	if action_id.is_empty():
		return
	press_flash = 1.0
	activated.emit(action_id)


func is_ready_to_activate() -> bool:
	return hovering and not action_id.is_empty() and hover_seconds >= 0.34


func _process(delta: float) -> void:
	if effect == null:
		return
	elapsed += delta
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
	effect.set_shader_parameter("noise_amount", noise_amount)
	effect.set_shader_parameter("option_mix", option_mix)
	effect.set_shader_parameter("proximity", 1.0 if hovering else 0.0)
	effect.set_shader_parameter("press_flash", press_flash)
	spill_light.light_energy = spill_energy * (1.0 - option_mix * 0.48)


func visible_polygon(camera: Camera3D) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for q in [Vector2(-0.5,-0.5), Vector2(0.5,-0.5), Vector2(0.5,0.5), Vector2(-0.5,0.5)]:
		polygon.append(camera.unproject_position(chassis.to_global(Vector3(q.x * glass_size.x, q.y * glass_size.y, 0.025))))
	return polygon


func accepts_hit(world_position: Vector3) -> bool:
	var local := chassis.to_local(world_position)
	var edge := Vector2(absf(local.x), absf(local.y)) - (glass_size * 0.5 - Vector2.ONE * 0.085)
	return edge.max(Vector2.ZERO).length() + minf(maxf(edge.x, edge.y), 0.0) <= 0.085
