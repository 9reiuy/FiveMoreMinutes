extends RefCounted
# Only the floor's live nodes receive expanded vertex attributes. Positions,
# UVs, normals, face order and triangles stay identical; original Mesh resources
# and collision shapes are never edited. Coplanar triangle/tile seams are omitted.
const INCLUDE="res://shaders/dream3d/office_style_rim.gdshaderinc"
var records:Array[Dictionary]=[]
var mesh_records:Array[Dictionary]=[]
var shaders:Dictionary={}
var geometry_cache:Dictionary={}
var edge_groups:Dictionary={}
var node_records:Dictionary={}
var variants:Dictionary={}
var rim_enabled:=false
var statistics:Dictionary={"triangles":0,"edge_groups":0,"suppressed_coplanar":0,"marked_sides":0,"skipped":0,"geometry_parity":true,"attribute_max_error":{}}

func eligible(material:Material) -> bool:
	if not material is ShaderMaterial or material.shader==null:return false
	var raw:String=material.shader.code
	if raw.contains(INCLUDE) or raw.contains("unshaded") or raw.contains("capture_texture") or raw.contains("CUSTOM0"):return false
	if not raw.contains("void light()") or not raw.contains("ATTENUATION"):return false
	if material.get_shader_parameter("world_surface")==1:return false
	if material.shader.resource_path.contains("floor"):return false
	return raw.contains("architecture_world") or raw.contains("office_dither_position") or raw.contains("apply_light_noise_contour")

func edge_key(a:Vector3,b:Vector3) -> String:
	var p:="%d,%d,%d"%[roundi(a.x*4096.0),roundi(a.y*4096.0),roundi(a.z*4096.0)]
	var q:="%d,%d,%d"%[roundi(b.x*4096.0),roundi(b.y*4096.0),roundi(b.z*4096.0)]
	return p+":"+q if p<q else q+":"+p

func setup(world:Node) -> int:
	var serial:=0
	for node in world.find_children("*","MeshInstance3D",true,false):
		if node.mesh==null or node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:continue
		var source:Mesh=node.mesh
		if source is ArrayMesh and source.get_blend_shape_count()>0:continue
		# Reject unrelated scenery before reading/expanding its triangle arrays.
		# This preserves the selected faces and their world-space edge adjacency.
		var selected_surfaces:Array[bool]=[];var has_selected:=false
		for surface in source.get_surface_count():
			var material:Material=node.material_override if node.material_override!=null else node.get_active_material(surface)
			var selected:=eligible(material);selected_surfaces.append(selected);has_selected=has_selected or selected
		if not has_selected:continue
		var surfaces:Array=[];var usable:=true;var any_eligible:=false
		for s in source.get_surface_count():
			var arrays:Array=source.surface_get_arrays(s)
			if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX]==null or arrays[Mesh.ARRAY_CUSTOM0]!=null or arrays[Mesh.ARRAY_BONES]!=null:usable=false;break
			if source is ArrayMesh and source.surface_get_primitive_type(s)!=Mesh.PRIMITIVE_TRIANGLES:usable=false;break
			var selected:bool=selected_surfaces[s];any_eligible=any_eligible or selected
			var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var order:PackedInt32Array=[]
			if arrays[Mesh.ARRAY_INDEX]!=null:order=arrays[Mesh.ARRAY_INDEX]
			else:
				for v in points.size():order.append(v)
			var triangles:Array=[]
			for i in range(0,order.size()-2,3):
				var vertices:PackedVector3Array=[]
				for j in 3:vertices.append(node.to_global(points[order[i+j]]))
				var n:=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
				var keys:Array[String]=[]
				for j in 3:
					var key:=edge_key(vertices[(j+1)%3],vertices[(j+2)%3]);keys.append(key)
					if selected:
						if not edge_groups.has(key):edge_groups[key]=[]
						edge_groups[key].append({"id":serial,"normal":n})
				triangles.append({"id":serial,"normal":n,"keys":keys,"selected":selected});serial+=1
			surfaces.append({"arrays":arrays,"order":order,"triangles":triangles,"material":source.surface_get_material(s),"selected":selected})
		if not usable or not any_eligible:continue
		mesh_records.append({"node":weakref(node),"original":source,"surfaces":surfaces,"transform":node.transform})
	for item in mesh_records:
		var masks:PackedInt32Array=[]
		for surface:Dictionary in item.surfaces:
			for triangle:Dictionary in surface.triangles:
				var bits:=0
				if triangle.selected:
					for e in 3:
						var coplanar:=false
						for adjacent:Dictionary in edge_groups.get(triangle.keys[e],[]):
							if adjacent.id!=triangle.id and triangle.normal.dot(adjacent.normal)>.995:coplanar=true;break
						if coplanar:statistics.suppressed_coplanar+=1
						else:bits|=1<<e;statistics.marked_sides+=1
				masks.append(bits)
		var cache_key:=str(item.original.get_instance_id())+":"+var_to_str(masks).sha256_text()
		if not geometry_cache.has(cache_key):geometry_cache[cache_key]=build_mesh(item,masks)
		item.decorated=geometry_cache[cache_key]
		var node:MeshInstance3D=item.node.get_ref()
		for s in node.mesh.get_surface_count():
			var material:Material=node.material_override if node.material_override!=null else node.get_active_material(s)
			if eligible(material):register(material)
	statistics.triangles=serial;statistics.edge_groups=edge_groups.size();statistics.meshes=mesh_records.size();statistics.shaders=shaders.size()
	for item:Dictionary in mesh_records:
		var node:MeshInstance3D=item.node.get_ref()
		if is_instance_valid(node):
			node_records[node.get_instance_id()]=item
			variants[str(node.get_instance_id())+":"+str(item.original.get_instance_id())]=item.decorated
	set_enabled(true);return records.size()

func build_mesh(item:Dictionary,masks:PackedInt32Array) -> ArrayMesh:
	var mesh:=ArrayMesh.new();var triangle_offset:=0
	for surface:Dictionary in item.surfaces:
		var input:Array=surface.arrays;var output:Array=[];output.resize(Mesh.ARRAY_MAX)
		for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
			if input[channel]==null:continue
			var data:Variant=input[channel].duplicate();data.clear()
			var stride:=4 if channel==Mesh.ARRAY_TANGENT else 1
			for v:int in surface.order:
				for j in stride:data.append(input[channel][v*stride+j])
			output[channel]=data
		var custom:=PackedFloat32Array()
		for t in surface.triangles.size():
			var bits:int=masks[triangle_offset+t]
			custom.append_array(PackedFloat32Array([1.0,0.0,float(bits),0.0,0.0,1.0,float(bits),0.0,0.0,0.0,float(bits),0.0]))
		triangle_offset+=surface.triangles.size();output[Mesh.ARRAY_CUSTOM0]=custom
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,output,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		mesh.surface_set_material(mesh.get_surface_count()-1,surface.material)
		var actual:Array=mesh.surface_get_arrays(mesh.get_surface_count()-1)
		for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
			if output[channel]==null:continue
			var maximum:=0.0
			for v in output[channel].size():
				if channel==Mesh.ARRAY_COLOR:
					var a:Color=output[channel][v];var b:Color=actual[channel][v]
					maximum=maxf(maximum,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),maxf(absf(a.b-b.b),absf(a.a-b.a)))))
				else:maximum=maxf(maximum,output[channel][v].distance_to(actual[channel][v]))
			statistics.attribute_max_error[str(channel)]=maxf(float(statistics.attribute_max_error.get(str(channel),0.0)),maximum)
			# Packed mesh normals undergo octahedral round-trip quantization.
			statistics.geometry_parity=statistics.geometry_parity and maximum<(.0002 if channel==Mesh.ARRAY_NORMAL else .00001)
	return mesh

func inject_body(code:String,function:String,prefix:String,suffix:String) -> String:
	var start:=code.find("void "+function+"()")
	if start<0:return code+"\nvoid "+function+"(){"+prefix+suffix+"}\n"
	var opening:=code.find("{",start);var ending:=opening+1;var depth:=1
	while depth>0 and ending<code.length():
		if code[ending]=="{":depth+=1
		elif code[ending]=="}":depth-=1
		ending+=1
	return code.substr(0,opening+1)+prefix+code.substr(opening+1,ending-opening-2)+suffix+code.substr(ending-1)

func register(material:ShaderMaterial) -> void:
	if records.any(func(r:Dictionary)->bool:return r.material==material):return
	var original:Shader=material.shader;var raw:String=original.code
	if not shaders.has(raw):
		var code:=raw.replace("void vertex(){","void vertex() {")
		code=code.replace("shader_type spatial;","shader_type spatial;\n#include \""+INCLUDE+"\"\n")
		code=inject_body(code,"vertex","\nedge_style_vertex=CUSTOM0.xyz;\n","")
		code=inject_body(code,"fragment","", "\nvec3 edge_bary=vec3(edge_style_vertex.xy,1.0-edge_style_vertex.x-edge_style_vertex.y);\nvec3 edge_flags=mod(floor(vec3(round(edge_style_vertex.z))/vec3(1.0,2.0,4.0)),vec3(2.0));\nedge_style_coverage=edge_style_mask(edge_bary,edge_flags);\n")
		var normal:="furniture_direct_normal" if raw.contains("material_family(furniture_direct_finish)") else "NORMAL"
		code=inject_body(code,"light","", "\nif(edge_style_rim){\nvec3 edge_n=normalize("+normal+");\nfloat edge_facing=0.30+0.70*pow(1.0-max(dot(edge_n,VIEW),0.0),2.0);\nfloat edge_lit=max(dot(edge_n,LIGHT),0.0)*ATTENUATION;\nvec3 edge_tint=mix(ALBEDO,vec3(1.0),0.5);\nDIFFUSE_LIGHT+=LIGHT_COLOR*edge_tint*(edge_style_coverage*edge_facing*edge_lit*0.30/PI);\n}\n")
		var shader:=Shader.new();shader.code=code;shaders[raw]=shader
	records.append({"material":material,"original":original,"decorated":shaders[raw]})

func set_enabled(enabled:bool) -> void:
	rim_enabled=enabled
	for item:Dictionary in mesh_records:
		var node:MeshInstance3D=item.node.get_ref()
		if enabled and is_instance_valid(node) and node.mesh!=item.original and node.mesh!=item.decorated:rebind_mesh(node)
		elif enabled and is_instance_valid(node) and bool(item.get("stale",false)):rebind_mesh(node)
		if is_instance_valid(node):assign_mesh(node,item.decorated if enabled else item.original)
	for item:Dictionary in records:
		var material:ShaderMaterial=item.material;var values:Dictionary={}
		for field in material.shader.get_shader_uniform_list():
			var value:Variant=material.get_shader_parameter(field.name)
			if value!=null:values[field.name]=value
		material.shader=item.decorated if enabled else item.original
		for key in values:
			if not String(key).begins_with("edge_style_"):material.set_shader_parameter(key,values[key])
		if enabled:material.set_shader_parameter("edge_style_rim",true)

func restore() -> void:
	set_enabled(false);records.clear();mesh_records.clear();shaders.clear();geometry_cache.clear();edge_groups.clear();node_records.clear();variants.clear()

func assign_mesh(node:MeshInstance3D,resource:Mesh) -> void:
	if node.mesh==resource:return
	# Godot refreshes the instance-uniform layout when a mesh changes. Keep the
	# wall's live cutaway and furniture coordinates across that refresh.
	var values:Dictionary={}
	for field in node.get_property_list():
		if String(field.name).begins_with("instance_shader_parameters/"):values[field.name]=node.get(field.name)
	node.mesh=resource
	for field in values:node.set(field,values[field])

func rebind_mesh(node:MeshInstance3D) -> void:
	if node.mesh==null or node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:return
	var id:int=node.get_instance_id()
	var item:Dictionary=node_records.get(id,{})
	if not item.is_empty() and node.mesh==item.decorated:return
	if not rim_enabled:
		if not item.is_empty():item.original=node.mesh;item.stale=true
		return
	var source:Mesh=node.mesh;var cache_key:=str(id)+":"+str(source.get_instance_id())
	if variants.has(cache_key):
		item.original=source;item.decorated=variants[cache_key];item.stale=false;assign_mesh(node,item.decorated);return
	var surfaces:Array=[];var local_groups:Dictionary={};var serial:=-1;var selected_any:=false
	for surface in source.get_surface_count():
		var arrays:Array=source.surface_get_arrays(surface)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX]==null or arrays[Mesh.ARRAY_CUSTOM0]!=null or arrays[Mesh.ARRAY_BONES]!=null:return
		var material:Material=node.material_override if node.material_override!=null else node.get_active_material(surface)
		var selected:bool=material is ShaderMaterial and (material.shader.code.contains(INCLUDE) or eligible(material))
		selected_any=selected_any or selected
		var order:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if order.is_empty():
			for point in arrays[Mesh.ARRAY_VERTEX].size():order.append(point)
		var triangles:Array=[]
		for start in range(0,order.size()-2,3):
			var points:PackedVector3Array=[]
			for corner in 3:points.append(node.to_global(arrays[Mesh.ARRAY_VERTEX][order[start+corner]]))
			var normal:Vector3=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
			var keys:Array[String]=[]
			for corner in 3:
				var key:String=edge_key(points[(corner+1)%3],points[(corner+2)%3]);keys.append(key)
				if selected:
					if not local_groups.has(key):local_groups[key]=[]
					local_groups[key].append({"id":serial,"normal":normal})
			triangles.append({"id":serial,"normal":normal,"keys":keys,"selected":selected});serial-=1
		surfaces.append({"arrays":arrays,"order":order,"triangles":triangles,"material":source.surface_get_material(surface),"selected":selected})
	if not selected_any:return
	var ignored:Dictionary={}
	for surface:Dictionary in item.get("surfaces",[]):
		for triangle:Dictionary in surface.triangles:ignored[triangle.id]=true
	var masks:PackedInt32Array=[]
	for surface:Dictionary in surfaces:
		for triangle:Dictionary in surface.triangles:
			var bits:=0
			if triangle.selected:
				for edge in 3:
					var coplanar:=false
					for neighbour:Dictionary in local_groups.get(triangle.keys[edge],[]):
						if neighbour.id!=triangle.id and triangle.normal.dot(neighbour.normal)>.995:coplanar=true;break
					if not coplanar:
						for neighbour:Dictionary in edge_groups.get(triangle.keys[edge],[]):
							if not ignored.has(neighbour.id) and triangle.normal.dot(neighbour.normal)>.995:coplanar=true;break
					if not coplanar:bits|=1<<edge
			masks.append(bits)
	var decorated:ArrayMesh=build_mesh({"surfaces":surfaces},masks)
	variants[cache_key]=decorated
	if item.is_empty():
		item={"node":weakref(node),"original":source,"surfaces":surfaces,"transform":node.transform};mesh_records.append(item);node_records[id]=item
	item.original=source;item.decorated=decorated;item.stale=false;assign_mesh(node,decorated)
