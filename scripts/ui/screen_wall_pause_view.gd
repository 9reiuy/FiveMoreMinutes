extends "res://scripts/preview/screen_wall_review.gd"
const PAUSE_MODEL := preload("res://art/preview/screen_wall/pause/screen_wall_pause_model.tscn")
const PAUSE_DISPLAY := preload("res://scripts/ui/screen_wall_pause_display.gd")
const REST_Y := 3.65
const CRT_COLORS := preload("res://scripts/ui/screen_wall_colors.gd")
var terminal: Node3D
var entering := false
var drop_tween: Tween
var scan_tween: Tween
var scanning := false
func _create_model() -> Node3D:
	return PAUSE_MODEL.instantiate()
func _setup_camera_and_lights() -> void:
	super._setup_camera_and_lights()
	camera.position=Vector3(0,3.65,12)
	camera.fov=28.0
	camera.look_at(Vector3(0,3.65,0))
	get_node("ScreenRoomLighting").environment.background_color=Color(0,0,0,0)
func _setup_overlay() -> void:
	var layer:=CanvasLayer.new()
	layer.name="TubeGlow"
	add_child(layer)
	var finish:=ColorRect.new()
	finish.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	finish.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/ui/screen_wall_pause_finish.gdshader")
	finish.material=material
	layer.add_child(finish)
func _ready() -> void:
	preview_only=false
	show_footer=false
	super._ready()
	terminal=PAUSE_DISPLAY.new()
	model.get_node("SettingsTerminal").add_child(terminal)
	terminal.configure(model.get_node("SettingsTerminal"),5)
	var parameters:={}
	for uniform in terminal.effect.shader.get_shader_uniform_list():
		parameters[uniform.name]=terminal.effect.get_shader_parameter(uniform.name)
	terminal.effect.shader=preload("res://shaders/ui/screen_wall_pause_crt.gdshader")
	var supported: Dictionary={}
	for uniform in terminal.effect.shader.get_shader_uniform_list(): supported[uniform.name]=true
	for name in parameters:
		if supported.has(name): terminal.effect.set_shader_parameter(name,parameters[name])
	terminal.full_content=true
	terminal.chassis.show()
	terminal.spill_light.position.z=3.0
	terminal.spill_light.omni_range=7.0
	terminal.spill_energy=6.0
	terminal.effect.set_shader_parameter("idle_snow_strength",0.045)
	terminal.base_tint=CRT_COLORS.primary()
	terminal.effect.set_shader_parameter("screen_tint",terminal.base_tint)
	terminal.spill_light.light_color=terminal.base_tint
	terminal.effect.set_shader_parameter("glass_axes_uv",Vector4(0.65,0,0,0.85))
func set_content_texture(texture: Texture2D) -> void:
	terminal.effect.set_shader_parameter("option_image",texture)
func activate_view() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	entering=true
	terminal.chassis.position.y=REST_Y+7.0
	if drop_tween!=null and drop_tween.is_valid(): drop_tween.kill()
	drop_tween=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	drop_tween.tween_property(terminal.chassis,"position:y",REST_Y-0.18,0.21).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	drop_tween.tween_property(terminal.chassis,"position:y",REST_Y+0.045,0.075).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drop_tween.tween_property(terminal.chassis,"position:y",REST_Y,0.055).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	drop_tween.tween_callback(func():entering=false)
func deactivate_view() -> void:
	stop_settings_scan()
	if drop_tween!=null and drop_tween.is_valid(): drop_tween.kill()
	entering=false
	hover_audio.stop()
	if hover_audio_tween!=null and hover_audio_tween.is_valid(): hover_audio_tween.kill()
	process_mode=Node.PROCESS_MODE_DISABLED
func play_hover_cue() -> void:
	terminal.set_hovered(false)
	terminal.noise_amount=0.0
	terminal.effect.set_shader_parameter("noise_amount",0.0)
	_play_hover_sound()
func _process(delta: float) -> void:
	if terminal!=null and scanning: terminal.noise_amount=0.0

func begin_settings_scan(previous: Texture2D) -> void:
	stop_settings_scan()
	scanning=true
	terminal.hovering=false
	terminal.noise_amount=0.0
	terminal.effect.set_shader_parameter("previous_page",previous)
	terminal.effect.set_shader_parameter("page_scan_active",1.0)
	terminal.effect.set_shader_parameter("page_scan",0.0)
	scan_tween=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	scan_tween.tween_method(func(value: float):terminal.effect.set_shader_parameter("page_scan",value),0.0,1.0,0.17)
	scan_tween.tween_callback(stop_settings_scan)
func stop_settings_scan() -> void:
	if scan_tween!=null and scan_tween.is_valid(): scan_tween.kill()
	scan_tween=null
	scanning=false
	if terminal!=null:
		terminal.effect.set_shader_parameter("page_scan_active",0.0)
		terminal.effect.set_shader_parameter("previous_page",null)
func screen_to_content(point: Vector2,allow_outside: bool=false) -> Vector2:
	var origin:=camera.project_ray_origin(point)
	var direction:=camera.project_ray_normal(point)
	var normal: Vector3=terminal.chassis.global_basis.z.normalized()
	var denominator:=normal.dot(direction)
	if denominator>=-0.05: return Vector2(-10000,-10000)
	var distance: float=(terminal.chassis.to_global(Vector3(0,0,0.025))-origin).dot(normal)/denominator
	if distance<0: return Vector2(-10000,-10000)
	var hit:=origin+direction*distance
	if not allow_outside and not terminal.accepts_hit(hit): return Vector2(-10000,-10000)
	var local: Vector3=terminal.chassis.to_local(hit)
	var uv:=Vector2(local.x/terminal.glass_size.x+0.5,0.5-local.y/terminal.glass_size.y)
	var centered:=uv*2.0-Vector2.ONE
	return uv+centered*centered.length_squared()*0.06*0.5
func content_to_screen(uv: Vector2) -> Vector2:
	var glass_uv:=uv
	for index in 10:
		var centered:=glass_uv*2.0-Vector2.ONE
		glass_uv+=uv-(glass_uv+centered*centered.length_squared()*0.06*0.5)
	var point: Vector3=terminal.chassis.to_global(Vector3((glass_uv.x-0.5)*terminal.glass_size.x,(0.5-glass_uv.y)*terminal.glass_size.y,0.025))
	return camera.unproject_position(point)
