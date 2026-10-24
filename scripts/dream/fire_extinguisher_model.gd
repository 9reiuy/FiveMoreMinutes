extends RefCounted
## Ten-sided cylinder, pixel-material label/valve, no imported assets.
static var cached_mesh: ArrayMesh
static func build() -> Node3D:
	var root:=Node3D.new()
	root.name="FireExtinguisherModel"
	if cached_mesh!=null:
		var cached:=MeshInstance3D.new();cached.mesh=cached_mesh;root.add_child(cached)
		return root
	var mats=preload("res://scripts/dream/office_pixel_materials.gd")
	for part in [[.155,.155,.52,0.0,"ad2635"],[.155,.105,.10,.31,"d33b3b"],[.07,.07,.10,.40,"677984"]]:
		var mesh:=MeshInstance3D.new()
		var cylinder:=CylinderMesh.new()
		cylinder.bottom_radius=part[0];cylinder.top_radius=part[1]
		cylinder.height=part[2];cylinder.radial_segments=10;cylinder.rings=1
		mesh.mesh=cylinder;mesh.position.y=part[3]
		mesh.material_override=mats.make(Color(part[4]),"metal")
		root.add_child(mesh)
	for part in [[Vector3(.24,.22,.025),Vector3(0,.03,.155),"ddd8c5"],[Vector3(.17,.025,.03),Vector3(0,.08,.174),"a52636"],[Vector3(.10,.022,.03),Vector3(0,-.005,.174),"354452"],[Vector3(.27,.045,.08),Vector3(.035,.46,0),"26323d"],[Vector3(.045,.34,.05),Vector3(.20,.15,.02),"202735"],[Vector3(.075,.09,.08),Vector3(.20,-.04,.02),"485761"],[Vector3(.20,.04,.10),Vector3(0,-.20,-.17),"505d66"]]:
		var mesh:=MeshInstance3D.new()
		var box:=BoxMesh.new();box.size=part[0]
		mesh.mesh=box;mesh.position=part[1]
		mesh.material_override=mats.make(Color(part[2]),"metal")
		root.add_child(mesh)
	# Two cached surfaces: scene-lit hardware and palette-exempt red paint.
	var batch:=SurfaceTool.new();batch.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint:=SurfaceTool.new();paint.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: MeshInstance3D in root.get_children():
		var arrays:=part.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var tint: Color=part.material_override.get_shader_parameter("base_color")
		var target: SurfaceTool=paint if tint.r>tint.g*1.8 and tint.r>tint.b*1.5 else batch
		for index in indices:
			target.set_color(tint)
			target.set_normal(normals[index])
			target.add_vertex(vertices[index]+part.position)
		root.remove_child(part);part.free()
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/dream3d/fire_extinguisher_pixel.gdshader")
	batch.set_material(material)
	cached_mesh=batch.commit()
	var paint_material:=ShaderMaterial.new()
	paint_material.shader=preload("res://shaders/dream3d/fire_extinguisher_red.gdshader")
	paint.set_material(paint_material);paint.commit(cached_mesh)
	var merged:=MeshInstance3D.new();merged.mesh=cached_mesh;root.add_child(merged)
	return root
