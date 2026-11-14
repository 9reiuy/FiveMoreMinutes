extends Node3D
## One visual-only gas instance. The shared owner supplies the scaled clock,
## wind and lights; source textures are immutable imported resources.
const GAS := preload("res://shaders/dream3d/explosion_volume.gdshader")
const IMPACT := preload("res://shaders/dream3d/explosion_impact.gdshader")
const SPARK := preload("res://shaders/dream3d/explosion_spark.gdshader")
const DURATION := 2.8
var library: Resource
var material: ShaderMaterial
var volume: MultiMeshInstance3D
var impact: MultiMeshInstance3D
var impact_material: ShaderMaterial
var sparks: MultiMeshInstance3D
var index_a := -1
var index_b := -1
var spark_angle := 0.0
var age := 0.0

static func source_frame(time: float) -> float:
	if time<.18:return 35.0*smoothstep(0.0,.18,time)
	if time<.72:return lerpf(35.0,90.0,(time-.18)/.54)
	if time<2.0:return lerpf(90.0,160.0,(time-.72)/1.28)
	return lerpf(160.0,199.0,clampf((time-2.0)/.8,0.0,1.0))

func bank(mesh: Mesh,paint: ShaderMaterial,count: int) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_custom_data=true
	multi.mesh=mesh
	multi.instance_count=count
	var carrier := MultiMeshInstance3D.new()
	carrier.multimesh=multi
	carrier.material_override=paint
	carrier.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(carrier)
	return carrier

func _ready() -> void:
	material=ShaderMaterial.new()
	material.shader=GAS
	material.set_shader_parameter("volume_size",library.world_size)
	var box := BoxMesh.new()
	box.size=library.world_size
	volume=bank(box,material,1)
	volume.name="AnimatedGasVolume"
	volume.multimesh.set_instance_transform(0,Transform3D.IDENTITY)
	volume.position=library.world_min+library.world_size*.5
	var ring := PlaneMesh.new()
	ring.size=Vector2(4.2,4.2)
	impact_material=ShaderMaterial.new()
	impact_material.shader=IMPACT
	impact=bank(ring,impact_material,1)
	impact.name="ImpactRing"
	impact.position.y=-.032
	impact.multimesh.set_instance_transform(0,Transform3D.IDENTITY)
	var streak := CylinderMesh.new()
	streak.height=1.0
	streak.top_radius=.010
	streak.bottom_radius=.002
	streak.radial_segments=4
	streak.rings=1
	var spark_material := ShaderMaterial.new()
	spark_material.shader=SPARK
	sparks=bank(streak,spark_material,10)
	sparks.name="BallisticSparks"
	set_age(0.0)
	hide()

func activate(at: Vector3,strength: float,seed_value: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed=seed_value
	position=at
	rotation=Vector3(0,random.randf_range(-PI,PI),0)
	scale=Vector3.ONE*strength
	spark_angle=random.randf_range(-PI,PI)
	show()
	set_age(0.0)

func set_age(time: float) -> void:
	age=maxf(time,0.0)
	var frame := source_frame(age)
	var first := mini(floori(frame/2.0),99)
	var second := mini(first+1,100)
	if index_a!=first:
		material.set_shader_parameter("source_a",library.frames[first])
		index_a=first
	if index_b!=second:
		material.set_shader_parameter("source_b",library.frames[second])
		index_b=second
	var start: float=library.source_frames[first]
	var end: float=library.source_frames[second]
	material.set_shader_parameter("source_mix",clampf((frame-start)/maxf(end-start,1.0),0.0,1.0))
	material.set_shader_parameter("fire_envelope",smoothstep(0.0,.025,age)*(1.0-smoothstep(.28,.72,age)))
	material.set_shader_parameter("smoke_envelope",smoothstep(.025,.16,age)*(1.0-smoothstep(2.1,2.8,age)))
	material.set_shader_parameter("overall_alpha",1.0 if age<DURATION else 0.0)
	impact.visible=age>.002 and age<.26
	impact_material.set_shader_parameter("phase",clampf(age/.26,0.0,1.0))
	var t := maxf(age-.025,0.0)
	sparks.visible=t>0.0 and t<.68
	sparks.multimesh.visible_instance_count=10 if sparks.visible else 0
	for index in 10:
		var theta := float(index)*TAU/10.0+.32*sin(float(index)*2.4)+spark_angle
		var direction := Vector3(cos(theta),.28+.13*float(index%3),sin(theta)).normalized()
		var velocity := direction*(4.2+float(index%4)*.55)
		var at := Vector3(0,.23,0)+velocity*t+Vector3(0,-3.8*t*t,0)
		var y_axis := (velocity+Vector3(0,-7.6*t,0)).normalized()
		var x_axis := y_axis.cross(Vector3.FORWARD).normalized()
		var z_axis := x_axis.cross(y_axis).normalized()
		var stretch := .11+.18*(1.0-clampf(t/.68,0.0,1.0))
		sparks.multimesh.set_instance_transform(index,Transform3D(Basis(x_axis,y_axis*stretch,z_axis),at))
		sparks.multimesh.set_instance_custom_data(index,Color(pow(1.0-clampf(t/.68,0.0,1.0),1.5),0,0,0))
	sync_transform()

func sync_transform() -> void:
	if is_inside_tree():material.set_shader_parameter("world_to_volume",volume.global_transform.affine_inverse())

func retire() -> void:
	hide()
	impact.hide()
	sparks.hide()
	sparks.multimesh.visible_instance_count=0
	material.set_shader_parameter("overall_alpha",0.0)
