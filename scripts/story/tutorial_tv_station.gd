@tool
extends Node3D
## Main Menu CRT chassis used as an in-world live monitor.
const ART=preload("res://scripts/testing/maintenance_environment.gd")
const TELEVISION=preload("res://scripts/preview/screen_wall_builder.gd")
const FEED_SHADER=preload("res://shaders/dream3d/tutorial_tv_feed.gdshader")
const TERMINAL=preload("res://scripts/story/tutorial_terminal.gd")
@export var table_enabled := true
@export var conversation_enabled := false
var interaction_target: Node2D
var collision_body: StaticBody2D
var screen_material: ShaderMaterial
var screen_light: OmniLight3D
var screen_mesh: MeshInstance3D
var screen_active := false
var power_available := true
var speaking := false

func set_power_available(enabled: bool) -> void:
	power_available=enabled
	if not enabled:set_screen_active(false)

func _ready() -> void:
	var top:=ART.metal(Color("566064"),.72)
	var steel:=ART.metal(Color("252e33"),.68)
	if table_enabled:
		var table:=Node3D.new();table.name="Table";add_child(table)
		ART.box(table,"Top",Vector3(3.6,.12,1.4),Vector3(0,.91,0),top)
		for x in [-1.55,1.55]:
			for z in [-.55,.55]:ART.box(table,"Leg",Vector3(.10,.86,.10),Vector3(x,.43,z),steel)
		ART.box(table,"Crossbar",Vector3(3.2,.08,.08),Vector3(0,.27,-.55),steel)
	else:
		ART.box(self,"WallMount",Vector3(.7,.07,.32),Vector3(0,.65,-.65),steel)
		ART.box(self,"WallPlate",Vector3(.65,.45,.06),Vector3(0,.90,-.76),steel)
	var tv: Node3D=TELEVISION._television(0,Vector2(1.4,.95),"",Color("86c6cf"))
	var screen_height:=1.54 if table_enabled else 1.25
	tv.name="Television";tv.position=Vector3(0,screen_height,.25);add_child(tv)
	if not table_enabled:tv.get_node("CC0_Antenna").hide()
	# The solid housing owns its shadow. Sub-pixel vents/LED/antenna details
	# must not create the oversized striped shadows seen on adjacent walls.
	for part in tv.find_children("*","MeshInstance3D",true,false):
		if part.name!="CC0_CRT_Chassis":part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tv.get_node("ChassisID").cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tv.get_node("ChassisID").shaded=true
	screen_material=ShaderMaterial.new();screen_material.shader=FEED_SHADER
	screen_material.set_meta(&"runtime_uniform_owner",true)
	screen_material.set_shader_parameter("glass_size",Vector2(1.4,.95))
	screen_mesh=tv.get_node("Screen");screen_mesh.material_override=screen_material
	screen_mesh.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	screen_light=OmniLight3D.new();screen_light.name="ScreenLight";screen_light.position=Vector3(0,screen_height-.04,.8)
	screen_light.light_color=Color("86c6cf");screen_light.light_energy=.48;screen_light.omni_range=2.7;screen_light.omni_attenuation=1.5
	screen_light.light_cull_mask=15;screen_light.shadow_caster_mask=15;screen_light.shadow_enabled=true
	screen_light.shadow_bias=.03;screen_light.shadow_normal_bias=.08;screen_light.visible=false;add_child(screen_light)
	# Apply the off state to the factory LED before this room is ever entered.
	screen_active=true;set_screen_active(false)
	set_meta(&"menu_tv_source",TELEVISION.CRT)

func set_camera_feed(texture: Texture2D) -> void:
	screen_material.set_shader_parameter("camera_feed",texture)

func _process(_delta: float) -> void:
	if speaking:
		screen_material.set_shader_parameter("noise_time",float(Time.get_ticks_msec()%120000)/1000.0)

func set_speaking(enabled: bool) -> void:
	enabled=enabled and power_available and screen_active
	if speaking==enabled:return
	speaking=enabled
	if screen_material!=null:screen_material.set_shader_parameter("speech_static",enabled)

func set_screen_active(enabled: bool) -> void:
	enabled=enabled and power_available
	if not enabled:set_speaking(false)
	if screen_active==enabled:return
	screen_active=enabled
	screen_material.set_shader_parameter("screen_power",enabled)
	screen_light.visible=enabled
	var led: MeshInstance3D=get_node("Television/StatusLED")
	var material: StandardMaterial3D=led.material_override
	material.albedo_color=Color("86c6cf") if enabled else Color.BLACK
	material.emission_enabled=enabled

func bind_gameplay(root: Node2D) -> void:
	if is_instance_valid(collision_body):return
	collision_body=StaticBody2D.new();collision_body.name="TelevisionDeskCollision"
	collision_body.collision_layer=4;collision_body.collision_mask=0
	var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=(Vector2(3.6,1.4) if table_enabled else Vector2(2.1,1.0))*32.0
	shape.shape=rectangle;collision_body.add_child(shape);root.add_child(collision_body)
	collision_body.global_position=Vector2(global_position.x,global_position.z)*32.0
	collision_body.rotation=-global_rotation.y
	if not conversation_enabled:return
	interaction_target=TERMINAL.new();interaction_target.name="TutorialTelevision";root.add_child(interaction_target)
	var face:=to_global(Vector3(0,0,.30))
	interaction_target.global_position=Vector2(face.x,face.z)*32.0

func _exit_tree() -> void:
	var ancestor: Node=self
	while ancestor!=null:
		if ancestor.has_meta(&"display_reparenting"):return
		ancestor=ancestor.get_parent()
	if is_instance_valid(collision_body):collision_body.queue_free()
	if is_instance_valid(interaction_target):interaction_target.queue_free()
