extends RefCounted
## Preview-only low-poly models. Footprints/heights come from the existing catalog.
const CATALOG = preload("res://scripts/dream/office_furniture_catalog.gd")
const SURFACE = preload("res://shaders/dream3d/office_pixel_surface.gdshader")
static var textures: Dictionary = {}
static var materials: Dictionary = {}

static func material(color: Color, kind: String) -> ShaderMaterial:
	var key := str(color) + kind
	if materials.has(key):
		return materials[key]
	if not textures.has(kind):
		var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		# Sparse authored marks, not procedural grain or fine repeating hatching.
		if kind == "cabinet":
			for y in [10,21]:
				for x in range(32): image.set_pixel(x,y,Color(.72,.72,.72))
				for x in range(12,20): image.set_pixel(x,y+4,Color(.32,.32,.32))
		elif kind == "wood":
			for x in range(4,12): image.set_pixel(x,21,Color(.94,.94,.94))
		elif kind == "wall":
			for x in range(6,9): image.set_pixel(x,26,Color(.95,.95,.95))
		image.generate_mipmaps()
		textures[kind] = ImageTexture.create_from_image(image)
	var result := ShaderMaterial.new()
	result.shader = SURFACE
	result.set_shader_parameter("base_color", color)
	result.set_shader_parameter("pixel_texture", textures[kind])
	result.set_shader_parameter("object_space", true)
	materials[key] = result
	return result

static func box(root: Node3D, dimensions: Vector3, center: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.position = center
	node.material_override = mat
	root.add_child(node)
	return node

static func furniture(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "QuietReferenceFurniture"
	var s: Vector3 = CATALOG.size_of(kind)
	var paint := material(Color(.67,.71,.72),"plain")
	var steel := material(Color(.25,.32,.36),"plain")
	var wood := material(Color(.49,.43,.32),"wood")
	var fabric := material(Color(.25,.34,.40),"plain")
	match kind:
		"workstation", "desk", "table", "coffee_table":
			box(root,Vector3(s.x,.10,s.z),Vector3(0,s.y-.05,0), paint if kind == "workstation" else wood)
			for x in [-1,1]:
				for z in [-1,1]:
					box(root,Vector3(.10,s.y-.10,.10),Vector3(x*(s.x*.5-.10),(s.y-.10)*.5,z*(s.z*.5-.10)),steel)
			if kind == "workstation":
				box(root,Vector3(.64,.38,.10),Vector3(0,s.y+.25,-.25),steel)
				box(root,Vector3(.12,.12,.12),Vector3(0,s.y+.06,-.25),steel)
		"cabinet", "cabinet_open":
			box(root,s,Vector3(0,s.y*.5,0),material(Color(.36,.42,.45),"cabinet"))
		"chair":
			var seat := Node3D.new()
			seat.name = "SeatRoot"
			root.add_child(seat)
			box(seat,Vector3(s.x,.12,s.z),Vector3(0,.43,0),fabric)
			box(seat,Vector3(s.x,.41,.10),Vector3(0,.695,-s.z*.5+.05),fabric)
			box(root,Vector3(.10,.37,.10),Vector3(0,.185,0),steel)
			box(root,Vector3(s.x,.07,.12),Vector3(0,.035,0),steel)
			box(root,Vector3(.12,.07,s.z),Vector3(0,.035,0),steel)
		"sofa":
			box(root,Vector3(s.x,.40,s.z),Vector3(0,.30,0),fabric)
			box(root,Vector3(s.x,.35,.18),Vector3(0,s.y-.175,-s.z*.5+.09),fabric)
			for x in [-1,1]:
				box(root,Vector3(.15,.32,s.z),Vector3(x*(s.x*.5-.075),.50,0),fabric)
		_:
			box(root,s,Vector3(0,s.y*.5,0),paint)
	return root
