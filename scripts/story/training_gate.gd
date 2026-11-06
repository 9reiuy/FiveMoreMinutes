extends Node3D
## Steel hatch and authoritative 2D solid; future rooms stay locked red.
@export var width := 3.0
@export var height := 2.7
@export var collision_layer := 4
var is_open := false
var body: StaticBody2D
var motion: Tween
var status_light: OmniLight3D
func bind_gameplay(root: Node2D) -> void:
	$Indicator.material_override=$Indicator.material_override.duplicate()
	status_light=OmniLight3D.new(); status_light.name="StatusLight"
	status_light.position=Vector3(0,height+.09,.3); status_light.omni_range=.75
	status_light.shadow_enabled=false; status_light.light_specular=0.; add_child(status_light)
	var header_fill := OmniLight3D.new()
	header_fill.name = "HeaderFill"
	header_fill.position = Vector3(0,height+.3,.65)
	header_fill.light_color = Color("9aa9bb")
	header_fill.light_energy = .45
	header_fill.omni_range = 2.4
	header_fill.light_specular = 0.
	header_fill.shadow_enabled = true
	add_child(header_fill)
	body=StaticBody2D.new(); body.name=name+"Collision"; body.collision_layer=collision_layer; body.collision_mask=0
	var shape:=CollisionShape2D.new(); var box:=RectangleShape2D.new(); box.size=Vector2(width,.16)*32.; shape.shape=box; body.add_child(shape)
	root.add_child(body); body.position=Vector2(global_position.x,global_position.z)*32.; body.rotation=-global_rotation.y
	_set_indicator(false)
	if name=="PreparationDoor": set_open(true)
func _set_indicator(unlocked: bool) -> void:
	var light: StandardMaterial3D=$Indicator.material_override
	# Exact primary markers keep the tiny LED readable through the world palette.
	light.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	light.albedo_color=Color(0,1,0) if unlocked else Color(1,0,0)
	light.emission_enabled=false
	if is_instance_valid(status_light):
		status_light.light_color=Color(.28,1.,.43) if unlocked else Color(1.,.08,.04)
		status_light.light_energy=.3 if unlocked else .055
func set_open(value: bool) -> void:
	if value==is_open: return
	is_open=value
	if is_instance_valid(motion): motion.kill()
	if not value and is_instance_valid(body): body.set_deferred("collision_layer",collision_layer)
	motion=create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property($Leaf,"position:y",-height if value else height*.5,.32)
	if value and is_instance_valid(body): motion.tween_callback(func(): body.set_deferred("collision_layer",0))
	_set_indicator(value)
func _exit_tree() -> void:
	if is_instance_valid(body): body.queue_free()
