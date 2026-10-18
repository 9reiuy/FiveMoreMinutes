extends Node3D
## Visual-only industrial trim. Moving details are children of the existing
## door leaves; the door still owns state, collision, opening and orientation.
const PIXEL=preload("res://scripts/dream/office_pixel_materials.gd")
var door: Node3D
var leaf_displays: Array[MeshInstance3D]=[]
var materials: Array[Material]=[
	PIXEL.make(Color("28343d"),"metal",true),
	PIXEL.make(Color("82939c"),"metal",true),
	PIXEL.make(Color("131d25"),"paint",true),
	PIXEL.make(Color("a29a73"),"paint",true)
]
func configure(source: Node3D) -> void:
	door=source
	name="IndustrialFacade"
	for leaf in [door.left_door_mesh,door.right_door_mesh]:
		var display:=MeshInstance3D.new(); display.name="IndustrialLeafPanels"
		display.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		leaf.add_child(display); leaf_displays.append(display)
	refresh()
func box(tools: Array[SurfaceTool], slot: int, size: Vector3, center: Vector3) -> void:
	tools[slot].set_meta(&"has_vertices",true)
	var mesh:=BoxMesh.new(); mesh.size=size
	tools[slot].append_from(mesh,0,Transform3D(Basis.IDENTITY,center))
func tools() -> Array[SurfaceTool]:
	var result: Array[SurfaceTool]=[]
	for material in materials:
		var tool:=SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES); result.append(tool)
	return result
func finish(builders: Array[SurfaceTool]) -> ArrayMesh:
	var mesh:=ArrayMesh.new()
	for i in builders.size():
		if not bool(builders[i].get_meta(&"has_vertices",false)): continue
		builders[i].set_material(materials[i]); builders[i].commit(mesh)
	return mesh
func refresh() -> void:
	for child in get_children(): child.free()
	var width: float=door.opening_width
	var depth: float=door.wall_depth
	var front: float=depth*.5+.025
	var build:=tools()
	# Ribbed jamb cover, sill and lintel cap stay outside the existing throat.
	for side in [-1.0,1.0]:
		var x: float=side*(width*.5+.045)
		box(build,0,Vector3(.16,2.6,.075),Vector3(x,1.3,front))
		box(build,1,Vector3(.055,2.5,.03),Vector3(x,1.3,front+.055))
		for y in [.25,.85,1.45,2.05,2.45]:
			box(build,2,Vector3(.11,.11,.035),Vector3(x,y,front+.06))
			box(build,1,Vector3(.04,.04,.02),Vector3(x,y,front+.085))
	box(build,0,Vector3(width+.3,.38,.09),Vector3(0,2.79,front))
	box(build,1,Vector3(width+.3,.045,.12),Vector3(0,3.0,front))
	box(build,1,Vector3(width+.15,.055,.48),Vector3(0,.03,depth*.5))
	for z in [-.16,-.02,.12]:
		box(build,2,Vector3(width-.2,.008,.035),Vector3(0,.061,depth*.5+z))
	# Small hazard tabs on the fixed jambs; no yellow field across the doorway.
	for side in [-1.0,1.0]:
		box(build,3,Vector3(.12,.16,.03),Vector3(side*(width*.5+.05),.14,front+.065))
	var frame:=MeshInstance3D.new(); frame.name="IndustrialFrameTrim"
	frame.mesh=finish(build); frame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(frame)
	var leaf_width: float=(door.left_door_mesh.mesh as BoxMesh).size.x
	for i in leaf_displays.size():
		var leaf_build:=tools()
		var face: float=(door.left_door_mesh.mesh as BoxMesh).size.z*.5+.014
		# Southern floor entrances expose the reverse leaf face to the fixed
		# gameplay camera. Both faces must carry the same industrial structure.
		for side in [-1.0,1.0]:
			box(leaf_build,2,Vector3(leaf_width-.17,2.2,.025),Vector3(0,0,side*face))
			box(leaf_build,0,Vector3(leaf_width-.24,2.12,.022),Vector3(0,0,side*(face+.02)))
			for x in [-leaf_width*.32,leaf_width*.32]:
				box(leaf_build,1,Vector3(.045,2.15,.027),Vector3(x,0,side*(face+.035)))
			for y in [-.9,.0,.9]:
				box(leaf_build,1,Vector3(leaf_width-.2,.035,.028),Vector3(0,y,side*(face+.04)))
			box(leaf_build,2,Vector3(.065,2.5,.03),Vector3((1 if i==0 else -1)*(leaf_width*.5-.045),0,side*(face+.035)))
		leaf_displays[i].mesh=finish(leaf_build)
