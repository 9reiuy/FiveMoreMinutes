extends RefCounted
## Animate the imported cannon and six-port launcher, without modifying the GLB.
var model: Node3D
var barrel: Node3D
var cannon: Node3D
var turret: Node3D
var upper_body: Node3D
var pod: Node3D
var pod_base: Node3D
var barrel_rest := Vector3.ZERO
var pod_rest := Vector3.ZERO
var base_rest := Vector3.ZERO
var lid_rest := Vector3.ZERO
var lid_open := 0.0
var recoil := 0.0
var rack_kick := 0.0
var elevation := 0.0
var raise_launcher := false
var relax_cannon := true

func configure(visual: Node3D) -> void:
	model=visual
	barrel=model.find_child("Howitzer_Pitch_Mesh",true,false) as Node3D
	cannon=model.find_child("Howitzer_Pitch",true,false) as Node3D
	turret=model.find_child("Howitzer_Yaw",true,false) as Node3D
	upper_body=model.find_child("UpperBody",true,false) as Node3D
	pod=model.find_child("MissilePod_Pitch",true,false) as Node3D
	pod_base=model.find_child("MissilePod_Base",true,false) as Node3D
	barrel_rest=barrel.position
	pod_rest=pod.rotation
	base_rest=pod_base.position
	lid_rest=upper_body.position

func advance(delta: float) -> void:
	recoil=move_toward(recoil,0,delta*1.35)
	rack_kick=move_toward(rack_kick,0,delta*1.8)
	elevation=move_toward(elevation,1. if raise_launcher else 0.,delta*4.2)
	if relax_cannon:turret.rotation.y=lerp_angle(turret.rotation.y,0.,1.-exp(-delta*9.))
	_apply()

func _apply() -> void:
	upper_body.position=lid_rest+Vector3.UP*(.88*lid_open)
	barrel.position=barrel_rest-Vector3(0,0,recoil)
	pod.rotation=pod_rest+Vector3(-deg_to_rad(68.)*elevation-rack_kick*.14,0,0)
	pod_base.position=base_rest+Vector3.UP*(elevation*.15-rack_kick*.025)

func fire_cannon() -> void:
	recoil=.36
	_apply()

func fire_port(index: int) -> Vector3:
	rack_kick=.2
	_apply()
	# The emissive tube mouths in the original atlas mesh form three columns,
	# two rows. These are their actual coordinates in the pitch pivot space.
	var column:=index%3
	var row:=floori(float(index)/3.)
	return pod.to_global(Vector3(-.20+column*.20,.064-row*.128,.610))

func cannon_muzzle() -> Vector3:
	# Imported barrel mesh is rotated 90 degrees about X; its +Y tip is +Z.
	return barrel.to_global(Vector3(0,1.885,0))

func aim_cannon(at: Vector3) -> void:
	relax_cannon=false
	var local:Vector3=(turret.get_parent() as Node3D).to_local(at)-turret.position
	turret.rotation.y=atan2(local.x,local.z)

func launch_direction() -> Vector3:
	return pod.global_basis.z.normalized()

func open_lid(progress: float) -> void:
	lid_open=smoothstep(0.,1.,progress)
	_apply()

func reset() -> void:
	raise_launcher=false
	elevation=0
	recoil=0
	rack_kick=0
	lid_open=0
	turret.rotation.y=0
	relax_cannon=true
	_apply()
