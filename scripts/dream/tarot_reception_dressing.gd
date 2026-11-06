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
	"led": Color("529ecd"), "rug": Color("293f58"),
	"velvet": Color("482938"), "runner": Color("3b2633"),
	"copper": Color("916947"), "stone": Color("303842")
}
func build(target: Node3D) -> void:
	room=target
	_lounge(); _back_office(); _plants(); _architecture(); _tarot_alcove()
	for chunk: Vector2i in batches:
		# Cloth lies flush on its support; it must not cast a false black seam.
		for cloth in [false,true]:
			var mesh := ArrayMesh.new()
			for key in batches[chunk]:
				if (key in ["rug","runner","velvet"]) != cloth: continue
				var tool: SurfaceTool=batches[chunk][key]
				tool.set_material(PIXEL.make_floor(palette[key], "fabric") if cloth else PIXEL.make(palette[key],"paint",false,key in ["lamp","led"]))
				tool.commit(mesh)
			if mesh.get_surface_count()==0: continue
			var visual := MeshInstance3D.new()
			visual.name="LobbyDetails_%d_%d_%s"%[chunk.x,chunk.y,"Cloth" if cloth else "Solid"]; visual.mesh=mesh
			visual.position=Vector3(chunk.x*8+4,0,chunk.y*8+4)
			if cloth: visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	# One waiting bench, grouped against the south wall, off the main aisle.
	box("rug",Vector3(3.8,.012,1.9),Vector3(10.7,.008,6.4))
	prop("sofa",Vector2(10.7,6.8),PI,Vector2(2.1,.85),"WaitingBench")
	prop("coffee_table",Vector2(10.7,5.9),0,Vector2(1.3,.75),"WaitingTable")
	box("blue",Vector3(.3,.045,.25),Vector3(10.5,.455,5.9))
	box("white",Vector3(.28,.02,.23),Vector3(10.5,.485,5.9))

func _back_office() -> void:
	# A compact service nook beside the single counter.
	prop("cabinet",Vector2(12.0,.25),0,Vector2(1.3,.65),"StaffStorage")
	prop("workstation",Vector2(11.8,1.5),PI,Vector2(2.2,1.1),"StaffTerminal")
	prop("chair",Vector2(11.8,2.5),PI,Vector2(.7,.7),"StaffChair")
	var p: Vector3=room.RECEPTION_DESK_POS_3D
	box("dark",Vector3(3.3,.77,.035),p+Vector3(0,.52,.58))
	box("lamp",Vector3(3.3,.035,.04),p+Vector3(0,.12,.61))
	box("dark",Vector3(.23,.27,.23),p+Vector3(1.15,1.185,0))
	box("white",Vector3(.26,.04,.23),p+Vector3(1.15,1.335,0))

func _plants() -> void:
	var points: Array[Vector2]=[Vector2(.6,6.7),Vector2(12.9,6.7)]
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
	for x in [4.6,10.3,13.1]:
		box("dark",Vector3(.22,3,.20),Vector3(x,1.5,-.35))
		box("lamp",Vector3(.12,.25,.06),Vector3(x,2.55,-.18))
	# Right-hand entrance is an open passage, with no extra elevator facade.
	box("metal",Vector3(.2,2.65,.2),Vector3(13.5,1.325,2.5))
	box("lamp",Vector3(.1,.65,.1),Vector3(13.35,1.8,2.5))
	box("metal",Vector3(.2,.38,.2),Vector3(13.5,.19,5.5))
	for x in [2.,6.,10.]:
		box("metal",Vector3(.5,.12,.12),Vector3(x,2.45,-.32))
		box("lamp",Vector3(.36,.07,.13),Vector3(x,2.41,-.25))

func label(text: String, point: Vector3, scale_pixels: float) -> void:
	var node:=Label3D.new(); node.text=text; node.font_size=32; node.pixel_size=scale_pixels
	node.modulate=palette.white; node.position=point; node.outline_size=0
	node.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST; room.props_root.add_child(node)

func _tarot_alcove() -> void:
	# Readable right-to-left route: arrival, front desk, then the sole lift.
	box("runner",Vector3(13.9,.018,1.7),Vector3(9.35,.028,4.55))
	for z in [3.75,5.35]: box("copper",Vector3(13.9,.008,.035),Vector3(9.35,.042,z))
	box("rug",Vector3(1.8,.018,5.9),Vector3(1.5,.028,2.45))
	box("runner",Vector3(4.6,.018,3.1),Vector3(8,.028,2.15))
	box("stone",Vector3(4.3,2.5,.14),Vector3(8,1.25,-.3))
	for x in [5.9,10.1]:
		box("copper",Vector3(.075,2.5,.20),Vector3(x,1.25,-.22))
	box("copper",Vector3(4.4,.07,.22),Vector3(8,2.5,-.22))
	label("R E C E P T I O N",Vector3(8,2.,-.15),.008)
	var p: Vector3=room.RECEPTION_DESK_POS_3D
	box("velvet",Vector3(1.65,.018,.38),p+Vector3(0,1.09,.33))
	for index in 3: _card(index,p+Vector3(-.44+index*.44,1.28,.31))
	box("copper",Vector3(.28,.05,.25),p+Vector3(-1.15,1.10,.23))
	box("copper",Vector3(.06,.37,.06),p+Vector3(-1.15,1.30,.23))
	box("copper",Vector3(.36,.18,.30),p+Vector3(-1.15,1.53,.23))
	box("lamp",Vector3(.27,.025,.21),p+Vector3(-1.15,1.43,.23))

func _card(index: int, point: Vector3) -> void:
	var pixels:=Image.create(8,12,false,Image.FORMAT_RGB8)
	pixels.fill(Color("b9ad90"))
	for y in range(1,11):
		for x in range(1,7):
			var ink:=Color("283744")
			var mark: bool=(absi(x-3)+absi(y-5)<3) if index==0 else (x in [2,3] and y in range(3,8)) if index==1 else (y==5 or x==3) and y in range(3,8)
			if mark: ink=Color("c3a36b")
			pixels.set_pixel(x,y,ink)
	var material:=StandardMaterial3D.new(); material.albedo_texture=ImageTexture.create_from_image(pixels)
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST; material.roughness=1.; material.metallic_specular=0.
	var mesh:=MeshInstance3D.new(); mesh.name="OriginalTarotCard%d"%index
	var quad:=QuadMesh.new(); quad.size=Vector2(.25,.375); mesh.mesh=quad; mesh.material_override=material
	mesh.position=point; mesh.rotation_degrees.x=-28; room.props_root.add_child(mesh)
