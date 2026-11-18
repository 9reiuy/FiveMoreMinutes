extends Node3D
## Surface-attached blood. Its isolated query layer never affects gameplay physics.
const QUERY_LAYER := 1 << 29
const RECEIVER_LAYER := 1 << 16
const LAYERS := preload("res://scripts/dream/render_layer_mask.gd")
const MARK := preload("res://scripts/dream/surface_blood_mark.gd")
const MAX_DROPS := 192
const MAX_FACES := 36
const DENSITY := 32.0
const TILE_METRES := 4.0
const ORANGE := Color("df741e")
const NEAR_SPLASH_LIMIT := .95
const FAR_SPLASH_START := 1.30
var camera: Camera3D
var receivers: Array[Dictionary] = []
var _receiver_ids: Dictionary = {}
var faces: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var batch: MultiMeshInstance3D
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var active := true
var emitted := 0
var hit_count := 0
var dropped_budget := 0
var query_usec := 0
var atlas_uploads := 0
static var _filter_users := 0
static var _saved_filter := 1
var _upload_clock := 0.0
var recycled_faces := 0
var record_diagnostics := false
var mixed_splatters := 0
var emitted_large_drops := 0
var tapered_splatters := 0
var stamp_shapes: Array[Dictionary] = []
var use_surface_meshes := true

func set_surface_meshes(enabled: bool) -> void:
	if use_surface_meshes == enabled: return
	use_surface_meshes = enabled
	if enabled and is_inside_tree(): MARK.prewarm(self, camera)
	for face in faces:
		var old: Node3D = face.ref.get_ref()
		var receiver: Dictionary = receivers[face.receiver]
		if not is_instance_valid(old) or not is_instance_valid(receiver.owner.get_ref()): continue
		face.ref = weakref(_face_visual(receiver, face))
		old.free()

func _enter_tree() -> void:
	if _filter_users == 0:
		_saved_filter = int(ProjectSettings.get_setting("rendering/textures/decals/filter", 1))
	_filter_users += 1
	RenderingServer.decals_set_filter(RenderingServer.DECAL_FILTER_NEAREST)

func _ready() -> void:
	rng.seed = 813615
	if use_surface_meshes: MARK.prewarm(self, camera)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new(); quad.size = Vector2.ONE
	mm.mesh = quad; mm.instance_count = MAX_DROPS; mm.visible_instance_count = 0
	batch = MultiMeshInstance3D.new(); batch.name = "OriginalPixelBloodDrops"
	batch.multimesh = mm; batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/dream3d/surface_blood_drops.gdshader")
	mat.set_shader_parameter("frames", _make_particle_frames())
	mat.set_shader_parameter("large_colour",ORANGE)
	batch.material_override = mat; batch.top_level = true; add_child(batch)

func register_receiver(owner: Node3D, label: String, include_hidden := false) -> int:
	var id := owner.get_instance_id()
	if _receiver_ids.has(id): return int(_receiver_ids[id])
	var mesh_nodes: Array[Node] = owner.find_children("*", "MeshInstance3D", true, false)
	if owner is MeshInstance3D: mesh_nodes.push_front(owner)
	var triangles := PackedVector3Array()
	var originals: Array[Dictionary] = []
	var bounds := AABB(); var first := true
	for item in mesh_nodes:
		var mesh_node := item as MeshInstance3D
		if bool(mesh_node.get_meta(&"surface_blood_excluded", false)): continue
		if mesh_node.mesh == null or (not include_hidden and not mesh_node.is_visible_in_tree()): continue
		if mesh_node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var node_name := String(mesh_node.name).to_lower()
		if "shadow" in node_name or "reflection" in node_name or "glow" in node_name: continue
		var xform := owner.global_transform.affine_inverse() * mesh_node.global_transform
		var vertices := mesh_node.mesh.get_faces()
		if vertices.is_empty(): continue
		for vertex in vertices:
			var p: Vector3 = xform * vertex
			triangles.append(p)
			if first: bounds = AABB(p,Vector3.ZERO); first = false
			else: bounds = bounds.expand(p)
		originals.append({"ref":weakref(mesh_node),"layers":mesh_node.layers})
		LAYERS.apply(mesh_node, mesh_node.layers | RECEIVER_LAYER)
	if triangles.is_empty(): return -1
	var body := StaticBody3D.new(); body.name = "BloodOnlySurfaceQueries"
	body.collision_layer = QUERY_LAYER if owner.is_visible_in_tree() else 0; body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new(); shape.set_faces(triangles); shape.backface_collision = true
	var collision := CollisionShape3D.new(); collision.shape = shape; body.add_child(collision)
	var index := -1
	for i in receivers.size():
		if not is_instance_valid(receivers[i].owner.get_ref()): index = i; break
	if index < 0: index = receivers.size()
	body.set_meta(&"blood_receiver", index)
	owner.add_child(body)
	var record := {"id":id,"owner":weakref(owner),"body":weakref(body),"name":label,"bounds":bounds,"originals":originals}
	if index == receivers.size(): receivers.append(record)
	else:
		_receiver_ids.erase(receivers[index].get("id",0))
		receivers[index] = record
	_receiver_ids[id] = index
	owner.visibility_changed.connect(_receiver_visibility_changed.bind(index))
	owner.tree_entered.connect(_receiver_visibility_changed.bind(index))
	return index

func _receiver_visibility_changed(index: int) -> void:
	if index<0 or index>=receivers.size(): return
	var receiver := receivers[index]
	var owner: Node3D = receiver.owner.get_ref()
	var body: StaticBody3D = receiver.body.get_ref()
	if not is_instance_valid(body): return
	var mask := QUERY_LAYER if is_instance_valid(owner) and owner.is_visible_in_tree() else 0
	if body.collision_layer!=mask: body.collision_layer = mask

func restore_receiver_layers() -> void:
	# Floor reflection installation legitimately rewrites render masks during
	# rollback. Re-add only our receiver bit after that owner has finished.
	for receiver in receivers:
		for original in receiver.originals:
			var mesh: VisualInstance3D = original.ref.get_ref()
			if is_instance_valid(mesh): LAYERS.apply(mesh,mesh.layers | RECEIVER_LAYER)

func emit_spray(origin: Vector3, direction: Vector3, lethal := false, strength := 1.0, seed_value := -1) -> void:
	if not active: return
	if seed_value >= 0: rng.seed = seed_value
	var heading := Vector3(direction.x,0,direction.z).normalized()
	if heading.length_squared() < .1: heading = Vector3.FORWARD
	var count := 56 if lethal else 32
	var large_count := 10 if lethal else 6
	# Freeze one view ray for this burst: its surface projection must meet the
	# visible wound, not the foot position below it. Deposited marks stay local.
	var source_ray := Vector3.UP
	if is_instance_valid(camera):
		source_ray = camera.global_basis.z.normalized() if camera.projection==Camera3D.PROJECTION_ORTHOGONAL else (origin-camera.global_position).normalized()
	for i in count:
		if drops.size() >= MAX_DROPS: dropped_budget += 1; continue
		var dir := heading.rotated(Vector3.UP,rng.randf_range(-.32,.32))
		var speed := rng.randf_range(3.2,7.6) * clampf(strength,.7,1.4)
		# A directed jet plus slower low droplets, not a screen-facing line.
		if i % 5 == 0: speed *= .35
		var large := i<large_count
		if large: speed *= .48
		var velocity := dir * speed + Vector3.UP*rng.randf_range(.4,2.4)
		if i % 4 == 1: velocity.y += 1.6
		var position_world := origin + Vector3(rng.randf_range(-.025,.025),rng.randf_range(-.045,.045),rng.randf_range(-.025,.025))
		var life := rng.randf_range(.65,1.15)
		var size := rng.randf_range(.08,.15)
		var stamp := rng.randf_range(1.3,3.4)
		if large: size *= 2.65; stamp *= 1.7; emitted_large_drops += 1
		# All droplets in this burst share the wound, despite tiny starting jitter.
		drops.append({"p":position_world,"origin":origin,"source_ray":source_ray,"v":velocity,"age":0.0,"life":life,"size":size,"stamp":stamp,"large":large})
		emitted += 1

func emit_drips(origin: Vector3, count := 3, radius := 2.0) -> void:
	if not active: return
	for i in count:
		if drops.size() >= MAX_DROPS: dropped_budget += 1; continue
		drops.append({"p":origin,"v":Vector3(rng.randf_range(-.25,.25),rng.randf_range(.1,.5),rng.randf_range(-.25,.25)),"age":0.0,"life":.7,"size":.09,"stamp":radius})
		emitted += 1

func _physics_process(delta: float) -> void:
	if not active: return
	step(delta)

func step(delta: float) -> void:
	elapsed += delta
	var start := Time.get_ticks_usec()
	# Receiver visibility is event-driven: avoid visiting thousands of static
	# furniture parts or rewriting their physics layers on every particle tick.
	var space := get_world_3d().direct_space_state
	for i in range(drops.size()-1,-1,-1):
		var drop := drops[i]
		var previous: Vector3 = drop.p
		var velocity: Vector3 = drop.v
		velocity += Vector3.DOWN * 9.8 * delta
		velocity *= maxf(0.0,1.0-.42*delta)
		var next := previous + velocity * delta
		var ray := PhysicsRayQueryParameters3D.create(previous,next,QUERY_LAYER)
		ray.hit_back_faces = true
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			hit["spray_velocity"] = velocity
			hit["spray_origin"] = drop.get("origin",previous)
			hit["source_ray"] = drop.get("source_ray",Vector3.UP)
			hit["large_drop"] = bool(drop.get("large",false))
			var displacement: Vector3 = Vector3(hit.position)-Vector3(drop.get("origin",previous))
			var contact_normal: Vector3 = hit.normal
			hit["surface_travel"] = (displacement-contact_normal*displacement.dot(contact_normal)).length()
			var contact_radius := float(drop.stamp)
			if bool(drop.get("large",false)):
				contact_radius *= lerpf(1.0,.5,smoothstep(.35,1.5,Vector3(hit.position).distance_to(drop.origin)))
			deposit(hit,contact_radius); drops.remove_at(i); continue
		drop.p = next; drop.v = velocity; drop.age += delta
		if drop.age >= drop.life or next.y < -2: drops.remove_at(i)
	query_usec = Time.get_ticks_usec()-start
	_upload_clock += delta
	if _upload_clock >= 1.0/15.0:
		_flush_faces(); _upload_clock = 0.0
	_draw_drops()

func trace(from: Vector3, to: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(from,to,QUERY_LAYER)
	ray.hit_back_faces = true
	return get_world_3d().direct_space_state.intersect_ray(ray)

func deposit(hit: Dictionary, radius := 2.5) -> void:
	var body: Node = hit.collider
	if not is_instance_valid(body) or not body.has_meta(&"blood_receiver"): return
	var index := int(body.get_meta(&"blood_receiver"))
	var receiver := receivers[index]
	var owner: Node3D = receiver.owner.get_ref()
	if not is_instance_valid(owner): return
	var point: Vector3 = owner.to_local(hit.position)
	var normal: Vector3 = (owner.global_basis.transposed() * Vector3(hit.normal)).normalized()
	var plane := snappedf(point.dot(normal),.015625)
	var tangent := Vector3.RIGHT-normal*Vector3.RIGHT.dot(normal)
	if tangent.length_squared() < .1: tangent = Vector3.FORWARD-normal*Vector3.FORWARD.dot(normal)
	tangent = tangent.normalized()
	var bitangent := tangent.cross(normal).normalized()
	var tile := Vector2i(floori(point.dot(tangent)/TILE_METRES),floori(point.dot(bitangent)/TILE_METRES))
	var key := "%d:%s:%.4f:%s" % [index,normal.snapped(Vector3.ONE*.05),plane,tile]
	var face: Dictionary = {}
	for existing in faces:
		if existing.key == key and existing.ref.get_ref() != null: face = existing; break
	if face.is_empty():
		if faces.size() >= MAX_FACES:
			var oldest := 0
			for i in faces.size():
				if faces[i].ref.get_ref() == null: oldest = i; break
				if float(faces[i].get("last_used",0.0)) < float(faces[oldest].get("last_used",0.0)): oldest = i
			var retired: Node3D = faces[oldest].ref.get_ref()
			if is_instance_valid(retired): retired.free()
			faces.remove_at(oldest); recycled_faces += 1
		face = _new_face(index,normal,plane,key,tile)
		faces.append(face)
	face.last_used = elapsed
	var origin: Vector3 = face.origin
	var local := point-origin
	# Both renderers use the same local face UVs and painted image.
	var uv := Vector2(local.dot(face.u),local.dot(face.v)) * DENSITY + Vector2(face.dimensions)*.5
	var pixel := Vector2i(roundi(uv.x),roundi(uv.y))
	var velocity: Vector3 = hit.get("spray_velocity",Vector3.ZERO)
	var local_velocity := owner.global_basis.inverse()*velocity
	var axis := Vector2(local_velocity.dot(face.u),local_velocity.dot(face.v))
	var source_local: Vector3 = owner.to_local(hit.get("spray_origin",hit.position))
	var local_ray := owner.global_basis.inverse()*Vector3(hit.get("source_ray",Vector3.UP))
	var projected_source := source_local
	var denominator := local_ray.dot(normal)
	if absf(denominator)>.001:
		projected_source += local_ray*((point-source_local).dot(normal)/denominator)
	var source_offset := projected_source-Vector3(face.origin)
	var source_uv := Vector2(source_offset.dot(face.u),source_offset.dot(face.v))*DENSITY+Vector2(face.dimensions)*.5
	var source_screen_error := -1.0
	if is_instance_valid(camera) and absf(denominator)>.001:
		source_screen_error = camera.unproject_position(owner.to_global(projected_source)).distance_to(camera.unproject_position(owner.to_global(source_local)))
	var radial := Vector2(pixel)-source_uv
	if radial.length_squared()>.25: axis = radial
	if axis.length_squared()<.01: axis = Vector2.from_angle(rng.randf()*TAU)
	_paint_mixed_impact(face,pixel,radius,normal,axis.normalized(),hit.position,bool(hit.get("large_drop",false)),float(hit.get("surface_travel",0.0)),source_uv,source_screen_error)
	mixed_splatters += 1
	hit_count += 1
	if record_diagnostics and impacts.size() < 2048:
		impacts.append({"receiver":receiver.name,"point":hit.position,"normal":hit.normal,"face":key})

func _new_face(index: int, normal: Vector3, plane: float, key: String, tile: Vector2i) -> Dictionary:
	var receiver := receivers[index]
	var owner: Node3D = receiver.owner.get_ref()
	var u := Vector3.RIGHT-normal*Vector3.RIGHT.dot(normal)
	if u.length_squared() < .1: u = Vector3.FORWARD-normal*Vector3.FORWARD.dot(normal)
	u = u.normalized()
	var v := u.cross(normal).normalized()
	# Bounded local tiles avoid reuploading a room-sized image for one drop.
	# Power-of-two padding preserves stamps/drips crossing a tile boundary.
	var middle := (Vector2(tile)+Vector2.ONE*.5)*TILE_METRES
	var dimension := _power_two(ceili(TILE_METRES*DENSITY)+24)
	var dimensions := Vector2i(dimension,dimension)
	var origin := u*middle.x + v*middle.y + normal*plane
	var image := Image.create(dimensions.x,dimensions.y,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	var texture := ImageTexture.create_from_image(image)
	var face := {"key":key,"receiver":index,"image":image,"texture":texture,"dimensions":dimensions,"u":u,"v":v,"origin":origin,"dirty":false,"paint_count":0,"last_used":elapsed}
	face.ref = weakref(_face_visual(receiver, face))
	return face

func _face_visual(receiver: Dictionary, face: Dictionary) -> Node3D:
	if use_surface_meshes: return MARK.create(receiver, face)
	var owner: Node3D = receiver.owner.get_ref()
	var decal := Decal.new(); decal.name = "AttachedOrangeBlood"
	decal.texture_albedo = face.texture; decal.texture_emission = face.texture
	decal.emission_energy = .42
	decal.cull_mask = RECEIVER_LAYER
	decal.normal_fade = .75; decal.upper_fade = 0.0; decal.lower_fade = 0.0
	decal.size = Vector3(face.dimensions.x/DENSITY,.065,face.dimensions.y/DENSITY)
	decal.distance_fade_enabled = false
	owner.add_child(decal)
	var normal: Vector3 = Vector3(face.v).cross(face.u).normalized()
	decal.transform = Transform3D(Basis(face.u,normal,face.v),face.origin+normal*.008)
	return decal

func _power_two(value: int) -> int:
	var result := 16
	while result < value and result < 2048: result *= 2
	return result

func _paint_mixed_impact(face: Dictionary, center: Vector2i, radius: float, normal: Vector3, incoming: Vector2, impact_world: Vector3, large: bool, travel: float, source_uv: Vector2, source_screen_error: float) -> void:
	var paint_rng := RandomNumberGenerator.new()
	paint_rng.seed = center.x*917+center.y*113+int(face.receiver)*97+int(face.paint_count)*53
	# Near the wound keep heavy irregular drops. Farther contacts interleave
	# individual pointed splashes with the original fine specks, never lanes.
	var far_weight := smoothstep(.70,FAR_SPLASH_START,travel)
	# Cap every outer mark, including ordinary droplets. Merely switching off
	# the heavy flag previously left big round spots at distant contacts.
	radius = minf(radius,lerpf(5.2,.95,far_weight))
	var heavy := large and travel<NEAR_SPLASH_LIMIT
	var pointed := not heavy and travel>.55 and paint_rng.randf()<lerpf(.70,.45,far_weight)
	var angle := incoming.angle()
	var axis := Vector2.from_angle(angle)
	var side := Vector2(-axis.y,axis.x)
	var elongation := paint_rng.randf_range(.85,1.35) if heavy else paint_rng.randf_range(.75,1.8)
	var colour := ORANGE.darkened(paint_rng.randf_range(.01,.16))
	var phase := paint_rng.randf()*TAU
	var owner: Node3D = receivers[face.receiver].owner.get_ref()
	var world_normal := (owner.global_basis*normal).normalized()
	var context := {"owner":owner,"normal":world_normal,"anchor":impact_world+world_normal*.08,"receiver":int(face.receiver),"cache":{}}
	if pointed:
		_paint_pointed_impact(face,center,radius,axis,side,colour,context,paint_rng,travel,source_uv,source_screen_error)
		tapered_splatters += 1
		face.paint_count += 1; face.dirty = true
		return
	if travel>=FAR_SPLASH_START:
		_paint_first_sample_speck(face,center,radius,colour,context,paint_rng)
		if stamp_shapes.size()<512: stamp_shapes.append({"radius":radius,"angle":angle,"large":false,"elongation":1.0,"kind":"speck","travel":travel})
		face.paint_count += 1; face.dirty = true
		return
	var extent := ceili(radius*maxf(elongation,1.0)*1.45)+1
	var torn := heavy and paint_rng.randf()<.35
	# Actual particle contacts supply the layout. Each contact contributes an
	# irregular spot with different size/angle; there are no synthetic lanes.
	for y in range(-extent,extent+1):
		for x in range(-extent,extent+1):
			var q0 := Vector2(x,y)
			var q := Vector2(q0.dot(axis)/elongation,q0.dot(side))/maxf(radius,.5)
			var lobe_a := (q-Vector2(.48,-.23))/Vector2(.68,.60)
			var lobe_b := (q-Vector2(-.38,.30))/Vector2(.65,.56)
			var fill := minf(q.length_squared(),minf(lobe_a.length_squared(),lobe_b.length_squared()))
			if fill>1.0+.12*sin(q.angle()*3.0+phase): continue
			if torn and (q-Vector2(.65,.40)).length_squared()<.065: continue
			_put_mixed_pixel(face,center+Vector2i(x,y),colour,context)
	var satellites := paint_rng.randi_range(1,3) if heavy else int(paint_rng.randf()<.16)
	for i in satellites:
		var offset := Vector2.from_angle(angle+paint_rng.randf_range(-1.2,1.2))*radius*paint_rng.randf_range(1.5,2.5)
		var point := center+Vector2i(offset)
		_put_mixed_pixel(face,point,colour,context)
		if heavy: _put_mixed_pixel(face,point+Vector2i(1,0),colour,context)
	if heavy and absf(normal.y)<.5 and paint_rng.randf()<.3:
		var gravity := Vector3.DOWN-normal*normal.dot(Vector3.DOWN)
		var down := Vector2(gravity.dot(face.u),gravity.dot(face.v)).normalized()
		for i in paint_rng.randi_range(3,8): _put_mixed_pixel(face,center+Vector2i(down*i),colour,context)
	if stamp_shapes.size()<512: stamp_shapes.append({"radius":radius,"angle":angle,"large":heavy,"elongation":elongation,"kind":"heavy" if heavy else "speck","travel":travel})
	face.paint_count += 1; face.dirty = true

func _paint_pointed_impact(face: Dictionary, center: Vector2i, radius: float, axis: Vector2, side: Vector2, colour: Color, context: Dictionary, paint_rng: RandomNumberGenerator, travel: float, source_uv: Vector2, source_screen_error: float) -> void:
	var far_weight := smoothstep(.70,FAR_SPLASH_START,travel)
	var length := paint_rng.randf_range(7.5,15.0)*lerpf(1.0,.28,far_weight)
	var width := clampf(radius*paint_rng.randf_range(.25,.40),.35,lerpf(1.5,.55,far_weight))
	var back := paint_rng.randf_range(1.0,2.5)*lerpf(1.0,.28,far_weight)
	var split := paint_rng.randf()<.65
	var gap := paint_rng.randf_range(.3,.65)
	var gap_size := paint_rng.randf_range(.06,.15)
	var extent := ceili(length+3.0)
	var painted := PackedVector2Array()
	# Straight fragments radiate from the wound projected into this surface.
	# Vary shape/length/breaks, never add an independent angle or curve.
	for y in range(-extent,extent+1):
		for x in range(-extent,extent+1):
			var q := Vector2(x,y)
			var along := q.dot(axis)
			var t := (along+back)/(length+back)
			if t<0.0 or t>1.0: continue
			if split and absf(t-gap)<gap_size*.5: continue
			var half_width := width*pow(1.0-t,1.35)+.30
			if absf(q.dot(side))>half_width: continue
			var pixel := center+Vector2i(x,y)
			if _put_mixed_pixel(face,pixel,colour,context): painted.append(Vector2(pixel))
	# A few separated original-size chips retain the first sample's spray.
	for i in paint_rng.randi_range(1,3):
		var t := paint_rng.randf_range(.35,1.15)
		var offset := axis*(length*t)+side*paint_rng.randf_range(-width,width)
		var pixel := center+Vector2i(offset)
		if _put_mixed_pixel(face,pixel,colour,context): painted.append(Vector2(pixel))
	if stamp_shapes.size()<512: stamp_shapes.append({"radius":radius,"angle":axis.angle(),"large":false,"elongation":length/(2.0*width),"kind":"pointed","travel":travel,"length":length,"width":width,"source_uv":source_uv,"center":Vector2(center),"pixels":painted,"source_screen_error_px":source_screen_error})

func _paint_first_sample_speck(face: Dictionary, center: Vector2i, radius: float, colour: Color, context: Dictionary, paint_rng: RandomNumberGenerator) -> void:
	# Reuse the first sample's ragged tiny spot and 1px satellite layout,
	# restricted to a sub-texel radius instead of a distant heavy lobe.
	var extent := ceili(radius)+1
	for y in range(-extent,extent+1):
		for x in range(-extent,extent+1):
			var p := Vector2(x,y)
			var irregular := radius*(.8+.22*sin(float(x*7+y*11+face.paint_count)))
			if p.length()>irregular: continue
			_put_mixed_pixel(face,center+Vector2i(x,y),colour,context)
	for i in paint_rng.randi_range(1,3):
		var offset := Vector2.from_angle(paint_rng.randf()*TAU)*paint_rng.randf_range(radius+1,radius+5)
		_put_mixed_pixel(face,center+Vector2i(offset),colour,context)

func _put_mixed_pixel(face: Dictionary, point: Vector2i, colour: Color, context: Dictionary) -> bool:
	if not Rect2i(Vector2i.ZERO,face.dimensions).has_point(point): return false
	if not context.cache.has(point): context.cache[point] = _surface_stamp_point_visible(face,point,context)
	if not bool(context.cache[point]): return false
	_put(face.image,point,colour)
	return true

func _surface_stamp_point_visible(face: Dictionary, pixel: Vector2i, context: Dictionary) -> bool:
	var local_uv := (Vector2(pixel)-Vector2(face.dimensions)*.5)/DENSITY
	var local: Vector3 = face.origin+Vector3(face.u)*local_uv.x+Vector3(face.v)*local_uv.y
	var point: Vector3 = context.owner.to_global(local)
	var normal: Vector3 = context.normal
	var surface := trace(point+normal*.08,point-normal*.08)
	if surface.is_empty() or not surface.collider.has_meta(&"blood_receiver") or int(surface.collider.get_meta(&"blood_receiver"))!=int(context.receiver): return false
	if Vector3(surface.normal).dot(normal)<.9: return false
	var destination := point+normal*.08
	if destination.distance_squared_to(context.anchor)<.0001: return true
	return trace(context.anchor,destination).is_empty()

func _put(image: Image, point: Vector2i, colour: Color) -> void:
	if point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height():
		image.set_pixelv(point,colour)

func _flush_faces() -> void:
	for face in faces:
		if not is_instance_valid(face.ref.get_ref()): continue
		if face.dirty:
			# A mutable ImageTexture upload alone leaves Godot's decal atlas cache
			# stale. Rebind the merged face, not one Decal per blood droplet.
			var texture := ImageTexture.create_from_image(face.image)
			var visual: Node3D = face.ref.get_ref()
			if visual is Decal:
				visual.texture_albedo = texture; visual.texture_emission = texture
			elif visual is MeshInstance3D:
				visual.material_override.set_shader_parameter(&"blood_texture", texture)
			face.texture = texture; face.dirty = false; atlas_uploads += 1

func _draw_drops() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(batch): return
	var back := camera.global_basis.z.normalized()
	for i in drops.size():
		var drop := drops[i]
		var velocity: Vector3 = drop.v
		var along := velocity-back*velocity.dot(back)
		if along.length_squared() < .01: along = camera.global_basis.x
		along = along.normalized()
		var up := back.cross(along).normalized()
		var size: float = drop.size
		var large: bool = bool(drop.get("large",false))
		if large:
			var distance := Vector2(drop.p.x-drop.origin.x,drop.p.z-drop.origin.z).length()
			size *= lerpf(1.15,1.0/2.65,smoothstep(.30,FAR_SPLASH_START,distance))
			if distance>=FAR_SPLASH_START: large = false
		var stretch := lerpf(1.7,.85,clampf(drop.age/.35,0,1))
		var basis := Basis(along*size*stretch,up*size,back)
		batch.multimesh.set_instance_transform(i,Transform3D(basis,drop.p))
		batch.multimesh.set_instance_custom_data(i,Color(clampf(drop.age/drop.life,0,.999),1.0 if large else 0.0,0,1))
	batch.multimesh.visible_instance_count = drops.size()

func _make_particle_frames() -> Texture2D:
	var image := Image.create(80,32,false,Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT)
	# Top row preserves the first sample's 8px frames at exact 2x nearest scale.
	var pixels := [[Vector2i(1,3),Vector2i(2,3),Vector2i(3,3),Vector2i(4,3),Vector2i(5,3),Vector2i(5,4)],
		[Vector2i(2,3),Vector2i(3,3),Vector2i(4,3),Vector2i(5,3),Vector2i(4,4)],
		[Vector2i(3,2),Vector2i(3,3),Vector2i(4,3),Vector2i(3,4),Vector2i(4,4)],
		[Vector2i(3,2),Vector2i(3,3),Vector2i(4,3),Vector2i(5,5)],
		[Vector2i(3,3),Vector2i(4,4),Vector2i(6,5)]]
	for f in 5:
		for p in pixels[f]:
			for y in 2:
				for x in 2: image.set_pixelv(p*2+Vector2i(f*16+x,y),Color.WHITE)
		# The second row is a short irregular heavy drop, never a long beam.
		for y in 16:
			for x in 16:
				var q := (Vector2(x,y)-Vector2(8.5+f*.25,7.5))/Vector2(4.7-f*.45,4.2-f*.36)
				var lobe := (Vector2(x,y)-Vector2(7,9))/Vector2(3.0-f*.22,2.8-f*.2)
				var filled := q.length_squared()<1.0+.10*sin(q.angle()*3.0+float(f)) or lobe.length_squared()<1.0
				if filled: image.set_pixel(f*16+x,16+y,Color.WHITE)
	return ImageTexture.create_from_image(image)

func clear_blood() -> void:
	drops.clear(); impacts.clear()
	stamp_shapes.clear(); mixed_splatters = 0; emitted_large_drops = 0; tapered_splatters = 0
	for face in faces:
		var node: Node3D = face.ref.get_ref()
		if is_instance_valid(node): node.free()
	faces.clear()
	if is_instance_valid(batch): batch.multimesh.visible_instance_count = 0
	emitted = 0; hit_count = 0; dropped_budget = 0; atlas_uploads = 0; recycled_faces = 0

func stats() -> Dictionary:
	var counts: Dictionary = {}
	for impact in impacts: counts[impact.receiver] = int(counts.get(impact.receiver,0))+1
	return {"emitted":emitted,"emitted_large_drops":emitted_large_drops,"tapered_splatters":tapered_splatters,"active_drops":drops.size(),"impacts":hit_count,"receiver_hits":counts,"face_atlases":faces.size(),"recycled_faces":recycled_faces,"budget_skips":dropped_budget,"query_usec":query_usec,"atlas_uploads":atlas_uploads,"mixed_splatters":mixed_splatters,"light_nodes":find_children("*","Light3D",true,false).size()}

func _exit_tree() -> void:
	# Reparenting into the rollback stash temporarily exits the tree. Keep all
	# local stains/particles intact; only release actual resources on deletion.
	_filter_users = maxi(_filter_users-1,0)
	if _filter_users == 0: RenderingServer.decals_set_filter(_saved_filter)

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE: return
	clear_blood()
	for receiver in receivers:
		var body: Node = receiver.body.get_ref()
		if is_instance_valid(body): body.queue_free()
		for original in receiver.originals:
			var mesh_node: VisualInstance3D = original.ref.get_ref()
			if is_instance_valid(mesh_node): LAYERS.apply(mesh_node,original.layers)
