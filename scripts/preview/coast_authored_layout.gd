extends RefCounted
## Reads saved nodes. No geometry is created or transforms reset at startup.
var terrain: MeshInstance3D
var vertices: PackedVector3Array
var cols := 261
var rows := 131
var x0 := -65.0
var z0 := -20.0
var spacing := .5

func bind(coast: Node3D) -> void:
 terrain=coast.get_node("SandRidge")
 var arrays:=terrain.mesh.surface_get_arrays(0)
 vertices=arrays[Mesh.ARRAY_VERTEX]
 assert(vertices.size()==cols*rows,"Coast terrain must retain its height-grid topology.")

func local_point(x: float,z: float) -> Vector3:
 return terrain.transform.affine_inverse()*Vector3(x,terrain.position.y,z)

func height_at(x: float,z: float) -> float:
 var p:=local_point(x,z)
 var gx:=clampf((p.x-x0)/spacing,0,cols-1.00001)
 var gz:=clampf((p.z-z0)/spacing,0,rows-1.00001)
 var ix:=int(gx); var iz:=int(gz)
 var u:=gx-ix; var v:=gz-iz
 var i:=iz*cols+ix
 var a:=vertices[i].y; var b:=vertices[i+1].y
 var c:=vertices[i+cols].y; var d:=vertices[i+cols+1].y
 var h: float=a+(b-a)*u+(c-a)*v if u+v<=1 else d+(c-d)*(1-u)+(b-d)*(1-v)
 return (terrain.transform*Vector3(p.x,h,p.z)).y

func read_breakers(coast: Node3D) -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 for piece in coast.get_node("WaveBreakers").get_children():
  if not piece is Node3D or not piece.has_meta("flow_obstacle_radius"): continue
  var p: Vector3=coast.to_local(piece.global_position)
  var basis: Basis=coast.global_basis.inverse()*piece.global_basis
  result.append({"p":Vector2(p.x,p.z),"radius":float(piece.get_meta("flow_obstacle_radius"))*maxf(basis.x.length(),basis.z.length()),"concrete":bool(piece.get_meta("concrete",false)),"yaw":piece.rotation.y})
 return result

func materials(coast: Node) -> Array[ShaderMaterial]:
 var found: Array[ShaderMaterial]=[]
 for node in coast.find_children("*","",true,false):
  var material: Material
  if node is MeshInstance3D: material=node.material_override
  elif node is CanvasItem: material=node.material
  if material is ShaderMaterial and not found.has(material): found.append(material)
 return found
