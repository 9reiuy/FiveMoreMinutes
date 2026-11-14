extends Node3D
## Steel hatch and authoritative 2D solid; future rooms stay locked red.
@export var width := 3.0
@export var height := 2.7
@export var collision_layer := 4
@export var indicator_light_scale := 1.0
var is_open := false
var body: StaticBody2D
var motion: Tween
var status_light: OmniLight3D
var indicator_power_enabled := true
func set_indicator_power_enabled(enabled: bool) -> void:
	if indicator_power_enabled==enabled:return
	indicator_power_enabled=enabled
	_set_indicator(is_open)
func bind_gameplay(root: Node2D) -> void:
	$Indicator.material_override=$Indicator.material_override.duplicate()
	status_light=OmniLight3D.new(); status_light.name="StatusLight"
	status_light.position=Vector3(0,height+.09,.4);status_light.omni_range=4.2
	status_light.omni_attenuation=1.2;status_light.light_specular=.6
	status_light.light_cull_mask=15;status_light.shadow_caster_mask=15
	status_light.shadow_enabled=true;status_light.shadow_bias=.03;status_light.shadow_normal_bias=.08
	add_child(status_light)
	body=StaticBody2D.new(); body.name=name+"Collision"; body.collision_layer=collision_layer; body.collision_mask=0
	var shape:=CollisionShape2D.new(); var box:=RectangleShape2D.new(); box.size=Vector2(width,.16)*32.; shape.shape=box; body.add_child(shape)
	root.add_child(body); body.position=Vector2(global_position.x,global_position.z)*32.; body.rotation=-global_rotation.y
	_set_indicator(false)
	if name=="PreparationDoor": set_open(true)
func _set_indicator(unlocked: bool) -> void:
	var light: StandardMaterial3D=$Indicator.material_override
	light.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var colour := Color(.28,1.,.43) if unlocked else Color(1.,.08,.04)
	light.albedo_color=colour if indicator_power_enabled else Color.BLACK
	light.emission_enabled=indicator_power_enabled;light.emission=colour;light.emission_energy_multiplier=1.2
	if is_instance_valid(status_light):
		status_light.visible=indicator_power_enabled
		status_light.light_color=colour
		status_light.light_energy=(1.8 if unlocked else 2.6)*indicator_light_scale
func set_open(value: bool) -> void:
	if value==is_open: return
	is_open=value
	if is_instance_valid(motion): motion.kill()
	if not value and is_instance_valid(body): body.set_deferred("collision_layer",collision_layer)
	motion=create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property($Leaf,"position:y",-height if value else height*.5,.32)
	if value and is_instance_valid(body):
		motion.tween_callback(func():
			if is_instance_valid(body):body.set_deferred("collision_layer",0))
	_set_indicator(value)
func _exit_tree() -> void:
	var ancestor: Node=self
	while ancestor!=null:
		if ancestor.has_meta(&"display_reparenting"):return
		ancestor=ancestor.get_parent()
	if is_instance_valid(motion):motion.kill()
	if is_instance_valid(body): body.queue_free()
