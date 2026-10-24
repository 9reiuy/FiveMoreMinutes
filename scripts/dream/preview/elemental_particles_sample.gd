extends Node3D
const EFFECTS=preload("res://scripts/dream/elemental_particles_3d.gd")
var effects: Node3D
var camera: Camera3D
var status: Label
var auto_explosion := true
var burst_clock := 0.0
var wind_mode := 0
func _ready() -> void:
	get_tree().root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.content_scale_size=Vector2i(640,360)
	var environment:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("141724")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("9babc5")
	env.ambient_light_energy=.65
	environment.environment=env
	add_child(environment)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=6.8
	add_child(camera)
	camera.position=Vector3(7,8,11)
	camera.look_at(Vector3(0,.65,0))
	camera.current=true
	var key:=DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-50,-25,0)
	key.light_energy=.5
	add_child(key)
	_box(Vector3(0,-.13,0),Vector3(10,.25,5),Color("555663"))
	_box(Vector3(0,1.0,-2.25),Vector3(10,2.0,.15),Color("343a4c"))
	# A short foreground block deliberately occludes particles; effects are
	# genuine world geometry, not a screen overlay that shines through walls.
	_box(Vector3(1.5,.32,1.3),Vector3(1.0,.64,.20),Color("6b7180"))
	for x in [-3.0,0.0,3.0]:
		_box(Vector3(x,.02,0),Vector3(2.0,.05,2.0),Color("303442"))
		var caption:=Label3D.new()
		caption.text="持续火焰" if x<0 else ("爆炸" if x==0 else "烟雾")
		caption.position=Vector3(x,.1,1.4)
		caption.pixel_size=.007
		caption.font_size=24
		caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		add_child(caption)
	effects=EFFECTS.new()
	add_child(effects)
	reset_effects()
	var ui:=CanvasLayer.new()
	add_child(ui)
	status=Label.new()
	status.position=Vector2(12,10)
	status.add_theme_font_size_override("font_size",16)
	ui.add_child(status)
	_update_status()

func _box(at: Vector3,size: Vector3,tint: Color) -> void:
	var visual:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	visual.mesh=mesh
	var material:=StandardMaterial3D.new()
	material.albedo_color=tint
	material.roughness=1.0
	visual.material_override=material
	visual.position=at
	add_child(visual)

func reset_effects() -> void:
	effects.clear()
	effects.emit_fire(Vector3(-3,.12,0))
	effects.emit_smoke(Vector3(3,.12,0),16)
	effects.explode(Vector3(0,.25,0),.85)
	burst_clock=0.0

func _process(delta: float) -> void:
	burst_clock+=delta
	if auto_explosion and burst_clock>=4.0:
		burst_clock=0.0
		effects.explode(Vector3(0,.25,0),.85)
		effects.emit_smoke(Vector3(3,.12,0),12)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_1: wind_mode=0; effects.set_wind(Vector3.ZERO)
		KEY_2: wind_mode=-1; effects.set_wind(Vector3(-1.8,0,0))
		KEY_3: wind_mode=1; effects.set_wind(Vector3(1.8,0,0))
		KEY_SPACE: effects.explode(Vector3(0,.25,0),.85)
		KEY_R: reset_effects()
		_: return
	_update_status()
	get_viewport().set_input_as_handled()

func _update_status() -> void:
	status.text="火焰 / 爆炸 / 烟雾 · 独立样板\n1 无风  2 左风  3 右风  空格 爆炸  R 重置\n当前：%s" % ("无风" if wind_mode==0 else ("左风" if wind_mode<0 else "右风"))
