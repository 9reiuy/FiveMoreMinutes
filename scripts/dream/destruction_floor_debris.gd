extends Node3D
## Source-mesh fracture, tumbling panels, then brief impact crumbs. No bodies.
const MAX_BURSTS := 32
const PERF=preload("res://scripts/app/performance_markers.gd")
const CRUMB_DURATION := .4
const MAX_LIFETIME := 2.5
var pieces: Array[Dictionary] = []
var world: Node
var retiring := false
var render: MultiMeshInstance3D
var elapsed := 0.0
var glass_burst := false
var random := RandomNumberGenerator.new()
var glass_edge_material: StandardMaterial3D
## Fracture geometry depends only on the source mesh, its materials and the grid
## cell, so identical windows/doors reuse the sliced panels instead of re-clipping
## every triangle on the CPU in the frame the glass breaks.
const SLICE_CACHE_LIMIT := 1024
static var _slice_cache: Dictionary = {}
static var _outline_cache: Dictionary = {}
static var _geometry_cache:Dictionary={}
static var _door_geometry_keys:Dictionary={}
var audit_slice_hits:=0
var audit_slice_misses:=0
var audit_geometry_hits:=0
var audit_geometry_misses:=0
var audit_nodes:=0
var audit_unique_nodes:=0
var audit_slice_usec:=0
var audit_node_usec:=0
var audit_outline_hits:=0
var audit_outline_misses:=0
var audit_outline_usec:=0
const MAX_PREFILL_SPECS:=32
## One cutaway-disabled copy per source material (was one duplicate per fragment).
## Sharing also lets OfficeDitherLighting reuse its dither copy instead of
## compiling a fresh material for every short-lived panel.
static var _fragment_materials: Dictionary = {}
static var _shared_edge_material: StandardMaterial3D
static var _crumb_materials: Dictionary = {}
static var _crumb_shape: BoxMesh

static func spawn(source: Node3D, direction: Vector2, glass: bool) -> bool:
	var owner_world: Node = source
	while owner_world != null and not owner_world.has_method("_cell_for_gameplay_position"):
		owner_world = owner_world.get_parent()
	if owner_world == null: return false
	var diagnostic_started:=PERF.begin(owner_world)
	var burst: Node3D = load("res://scripts/dream/destruction_floor_debris.gd").new()
	burst.world = owner_world
	owner_world.floor_root.add_child(burst)
	burst.add_to_group(&"persistent_destruction_debris") # Existing floor cleanup contract.
	burst.build_from_source(source,direction,glass)
	var live: Array = source.get_tree().get_nodes_in_group(&"persistent_destruction_debris").filter(func(n: Node) -> bool: return n.get_parent()==burst.get_parent() and not n.retiring)
	if live.size()>MAX_BURSTS: live[0].retire()
	PERF.end(owner_world,"fracture_build",diagnostic_started)
	PERF.event(owner_world,"glass_break" if glass else "door_break",{"pieces":burst.pieces.size(),"source":String(source.name),"nodes":burst.audit_nodes,"unique_nodes":burst.audit_unique_nodes,"slice_hits":burst.audit_slice_hits,"slice_misses":burst.audit_slice_misses,"geometry_hits":burst.audit_geometry_hits,"geometry_misses":burst.audit_geometry_misses,"outline_hits":burst.audit_outline_hits,"outline_misses":burst.audit_outline_misses,"slice_us":burst.audit_slice_usec,"node_us":burst.audit_node_usec,"outline_us":burst.audit_outline_usec})
	return true

func build_from_source(source: Node3D, direction: Vector2, glass: bool) -> void:
	random.seed = get_instance_id()
	glass_burst = glass
	var nodes: Array[MeshInstance3D] = []
	if glass:
		if is_instance_valid(source.glass_pane): nodes.append(source.glass_pane)
		if is_instance_valid(source.frame_root):
			for child in source.frame_root.find_children("*","MeshInstance3D",true,false):
				if child.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: nodes.append(child)
	else:
		for visual in source._visuals:
			if not is_instance_valid(visual): continue
			nodes.append(visual)
			for child in visual.find_children("*","MeshInstance3D",true,false):
				if child.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: nodes.append(child)
		for handle in source._handle_visuals:
			if is_instance_valid(handle) and not nodes.has(handle): nodes.append(handle)
	audit_nodes=nodes.size()
	var distinct:Dictionary={}
	for node in nodes:distinct[node.get_instance_id()]=true
	audit_unique_nodes=distinct.size()
	for node in nodes: _fracture(node,direction)
	var started:=PERF.begin(self)
	_make_crumb_batch()
	PERF.end(self,"fracture_crumbs",started)
	if PERF.current(self)!=null:
		PERF.current(self).record_stage("fracture_slice",audit_slice_usec/1000.0)
		PERF.current(self).record_stage("fracture_nodes",audit_node_usec/1000.0)
		PERF.current(self).record_stage("fracture_outline",audit_outline_usec/1000.0)

func _fracture(source: MeshInstance3D, direction: Vector2) -> void:
	if source.mesh==null: return
	var diagnostic_active:bool=PERF.current(self)!=null
	var bounds := source.mesh.get_aabb()
	var is_glass := String(source.name) in ["GlassPane","WindowGlassVisual","ReviewPixelGlass"]
	var columns := 3 if is_glass else 2
	var rows := 2 if is_glass else 3
	# Small handles and thin frame bars remain one recognizable piece.
	if bounds.size.x<.18 or bounds.size.y<.18: columns=1; rows=1
	for row in rows:
		for column in columns:
			var low := Vector2(bounds.position.x+bounds.size.x*column/columns,bounds.position.y+bounds.size.y*row/rows)
			var high := low+Vector2(bounds.size.x/columns,bounds.size.y/rows)
			var sides: Array = [-1,1] if is_glass and columns>1 else [0]
			for side: int in sides:
				var diagnostic_started:int=Time.get_ticks_usec() if diagnostic_active else 0
				var fractured := _cached_slice(source,low,high,side)
				if diagnostic_active:audit_slice_usec+=Time.get_ticks_usec()-diagnostic_started
				if fractured.get_surface_count()==0: continue
				diagnostic_started=Time.get_ticks_usec() if diagnostic_active else 0
				var pivot := Vector3((low.x+high.x)*.5,(low.y+high.y)*.5,bounds.get_center().z)
				var piece := Node3D.new()
				add_child(piece)
				piece.transform = global_transform.affine_inverse()*source.global_transform*Transform3D(Basis.IDENTITY,pivot)
				var visual := MeshInstance3D.new()
				visual.mesh = fractured
				visual.position = -pivot
				visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				piece.add_child(visual)
				if is_glass:
					var rim := MeshInstance3D.new()
					var outline_started:int=Time.get_ticks_usec() if diagnostic_active else 0
					rim.mesh = _cached_outline(fractured)
					if diagnostic_active:audit_outline_usec+=Time.get_ticks_usec()-outline_started
					rim.position = -pivot
					rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					piece.add_child(rim)
				# Gameplay supplies a map-space push direction. Launch every large
				# fragment forward, including glass, with only a narrow fan of scatter.
				var heading := direction.normalized() if direction.length_squared()>.0001 else Vector2.RIGHT.rotated(random.randf_range(-PI,PI))
				var scatter := heading.rotated(random.randf_range(-.18,.18))*random.randf_range(4.0,6.0)
				pieces.append({"node":piece,"visual":visual,"velocity":Vector3(scatter.x,random.randf_range(.2,1.4),scatter.y),"spin":Vector3(random.randf_range(-10,10),random.randf_range(-4,4),random.randf_range(-7,7)),"settled":false,"impact_age":0.0,"crumb_origin":Vector3.ZERO,"crumbs":[]})
				if diagnostic_active:audit_node_usec+=Time.get_ticks_usec()-diagnostic_started

func _cached_slice(source: MeshInstance3D, low: Vector2, high: Vector2, diagonal_side: int) -> ArrayMesh:
	var signature := "%d|%d" % [source.mesh.get_instance_id(), source.material_override.get_instance_id() if source.material_override!=null else 0]
	for surface in source.mesh.get_surface_count():
		var override := source.get_surface_override_material(surface)
		signature += "|%d" % (override.get_instance_id() if override!=null else 0)
	var geometry_key:=_geometry_key(source,low,high,diagonal_side)
	var key := signature+"|"+geometry_key
	var cached: Variant = _slice_cache.get(key)
	if cached is ArrayMesh:
		audit_slice_hits+=1
		return cached
	audit_slice_misses+=1
	if _slice_cache.size()>=SLICE_CACHE_LIMIT:
		_slice_cache.clear()
		_outline_cache.clear()
	# Geometry is immutable and shared across door leaves; material bindings are
	# not. Keep their cache keys separate so unique per-door tints/mirrors do not
	# force us to re-clip the same triangles, or leak one door's paint to another.
	var output:ArrayMesh
	if _geometry_cache.has(geometry_key):
		audit_geometry_hits+=1
		output=ArrayMesh.new()
		for surface_data in _geometry_cache[geometry_key]:
			output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface_data.arrays)
			var material:=_slice_material(source,int(surface_data.source_surface))
			if material!=null:output.surface_set_material(output.get_surface_count()-1,material)
	else:
		audit_geometry_misses+=1
		output=_slice_mesh(source,low,high,diagonal_side)
		if _geometry_cache.size()>=SLICE_CACHE_LIMIT:_geometry_cache.clear()
		var surfaces:Array=[]
		var original_surfaces:PackedInt32Array=output.get_meta(&"fragment_source_surfaces",PackedInt32Array())
		var original_arrays:Array=output.get_meta(&"fragment_source_arrays",[])
		for index in output.get_surface_count():
			# Cache BEFORE ArrayMesh packs the normals. Reading packed normals back
			# then repacking them introduces tiny second-generation rounding changes.
			surfaces.append({"source_surface":int(original_surfaces[index]),"arrays":original_arrays[index]})
		_geometry_cache[geometry_key]=surfaces
		output.remove_meta(&"fragment_source_arrays")
	output.set_meta(&"fragment_geometry_key",geometry_key)
	_slice_cache[key] = output
	return output

static func _standard_glass_spec(source:MeshInstance3D)->String:
	# Deliberately limited to our two controlled window factories. Read FINAL
	# parameters at use time; continuous windows mutate size after base creation.
	if source.mesh==null or source.mesh.get_script()!=null:return ""
	var door:Node=source.get_parent()
	while door!=null and not door is PhysicalDoor3D:door=door.get_parent()
	if door is PhysicalDoor3D and door.get_script().resource_path=="res://scripts/dream/physical_door_3d.gd":
		# Some live leaves are rebuilt by PhysicalDoor after the dressing pass.
		# Canonicalize ONLY final geometry inside this controlled door factory.
		if source.mesh is BoxMesh:return _box_spec(source.mesh)
		if source.mesh is QuadMesh:return _quad_spec(source.mesh)
		if source.mesh is ArrayMesh and source.mesh.get_blend_shape_count()==0:
			return _door_array_spec(source.mesh)
	var window:Node=source.get_parent()
	if window!=null and window.name==&"WindowFrame":window=window.get_parent()
	if window==null or window.get_script()==null:return ""
	if window.get_script().resource_path=="res://scripts/dream/wall_segment_3d.gd" and source==window.window_pane:
		if source.mesh is BoxMesh:return _box_spec(source.mesh)
		if source.mesh is QuadMesh:return _quad_spec(source.mesh)
	if window.get_script().resource_path not in ["res://scripts/dream/breakable_glass_window_3d.gd","res://scripts/dream/continuous_office_glass.gd"]:return ""
	if source!=window.glass_pane and source.get_parent()!=window.frame_root:return ""
	if source.mesh is BoxMesh:
		return _box_spec(source.mesh)
	if source.mesh is QuadMesh:
		return _quad_spec(source.mesh)
	return ""

static func _box_spec(box:BoxMesh)->String:
	return "standard_glass_box_v1/"+var_to_bytes([box.size,box.subdivide_width,box.subdivide_height,box.subdivide_depth,box.flip_faces,box.add_uv2,box.uv2_padding,box.get_aabb()]).hex_encode()

static func _quad_spec(quad:QuadMesh)->String:
	return "standard_glass_quad_v1/"+var_to_bytes([quad.size,quad.center_offset,quad.orientation,quad.flip_faces,quad.add_uv2,quad.uv2_padding,quad.get_aabb()]).hex_encode()

static func _door_array_spec(mesh:ArrayMesh)->String:
	if _door_geometry_keys.has(mesh):return _door_geometry_keys[mesh]
	var data:Array=[mesh.get_aabb()]
	for surface in mesh.get_surface_count():data.append([mesh.surface_get_primitive_type(surface),mesh.surface_get_format(surface),mesh.surface_get_arrays(surface)])
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(var_to_bytes(data))
	var key:="controlled_door_array_v1/"+digest.finish().hex_encode()
	if _door_geometry_keys.size()>=128:_door_geometry_keys.clear()
	_door_geometry_keys[mesh]=key
	if mesh.get_meta(&"fracture_geometry_watched",0)!=mesh.get_instance_id():
		mesh.set_meta(&"fracture_geometry_watched",mesh.get_instance_id())
		var reference:WeakRef=weakref(mesh)
		mesh.changed.connect(func()->void:
			var value:Resource=reference.get_ref()
			if value!=null:_door_geometry_keys.erase(value))
	return key

static func _geometry_key(source:MeshInstance3D,low:Vector2,high:Vector2,side:int)->String:
	var spec:=_standard_glass_spec(source)
	if spec.is_empty():spec="mesh/"+str(source.mesh.get_instance_id())
	return spec+"/"+var_to_bytes([low,high,side]).hex_encode()

static func prefill_standard_glass(owner_world:Node)->Dictionary:
	# Loading only. No pieces, RNG, health, signals, collision or transforms change.
	var started:=Time.get_ticks_usec()
	var worker=load("res://scripts/dream/destruction_floor_debris.gd").new()
	var specs:Dictionary={}
	var windows:=0
	var current_root:Node=owner_world.get("generated_root")
	if not is_instance_valid(current_root):current_root=owner_world.floor_root
	for window in owner_world.get_tree().get_nodes_in_group(&"breakable_glass_windows"):
		if not current_root.is_ancestor_of(window) or window.is_shattered:continue
		var sources:Array=[]
		if is_instance_valid(window.glass_pane):sources.append(window.glass_pane)
		if is_instance_valid(window.frame_root):
			for child in window.frame_root.find_children("*","MeshInstance3D",true,false):
				if child.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:sources.append(child)
		windows+=1
		worker._prefill_sources(sources,specs)
	var doors:=0
	if is_instance_valid(owner_world.get("door_root")):
		for door in owner_world.door_root.get_children():
			if not door is PhysicalDoor3D:continue
			var sources:Array=[]
			for visual in door._visuals:
				if not is_instance_valid(visual):continue
				sources.append(visual)
				for child in visual.find_children("*","MeshInstance3D",true,false):
					if child.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:sources.append(child)
			for handle in door._handle_visuals:
				if is_instance_valid(handle) and not sources.has(handle):sources.append(handle)
			doors+=1
			worker._prefill_sources(sources,specs)
	var result:Dictionary={"windows":windows,"doors":doors,"specs":specs.size(),"geometry_misses":worker.audit_geometry_misses,"outline_misses":worker.audit_outline_misses,"cpu_ms":(Time.get_ticks_usec()-started)/1000.0}
	worker.free()
	PERF.event(owner_world,"glass_geometry_prefilled",result)
	return result

func _prefill_sources(sources:Array,specs:Dictionary)->void:
		for source:MeshInstance3D in sources:
			var pane:bool=String(source.name) in ["GlassPane","WindowGlassVisual","ReviewPixelGlass"]
			var spec:=_standard_glass_spec(source)
			if not spec.is_empty():spec+="/pane" if pane else "/frame"
			if spec.is_empty() or specs.has(spec) or specs.size()>=MAX_PREFILL_SPECS:continue
			specs[spec]=true
			var bounds:=source.mesh.get_aabb()
			var columns:=3 if pane else 2
			var rows:=2 if pane else 3
			if bounds.size.x<.18 or bounds.size.y<.18:columns=1;rows=1
			for row in rows:
				for column in columns:
					var low:=Vector2(bounds.position.x+bounds.size.x*column/columns,bounds.position.y+bounds.size.y*row/rows)
					var high:=low+Vector2(bounds.size.x/columns,bounds.size.y/rows)
					for side:int in ([-1,1] if pane and columns>1 else [0]):
						var fragment:ArrayMesh=_cached_slice(source,low,high,side)
						if pane and fragment.get_surface_count()>0:_cached_outline(fragment)

func _slice_material(source:MeshInstance3D,surface:int)->Material:
	var material:Material=source.material_override if source.material_override!=null else source.get_surface_override_material(surface)
	if material==null:material=source.mesh.surface_get_material(surface)
	if material==null:return null
	if not _fragment_materials.has(material):PERF.event(self,"fragment_material_clone",{"source_id":material.get_instance_id(),"type":material.get_class()})
	return _fragment_material(material)

func _cached_outline(mesh: ArrayMesh) -> ArrayMesh:
	var geometry:Variant=mesh.get_meta(&"fragment_geometry_key",mesh)
	# Default edge paint is shared. Explicit custom paint must keep its identity.
	var edge_id:=glass_edge_material.get_instance_id() if glass_edge_material!=null and glass_edge_material!=_shared_edge_material else 0
	var key:Variant=geometry+"/edge/"+str(edge_id) if geometry is String else mesh
	var cached: Variant = _outline_cache.get(key)
	if cached is ArrayMesh:
		audit_outline_hits+=1
		return cached
	audit_outline_misses+=1
	var output := _glass_outline(mesh)
	_outline_cache[key] = output
	return output

static func _fragment_material(source: Material) -> Material:
	var cached: Variant = _fragment_materials.get(source)
	if cached is Material: return cached
	if _fragment_materials.size()>=256: _fragment_materials.clear()
	var material: Material = source.duplicate()
	if material is ShaderMaterial: material.set_shader_parameter("architecture_cutaway",false)
	_fragment_materials[source] = material
	return material

func _slice_mesh(source: MeshInstance3D, low: Vector2, high: Vector2, diagonal_side: int = 0) -> ArrayMesh:
	var output := ArrayMesh.new()
	var original_surfaces:=PackedInt32Array()
	var original_arrays:Array=[]
	for surface in source.mesh.get_surface_count():
		if source.mesh is ArrayMesh and source.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: continue
		var arrays := source.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		var added := 0
		for triangle in range(0,indices.size(),3):
			var polygon: Array = []
			for corner in 3:
				var index := indices[triangle+corner]
				polygon.append({"v":vertices[index],"n":normals[index] if not normals.is_empty() else Vector3.FORWARD,"uv":uvs[index] if not uvs.is_empty() else Vector2.ZERO})
			for plane in [Vector3(0,low.x,1),Vector3(0,high.x,-1),Vector3(1,low.y,1),Vector3(1,high.y,-1)]:
				polygon = _clip(polygon,int(plane.x),plane.y,plane.z)
				if polygon.is_empty(): break
			if diagonal_side!=0:
				var diagonal := Vector2(high.y-low.y,high.x-low.x)
				polygon = _clip_plane(polygon,diagonal,diagonal.dot(Vector2(low.x,high.y)),float(diagonal_side))
			for i in range(1,polygon.size()-1):
				for corner in [polygon[0],polygon[i],polygon[i+1]]:
					builder.set_normal(corner.n)
					builder.set_uv(corner.uv)
					builder.add_vertex(corner.v)
					added += 1
		if added==0: continue
		var material:Material=_slice_material(source,surface)
		if material!=null:
			builder.set_material(material)
		original_arrays.append(builder.commit_to_arrays())
		builder.commit(output)
		original_surfaces.append(surface)
	output.set_meta(&"fragment_source_surfaces",original_surfaces)
	output.set_meta(&"fragment_source_arrays",original_arrays)
	return output

func _glass_outline(mesh: ArrayMesh) -> ArrayMesh:
	# Newly exposed cut edges catch light; keep the pane's original transparent
	# pixels instead of making it opaque just to reveal the flying fragments.
	var points := PackedVector2Array()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]: points.append(Vector2(point.x,point.y))
	var hull := Geometry2D.convex_hull(points)
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(hull.size()-1):
		var segment := hull[i+1]-hull[i]
		if segment.length()<.001: continue
		var box := BoxMesh.new()
		box.size = Vector3(segment.length(),.025,.015)
		var middle := (hull[i]+hull[i+1])*.5
		builder.append_from(box,0,Transform3D(Basis(Vector3.BACK,segment.angle()),Vector3(middle.x,middle.y,mesh.get_aabb().get_center().z)))
	if glass_edge_material==null:
		if _shared_edge_material==null:
			_shared_edge_material = StandardMaterial3D.new()
			_shared_edge_material.albedo_color = Color(.67,.8,.83)
			_shared_edge_material.roughness = .9
			_shared_edge_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		glass_edge_material = _shared_edge_material
	builder.set_material(glass_edge_material)
	return builder.commit()

func _clip(polygon: Array, axis: int, boundary: float, side: float) -> Array:
	return _clip_plane(polygon,Vector2.RIGHT if axis==0 else Vector2.DOWN,boundary,side)

func _clip_plane(polygon: Array, normal: Vector2, boundary: float, side: float) -> Array:
	var result: Array = []
	if polygon.is_empty(): return result
	var before: Dictionary = polygon.back()
	var a: float = (normal.dot(Vector2(before.v.x,before.v.y))-boundary)*side
	for after: Dictionary in polygon:
		var b: float = (normal.dot(Vector2(after.v.x,after.v.y))-boundary)*side
		if (a>=0)!=(b>=0):
			var t := a/(a-b)
			result.append({"v":before.v.lerp(after.v,t),"n":before.n.lerp(after.n,t).normalized(),"uv":before.uv.lerp(after.uv,t)})
		if b>=0: result.append(after)
		before=after; a=b
	return result

func _make_crumb_batch() -> void:
	render = MultiMeshInstance3D.new()
	render.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = _crumb_materials.get(glass_burst)
	if material==null:
		material = StandardMaterial3D.new()
		material.albedo_color = Color(.64,.79,.81) if glass_burst else Color(.35,.43,.48)
		material.roughness = .9
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_crumb_materials[glass_burst] = material
	render.material_override = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	if _crumb_shape==null:
		_crumb_shape = BoxMesh.new()
		_crumb_shape.size = Vector3.ONE
	multi.mesh = _crumb_shape
	multi.instance_count = pieces.size()*4
	render.multimesh = multi
	add_child(render)
	for i in multi.instance_count: multi.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))

func retire() -> void:
	retiring = true
	queue_free()

func _process(delta: float) -> void:
	if is_queued_for_deletion(): return
	elapsed += maxf(delta,0)
	if elapsed>=MAX_LIFETIME: queue_free(); return
	var alive := false
	for i in pieces.size():
		var item: Dictionary = pieces[i]
		var piece: Node3D = item.node
		if item.settled:
			item.impact_age += delta
			var age: float = item.impact_age
			for j in 4:
				var crumb: Dictionary = item.crumbs[j]
				var travel: Vector3 = crumb.velocity*minf(age,.16)
				travel.y = maxf(0.0,float(crumb.velocity.y)*age-10.0*age*age)
				var scale_factor := 1.0-smoothstep(.2,CRUMB_DURATION,age)
				var pose := Transform3D(Basis.from_euler(crumb.rotation).scaled(crumb.size*scale_factor),item.crumb_origin+travel)
				render.multimesh.set_instance_transform(i*4+j,pose)
			if age<CRUMB_DURATION: alive=true
			continue
		alive=true
		var velocity: Vector3 = item.velocity
		velocity.y -= 18.0*delta
		piece.position += velocity*delta
		piece.rotation += Vector3(item.spin)*delta
		var point: Vector3 = world.to_local(piece.global_position)
		var cell: Vector2i = world._cell_for_gameplay_position(Vector2(point.x,point.z)*32)
		var grounded: bool = world.floor_cells.has(cell) and not world.pit_cells.has(cell)
		var lowest := INF
		if grounded and velocity.y<0:
			var visual: MeshInstance3D = item.visual
			var bounds := visual.mesh.get_aabb()
			var pose: Transform3D = world.global_transform.affine_inverse()*visual.global_transform
			for corner in 8: lowest=minf(lowest,(pose*bounds.get_endpoint(corner)).y)
		if grounded and lowest<=.04 and velocity.y<0:
			piece.hide()
			item.settled=true
			item.crumb_origin = to_local(world.to_global(Vector3(point.x,.035,point.z)))
			for j in 4:
				item.crumbs.append({"velocity":Vector3(random.randf_range(-.6,.6),random.randf_range(.3,.7),random.randf_range(-.6,.6)),"size":Vector3(random.randf_range(.04,.10),.025,random.randf_range(.03,.08)),"rotation":Vector3(0,random.randf_range(-PI,PI),0)})
		elif point.y < -8: piece.hide()
		item.velocity=velocity
	if not alive: queue_free()
