extends Node3D
## Original low-poly camera. No capture viewport or duplicate simulation.
var target: Node2D
var head: Node3D
static func create(world: Node3D, site: Dictionary) -> Node3D:
	var camera: Node3D = load("res://scripts/story/surveillance_camera.gd").new()
	camera.target = world.player
	var point: Vector2 = site.point + site.inward * .08
	camera.position = Vector3(point.x, 2.2, point.y)
	camera.rotation.y = atan2(site.inward.x, site.inward.y)
	camera.set_meta(&"wall_site", site.duplicate(true))
	return camera

func _ready() -> void:
	var world: Node = get_parent().get_parent()
	var site: Dictionary = get_meta(&"wall_site", {})
	if world.has_method("register_wall_attachment") and site.has("edge"):
		world.register_wall_attachment(self, site.edge)
	_asset(self,"camera_mount")
	head=Node3D.new(); head.position=Vector3(0,-.14,.415); add_child(head)
	_asset(head,"camera_head")
	var cone:=SpotLight3D.new(); cone.name="MonitoringCone"
	cone.position=Vector3(0,-.03,.4); cone.rotation=Vector3(-.6,PI,0)
	cone.light_color=Color(.38,.57,.66); cone.light_energy=.09
	cone.spot_range=4.; cone.spot_angle=38.; cone.spot_attenuation=1.1
	cone.light_specular=0.; cone.shadow_enabled=false; head.add_child(cone)
func _asset(parent: Node3D,name: String) -> void:
	var mesh:=MeshInstance3D.new(); mesh.mesh=load("res://art/story/chapter1/"+name+".obj"); mesh.material_override=load("res://art/story/chapter1/"+name+".tres"); parent.add_child(mesh)
func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.dead: return
	var world: Node3D=get_parent().get_parent()
	var destination: Vector3=world.to_global(Vector3(target.global_position.x/32.,1.,target.global_position.y/32.))
	var local:=to_local(destination)-head.position
	head.rotation.y=lerp_angle(head.rotation.y,atan2(local.x,local.z),1.-exp(-delta*3.))
