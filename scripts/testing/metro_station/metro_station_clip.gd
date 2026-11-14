extends RefCounted
## Runtime display slice. Source assets, PBR materials and physics stay intact.
## Only the few meshes intersecting a station boundary need new triangles.
var entries: Array[Dictionary]=[]
var update_us:=0
var rebuilt_meshes:=0
var partial_meshes:=0

func _init(root: Node3D) -> void:
	for node: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		var surfaces: Array[Dictionary]=[]
		for surface in node.mesh.get_surface_count():
			surfaces.append({"arrays":node.mesh.surface_get_arrays(surface),"material":node.mesh.surface_get_material(surface)})
		entries.append({"node":node,"source":node.mesh,"bounds":node.mesh.get_aabb(),"layers":node.layers,"surfaces":surfaces,"last_transform":Transform3D.IDENTITY,"sliced":false})

func update(enabled: bool,minimum: float,maximum: float) -> void:
	# Keep render layers fixed. Repeated layer-mask changes near local lights
	# trigger Godot 4.7's light-pairing bug (#121989) during cleanup.
	var started:=Time.get_ticks_usec()
	rebuilt_meshes=0;partial_meshes=0
	for entry in entries:
		var node: MeshInstance3D=entry.node
		if not enabled:
			node.mesh=entry.source;entry.sliced=false
			continue
		var transform: Transform3D=node.global_transform
		var bounds: AABB=transform*entry.bounds
		if bounds.end.x<=minimum or bounds.position.x>=maximum:
			node.mesh=null;entry.sliced=false
			continue
		if bounds.position.x>=minimum and bounds.end.x<=maximum:
			node.mesh=entry.source;entry.sliced=false
			continue
		partial_meshes+=1
		if entry.sliced and transform.is_equal_approx(entry.last_transform):continue
		# Dot with this normal gives the world X displacement from the origin.
		var normal:=transform.basis.transposed()*Vector3.RIGHT
		var result:=ArrayMesh.new()
		for surface: Dictionary in entry.surfaces:
			var builder:=SliceSurface.new(surface.arrays,normal,minimum-transform.origin.x,maximum-transform.origin.x)
			var arrays:=builder.build()
			if arrays.is_empty():continue
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			result.surface_set_material(result.get_surface_count()-1,surface.material)
		if result.get_surface_count()>0:
			node.mesh=result
		else:
			node.mesh=null
		entry.sliced=true;entry.last_transform=transform
		rebuilt_meshes+=1
	update_us=Time.get_ticks_usec()-started

class SliceSurface extends RefCounted:
	var original: Array
	var plane_normal: Vector3
	var minimum: float
	var maximum: float
	var distances:=PackedFloat32Array()
	var remap:=PackedInt32Array()
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var tangents:=PackedFloat32Array()
	var uvs:=PackedVector2Array()
	var uvs2:=PackedVector2Array()
	var colors:=PackedColorArray()
	var indices:=PackedInt32Array()
	var has_tangents:=false
	var has_uv2:=false
	var has_colors:=false

	func _init(arrays: Array,normal: Vector3,low: float,high: float) -> void:
		original=arrays;plane_normal=normal;minimum=low;maximum=high
		has_tangents=arrays[Mesh.ARRAY_TANGENT]!=null and not arrays[Mesh.ARRAY_TANGENT].is_empty()
		has_uv2=arrays[Mesh.ARRAY_TEX_UV2]!=null and not arrays[Mesh.ARRAY_TEX_UV2].is_empty()
		has_colors=arrays[Mesh.ARRAY_COLOR]!=null and not arrays[Mesh.ARRAY_COLOR].is_empty()

	func build() -> Array:
		var source_vertices: PackedVector3Array=original[Mesh.ARRAY_VERTEX]
		var source_indices: PackedInt32Array=original[Mesh.ARRAY_INDEX]
		distances.resize(source_vertices.size());remap.resize(source_vertices.size());remap.fill(-1)
		var all_inside:=true
		var all_low:=true;var all_high:=true
		for i in source_vertices.size():
			var distance:=plane_normal.dot(source_vertices[i]);distances[i]=distance
			all_inside=all_inside and distance>=minimum and distance<=maximum
			all_low=all_low and distance<minimum;all_high=all_high and distance>maximum
		if all_low or all_high:return []
		if all_inside:return original
		for start in range(0,source_indices.size(),3):
			var a:=source_indices[start];var b:=source_indices[start+1];var c:=source_indices[start+2]
			var da:=distances[a];var db:=distances[b];var dc:=distances[c]
			if maxf(da,maxf(db,dc))<minimum or minf(da,minf(db,dc))>maximum:continue
			if minf(da,minf(db,dc))>=minimum and maxf(da,maxf(db,dc))<=maximum:
				indices.append(source_index(a));indices.append(source_index(b));indices.append(source_index(c))
				continue
			var polygon: Array=[record(a),record(b),record(c)]
			polygon=clip_polygon(polygon,minimum,true)
			polygon=clip_polygon(polygon,maximum,false)
			if polygon.size()<3:continue
			var first:=append_record(polygon[0])
			for i in range(1,polygon.size()-1):
				var second:=append_record(polygon[i]);var third:=append_record(polygon[i+1])
				if (vertices[second]-vertices[first]).cross(vertices[third]-vertices[first]).length_squared()<1e-16:continue
				indices.append(first);indices.append(second);indices.append(third)
		if indices.is_empty():return []
		var result: Array=[];result.resize(Mesh.ARRAY_MAX)
		result[Mesh.ARRAY_VERTEX]=vertices;result[Mesh.ARRAY_NORMAL]=normals
		result[Mesh.ARRAY_TEX_UV]=uvs;result[Mesh.ARRAY_INDEX]=indices
		if has_tangents:result[Mesh.ARRAY_TANGENT]=tangents
		if has_uv2:result[Mesh.ARRAY_TEX_UV2]=uvs2
		if has_colors:result[Mesh.ARRAY_COLOR]=colors
		return result

	func record(index: int) -> Array:
		var tangent:=Vector4.ZERO
		if has_tangents:
			var data: PackedFloat32Array=original[Mesh.ARRAY_TANGENT]
			tangent=Vector4(data[index*4],data[index*4+1],data[index*4+2],data[index*4+3])
		return [original[Mesh.ARRAY_VERTEX][index],original[Mesh.ARRAY_NORMAL][index],tangent,original[Mesh.ARRAY_TEX_UV][index],distances[index],index,original[Mesh.ARRAY_TEX_UV2][index] if has_uv2 else Vector2.ZERO,original[Mesh.ARRAY_COLOR][index] if has_colors else Color.WHITE]

	func source_index(index: int) -> int:
		if remap[index]>=0:return remap[index]
		return append_record(record(index))

	func append_record(data: Array) -> int:
		var source: int=data[5]
		if source>=0 and remap[source]>=0:return remap[source]
		var index:=vertices.size()
		vertices.append(data[0]);normals.append(data[1]);uvs.append(data[3])
		if has_tangents:
			var tangent: Vector4=data[2]
			tangents.append(tangent.x);tangents.append(tangent.y);tangents.append(tangent.z);tangents.append(tangent.w)
		if has_uv2:uvs2.append(data[6])
		if has_colors:colors.append(data[7])
		if source>=0:remap[source]=index
		return index

	func interpolate(a: Array,b: Array,boundary: float) -> Array:
		var t: float=(boundary-float(a[4]))/(float(b[4])-float(a[4]))
		var normal: Vector3=Vector3(a[1]).lerp(b[1],t).normalized()
		var tangent: Vector4=Vector4(a[2]).lerp(b[2],t)
		if has_tangents:
			var xyz:=Vector3(tangent.x,tangent.y,tangent.z)
			xyz=(xyz-normal*xyz.dot(normal)).normalized()
			tangent=Vector4(xyz.x,xyz.y,xyz.z,1.0 if tangent.w>=0 else -1.0)
		return [Vector3(a[0]).lerp(b[0],t),normal,tangent,Vector2(a[3]).lerp(b[3],t),boundary,-1,Vector2(a[6]).lerp(b[6],t),Color(a[7]).lerp(b[7],t)]

	func clip_polygon(polygon: Array,boundary: float,keep_greater: bool) -> Array:
		if polygon.is_empty():return []
		var result: Array=[]
		var previous: Array=polygon[-1]
		var previous_inside: bool=previous[4]>=boundary if keep_greater else previous[4]<=boundary
		for current: Array in polygon:
			var current_inside: bool=current[4]>=boundary if keep_greater else current[4]<=boundary
			if previous_inside!=current_inside:result.append(interpolate(previous,current,boundary))
			if current_inside:result.append(current)
			previous=current;previous_inside=current_inside
		return result
