extends RefCounted
## Authored lobby dressing. The room owns gameplay and interactions; this
## builder reuses approved furniture and batches static decorative surfaces.
const ART = preload("res://scripts/dream/office_room_low_pixel_art.gd")
const PIXEL = preload("res://scripts/dream/office_pixel_materials.gd")
var room: Node3D
var batches: Dictionary = {}
var palette := {
	"dark": Color("29333e"), "metal": Color("667a8d"),
	"white": Color("ced5d8"), "blue": Color("324e77"),
	"green": Color("416347"), "leaf": Color("718b52"),
	"stem": Color("384638"), "lamp": Color("ecdcb9"),
	"led": Color("529ecd"), "rug": Color("293f58")
}
func build(target: Node3D) -> void:
	room=target
	_lounge(); _back_office(); _gates(); _plants(); _architecture()
	for chunk: Vector2i in batches:
		var mesh := ArrayMesh.new()
		for key in batches[chunk]:
			var tool: SurfaceTool=batches[chunk][key]
			tool.set_material(PIXEL.make(palette[key],"fabric" if key=="rug" else "paint",false,key in ["lamp","led"]))
			tool.commit(mesh)
		var visual := MeshInstance3D.new()
		visual.name="LobbyDetails_%d_%d"%[chunk.x,chunk.y]; visual.mesh=mesh
		visual.position=Vector3(chunk.x*8+4,0,chunk.y*8+4)
		room.props_root.add_child(visual)
func box(key: String, size: Vector3, point: Vector3, basis: Basis=Basis.IDENTITY) -> void:
	var chunk:=Vector2i(floori(point.x/8),floori(point.z/8))
	if not batches.has(chunk): batches[chunk]={}
	if not batches[chunk].has(key):
		var tool:=SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES); batches[chunk][key]=tool
	var shape:=BoxMesh.new(); shape.size=size
	(batches[chunk][key] as SurfaceTool).append_from(shape,0,Transform3D(basis,point-Vector3(chunk.x*8+4,0,chunk.y*8+4)))
func prop(kind: String, point: Vector2, yaw: float, footprint: Vector2, label: String) -> Node3D:
	var item: Node3D=ART.make_visual(kind)
	item.name=label; item.position=Vector3(point.x,0,point.y); item.rotation.y=yaw
	item.set_meta(&"lobby_kind",kind); room.props_root.add_child(item)
	if footprint.length_squared()>0:
		var size:=Vector2(footprint.y,footprint.x) if absf(sin(yaw))>.5 else footprint
		room._spawn_wall_collision(point*32.0,size*32.0,label+"Collider")
	return item
func _lounge() -> void:
	box("rug",Vector3(8,.012,6),Vector3(4.8,.008,11))
	for x in [.85,8.75]: box("metal",Vector3(.08,.015,6),Vector3(x,.012,11))
	for z in [8.05,13.95]: box("metal",Vector3(8,.015,.08),Vector3(4.8,.012,z))
	var seats: Array = [[1.8,9.5,PI*.5],[1.8,12.0,PI*.5],[7.8,9.5,-PI*.5],[7.8,12.0,-PI*.5],[4.8,13.5,PI]]
	for i in seats.size():
		var seat: Array=seats[i]
		prop("sofa",Vector2(seat[0],seat[1]),seat[2],Vector2(2.1,.85),"LoungeSofa%d"%i)
	for i in 2:
		var z:=10.0+float(i)*2.3
		prop("coffee_table",Vector2(4.8,z),0,Vector2(1.3,.75),"LoungeTable%d"%i)
		box("blue",Vector3(.3,.045,.25),Vector3(4.5,.455,z))
		box("white",Vector3(.28,.02,.23),Vector3(4.5,.485,z))
		box("dark",Vector3(.19,.12,.19),Vector3(5.1,.49,z))
		box("leaf",Vector3(.33,.18,.33),Vector3(5.1,.62,z))
func _back_office() -> void:
	for i in 3:
		var x:=16.0+float(i)*3.4
		prop("workstation",Vector2(x,1.3),PI,Vector2(2.2,1.1),"RearWorkstation%d"%i)
		if i>0: prop("chair",Vector2(x,2.35),PI,Vector2(.7,.7),"EmptyStaffChair%d"%i)
		prop("cabinet",Vector2(x+1.35,.3),0,Vector2(1.3,.65),"StaffStorage%d"%i)
		box("dark",Vector3(.23,.27,.23),Vector3(x+1.15,1.185,3.6))
		box("white",Vector3(.26,.04,.23),Vector3(x+1.15,1.335,3.6))
		# Recessed fascia adds the reference's dark cabinet face without
		# changing the reusable white desk asset or its existing collision.
		box("dark",Vector3(3.3,.77,.035),Vector3(x,.52,4.18))
		box("lamp",Vector3(3.3,.035,.04),Vector3(x,.12,4.21))
	for z in [8.0,11.8]:
		prop("sorting_table",Vector2(24.7,z),PI*.5,Vector2(2,.8),"WallConsole%d"%int(z))
		box("white",Vector3(.32,.15,.23),Vector3(24.7,.9,z))
func _gates() -> void:
	for i in 6:
		var x:=9.0+float(i)*1.4
		box("dark",Vector3(.28,.9,1.35),Vector3(x,.45,15.5))
		box("metal",Vector3(.31,.075,1.4),Vector3(x,.94,15.5))
		box("white",Vector3(.22,.72,.045),Vector3(x,.48,16.19))
		box("blue",Vector3(.17,.2,.045),Vector3(x,.85,16.23))
		box("led",Vector3(.07,.1,.05),Vector3(x,.85,16.26))
		# Open leaves lie along their housings; nothing crosses a walk lane.
		box("metal",Vector3(.05,.47,.53),Vector3(x+.19,.54,15.3))
		room._spawn_wall_collision(Vector2(x,15.5)*32,Vector2(.32,1.4)*32,"OpenGatePost%d"%i)
	for x in [7.0,18.0]:
		box("dark",Vector3(.95,1.75,.16),Vector3(x,.875,14.9))
		box("metal",Vector3(1.08,.08,.3),Vector3(x,.04,14.9))
		box("blue",Vector3(.5,.18,.025),Vector3(x,1.5,15.0),Basis(Vector3.FORWARD,-.4))
		for y in [.95,.76,.57]: box("white",Vector3(.58,.035,.02),Vector3(x,y,15.0))
		room._spawn_wall_collision(Vector2(x,14.9)*32,Vector2(1.08,.3)*32,"EntryDirectory%d"%int(x))
	box("rug",Vector3(5,.014,2.5),Vector3(12.5,.01,18.0))
func _plants() -> void:
	var points: Array[Vector2]=[Vector2(1,1.3),Vector2(5.5,1.3),Vector2(9.5,1.3),Vector2(13.2,1.3),Vector2(14,3.6),Vector2(24.7,3.6),Vector2(1.1,7.6),Vector2(8.2,7.6),Vector2(1.1,14.1),Vector2(8.2,14.1),Vector2(1.1,4.5),Vector2(17,14.5)]
	for i in points.size():
		var p:=Vector3(points[i].x,0,points[i].y)
		box("dark",Vector3(.72,.55,.72),p+Vector3(0,.275,0))
		box("metal",Vector3(.76,.07,.76),p+Vector3(0,.57,0))
		box("stem",Vector3(.09,.75,.09),p+Vector3(0,.94,0))
		for layer in 2:
			for leaf in 7:
				var angle:=float(leaf)*TAU/7.0+float(layer)*.43
				var basis:=Basis(Vector3.UP,angle)*Basis(Vector3.FORWARD,.38 if layer==0 else -.45)
				var offset:=Vector3(cos(angle)*.25,1.02+float(layer)*.29,sin(angle)*.25)
				box("green" if leaf%2==0 else "leaf",Vector3(.65,.07,.22),p+offset,basis)
		room._spawn_wall_collision(points[i]*32,Vector2(.72,.72)*32,"Planter%d"%i)
		var marker:=Node3D.new(); marker.name="Planter%d"%i; marker.position=p; marker.set_meta(&"lobby_kind","plant"); room.props_root.add_child(marker)
func _architecture() -> void:
	# Back-wall identity panel and quiet structural pilasters.
	box("metal",Vector3(11.0,2.65,.08),Vector3(19.5,1.45,-.38))
	for x in [1.0,5.5,9.5,13.5,25.0]:
		box("dark",Vector3(.3,3,.22),Vector3(x,1.5,-.35))
		box("lamp",Vector3(.13,.27,.06),Vector3(x,2.65,-.18))
	box("blue",Vector3(1.3,.45,.08),Vector3(19.0,2.0,-.25),Basis(Vector3.FORWARD,.6))
	box("white",Vector3(1.3,.45,.08),Vector3(19.9,1.65,-.25),Basis(Vector3.FORWARD,.6))
	label("RECEPTION",Vector3(19.5,1.1,-.26),.014)
	# Bay numbering is mounted on the shared freight housing. Door readers
	# retain green READY / red CLOSED indication without overlapping wall text.
	for x in [3.5,10.5,18.0,23.0]:
		box("dark",Vector3(.35,.04,.6),Vector3(x,2.92,6.3))
		box("lamp",Vector3(.22,.035,.48),Vector3(x,2.88,6.3))
	for z in [5.5,10.5,14.0]:
		for x in [0.0,25.0]:
			box("metal",Vector3(.15,.7,.25),Vector3(x,1.7,z))
			box("lamp",Vector3(.13,.5,.13),Vector3(x,1.7,z+.1))
func label(text: String, point: Vector3, scale_pixels: float) -> void:
	var node:=Label3D.new(); node.text=text; node.font_size=32; node.pixel_size=scale_pixels
	node.modulate=palette.white; node.position=point; node.outline_size=0
	node.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST; room.props_root.add_child(node)
