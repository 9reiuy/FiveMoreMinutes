extends Node
## Shared approved dressing; production mode changes visuals, never collision authority.
const LOW = preload("res://shaders/dream3d/office_low_pixel.gdshader")
const DITHER = preload("res://scripts/dream/office_dither_lighting.gd")
const ROOM = preload("res://scripts/dream/office_room_low_pixel_art.gd")
const FACE = preload("res://scripts/dream/preview/furniture_face_textures.gd")
var world: Node
var walls: Array[Dictionary]=[]
var props: Array[WeakRef]=[]
var doors: Array[Dictionary]=[]
var windows: Array[Dictionary]=[]
var wall_materials: Dictionary={}
var enabled := true
var elapsed := 0.0
static var wall_shader: Shader
static var wall_texture_cache: Dictionary={}
const WALL_TEXTURE_CACHE_LIMIT := 32
static var door_texture_cache: Dictionary={}
static var glass_texture_cache: Dictionary={}
static var shared_door_shader: Shader
static var shared_glass_shader: Shader
const DETAIL_TEXTURE_CACHE_LIMIT := 64
var production_mode := false
var _cutaway_dirty := true
const STYLE = preload("res://scripts/dream/office_art_room_style.gd")

func _ready() -> void:
	if world==null: world=get_parent()
	add_to_group(&"office_wall_dressing")
	call_deferred("refresh_assets")

func mark_cutaway_dirty() -> void:
	_cutaway_dirty = true
	if production_mode and not is_processing():
		set_process(true)


func _sync_cutaway_uniforms() -> void:
	for record in windows:
		_apply_window(record)
	for record in doors:
		for leaf in record.leaves:
			var visual: MeshInstance3D=leaf.node.get_ref()
			if not is_instance_valid(visual) or leaf.glass==null or not visual.material_override is ShaderMaterial:
				continue
			for parameter in ["architecture_cutaway","architecture_wall_height","architecture_floor_y"]:
				var value: Variant=visual.material_override.get_shader_parameter(parameter)
				if value!=null:
					leaf.glass.material_override.set_shader_parameter(parameter,value)


func _process(delta: float) -> void:
	if production_mode and get_parent().get_parent()!=world.office_art_root: return
	if production_mode:
		if _cutaway_dirty:
			_cutaway_dirty = false
			_sync_cutaway_uniforms()
		set_process(false)
		return
	_sync_cutaway_uniforms()
	elapsed+=delta
	if elapsed>=.5: elapsed=0; refresh_assets()

static func wall_image(key: String, height: float = 3.0) -> Image:
	if key=="corridor": return _corridor_wall_image(height)
	var colors := {"office":"82969c","conference":"7d888d","manager":"999082","archive":"b8b2a3","server":"6f818c","pantry":"a8b7aa","restroom":"a0b7b5","lounge":"8d9290","reception":"a7a99d","lift":"7b8d96"}
	var base := Color(colors.get(key,"71818a"))
	var image := Image.create(64,maxi(1,roundi(height*32)),false,Image.FORMAT_RGBA8); image.fill(base)
	for py in image.get_height():
		var y := floori(float(py)*96.0/image.get_height())
		for x in 64:
			var color := base
			if y>85: color=base.darkened(.23)
			elif y==84: color=base.lightened(.08)
			if key in ["pantry","restroom"]:
				var width := 16 if key=="restroom" else 32
				if x%width==0 or y%16==0: color=base.darkened(.18)
				if key=="pantry" and y>=55 and y<59: color=base.darkened(.32)
			elif key=="conference":
				if y>22 and y<78 and x%16<2: color=base.darkened(.19)
				if y==22 or y==78: color=base.lightened(.07)
			elif key=="manager":
				if y>58: color=base.darkened(.14)
				if y==58 or (y>60 and x%32==0): color=base.darkened(.32)
			elif key=="server":
				if x%32==5 or x%32==6: color=base.darkened(.30)
				if y==35 or y==65: color=base.darkened(.16)
			elif key=="archive":
				if y>60: color=base.darkened(.10)
				if y==60 or x%32==0: color=base.darkened(.17)
			elif key=="reception":
				if y>56 and y<76: color=base.darkened(.15)
				if y==56 or y==76: color=base.lightened(.09)
			elif key=="lounge":
				if y>58 and x%16==0: color=base.darkened(.20)
				if y==58: color=base.lightened(.08)
			elif key=="lift":
				if x%32==0: color=base.darkened(.24)
				if y==25: color=base.lightened(.08)
			else:
				if x%32==0: color=base.darkened(.18)
				if y==65: color=base.darkened(.13)
			image.set_pixel(x,py,color)
	return image

static func _corridor_wall_image(height: float) -> Image:
	var image := Image.create(64,maxi(1,roundi(height*32)),false,Image.FORMAT_RGBA8)
	var upper := Color("b8c0bf")
	var lower := Color("667373")
	var split := floori(image.get_height()*2.0/3.0)
	var skirting_start := image.get_height()-maxi(1,roundi(image.get_height()*.10))
	for y in image.get_height():
		for x in 64:
			var color := upper if y<split else lower
			# Flat painted areas; no repeated full-height grooves or baked lighting.
			if y==split: color=lower.lightened(.08)
			elif y>=skirting_start: color=Color("424d50")
			elif y>split+3:
				# A quiet panel joint and two small scuffs only on the durable lower wall.
				if x==0: color=lower.darkened(.08)
				elif y==split+9 and x>=37 and x<=41: color=lower.darkened(.065)
				elif y==split+16 and x>=12 and x<=14: color=lower.lightened(.045)
			image.set_pixel(x,y,color)
	return image

func _wall_material(room_id: int, wall: Node3D) -> ShaderMaterial:
	var key := String(world.rooms[room_id].get("sample_key","corridor")) if room_id>=0 else "outside"
	if production_mode and room_id>=0: key=STYLE.key(world.rooms[room_id])
	if room_id>=0 and String(world.rooms[room_id].get("room_type",""))=="corridor": key="corridor"
	if bool(wall.get_meta(&"window_variant",false)): key="window_frame"
	if not wall_materials.has(key):
		if wall_shader==null:
			wall_shader=Shader.new()
			var code := DITHER._shader(LOW).code.replace("filter_nearest_mipmap","filter_nearest")
			code=code.replace("varying vec3 world_normal;","varying vec3 world_normal;\nvarying vec3 review_local;\nuniform float review_phase = 0.0;\nuniform float review_height = 3.0;")
			code=code.replace("void vertex() {","void vertex() {\nreview_local=VERTEX;")
			code=code.replace("vec2 atlas_uv = UV;","vec2 atlas_uv=vec2(fract((review_local.x+0.5+review_phase)/2.0),clamp(1.0-review_local.y/review_height,0.0,0.999));")
			wall_shader.code=code
		var material := ShaderMaterial.new(); material.shader=wall_shader
		var atlas: Texture2D
		if production_mode and bool(world.get_meta(&"test_approved_art_texture_cache",false)):
			# Pixel construction depends on the style and rounded texture height;
			# phase/height/cutaway uniforms continue to belong to each wall material.
			var texture_key := "%s:%d" % [key,maxi(1,roundi(world.wall_height*32))]
			if not wall_texture_cache.has(texture_key):
				if wall_texture_cache.size()>=WALL_TEXTURE_CACHE_LIMIT:
					wall_texture_cache.erase(wall_texture_cache.keys()[0])
				wall_texture_cache[texture_key]=ImageTexture.create_from_image(window_frame_image(world.wall_height) if key=="window_frame" else wall_image(key,world.wall_height))
			atlas=wall_texture_cache[texture_key]
		else:
			atlas=ImageTexture.create_from_image(window_frame_image(world.wall_height) if key=="window_frame" else wall_image(key,world.wall_height))
		material.set_shader_parameter("atlas",atlas)
		material.set_shader_parameter("office_dither_enabled",true); material.set_shader_parameter("office_dither_step",1.0/32.0)
		wall_materials[key]=material
	var result: ShaderMaterial=wall_materials[key].duplicate()
	var along := wall.position.x if String(wall.get_meta(&"edge").axis)=="H" else -wall.position.z
	result.set_shader_parameter("review_phase",along)
	result.set_shader_parameter("review_height",world.wall_height)
	return result

func refresh_assets() -> void:
	if production_mode and get_parent().get_parent()!=world.office_art_root: return
	_refresh_windows()
	_refresh_doors()
	walls=walls.filter(func(r: Dictionary) -> bool: return is_instance_valid(r.node.get_ref()))
	var wall_ids := _record_node_ids(walls,&"node")
	for wall in world.wall_root.get_children():
		if not wall.has_method("set_wall_materials") or not wall.has_meta(&"edge"): continue
		if wall_ids.has(wall.get_instance_id()): continue
		var cells: Array=world._edge_side_cells(wall.get_meta(&"edge"))
		if cells.size()!=2: continue
		var neg: int=world.room_cells.get(cells[0],-1); var pos: int=world.room_cells.get(cells[1],-1)
		var record := {"node":weakref(wall),"front":wall.wall_material_front,"back":wall.wall_material_back,"new_front":_wall_material(pos,wall),"new_back":_wall_material(neg,wall)}
		walls.append(record); _apply_wall(record)
		wall_ids[wall.get_instance_id()]=true
	props=props.filter(func(r: WeakRef) -> bool: return is_instance_valid(r.get_ref()))
	for bridge in world.actor_depth_bridges_root.get_children():
		if not bridge is Furniture3DVisual or not is_instance_valid(bridge.source_actor): continue
		var visual: Node3D=bridge.visual_instance
		if visual==null or visual.has_meta(&"desktop_review_done"): continue
		visual.set_meta(&"desktop_review_done",true)
		var kind := String(bridge.source_actor.get_meta(&"office_furniture_kind",""))
		if production_mode and kind=="desk": kind="workstation"
		if kind=="water_dispenser": _water(visual)
		elif kind in ["workstation","table","dining_table","coffee_table","sorting_table","reception"]: _desktop(visual,bridge.source_actor,kind)

static func _record_node_ids(records: Array[Dictionary], key: StringName) -> Dictionary:
	# Build once per refresh: a growing facade must not perform an all-records
	# weak-reference search for every wall/window/door. Records remain the
	# authority for materials and restoration; this index only answers identity.
	var ids: Dictionary={}
	for record in records:
		var node: Node=record[key].get_ref()
		if is_instance_valid(node): ids[node.get_instance_id()]=true
	return ids

func _apply_wall(record: Dictionary) -> void:
	record.node.get_ref().set_wall_materials(record.new_front if enabled else record.front,record.new_back if enabled else record.back)

func set_mode(value: bool) -> void:
	enabled=value
	for record in walls: _apply_wall(record)
	for record in doors: _apply_door(record)
	for record in windows: _apply_window(record)
	for reference in props:
		if is_instance_valid(reference.get_ref()): reference.get_ref().visible=value

static func window_frame_image(height: float) -> Image:
	var image := Image.create(64,maxi(1,roundi(height*32)),false,Image.FORMAT_RGBA8)
	var paint := Color("667f8a"); image.fill(paint)
	for y in image.get_height():
		for x in 64:
			var edge := mini(y,image.get_height()-1-y)
			if edge==0: image.set_pixel(x,y,Color("465e69"))
			elif edge==1: image.set_pixel(x,y,Color("8da1a8"))
			elif edge==2: image.set_pixel(x,y,Color("5b727d"))
			elif x%32==1: image.set_pixel(x,y,paint.lightened(.045))
			if edge==2 and x in [9,41]: image.set_pixel(x,y,Color("a3b3b6"))
	return image

func _refresh_windows() -> void:
	windows=windows.filter(func(r: Dictionary) -> bool: return is_instance_valid(r.wall.get_ref()))
	var window_ids := _record_node_ids(windows,&"wall")
	for wall in world.wall_root.get_children():
		var breakable := production_mode and wall is BreakableGlassWindow3D
		if not breakable and (not wall.has_method("set_window_variant") or not bool(wall.get("window_variant"))): continue
		if window_ids.has(wall.get_instance_id()): continue
		var pane: MeshInstance3D=wall.glass_pane if breakable else wall.window_pane
		if pane==null or not pane.visible or not pane.mesh is BoxMesh: continue
		var size: Vector3=pane.mesh.size
		var quad := QuadMesh.new(); quad.size=Vector2(size.x,size.y)
		var use_cache := production_mode and bool(world.get_meta(&"test_approved_art_texture_cache",false))
		# Window pixels below replace the door-glass pattern. Do not construct
		# that unused pattern on the cached path.
		var mat := _glass_material(quad.size,use_cache,not use_cache)
		# Continuous horizontal reflection phase, not a strong border at each logical cell.
		var image := Image.create(maxi(2,roundi(size.x*32)),maxi(2,roundi(size.y*32)),false,Image.FORMAT_RGBA8)
		image.fill(Color(.64,.78,.81,.065))
		var edge: Dictionary=wall.edge_data if breakable else wall.get_meta(&"edge")
		var phase := roundi((wall.position.x if String(edge.axis)=="H" else -wall.position.z)*32)
		for y in image.get_height():
			for x in image.get_width():
				if y==0 or y==image.get_height()-1: image.set_pixel(x,y,Color(.73,.85,.87,.40))
				elif posmod(x+phase+y,47)==0 and posmod(x+phase,19)<4: image.set_pixel(x,y,Color(.85,.93,.94,.38))
		mat.set_shader_parameter("glass_pixels",ImageTexture.create_from_image(image))
		var record := {"wall":weakref(wall),"pane":weakref(pane),"old_mesh":pane.mesh,"old_mat":pane.material_override,"new_mesh":quad,"new_mat":mat,"breakable":breakable}
		windows.append(record); _apply_window(record)
		window_ids[wall.get_instance_id()]=true

func _apply_window(record: Dictionary) -> void:
	var wall: Node3D=record.wall.get_ref(); var pane: MeshInstance3D=record.pane.get_ref()
	if not is_instance_valid(wall) or not is_instance_valid(pane): return
	pane.mesh=record.new_mesh if enabled else record.old_mesh
	if enabled:
		record.new_mat.set_shader_parameter("architecture_cutaway",wall.cutaway_mode)
		record.new_mat.set_shader_parameter("architecture_wall_height",wall.structural_height if record.get("breakable",false) else wall.wall_height)
		pane.material_override=record.new_mat
	else:
		# The source owns the original dynamic opaque/cutaway sky materials.
		pane.material_override=record.old_mat if record.get("breakable",false) else wall.window_glass_cutaway_material if wall.cutaway_mode else record.old_mat

func _refresh_doors() -> void:
	doors=doors.filter(func(r: Dictionary) -> bool: return is_instance_valid(r.door.get_ref()))
	var door_ids := _record_node_ids(doors,&"door")
	for door in world.door_root.get_children():
		if not door is PhysicalDoor3D or door_ids.has(door.get_instance_id()): continue
		var style := "solid"
		for room_key in ["region_a_id","region_b_id"]:
			var id := int(door.get_meta(room_key,-1))
			if id<0 or id>=world.rooms.size(): continue
			var key := STYLE.key(world.rooms[id]) if production_mode else String(world.rooms[id].get("sample_key",""))
			if key=="conference": style="glass"
			elif key=="manager" and style!="glass": style="window"
		var record := {"door":weakref(door),"style":style,"leaves":[]}
		for visual in [door.left_visual,door.right_visual]:
			if visual==null: continue
			var width: float=door.leaf_width; var height: float=door.door_height
			var opening := Vector2.ZERO; var center := 0.0
			if style=="glass": opening=Vector2(maxf(.1,width-.16),height-.22)
			elif style=="window": opening=Vector2(width*.32,height*.32); center=height*.17
			var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
			if style=="solid": _door_box(st,Vector3(width,height,door.wall_thickness),Vector3.ZERO)
			else:
				var low := center-opening.y*.5; var high := center+opening.y*.5
				_door_box(st,Vector3(width,low+height*.5,door.wall_thickness),Vector3(0,(low-height*.5)*.5,0))
				_door_box(st,Vector3(width,height*.5-high,door.wall_thickness),Vector3(0,(high+height*.5)*.5,0))
				for side in [-1,1]: _door_box(st,Vector3((width-opening.x)*.5,opening.y,door.wall_thickness),Vector3(side*(width+opening.x)*.25,center,0))
			var pane: MeshInstance3D=null
			if style!="solid":
				pane=MeshInstance3D.new(); pane.name="ReviewPixelGlass"
				var quad := QuadMesh.new(); quad.size=opening; pane.mesh=quad; pane.position.y=center
				pane.material_override=_glass_material(opening,production_mode and bool(world.get_meta(&"test_approved_art_texture_cache",false)))
				pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				visual.add_child(pane)
			var caster := visual.get_node_or_null("SolidShadowCaster") as MeshInstance3D
			var index := 0 if visual==door.left_visual else 1
			var handle: MeshInstance3D=door.left_handle_visual if index==0 else door.right_handle_visual
			var leaf := {"node":weakref(visual),"old_mesh":visual.mesh,"old_mat":visual.material_override,"old_transform":visual.transform,"new_mesh":st.commit(),"size":Vector3(width,height,door.wall_thickness),"index":index,"glass":pane,"caster":caster,"old_caster":caster.mesh if caster!=null else null,"handle":handle,"old_handle_mat":handle.material_override if handle!=null else null}
			record.leaves.append(leaf)
		doors.append(record); _apply_door(record)
		door_ids[door.get_instance_id()]=true

static func _door_box(st: SurfaceTool, size: Vector3, center: Vector3) -> void:
	var box := BoxMesh.new(); box.size=size
	var data := box.surface_get_arrays(0)
	var points: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
	for index in data[Mesh.ARRAY_INDEX]:
		var point: Vector3=points[index]+center; var normal: Vector3=normals[index]
		var uv := Vector2(point.x,point.y) if absf(normal.z)>.5 else Vector2(point.z,point.y) if absf(normal.x)>.5 else Vector2(point.x,point.z)
		st.set_normal(normal); st.set_uv(uv); st.add_vertex(point)

static func _glass_image(size: Vector2) -> Image:
	var image := Image.create(maxi(2,roundi(size.x*32)),maxi(2,roundi(size.y*32)),false,Image.FORMAT_RGBA8)
	image.fill(Color(.61,.76,.79,.07))
	for y in image.get_height():
		for x in image.get_width():
			if x==0 or y==0 or x==image.get_width()-1 or y==image.get_height()-1:
				image.set_pixel(x,y,Color(.66,.81,.84,.48))
			elif (x+y)%27==0 and x%11<3: image.set_pixel(x,y,Color(.79,.89,.89,.44))
	return image

static func _glass_material(size: Vector2,use_cache: bool=false,generate_pixels: bool=true) -> ShaderMaterial:
	var shader := _glass_shader(use_cache)
	var mat := ShaderMaterial.new(); mat.shader=shader
	if generate_pixels:
		var key := "%d:%d" % [maxi(2,roundi(size.x*32)),maxi(2,roundi(size.y*32))]
		if use_cache:
			if not glass_texture_cache.has(key):
				if glass_texture_cache.size()>=DETAIL_TEXTURE_CACHE_LIMIT: glass_texture_cache.erase(glass_texture_cache.keys()[0])
				glass_texture_cache[key]=ImageTexture.create_from_image(_glass_image(size))
			mat.set_shader_parameter("glass_pixels",glass_texture_cache[key])
		else: mat.set_shader_parameter("glass_pixels",ImageTexture.create_from_image(_glass_image(size)))
	return mat

static func _glass_shader(use_cache: bool) -> Shader:
	if use_cache and shared_glass_shader!=null: return shared_glass_shader
	var shader := Shader.new()
	shader.code="shader_type spatial;\nrender_mode diffuse_lambert,cull_disabled;\n#include \"res://shaders/dream3d/architecture_cutaway.gdshaderinc\"\n#include \"res://shaders/dream3d/occlusion_cutout.gdshaderinc\"\nuniform sampler2D glass_pixels : source_color, filter_nearest, repeat_disable;\nvoid vertex(){architecture_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}\nvoid fragment(){if(architecture_cutaway && architecture_visibility(architecture_world)<0.5){discard;} if(combined_cutout(SCREEN_UV)<0.35){discard;} vec4 tex=texture(glass_pixels,UV); ALBEDO=tex.rgb; ALPHA=tex.a; ROUGHNESS=1.0; SPECULAR=0.0;}"
	if use_cache: shared_glass_shader=shader
	return shader

func _apply_door(record: Dictionary) -> void:
	for leaf in record.leaves:
		var visual: MeshInstance3D=leaf.node.get_ref()
		if not is_instance_valid(visual): continue
		visual.mesh=leaf.new_mesh if enabled else leaf.old_mesh
		visual.transform=Transform3D.IDENTITY if enabled else leaf.old_transform
		if enabled:
			var use_cache := production_mode and bool(world.get_meta(&"test_approved_art_texture_cache",false))
			var mat := ShaderMaterial.new(); mat.shader=_door_shader(use_cache)
			mat.set_shader_parameter("review_door_size",leaf.size)
			# Door leaves occlude actors like furniture: opt in to the halftone hole.
			mat.set_shader_parameter("occlusion_cutout_enabled",true)
			mat.set_shader_parameter("atlas",_door_texture(leaf.size,record.style,leaf.index,use_cache)); visual.material_override=mat
			if leaf.handle!=null: leaf.handle.material_override=_color("b4bec0")
		else:
			visual.material_override=leaf.old_mat
			if leaf.handle!=null: leaf.handle.material_override=leaf.old_handle_mat
		if leaf.glass!=null: leaf.glass.visible=enabled
		if leaf.caster!=null: leaf.caster.mesh=leaf.new_mesh if enabled else leaf.old_caster

static func _door_shader(use_cache: bool) -> Shader:
	if use_cache and shared_door_shader!=null: return shared_door_shader
	var shader := Shader.new()
	shader.code=DITHER._shader(LOW).code.replace("filter_nearest_mipmap","filter_nearest").replace("repeat_disable","repeat_enable")
	shader.code=shader.code.replace("varying vec3 world_normal;","varying vec3 world_normal;\nvarying vec3 review_door_local;\nvarying vec3 review_door_normal;\nuniform vec3 review_door_size=vec3(1.0);")
	shader.code=shader.code.replace("void vertex() {","void vertex() {\nreview_door_local=VERTEX; review_door_normal=NORMAL;")
	shader.code=shader.code.replace("vec2 atlas_uv = UV;","vec2 atlas_uv=vec2(review_door_local.x/review_door_size.x+0.5,0.5-review_door_local.y/review_door_size.y);\nvec2 door_pixels=vec2(textureSize(atlas,0));\nif(abs(review_door_normal.z)<0.5){atlas_uv=vec2(3.5/door_pixels.x,0.5-review_door_local.y/review_door_size.y);}\nif(review_door_normal.y>0.5){atlas_uv=vec2(0.5,1.5/door_pixels.y);}")
	shader.code=shader.code.replace("ALBEDO = texture(atlas, atlas_uv).rgb;","ALBEDO = texture(atlas, atlas_uv).rgb;\nif(abs(review_door_normal.z)<0.5){float depth_edge=review_door_size.z*0.5-abs(review_door_local.z); if(depth_edge<0.03125){ALBEDO=vec3(0.007,0.011,0.018);}}")
	if use_cache: shared_door_shader=shader
	return shader

static func _door_texture(size: Vector3,style: String,index: int,use_cache: bool) -> Texture2D:
	if not use_cache: return ImageTexture.create_from_image(door_image(size,style,index))
	var key := "%d:%d:%s:%d" % [maxi(4,roundi(size.x*32)),maxi(4,roundi(size.y*32)),style,index]
	if not door_texture_cache.has(key):
		if door_texture_cache.size()>=DETAIL_TEXTURE_CACHE_LIMIT: door_texture_cache.erase(door_texture_cache.keys()[0])
		door_texture_cache[key]=ImageTexture.create_from_image(door_image(size,style,index))
	return door_texture_cache[key]

static func door_image(size: Vector3, style: String, index: int) -> Image:
	var width := maxi(4,roundi(size.x*32)); var height := maxi(4,roundi(size.y*32))
	var image := Image.create(width,height,false,Image.FORMAT_RGBA8)
	var paint := Color("778e99")
	var rim := Color("141b24"); var lip := Color("91a3aa")
	var window := Rect2i(Vector2i.ZERO,Vector2i.ZERO)
	if style=="window":
		var pane := Vector2i(roundi(width*.32),roundi(height*.32))
		window=Rect2i(Vector2i((width-pane.x)/2,roundi(height*.33)-pane.y/2),pane)
	elif style=="glass":
		var pane:=Vector2i(maxi(1,roundi((size.x-.16)*32)),maxi(1,roundi((size.y-.22)*32)))
		window=Rect2i(Vector2i((width-pane.x)/2,(height-pane.y)/2),pane)
	for y in height:
		for x in width:
			var edge := mini(mini(x,width-1-x),mini(y,height-1-y))
			var color := paint
			if edge==0: color=rim
			elif edge==1 and style=="glass": color=lip if x==1 or y==1 else paint.darkened(.32)
			elif edge==1: color=lip if x==1 or y==1 else paint.darkened(.32)
			elif edge==2: color=paint.darkened(.13)
			# Insets are measured from the actual leaf edges, not repeating texture cells.
			if style=="solid" and x>=4 and x<width-4 and y>=8 and y<height-7:
				if x==4 or x==width-5 or y==8 or y==height-8: color=Color("35434c")
				elif x==5 or y==9: color=paint.lightened(.07)
			if style in ["window","glass"] and window.grow(2).has_point(Vector2i(x,y)):
				if not window.grow(1).has_point(Vector2i(x,y)): color=rim
				elif not window.has_point(Vector2i(x,y)): color=lip if x<window.position.x or y<window.position.y else paint.darkened(.32)
			# Pixel hinge plates and sparse edge wear, with no painted shadow gradient.
			var hinge_x := width-3 if index==0 else 2
			if absi(x-hinge_x)<=1 and (absi(y-height/5)<=2 or absi(y-height*4/5)<=2): color=Color("62747d")
			if x==hinge_x and (y==height/5 or y==height*4/5): color=Color("a2b2b8")
			var lock_x := 3 if index==0 else width-4
			if absi(x-lock_x)<=1 and absi(y-height*55/100)<=3: color=Color("a4b2b7")
			if x==lock_x and y==height*58/100: color=Color("52656c")
			if edge==2 and y%23 in [6,7]: color=paint.lightened(.12)
			# Keep a continuous single-texel contour; hardware never breaks it.
			if edge==0: color=rim
			image.set_pixel(x,y,color)
	return image

static func _color(color: String, alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.albedo_color=Color(color); mat.albedo_color.a=alpha
	mat.roughness=1.0; mat.metallic_specular=0.0
	if alpha<1.0:
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	return mat

static func _cylinder(root: Node3D, name: String, at: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new(); mesh.radial_segments=8; mesh.rings=0
	mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=height
	var display := MeshInstance3D.new(); display.name=name; display.mesh=mesh; display.position=at; display.material_override=mat
	display.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(display); return display

func _water(visual: Node3D) -> void:
	var root := Node3D.new(); root.name="ReviewWaterBarrel"; visual.add_child(root); props.append(weakref(root))
	_cylinder(root,"WaterInside",Vector3(0,1.122,0),.1998,.3335,_color("639cae"))
	_cylinder(root,"WaterSurface",Vector3(0,1.291,0),.20115,.009,_color("93bfca"))
	var shell := _cylinder(root,"TransparentBucket",Vector3(0,1.1845,0),.2295,.529,_color("abcfd5",.26))
	shell.mesh.cap_top=false; shell.mesh.cap_bottom=false
	var image := Image.create(45,17,false,Image.FORMAT_RGBA8); image.fill(Color.WHITE)
	for y in range(2,15):
		image.set_pixel(5,y,Color("d9e7e9")); image.set_pixel(6,y,Color.WHITE)
		image.set_pixel(31,y,Color("8eaeb8"))
	shell.material_override.albedo_texture=ImageTexture.create_from_image(image)
	shell.material_override.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_cylinder(root,"Neck",Vector3(0,.918,0),.1215,.036,_color("94b6c1"))
	_cylinder(root,"Cap",Vector3(0,1.469,0),.2322,.04,_color("36484e"))
	for y in [1.012,1.38]:
		var ring := _cylinder(root,"BucketRidge",Vector3(0,y,0),.23355,.015,_color("b3d1d7",.48))
		ring.mesh.cap_top=false; ring.mesh.cap_bottom=false
	root.visible=enabled

static func _box(root: Node3D, at: Vector3, size: Vector3, tile: String) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); ROOM._box(st,size,Vector3.ZERO,tile)
	var result := FACE.build(st.commit(),ROOM.texture(),"desktop",0)
	var mesh := MeshInstance3D.new(); mesh.mesh=result.mesh
	mesh.set_meta(&"review_desktop_detail",true)
	var mat := ShaderMaterial.new(); mat.shader=DITHER._shader(LOW); mat.set_shader_parameter("atlas",result.texture)
	mat.set_shader_parameter("office_dither_step",1.0/32.0); mat.set_shader_parameter("office_dither_enabled",true)
	mesh.position=at; mesh.material_override=mat; root.add_child(mesh)

func _desktop(visual: Node3D, source: Node2D, kind: String) -> void:
	var variant := posmod((str(world.active_seed)+str(source.get_index())+kind).hash(),4)
	var root := Node3D.new(); root.name="ReviewDesktopGroup"; visual.add_child(root); props.append(weakref(root))
	var height := .76; var center := Vector2(.36,-.10)
	match kind:
		"workstation": height=.74; center=Vector2(.70,.26)
		"table": height=.76; center=Vector2(.30,-.12)
		"coffee_table": height=.42; center=Vector2(.20,-.12)
		"sorting_table": height=.76; center=Vector2(.32,.18)
		"reception": height=1.05; center=Vector2(.05,.25)
	root.set_meta(&"kind",kind); root.set_meta(&"variant",variant); root.set_meta(&"surface_height",height)
	# Compact group locations intentionally avoid the authored monitor/paper clusters.
	var cup := Node3D.new(); cup.position=Vector3(center.x,height,center.y); root.add_child(cup)
	var cup_body := _cylinder(cup,"CupBody",Vector3(0,.045,0),.048,.09,_color("d7dccc" if variant%2==0 else "738894"))
	cup_body.mesh.cap_top=false
	_cylinder(cup,"Coffee",Vector3(0,.085,0),.039,.004,_color("543d2b"))
	_box(cup,Vector3(.058,.045,0),Vector3(.026,.04,.018),"porcelain")
	if variant!=3:
		var book := Node3D.new(); book.position=Vector3(center.x-.20,height,center.y+.05); book.rotation.y=-.18+variant*.17; root.add_child(book)
		_box(book,Vector3(0,.018,0),Vector3(.16,.028,.22),"paper")
		_box(book,Vector3(0,.036,0),Vector3(.17,.009,.23),"mustard" if variant==1 else "fabric")
		_box(book,Vector3(-.08,.023,0),Vector3(.016,.03,.23),"dark")
	var pens := Node3D.new(); pens.position=Vector3(center.x+.13,height+.008,center.y); pens.rotation.y=.35+variant*.22; root.add_child(pens)
	_box(pens,Vector3.ZERO,Vector3(.015,.014,.16),"dark")
	_box(pens,Vector3(0,0,-.055),Vector3(.018,.016,.035),"steel")
	if variant==2: _box(pens,Vector3(.035,0,.025),Vector3(.014,.013,.15),"mustard")
	root.visible=enabled
