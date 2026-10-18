extends Node
## Floor-owned approved scenery in the formal depth buffer; exterior lights cannot affect gameplay.
const CITY_LAYER := 1 << 19
const WINDOW_LIGHT_LIMIT := 4
const CITY_SHADER = preload("res://shaders/dream3d/preview/sample_neon_city.gdshader")
var world: Node3D
var scene_root: Node3D
var render_materials: Array[ShaderMaterial]=[]
var attached_mask: ShaderMaterial
var topology: Dictionary={}
var build_seed := -1
var buildings := 0
var near_towers: Array[Dictionary]=[]
var middle_towers: Array[Dictionary]=[]
var facade_segments := 0
var enabled := true
var window_lights: Array[OmniLight3D]=[]
var light_candidates: Array[Dictionary]=[]
var window_lights_enabled := true
var height_fog_enabled := true
var last_light_selection := -1000
var production_mode := false

func _ready() -> void:
	if world==null: world=get_parent()
	process_priority=100

func _enter_tree() -> void:
	if not RenderingServer.frame_pre_draw.is_connected(_sync_render_snapshot):
		RenderingServer.frame_pre_draw.connect(_sync_render_snapshot)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_render_snapshot): RenderingServer.frame_pre_draw.disconnect(_sync_render_snapshot)

func _process(_delta: float) -> void:
	if world.floor_cells.is_empty() or world.room_visibility==null: return
	if scene_root==null or not is_instance_valid(scene_root) or build_seed!=world.active_seed:
		_build()
	var mask: ShaderMaterial=world.room_visibility.outside_mask_material
	if mask!=null and mask!=attached_mask: _attach_mask(mask)
	if Time.get_ticks_msec()-last_light_selection>=300: _select_window_lights()

static func classify_void(floor_cells: Dictionary, rect: Rect2i) -> Dictionary:
	var bounds := rect.grow(2)
	var external: Dictionary={}; var queue: Array[Vector2i]=[]
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			var cell := Vector2i(x,y)
			if x!=bounds.position.x and x!=bounds.end.x-1 and y!=bounds.position.y and y!=bounds.end.y-1: continue
			if not floor_cells.has(cell) and not external.has(cell): external[cell]=true; queue.append(cell)
	var index := 0
	while index<queue.size():
		var cell := queue[index]; index+=1
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+step
			if bounds.has_point(next) and not floor_cells.has(next) and not external.has(next): external[next]=true; queue.append(next)
	var image := Image.create(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGB8)
	for y in bounds.size.y:
		for x in bounds.size.x:
			var cell := bounds.position+Vector2i(x,y)
			image.set_pixel(x,y,Color(1 if external.has(cell) else 0,1 if floor_cells.has(cell) else 0,0))
	return {"bounds":bounds,"external":external,"image":image}

func _build() -> void:
	if is_instance_valid(scene_root): scene_root.free()
	attached_mask=null; build_seed=world.active_seed
	topology=classify_void(world.floor_cells,world.building_rect)
	scene_root=Node3D.new(); scene_root.name="SampleNeonCityGeometry"
	if production_mode: get_parent().add_child(scene_root)
	else: world.add_child(scene_root)
	scene_root.global_transform=world.global_transform
	var facade := SurfaceTool.new(); facade.begin(Mesh.PRIMITIVE_TRIANGLES)
	var neon := SurfaceTool.new(); neon.begin(Mesh.PRIMITIVE_TRIANGLES)
	var own := SurfaceTool.new(); own.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new(); rng.seed=world.active_seed+88211
	var rect: Rect2i=world.building_rect; buildings=0
	near_towers.clear(); middle_towers.clear(); facade_segments=0; render_materials.clear()
	window_lights.clear(); light_candidates.clear(); last_light_selection=-1000
	var center := Vector2(rect.get_center())
	# Follow real exterior wall runs, rather than eight widely separated center points.
	near_towers=near_layout(world.floor_cells,topology.external,rng)
	for tower in near_towers:
		var tint := Color("566487").lerp(Color("665472"),rng.randf())
		_tower(facade,neon,tower.position,tower.size,tint,buildings)
		_add_window_candidate(tower,buildings)
		buildings+=1
	# A second compact ring fills the old navy void behind the foreground street gaps.
	for z in range(rect.position.y-44,rect.end.y+44,12):
		for x in range(rect.position.x-44,rect.end.x+44,12):
			var size := Vector3(rng.randf_range(6.5,8.5),rng.randf_range(46,61),rng.randf_range(6.5,8.5))
			var at := Vector3(x,-46+size.y*.5,z)
			var footprint := Rect2(Vector2(at.x-size.x*.5,at.z-size.z*.5),Vector2(size.x,size.z))
			if near_towers.any(func(tower: Dictionary) -> bool: return tower.footprint.grow(3.0).intersects(footprint)): continue
			if world.floor_cells.keys().any(func(cell: Vector2i) -> bool: return footprint.grow(3.0).intersects(Rect2(Vector2(cell)-Vector2(.5,.5),Vector2.ONE))): continue
			middle_towers.append({"position":at,"size":size,"footprint":footprint})
			_tower(facade,neon,at,size,Color("414a6e").lerp(Color("4d4268"),rng.randf()),buildings)
			buildings+=1
	for z in range(rect.position.y-140,rect.end.y+140,12):
		for x in range(rect.position.x-140,rect.end.x+140,12):
			if rect.grow(34).has_point(Vector2i(x,z)): continue
			if rng.randf()<.17: continue
			var width := rng.randf_range(4.0,7.8); var depth := rng.randf_range(4.0,7.8)
			var height := rng.randf_range(8.0,28.0)
			var at := Vector3(x+rng.randf_range(-1,1),-40+height*.5,z+rng.randf_range(-1,1))
			var footprint := Rect2(Vector2(at.x-width*.5,at.z-depth*.5),Vector2(width,depth))
			if middle_towers.any(func(tower: Dictionary) -> bool: return tower.footprint.grow(3.0).intersects(footprint)): continue
			var tint := Color("3f496c").lerp(Color("554165"),rng.randf())
			_tower(facade,neon,at,Vector3(width,height,depth),tint,buildings)
			buildings+=1
	_box(facade,Vector3(rect.size.x+320,.1,rect.size.y+320),Vector3(center.x,-43,center.y),Color("17233f"))
	# Skin follows the true outer contour, not the rectangular container or internal holes.
	for cell in world.floor_cells:
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if not topology.external.has(cell+step): continue
			var at := Vector3(cell.x+step.x*.51,-21.02,cell.y+step.y*.51)
			var size := Vector3(.08,42.0,1.0) if step.x!=0 else Vector3(1.0,42.0,.08)
			_box(own,size,at,Color("748597")); facade_segments+=1
	for item in [[facade.commit(),_scenery_material(false,false),"NeighbourBuildings"],[neon.commit(),_scenery_material(true,false),"CityNeon"],[own.commit(),_scenery_material(false,true),"CurrentBuildingFacade"]]:
		var visible := MeshInstance3D.new(); visible.mesh=item[0]; visible.material_override=item[1]
		visible.name=item[2]
		visible.layers=CITY_LAYER
		visible.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scene_root.add_child(visible)
	var lights := Node3D.new(); lights.name="ExteriorWindowLights"; scene_root.add_child(lights)
	for index in WINDOW_LIGHT_LIMIT:
		var light := OmniLight3D.new(); light.name="WindowLightSlot%d" % index
		light.light_cull_mask=CITY_LAYER; light.shadow_enabled=false
		light.omni_range=11.0; light.omni_attenuation=1.0; light.light_energy=2.2
		lights.add_child(light); window_lights.append(light)
	_select_window_lights()
	_sync_render_snapshot()

static func near_layout(floor_cells: Dictionary, external: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var lines: Dictionary={}
	for cell in floor_cells:
		for side in 4:
			var step: Vector2i=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN][side]
			if not external.has(cell+step): continue
			var line := Vector2i(side,cell.x if side<2 else cell.y)
			if not lines.has(line): lines[line]=[]
			lines[line].append(cell.y if side<2 else cell.x)
	var runs: Array[Dictionary]=[]
	for line in lines:
		var along: Array=lines[line]; along.sort()
		var start: int=along[0]; var previous := start
		for value in along.slice(1):
			if value!=previous+1:
				runs.append({"side":line.x,"fixed":line.y,"start":start-.5,"length":previous-start+1})
				start=value
			previous=value
		runs.append({"side":line.x,"fixed":line.y,"start":start-.5,"length":previous-start+1})
	# Stable long-run-first placement keeps corners from creating overlapping towers.
	runs.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.length!=b.length: return a.length>b.length
		if a.side!=b.side: return a.side<b.side
		if a.fixed!=b.fixed: return a.fixed<b.fixed
		return a.start<b.start)
	var result: Array[Dictionary]=[]
	for run in runs:
		if run.length<6: continue
		var along_gap := rng.randf_range(3.0,4.0)
		var count := maxi(1,ceili((run.length+along_gap)/(9.0+along_gap)))
		if (run.length-(count-1)*along_gap)/count<5.0: count=maxi(1,count-1)
		var width: float=(run.length-(count-1)*along_gap)/count
		for index in count:
			var gap := rng.randf_range(3.0,4.0); var depth := rng.randf_range(8.0,11.0)
			var height := rng.randf_range(64.0,76.0)
			var side: int=run.side; var sign_value := -1.0 if side==0 or side==2 else 1.0
			var crossing: float=run.fixed+sign_value*(.5+gap+depth*.5)
			var along: float=run.start+width*.5+index*(width+along_gap)
			var at := Vector3(crossing,-46+height*.5,along) if side<2 else Vector3(along,-46+height*.5,crossing)
			var size := Vector3(depth,height,width) if side<2 else Vector3(width,height,depth)
			var footprint := Rect2(Vector2(at.x-size.x*.5,at.z-size.z*.5),Vector2(size.x,size.z))
			var blocked: bool=result.any(func(tower: Dictionary) -> bool: return tower.footprint.grow(3.0).intersects(footprint))
			if blocked: continue
			# Do not insert towers into narrow concave recesses or enclosed courtyards.
			for cell in floor_cells:
				if footprint.grow(2.99).intersects(Rect2(Vector2(cell)-Vector2(.5,.5),Vector2.ONE)):
					blocked=true; break
			if not blocked: result.append({"position":at,"size":size,"top":at.y+height*.5,"side":side,"gap":gap,"footprint":footprint})
	return result

static func window_tone(cell: Vector2i, seed_value: int) -> int:
	return posmod(cell.x*17+cell.y*37+seed_value*7,13)

func _add_window_candidate(tower: Dictionary,index: int) -> void:
	var at: Vector3=tower.position; var size: Vector3=tower.size; var side: int=tower.side
	var inward := Vector3.RIGHT if side==0 else Vector3.LEFT if side==1 else Vector3.BACK if side==2 else Vector3.FORWARD
	var seed_value := index%251
	# Match a genuinely lit texel window, including its two-cell floor spacing.
	var row := floori((.5-at.y-.90625)/2.0)
	for column in range(-2,3):
		var tone := window_tone(Vector2i(column,row),seed_value)
		if tone<5: continue
		var local := Vector3(inward.x*(size.x*.5+.08),row*2.0+.90625,column+.484375) if side<2 else Vector3(column+.484375,row*2.0+.90625,inward.z*(size.z*.5+.08))
		var color := Color("edbd87") if tone>=9 else Color("87bbc8")
		light_candidates.append({"position":at+local,"color":color,"tower":index,"cell":Vector2i(column,row)})
		break

func _select_window_lights() -> void:
	if not is_instance_valid(scene_root) or window_lights.is_empty(): return
	last_light_selection=Time.get_ticks_msec()
	var camera: Camera3D=world.camera_3d
	var size := camera.get_viewport().get_visible_rect().size
	var ranked: Array[Dictionary]=[]
	for candidate in light_candidates:
		var position: Vector3=scene_root.to_global(candidate.position)
		var score := camera.global_position.distance_squared_to(position)
		if camera.is_position_behind(position): score+=10000.0
		else: score+=(camera.unproject_position(position)/size-Vector2(.5,.5)).length_squared()*1500.0
		ranked.append({"candidate":candidate,"score":score})
	ranked.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.score<b.score)
	var wanted: Dictionary={}
	var threshold: float=ranked[mini(WINDOW_LIGHT_LIMIT,ranked.size())-1].score*1.2 if not ranked.is_empty() else 0.0
	# Keep an existing source until its contribution falls twenty percent behind.
	for light in window_lights:
		var id: int=light.get_meta(&"candidate_tower",-1)
		for item in ranked:
			if item.candidate.tower==id and item.score<=threshold: wanted[id]=item.candidate; break
	for item in ranked:
		if wanted.size()>=WINDOW_LIGHT_LIMIT: break
		wanted[item.candidate.tower]=item.candidate
	var retained: Dictionary={}
	for light in window_lights:
		var id: int=light.get_meta(&"candidate_tower",-1)
		if wanted.has(id): retained[id]=true
	for light in window_lights:
		var id: int=light.get_meta(&"candidate_tower",-1)
		if not wanted.has(id):
			id=-1
			for key in wanted:
				if not retained.has(key): id=key; retained[key]=true; break
		light.set_meta(&"candidate_tower",id)
		if id<0: light.visible=false; continue
		var candidate: Dictionary=wanted[id]
		light.position=candidate.position; light.light_color=candidate.color
		light.visible=window_lights_enabled

static func _tower(facade: SurfaceTool,neon: SurfaceTool,at: Vector3,size: Vector3,tint: Color,index: int) -> void:
	# Alpha is opaque vertex metadata, not transparency: one stable window seed per tower.
	# COLOR may use eight-bit storage, so encode an exact byte instead of 997 seeds.
	tint.a=float(index%251)/255.0
	_box(facade,size,at,tint)
	_box(facade,Vector3(size.x*.7,.25,size.z*.7),at+Vector3(0,size.y*.5+.125,0),tint.lightened(.08))
	_box(facade,Vector3(size.x*.22,.7,size.z*.25),at+Vector3(size.x*.15,size.y*.5+.6,size.z*.13),tint.darkened(.15))
	if index%2==0:
		var color := Color("60a7b6") if index%3==0 else Color("b45d91") if index%3==1 else Color("637dcc")
		_box(neon,Vector3(size.x*.55,.18,.06),at+Vector3(0,size.y*.25,size.z*.5+.04),color)
		_box(neon,Vector3(.07,size.y*.3,.07),at+Vector3(size.x*.5+.035,size.y*.25,size.z*.35),color*.7)

func _scenery_material(neon: bool, own: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new(); mat.shader=CITY_SHADER
	mat.set_shader_parameter("neon_surface",neon); mat.set_shader_parameter("own_facade",own)
	mat.set_shader_parameter("city_void",ImageTexture.create_from_image(topology.image))
	mat.set_shader_parameter("city_origin",Vector2(topology.bounds.position))
	mat.set_shader_parameter("city_grid_size",Vector2(topology.bounds.size))
	render_materials.append(mat); return mat

static func _box(st: SurfaceTool,size: Vector3,at: Vector3,tint: Color) -> void:
	var box := BoxMesh.new(); box.size=size
	var arrays := box.surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	for index in arrays[Mesh.ARRAY_INDEX]:
		var local := points[index]; var normal := normals[index]
		var uv := Vector2(local.x,local.y) if absf(normal.z)>.5 else Vector2(local.z,local.y) if absf(normal.x)>.5 else Vector2(local.x,local.z)
		st.set_normal(normal); st.set_uv(uv); st.set_color(tint); st.add_vertex(local+at)

func _sync_render_snapshot() -> void:
	# Reparenting into the rollback stash must not sample the staged new floor.
	if production_mode and (world==null or get_parent().get_parent()!=world.office_art_root): return
	if not is_instance_valid(scene_root) or world.room_visibility==null: return
	var mask: ShaderMaterial=world.room_visibility.outside_mask_material
	if mask==null: return
	for mat in render_materials:
		mat.set_shader_parameter("height_fog_enabled",height_fog_enabled)
		for parameter in ["map_origin","map_x_axis","map_z_axis","ray_origin_tl","ray_origin_dx","ray_origin_dy","ray_direction_tl","ray_direction_dx","ray_direction_dy"]:
			var value: Variant=mask.get_shader_parameter(parameter)
			if value!=null: mat.set_shader_parameter(parameter,value)
	var active := String(world.transition_phase)!="CAB_RIDE"
	scene_root.visible=active and enabled
	for light in window_lights: light.visible=active and enabled and window_lights_enabled and int(light.get_meta(&"candidate_tower",-1))>=0

func _attach_mask(source: ShaderMaterial) -> void:
	var material := source.duplicate() as ShaderMaterial
	var shader := Shader.new(); var code := source.shader.code
	code=code.replace("uniform sampler2D footprint_distance", "uniform sampler2D city_void : filter_nearest, repeat_disable;\nuniform vec2 city_origin;\nuniform vec2 city_grid_size;\nuniform sampler2D footprint_distance")
	code=code.replace("float alpha = 1.0;","float alpha = 1.0;\nvec3 background_color=vec3(0.0);\nbool city_exterior=true;")
	code=code.replace("vec2 uv = (map_cell", "vec2 city_uv=(map_cell-city_origin+vec2(.5))/city_grid_size;\nif(all(greaterThanEqual(city_uv,vec2(0.0))) && all(lessThanEqual(city_uv,vec2(1.0)))){vec2 classification=texture(city_void,city_uv).rg; city_exterior=classification.r>.5; if(classification.r<.5 && classification.g<.5){alpha=1.0;}}\nvec2 uv = (map_cell")
	code=code.replace("alpha = smoothstep(0.0, 1.0, distance_to_floor);", "alpha = smoothstep(0.0, 1.0, distance_to_floor);\nvec2 classification=texture(city_void,city_uv).rg; if(!city_exterior && classification.g<.5){alpha=1.0;}")
	# Exterior pixels remain in the formal 3D depth buffer, instead of being painted over.
	code=code.replace("COLOR = vec4(0.0, 0.0, 0.0, alpha);", "if(city_exterior){alpha=0.0;}\nCOLOR = vec4(background_color, alpha);")
	shader.code=code; material.shader=shader
	material.set_shader_parameter("city_void",ImageTexture.create_from_image(topology.image))
	material.set_shader_parameter("city_origin",Vector2(topology.bounds.position))
	material.set_shader_parameter("city_grid_size",Vector2(topology.bounds.size))
	world.room_visibility.outside_mask_material=material
	world.room_visibility.outside_black_gradient.material=material
	attached_mask=material
