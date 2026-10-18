extends RefCounted
## Shared visible wall geometry. Source meshes, gameplay and shadow geometry stay immutable.
var root_height := 0.12
var knee_height := 0.34
var bevel_length := 0.25
var post_length := 0.20
var thin_meshes: Dictionary={}
var joined_meshes: Dictionary={}
var root_meshes: Dictionary={}

func cut_mesh(height:float,depth:float,left:bool,right:bool,phase:float)->Mesh:
	var key:="%s:%s:%s:%s:%s"%[height,depth,left,right,phase]
	if not root_meshes.has(key): root_meshes[key]=_make_root_mesh(height,depth,left,right,phase)
	return root_meshes[key]

func _thin_mesh(source:Mesh,depth:float)->Mesh:
	if absf(source.get_aabb().size.z-depth)<.0001: return source
	var key:="%d:%s"%[source.get_instance_id(),depth]
	if not thin_meshes.has(key):
		var mesh:=ArrayMesh.new()
		var ratio:=depth/source.get_aabb().size.z
		for surface in source.get_surface_count():
			var arrays:Array=source.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size(): vertices[i].z*=ratio
			arrays[Mesh.ARRAY_VERTEX]=vertices
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		thin_meshes[key]=mesh
	return thin_meshes[key]

func join_mesh(source: Mesh,miters: Vector2)->Mesh:
	if miters==Vector2.ZERO: return source
	var cache_key:="%d:%s"%[source.get_instance_id(),miters]
	if not joined_meshes.has(cache_key):
		var joined:=ArrayMesh.new()
		for surface in source.get_surface_count():
			var arrays: Array=source.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			for i in vertices.size():
				var coefficient: float=miters.x if absf(vertices[i].x+.5)<.00001 else miters.y if absf(vertices[i].x-.5)<.00001 else 0.0
				vertices[i].x+=coefficient*vertices[i].z
				if coefficient!=0.0 and absf(normals[i].x)>.99:
					normals[i]=Vector3(normals[i].x,0,-coefficient*normals[i].x).normalized()
			arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals
			joined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		joined_meshes[cache_key]=joined
	return joined_meshes[cache_key]

static func section_image(height:float,thickness:float)->Image:
	var image:=Image.create(maxi(4,roundi(thickness*32)),maxi(4,roundi(height*32)),false,Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var color:=Color("a4aca3")
			if x==0 or x==image.get_width()-1: color=Color("c4c9bc")
			image.set_pixel(x,y,color)
	return image

func _make_root_mesh(height:float,depth:float,left:bool,right:bool,phase:float)->ArrayMesh:
	var xs: Array[float]=[-.5]
	var ys: Array[float]=[height if left else root_height]
	if left:
		xs.append_array([-.5+post_length,-.5+post_length,-.5+post_length+bevel_length])
		ys.append_array([height,knee_height,root_height])
	if right:
		xs.append_array([.5-post_length-bevel_length,.5-post_length,.5-post_length])
		ys.append_array([root_height,knee_height,height])
	xs.append(.5); ys.append(height if right else root_height)
	var buckets: Array=[]
	for i in 3: buckets.append({"v":PackedVector3Array(),"n":PackedVector3Array(),"uv":PackedVector2Array()})
	var z:=depth*.5
	for i in xs.size()-1:
		var a:=xs[i]; var b:=xs[i+1]; var ha:=ys[i]; var hb:=ys[i+1]
		if absf(b-a)<.00001:
			_quad(buckets[2],[Vector3(a,ha,z),Vector3(b,hb,z),Vector3(b,hb,-z),Vector3(a,ha,-z)],Vector3.RIGHT if hb<ha else Vector3.LEFT,height,phase)
			continue
		_quad(buckets[0],[Vector3(a,0,z),Vector3(b,0,z),Vector3(b,hb,z),Vector3(a,ha,z)],Vector3.BACK,height,phase)
		_quad(buckets[1],[Vector3(b,0,-z),Vector3(a,0,-z),Vector3(a,ha,-z),Vector3(b,hb,-z)],Vector3.FORWARD,height,phase)
		_quad(buckets[2],[Vector3(a,ha,z),Vector3(b,hb,z),Vector3(b,hb,-z),Vector3(a,ha,-z)],Vector3(-(hb-ha)/(b-a),1,0).normalized(),height,phase)
	_quad(buckets[0],[Vector3(.5,0,z),Vector3(.5,0,-z),Vector3(.5,ys[-1],-z),Vector3(.5,ys[-1],z)],Vector3.RIGHT,height,phase)
	_quad(buckets[0],[Vector3(-.5,0,-z),Vector3(-.5,0,z),Vector3(-.5,ys[0],z),Vector3(-.5,ys[0],-z)],Vector3.LEFT,height,phase)
	_quad(buckets[2],[Vector3(-.5,0,-z),Vector3(.5,0,-z),Vector3(.5,0,z),Vector3(-.5,0,z)],Vector3.DOWN,height,phase)
	var mesh:=ArrayMesh.new()
	for bucket:Dictionary in buckets:
		var arrays:Array=[]; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=bucket.v; arrays[Mesh.ARRAY_NORMAL]=bucket.n; arrays[Mesh.ARRAY_TEX_UV]=bucket.uv
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _quad(bucket:Dictionary,points:Array,normal:Vector3,height:float,phase:float)->void:
	# Godot uses clockwise front faces, matching WallSegment3D._add_face.
	for i in [0,2,1,0,3,2]:
		var p:Vector3=points[i]
		bucket.v.append(p); bucket.n.append(normal); bucket.uv.append(Vector2((p.x+.5+phase)/3,1-p.y/height))
