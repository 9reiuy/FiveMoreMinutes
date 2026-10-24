extends Node3D
## Original model tumble, then the shared outlined particle explosion.
var model: Node3D
var flying:=false
var elapsed:=0.0
var burst_started:=false
var base_transform: Transform3D
var owner_world: Node3D
var elemental: Node3D

func begin(source: Node3D, airborne: bool, p_world: Node3D=null) -> void:
	name="UnitDeathEffect"
	set_meta(&"unit_death_effect",true)
	flying=airborne
	owner_world=p_world
	global_position=source.global_position
	model=source
	model.reparent(self)
	base_transform=model.transform
	for node in model.find_children("*","Light3D",true,false):node.hide()
	for node in model.find_children("*","MeshInstance3D",true,false):node.material_overlay=null

func _process(delta: float) -> void:
	elapsed+=delta
	var tumble:=.65 if flying else .42
	if not burst_started:
		if not is_instance_valid(model):queue_free();return
		var t:=clampf(elapsed/tumble,0,1)
		model.transform=base_transform
		model.rotate_object_local(Vector3.FORWARD,t*(4.5 if flying else 1.45))
		if flying:
			model.rotate_object_local(Vector3.RIGHT,t*2.5)
			model.position+=Vector3(.35*t,-2.2*t*t,0)
		else:model.position.y+=.08*sin(t*PI)
		if t>=1.0:burst()
	elif elapsed-tumble>=2.6:queue_free()

func burst() -> void:
	if burst_started or not is_instance_valid(model):return
	burst_started=true
	var at:=model.global_position+Vector3.UP*.2
	model.hide()
	if is_instance_valid(owner_world):
		elemental=preload("res://scripts/dream/burning_effects.gd").install(owner_world)
		elemental.explosion(at)
	else:
		elemental=preload("res://scripts/dream/elemental_particles_3d.gd").new()
		add_child(elemental)
		elemental.explode(elemental.to_local(at),1.65)
