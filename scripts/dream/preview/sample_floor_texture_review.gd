extends Node
## Shared approved floor presentation; production placement uses actual room bounds.
const LOW = preload("res://shaders/dream3d/office_low_pixel.gdshader")
const DITHER = preload("res://scripts/dream/office_dither_lighting.gd")
const CATALOG = preload("res://scripts/dream/office_furniture_catalog.gd")
const PROP = preload("res://scenes/dream/props/desk.tscn")
var world: Node
var records: Array[Dictionary]=[]
var plants: Array[WeakRef]=[]
var materials: Dictionary={}
var extras: WeakRef
var elapsed := 0.0
var enabled := true
var old_rugs: Array[WeakRef]=[]
var plant_rooms: Dictionary={}
var production_mode := false
static var floor_texture_cache: Dictionary={}
const FLOOR_TEXTURE_CACHE_LIMIT := 32
const STYLE = preload("res://scripts/dream/office_art_room_style.gd")

func _ready() -> void:
	if world==null: world=get_parent()
	call_deferred("refresh_assets")

func _process(delta: float) -> void:
	elapsed+=delta
	if elapsed>=.5: elapsed=0.0; refresh_assets()

func _material(image: Image, bevel: Image = null) -> ShaderMaterial:
	return _material_from_textures(ImageTexture.create_from_image(image),ImageTexture.create_from_image(bevel) if bevel!=null else null)

func _material_from_textures(atlas: Texture2D, bevel: Texture2D = null) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code=DITHER._shader(LOW).code.replace("filter_nearest_mipmap","filter_nearest")
	if bevel!=null:
		shader.code=shader.code.replace("varying vec3 world_normal;","varying vec3 world_normal;\nuniform sampler2D review_bevel : hint_normal, filter_nearest, repeat_disable;")
		shader.code=shader.code.replace("ROUGHNESS = 1.0;","NORMAL_MAP = texture(review_bevel, atlas_uv).rgb;\nNORMAL_MAP_DEPTH = 1.0;\nROUGHNESS = 1.0;")
	mat.shader=shader
	mat.set_shader_parameter("atlas",atlas)
	if bevel!=null: mat.set_shader_parameter("review_bevel",bevel)
	mat.set_shader_parameter("office_dither_step",1.0/32.0)
	mat.set_shader_parameter("office_dither_enabled",true)
	return mat

func floor_material(room: Dictionary) -> Material:
	var key := STYLE.key(room) if production_mode else String(room.get("sample_key","corridor"))
	if String(room.get("room_type",""))=="corridor": key="corridor"
	var variant := posmod((str(world.active_seed)+key).hash(),3)
	var cache_key := key+str(variant)
	if not materials.has(cache_key):
		if production_mode and bool(world.get_meta(&"test_approved_art_texture_cache",false)):
			var texture_key := "%s:%d" % [key,variant]
			if not floor_texture_cache.has(texture_key):
				# Only immutable pixels cross floors. Per-floor uniforms and materials
				# remain separate, including the retained floor during rollback.
				if floor_texture_cache.size()>=FLOOR_TEXTURE_CACHE_LIMIT:
					floor_texture_cache.erase(floor_texture_cache.keys()[0])
				floor_texture_cache[texture_key]={"atlas":ImageTexture.create_from_image(floor_image(key,variant)),"bevel":ImageTexture.create_from_image(floor_normal_image(key,variant)) if key!="office" else null}
			var pixels: Dictionary=floor_texture_cache[texture_key]
			materials[cache_key]=_material_from_textures(pixels.atlas,pixels.bevel)
		else:
			materials[cache_key]=_material(floor_image(key,variant),floor_normal_image(key,variant) if key!="office" else null)
	materials[cache_key].set_meta(&"floor_surface_style",key)
	return materials[cache_key]

static func floor_image(key: String, variant: int) -> Image:
	if key=="office": return _carpet_planks(variant)
	if key in ["conference","manager","lounge"]: return _wood_planks(key,variant)
	if key=="reception": return _marble(variant)
	if key=="corridor": return _terrazzo(variant)
	if key=="restroom": return _restroom_tiles(variant)
	var colors := {"office":"697c86","conference":"938b7e","manager":"95816c","archive":"69777e","server":"71828c","pantry":"adb4a4","restroom":"a3b8b4","lounge":"8e8177","reception":"b1b2a7","lift":"7c8c94"}
	var base := Color(colors.get(key,"626d78"))
	base=base.darkened(.035*variant)
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var color := base
			var sx := 32; var sy := 32
			if key in ["pantry","restroom"]: sx=16 if key=="restroom" else 32; sy=sx
			elif key in ["office","manager","conference","lounge"]: sy=16 if variant!=1 else 32
			elif key=="server": sx=32; sy=16
			var offset := (sx/2 if (y/sy)%2==1 else 0) if key in ["office","manager","conference"] else 0
			var px := posmod(x+offset,sx); var py := y%sy
			if px==0 or py==0: color=base.darkened(.06)
			elif px==1 or py==1: color=base.lightened(.012)
			# Reference-inspired inserts belong to the wet rooms, not every floor.
			if key in ["pantry","restroom"]:
				var radius := 5 if key=="pantry" else 3
				if absi(px-sx/2)+absi(py-sy/2)<=radius and ((x+offset)/sx+y/sy+variant)%2==0:
					color=base.darkened(.48)
			elif key=="reception" and (px<3 and py<3): color=base.darkened(.38)
			elif key=="server" and px>4 and px<9 and py==4: color=base.darkened(.14)
			elif key=="archive" and py==16 and px>4 and px<27: color=base.darkened(.07)
			image.set_pixel(x,y,color)
	return image

static func _restroom_tiles(variant: int) -> Image:
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	var base := Color("858c8d").darkened(.018*variant)
	for y in 64:
		for x in 64:
			var px := x%16; var py := y%16
			var color := base.darkened(.012*((x/16+y/16+variant)%3))
			if px==0 or py==0: color=base.darkened(.055)
			elif px==1 or py==1: color=base.lightened(.012)
			if (px<=1 or px==15) and (py<=1 or py==15): color=base.darkened(.25)
			image.set_pixel(x,y,color)
	return image

static func _terrazzo(variant: int) -> Image:
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	var base := Color("d4d9d8").darkened(.018*variant)
	image.fill(base)
	# One two-unit slab, with sparse authored-size chips rather than per-pixel noise.
	var rng := RandomNumberGenerator.new()
	rng.seed=71031+variant*109
	for chip in 24:
		var x := rng.randi_range(4,59)
		var y := rng.randi_range(4,59)
		var width := rng.randi_range(2,4)
		var height := rng.randi_range(2,3)
		var color := base.lightened(.12) if chip%3==0 else base.darkened(.075 if chip%3==1 else .045)
		for dy in height:
			for dx in width:
				if (dx==0 and dy==0) or (dx==width-1 and dy==height-1): continue
				image.set_pixel(x+dx,y+dy,color)
	for i in 64:
		image.set_pixel(i,0,base.darkened(.05))
		image.set_pixel(0,i,base.darkened(.05))
	return image

static func _carpet_planks(variant: int) -> Image:
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	var base := Color("67696a").darkened(.02*variant)
	for y in 64:
		for x in 64:
			var row := y/16
			var px := posmod(x+(32 if row%2==1 else 0),64)
			var py := y%16
			var strip := (row+variant)%4
			var color := base.darkened(.018*strip)
			# Textile joins are subdued, without bevels, grout or reflected light.
			if px==0 or py==0: color=color.darkened(.028)
			elif strip%2==0:
				if py in [4,10] and px>5 and px<46 and (px+strip*9)%28<18: color=color.lightened(.035)
				elif py==7 and px>15 and px<58: color=color.darkened(.025)
			else:
				# Alternating broad, slightly sloping fibre bundles (not wood grain).
				if py==4+px/24 or py==10+px/32: color=color.lightened(.028)
			image.set_pixel(x,y,color)
	return image

static func _wood_planks(key: String, variant: int) -> Image:
	var base := Color("9e8d76" if key=="conference" else "98765a" if key=="manager" else "8f8170")
	base=base.darkened(.025*variant)
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var row := y/16
			var px := posmod(x+(32 if row%2==1 else 0)+variant*8,64)
			var py := y%16
			var color := base.darkened(.025*((row+variant)%3))
			if px==0 or py==0: color=color.darkened(.06)
			elif py==3+(px/12+row)%3 or py==10+(px/16+variant)%2:
				color=color.darkened(.095)
			elif py==7 and px>9 and px<35: color=color.lightened(.055)
			image.set_pixel(x,y,color)
	return image

static func _marble(variant: int) -> Image:
	var base := Color("bdbcb5").darkened(.018*variant)
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var color := base
			if x==0 or y==0: color=base.darkened(.055)
			else:
				var vein := 16+variant*6+x/5+(2 if x>28 and x<44 else 0)
				if y==vein and x>4 and x<56: color=base.darkened(.12)
				elif y==vein+1 and x>12 and x<48: color=base.darkened(.055)
				elif x>28 and x<48 and y==43-(x-28)/3: color=base.darkened(.08)
			image.set_pixel(x,y,color)
	return image

static func floor_normal_image(key: String, variant: int) -> Image:
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	image.fill(Color(.5,.5,1.0))
	if key=="office": return image
	for y in 64:
		for x in 64:
			var sx := 32; var sy := 32; var offset := 0
			if key in ["conference","manager","lounge"]:
				sx=64; sy=16; offset=(32 if (y/16)%2==1 else 0)+variant*8
			elif key in ["reception","corridor"]: sx=64; sy=64
			elif key=="restroom": sx=16; sy=16
			elif key=="server": sy=16
			var px := posmod(x+offset,sx); var py := y%sy
			# Narrow, shallow bevels. Flat centers; no displacement or glossy response.
			var nx := -.13 if px==1 else .13 if px==sx-1 else 0.0
			var ny := -.13 if py==1 else .13 if py==sy-1 else 0.0
			var normal := Vector3(nx,ny,1.0).normalized()
			image.set_pixel(x,y,Color(normal.x*.5+.5,normal.y*.5+.5,normal.z*.5+.5))
	return image

func refresh_assets() -> void:
	if production_mode and get_parent().get_parent()!=world.office_art_root: return
	if world.floor_root==null or world.floor_root.get_child_count()==0: return
	rebuild_floor_surfaces()
	if extras==null or not is_instance_valid(extras.get_ref()): _build_rugs()
	_add_plants()

## Shared final floor UV/material pass, also used by the standalone lobby.
## Placement of production rugs/plants remains in refresh_assets().
func rebuild_floor_surfaces() -> void:
	if world.floor_root==null or world.floor_root.get_child_count()==0: return
	records=records.filter(func(r: Dictionary) -> bool: return is_instance_valid(r.node.get_ref()))
	for node in world.floor_root.get_children():
		if not node is MeshInstance3D or not node.name.begins_with("FloorBatch_"): continue
		if records.any(func(r: Dictionary) -> bool: return r.node.get_ref()==node): continue
		var source: Mesh=node.mesh
		var builders: Dictionary={}
		for surface in source.get_surface_count():
			var data := source.surface_get_arrays(surface)
			var points: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
			for offset in range(0,points.size(),4):
				var center: Vector3=(points[offset]+points[offset+2])*.5+node.position
				var cell := Vector2i(roundi(center.x),roundi(center.z))
				var room_id: int=world.room_cells.get(cell,-1)
				if not builders.has(room_id):
					var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); builders[room_id]=st
				var st: SurfaceTool=builders[room_id]
				var origin := Vector2i.ZERO
				if room_id>=0: origin=world.rooms[room_id].grid_rect.position
				var uv := Vector2(posmod(cell.x-origin.x,2),posmod(cell.y-origin.y,2))*.5
				var coords := [uv,uv+Vector2(.5,0),uv+Vector2(.5,.5),uv+Vector2(0,.5)]
				for index in [0,1,2,0,2,3]:
					st.set_normal(Vector3.UP); st.set_uv(coords[index]); st.add_vertex(points[offset+index])
		# Tangent follows room-local +X and UV +Y follows +Z, including the rotated map.
		for room_id in builders: builders[room_id].generate_tangents()
		var target := ArrayMesh.new()
		for room_id in builders:
			var st: SurfaceTool=builders[room_id]
			st.set_material(floor_material(world.rooms[room_id] if room_id>=0 else {}))
			st.index(); st.commit(target)
		var overrides: Array=[]
		for surface in source.get_surface_count(): overrides.append(node.get_surface_override_material(surface))
		var record := {"node":weakref(node),"old":source,"new":target,"overrides":overrides}
		records.append(record); _apply(record)

func _apply(record: Dictionary) -> void:
	var node: MeshInstance3D=record.node.get_ref()
	if not is_instance_valid(node): return
	for surface in node.mesh.get_surface_count(): node.set_surface_override_material(surface,null)
	node.mesh=record.new if enabled else record.old
	if not enabled:
		for surface in record.overrides.size(): node.set_surface_override_material(surface,record.overrides[surface])

func set_mode(value: bool) -> void:
	enabled=value
	for record in records: _apply(record)
	if extras!=null and is_instance_valid(extras.get_ref()): extras.get_ref().visible=value
	for reference in old_rugs:
		if is_instance_valid(reference.get_ref()): reference.get_ref().visible=not value

func _build_rugs() -> void:
	plant_rooms.clear()
	var root := Node3D.new(); root.name="TextureReviewRugs"; world.floor_root.add_child(root); extras=weakref(root)
	# Hide prior seat patches on this floor, avoiding stacked planes.
	old_rugs.clear()
	for mesh in world.floor_root.find_children("LowContrastSeatRug","MeshInstance3D",true,false):
		old_rugs.append(weakref(mesh)); mesh.visible=not enabled
	for room in world.rooms:
		var key := STYLE.key(room) if production_mode else String(room.get("sample_key",""))
		var specs := {"conference":[Vector2(5.5,7.0),Vector2(5.2,3.5),"6d7782"],"manager":[Vector2(9.2,5.7),Vector2(3.2,3.0),"78656a"],"lounge":[Vector2(5.1,4.6),Vector2(3.6,5.2),"657b80"],"reception":[Vector2(11,4.5),Vector2(2.8,3.1),"827b62"]}
		if not specs.has(key): continue
		var spec: Array=specs[key]
		var size: Vector2=spec[1]
		var center: Vector2=Vector2(room.grid_rect.position)+spec[0]
		if production_mode:
			var anchor: Node2D = null
			for source in world.furniture_root.get_children():
				if int(source.get_meta(&"dream_room_id",-1))!=int(room.id): continue
				var kind := String(source.get_meta(&"office_furniture_kind",""))
				if kind in (["table"] if key=="conference" else ["coffee_table","sofa"]):
					anchor=source; break
			if anchor==null: continue
			center=anchor.position/32.0
			size=Vector2(minf(size.x,room.grid_rect.size.x-2.0),minf(size.y,room.grid_rect.size.y-2.0))
			if size.x<1.0 or size.y<1.0: continue
			var valid := true
			var bounds := Rect2(center-size*.5,size)
			for y in range(floori(bounds.position.y),ceili(bounds.end.y)+1):
				for x in range(floori(bounds.position.x),ceili(bounds.end.x)+1):
					if int(world.room_cells.get(Vector2i(x,y),-1))!=int(room.id): valid=false
			if not valid: continue
		var image := Image.create(roundi(size.x*32),roundi(size.y*32),false,Image.FORMAT_RGBA8)
		var color := Color(spec[2]); image.fill(color)
		for y in image.get_height():
			for x in image.get_width():
				var edge := mini(mini(x,image.get_width()-1-x),mini(y,image.get_height()-1-y))
				if edge<2: image.set_pixel(x,y,color.darkened(.24))
				elif edge==5: image.set_pixel(x,y,color.lightened(.14))
		var mesh := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size=size; mesh.mesh=plane
		mesh.material_override=_material(image); mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.position=Vector3(center.x,.012,center.y); mesh.name="ReviewRug_"+key
		root.add_child(mesh)
	root.visible=enabled

func _add_plants() -> void:
	plants=plants.filter(func(r: WeakRef) -> bool: return is_instance_valid(r.get_ref()))
	for room in world.rooms:
		var key := STYLE.key(room) if production_mode else String(room.get("sample_key",""))
		if key not in ["office","manager","conference","pantry"]: continue
		if plant_rooms.has(int(room.id)): continue
		plant_rooms[int(room.id)]=true
		var rect: Rect2i=room.grid_rect
		for local in [Vector2(1.2,1.2),Vector2(rect.size.x-1.2,rect.size.y-1.2),Vector2(1.2,rect.size.y-1.2),Vector2(rect.size.x-1.2,1.2),Vector2(1.2,3.5),Vector2(rect.size.x-1.2,3.5),Vector2(3.5,rect.size.y-1.2)]:
			var point: Vector2=(Vector2(rect.position)+local)*32.0
			if not world._content_position_is_clear(point,22.0): continue
			var source := PROP.instantiate() as Node2D; CATALOG.configure(source,"plant"); source.position=point
			if not world._furniture_placement_is_clear(source,room.id): source.free(); continue
			var blocked := false
			var reservations: Array=preload("res://scripts/dream/otxo_room_layout_planner.gd").get_doorway_reservation_rects(world._get_room_doors(room.id))
			for reservation in reservations:
				if reservation.grow(16.0).has_point(point): blocked=true
			if blocked: source.free(); continue
			source.set_meta(&"dream_room_id",room.id); source.set_meta(&"office_visual_style","approved_room")
			source.set_meta(&"content_kind",&"furniture"); source.set_meta(&"floor_review_plant",true)
			if production_mode:
				source.set_meta(&"approved_art_addition",true)
				world.furniture_count+=1
			world.furniture_root.add_child(source); source.reset_spawn_physics(); world._spawn_furniture_presentation(source)
			plants.append(weakref(source)); break
