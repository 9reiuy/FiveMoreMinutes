extends RefCounted
## Grouped land-side dressing; excludes the central three-metre walking route.
var outline: ShaderMaterial
var footprints: Array[Vector3]=[] # x,z,radius for movement collision.
var rock_count:=0
var concrete_count:=0
var outlined_meshes:=0

var outlines: Array[ShaderMaterial]=[]

func bind(coast: Node3D) -> void:
 for piece in coast.get_node("DuneDressing").get_children():
  if not piece is Node3D or not piece.has_meta("walk_obstacle_radius"): continue
  var p: Vector3=coast.to_local(piece.global_position)
  var basis: Basis=coast.global_basis.inverse()*piece.global_basis
  var radius: float=float(piece.get_meta("walk_obstacle_radius"))*maxf(basis.x.length(),basis.z.length())
  footprints.append(Vector3(p.x,p.z,radius))
  if bool(piece.get_meta("concrete",false)): concrete_count+=1
  else: rock_count+=1
 for border in coast.find_children("GreyOutline","MeshInstance3D",true,false):
  outlined_meshes+=1
  var material: ShaderMaterial=border.material_override
  if not outlines.has(material): outlines.append(material)
 if not outlines.is_empty(): outline=outlines[0]

func resolve_motion(previous: Vector3,target: Vector3) -> Vector3:
 var p:=Vector2(target.x,target.z)
 for feature in footprints:
  var center:=Vector2(feature.x,feature.y)
  var distance:=p.distance_to(center)
  if distance<feature.z+.20:
   var direction: Vector2=(p-center).normalized()
   if direction.length_squared()<.001: direction=(Vector2(previous.x,previous.z)-center).normalized()
   p=center+direction*(feature.z+.20)
 return Vector3(p.x,target.y,p.y)

func set_moon(value: float) -> void:
 for material in outlines: material.set_shader_parameter("moon_visibility",value)
