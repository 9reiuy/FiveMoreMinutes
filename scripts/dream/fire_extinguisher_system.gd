extends Node3D
## Floor-local gas coverage is authoritative. Whole smoke cards fit within
## boundary clearance instead of getting cut off by a fragment mask.
const TANK=preload("res://scripts/dream/fire_extinguisher.gd")
const PERF=preload("res://scripts/app/performance_markers.gd")
const SMOKE_SHADER=preload("res://shaders/dream3d/extinguisher_smoke.gdshader")
const OUTER_SHADER=preload("res://shaders/dream3d/extinguisher_smoke_outline.gdshader")
const MAX_PUFFS:=192
const MAX_CELLS:=1536
const DURATION:=12.0
const DIRECTIONS=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
var world: Node3D
var sources: Array[Dictionary]=[]
var cells: Dictionary={}
var blocked_doors: Dictionary={}
var silhouettes: Dictionary={}
var puffs: Array[Dictionary]=[]
var banks: Array[MultiMesh]=[]
var outer_banks: Array[MultiMesh]=[]
var fusion_pairs:=0
const FIELD_NEIGHBORS:=4
var fusion_field_image: Image
var fusion_field_texture: ImageTexture
var field_updated_at:=-1000.0
var field_layout:=""
var field_camera_basis:=Basis.IDENTITY
var visual_revision:=0
var clouds: Array[Dictionary]=[]
var fringe_clouds: Array[Dictionary]=[]
var clock:=0.0
var materials: Array[ShaderMaterial]=[]
var mask_image: Image
var mask_texture: ImageTexture
var mask_origin:=Vector2i.ZERO
var mask_size:=Vector2i.ONE
var refresh_left:=0.0
var rng:=RandomNumberGenerator.new()
var static_links: Dictionary={}
var _potential_links: Dictionary={}
var _edge_cells: Dictionary={}
var _cached_blockers: Dictionary={}
var _cached_pits: Dictionary={}
var _links_force_refresh:=false
var link_full_rebuilds:=0
var link_cell_updates:=0
var links_signature:=""
var smallest_room_cells:=MAX_CELLS
var coverage_radius:=1
var visual_edges: Array=[]
var visual_cells: Dictionary={}
var visual_structure:=""
var visual_strengths: Dictionary={}
var visual_path_cells:Dictionary={}
var trail_width_scale:=1.25
var trail_visual_scale:=1.25
var trail_core_strength:=.90
var emission_revision:=0
var source_serial:=0
var hidden_enemies: Dictionary={}
# Gameplay and the fusion gate still advance on every physics tick. Only
# the final presentation upload is shared by catch-up ticks in one frame.
var coalesce_presentation_enabled:=true
var coalesce_fusion_calculation_enabled:=true
var fusion_gate_passes:=0
var fusion_calculations:=0
var _fusion_calculation_pending:=false
var _fusion_snapshot_rendered:Array[Dictionary]=[]
var _fusion_snapshot_basis:=Basis.IDENTITY
var _fusion_snapshot_connectivity:Dictionary={}
var _presentation_pending:=false
var _prepared_rendered:Array[Dictionary]=[]
var _prepared_ready:=false
var _fusion_texture_pending:=false
var _camera_valid:=false
var _camera_position:=Vector3.ZERO
var _camera_basis:=Basis.IDENTITY

func _enter_tree()->void:
	if not RenderingServer.frame_pre_draw.is_connected(_flush_before_draw):
		RenderingServer.frame_pre_draw.connect(_flush_before_draw)

func _flush_before_draw()->void:
	flush_presentation()

func flush_presentation(force:=false)->void:
	if not _presentation_pending or not is_instance_valid(world):return
	if not force and (not can_process() or world.floor_transition_in_progress):return
	_presentation_pending=false
	upload_puffs()

static func install(owner_world: Node3D) -> Node3D:
	var existing: Node=owner_world.floor_root.get_node_or_null("FireExtinguisherSystem")
	if existing!=null:return existing
	var system:=load("res://scripts/dream/fire_extinguisher_system.gd").new() as Node3D
	system.name="FireExtinguisherSystem"
	owner_world.floor_root.add_child(system)
	system.configure(owner_world)
	return system

func configure(owner_world: Node3D) -> void:
	world=owner_world
	measure_smallest_room()
	rng.randomize()
	var low:=Vector2i(100000,100000)
	var high:=-low
	for cell: Vector2i in world.floor_cells:
		low=Vector2i(mini(low.x,cell.x),mini(low.y,cell.y))
		high=Vector2i(maxi(high.x,cell.x),maxi(high.y,cell.y))
	if world.floor_cells.is_empty():low=Vector2i.ZERO;high=Vector2i.ZERO
	mask_origin=low
	mask_size=high-low+Vector2i.ONE
	mask_image=Image.create(mask_size.x,mask_size.y,false,Image.FORMAT_RGBA8)
	mask_image.fill(Color.BLACK)
	mask_texture=ImageTexture.create_from_image(mask_image)
	cache_links()
	fusion_field_image=Image.create(FIELD_NEIGHBORS*2,MAX_PUFFS,false,Image.FORMAT_RGBAF)
	fusion_field_image.fill(Color(0,0,0,0))
	fusion_field_texture=ImageTexture.create_from_image(fusion_field_image)
	for variant in 1:
		var material:=ShaderMaterial.new()
		material.shader=SMOKE_SHADER
		# Shared silhouette pass precedes all lit fills, avoiding inner black
		# rings while keeping each group's halftone shadow and depth ordering.
		material.render_priority=3
		material.set_shader_parameter("cloud_variant",float(variant))
		material.set_shader_parameter("smoke_mask",mask_texture)
		material.set_shader_parameter("world_to_floor",world.global_transform.affine_inverse())
		material.set_shader_parameter("clip_at_floor",true)
		material.set_shader_parameter("fusion_enabled",true)
		material.set_shader_parameter("collective_fusion",true)
		material.set_shader_parameter("fusion_field",fusion_field_texture)
		material.set_shader_parameter("mask_origin",Vector2(mask_origin))
		material.set_shader_parameter("mask_size",Vector2(mask_size))
		var mesh:=QuadMesh.new();mesh.size=Vector2.ONE;mesh.material=material
		var bank:=MultiMesh.new()
		bank.transform_format=MultiMesh.TRANSFORM_3D;bank.use_colors=true;bank.use_custom_data=true;bank.mesh=mesh
		bank.instance_count=MAX_PUFFS;bank.visible_instance_count=0
		var carrier:=MultiMeshInstance3D.new();carrier.multimesh=bank
		carrier.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(carrier);banks.append(bank);materials.append(material)
		var outer_material:=material.duplicate() as ShaderMaterial
		outer_material.shader=OUTER_SHADER;outer_material.render_priority=2
		outer_material.set_shader_parameter("outer_outline_pass",true)
		var outer_mesh:=mesh.duplicate() as QuadMesh;outer_mesh.material=outer_material
		var outer_bank:=MultiMesh.new()
		outer_bank.transform_format=MultiMesh.TRANSFORM_3D;outer_bank.use_colors=true;outer_bank.use_custom_data=true;outer_bank.mesh=outer_mesh
		outer_bank.instance_count=MAX_PUFFS;outer_bank.visible_instance_count=0
		var outer_carrier:=MultiMeshInstance3D.new();outer_carrier.multimesh=outer_bank
		outer_carrier.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(outer_carrier);outer_banks.append(outer_bank);materials.append(outer_material)
	spawn_wall_tanks()

func measure_smallest_room() -> void:
	var counts: Dictionary={}
	for cell: Vector2i in world.floor_cells:
		if world.pit_cells.has(cell):continue
		var id:=int(world.room_cells.get(cell,-1))
		if id<0:continue
		var room: Dictionary=world.rooms[id] if id<world.rooms.size() else {}
		var kind:=String(room.get("archetype",room.get("room_type",room.get("type",""))))
		if kind in ["corridor","transition","elevator","elevator_lobby"] or String(world.floor_cells[cell])=="corridor":continue
		counts[id]=int(counts.get(id,0))+1
	smallest_room_cells=MAX_CELLS
	for count in counts.values():smallest_room_cells=mini(smallest_room_cells,int(count))
	if counts.is_empty():smallest_room_cells=mini(MAX_CELLS,maxi(1,world.floor_cells.size()))
	# A local footprint as well as an area budget prevents a thin corridor
	# from turning a small-room allowance into a long ribbon of gas.
	coverage_radius=maxi(1,ceili(sqrt(float(smallest_room_cells)/PI)))

func spawn_wall_tanks() -> void:
	var placement_rng:=RandomNumberGenerator.new()
	placement_rng.seed=int(world.active_seed)^0xF17E381
	var candidates: Array=[]
	for edge: Dictionary in world.wall_edges.values():
		var key: String=world._edge_key(edge)
		if world.door_edges.has(key) or world.door_opening_edges.has(key) or world.window_wall_edges.has(key) or world.glass_wall_edges.has(key):continue
		for cell: Vector2i in world._edge_side_cells(edge):
			if not world.floor_cells.has(cell) or world.pit_cells.has(cell):continue
			var center: Vector2=world._edge_gameplay_position(edge)
			var inward: Vector2=(Vector2(cell)*32-center).normalized()
			var point:=center+inward*maxf(11,world.wall_thickness*16+7)
			if not world._content_position_is_clear(point,6):continue
			candidates.append({"edge":key,"point":point,"inward":inward,"room":int(world.room_cells.get(cell,-1)),"cell":cell,"rank":placement_rng.randf()})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return float(a.rank)<float(b.rank))
	var counts: Dictionary={}
	var used: Array[Vector2]=[]
	for candidate in candidates:
		if used.size()>=18:break
		var room: int=candidate.room
		var corridor: bool=String(world.floor_cells.get(candidate.cell,""))=="corridor"
		if room>=0 and room<world.rooms.size():corridor=corridor or String(world.rooms[room].get("type",""))=="corridor" or String(world.rooms[room].get("archetype",""))=="corridor"
		if int(counts.get(room,0))>=(3 if corridor else 1):continue
		if used.any(func(at: Vector2)->bool:return at.distance_to(candidate.point)<96):continue
		# Deterministic variety, independent of enemy/weapon RNG.
		if not corridor and placement_rng.randf()>.70:continue
		var tank:=TANK.new()
		tank.name="FireExtinguisher_%d" % used.size()
		tank.world=world;tank.controller=self;tank.inward=candidate.inward
		tank.position=candidate.point
		tank.set_meta(&"wall_edge_key",candidate.edge)
		tank.set_meta(&"dream_room_id",room)
		world.key_root.add_child(tank)
		counts[room]=int(counts.get(room,0))+1
		used.append(candidate.point)

func discharge(point: Vector2) -> int:
	if sources.size()>=8:sources.remove_at(0)
	source_serial+=1
	sources.append({"id":source_serial,"cell":world._cell_for_gameplay_position(point),"point":point/32.0,"age":0.0,"trail":[],"cleared":{}})
	emission_revision+=1
	refresh_left=0
	PERF.event(self,"extinguisher_broken",{"source":source_serial,"x":point.x,"y":point.y,"sources":sources.size()})
	return source_serial

func emit_trail(from: Vector2,to: Vector2,id: int) -> void:
	for source in sources:
		if int(source.id)!=id:continue
		var steps:=maxi(1,ceili(from.distance_to(to)/16.0))
		for step in range(steps+1):
			var cell: Vector2i=world._cell_for_gameplay_position(from.lerp(to,float(step)/steps))
			if not world.floor_cells.has(cell) or world.pit_cells.has(cell):continue
			if not source.trail.is_empty() and source.trail.back().cell==cell:continue
			source.trail.append({"cell":cell,"born":float(source.age)})
			emission_revision+=1
			if source.trail.size()>128:source.trail.pop_front()
		refresh_left=0
		return

func disperse_segment(from: Vector2,to: Vector2) -> void:
	var started:=PERF.begin(self)
	var removed:=_disperse_segment_cells(from,to)
	PERF.end(self,"smoke_disperse",started)
	if removed>0:PERF.event(self,"smoke_dispersed",{"cells":removed,"sources":sources.size()})

func _disperse_segment_cells(from: Vector2,to: Vector2)->int:
	if cells.is_empty():return 0
	# Traverse only the segment actually travelled, nudging the endpoint back
	# inside its hit side so a bullet stopped at a wall cannot clear behind it.
	var direction:=from.direction_to(to)
	var start:=from+direction*.01
	var finish:=to-direction*.01 if from.distance_to(to)>.02 else from
	var steps:=maxi(1,ceili(start.distance_to(finish)/4.0))
	var changed:=0
	for index in range(steps+1):
		var cell: Vector2i=world._cell_for_gameplay_position(start.lerp(finish,float(index)/steps))
		if not cells.has(cell):continue
		for source in sources:source.cleared[cell]=float(source.age)
		cells.erase(cell);changed+=1
	if changed>0:refresh_left=0.0
	return changed

func emit_jet(point: Vector2,direction: Vector2) -> void:
	if puffs.size()>=24:return
	var mapped:=point/32+direction*.24
	var cell:=Vector2i(mapped.round())
	puffs.append({"cell":cell,"offset":mapped-Vector2(cell),"kind":rng.randi_range(0,5),"height":.40,"size":rng.randf_range(.45,.70),"age":0.0,"life":.25,"jet":direction})

func _physics_process(delta: float) -> void:
	var diagnostic_started:=PERF.begin(self)
	advance(delta,not coalesce_presentation_enabled)
	PERF.end(self,"smoke_physics",diagnostic_started)

func advance(delta: float,immediate_present:=true) -> void:
	if not is_instance_valid(world) or world.floor_transition_in_progress:return
	clock+=delta
	for index in range(sources.size()-1,-1,-1):
		sources[index].age+=delta
		if float(sources[index].age)>=DURATION:sources.remove_at(index)
	if sources.is_empty() and cells.is_empty() and puffs.is_empty():return
	refresh_left-=delta
	if refresh_left<=0:
		refresh_left=.1
		var diagnostic_started:=PERF.begin(self)
		rebuild_field()
		PERF.end(self,"smoke_rebuild",diagnostic_started)
		diagnostic_started=PERF.begin(self)
		apply_coverage()
		PERF.end(self,"smoke_coverage",diagnostic_started)
	else:
		# Moving across the cloud edge must not wait for the slower emission
		# refresh to hide/reveal enemies. Gameplay vision already tests each tick.
		var diagnostic_started:=PERF.begin(self)
		update_enemy_visibility()
		PERF.end(self,"smoke_visibility",diagnostic_started)
	for index in range(puffs.size()-1,-1,-1):
		puffs[index].age+=delta
		if float(puffs[index].age)>=float(puffs[index].life):puffs.remove_at(index)
	if immediate_present:
		_presentation_pending=false;_prepared_ready=false
		upload_puffs()
	else:
		_presentation_pending=true
		var diagnostic_started:=PERF.begin(self)
		_prepared_rendered=_prepare_puffs()
		PERF.end(self,"smoke_prepare",diagnostic_started)
		var camera:Camera3D=world.get("camera_3d")
		_camera_valid=is_instance_valid(camera)
		_camera_position=camera.global_position if _camera_valid else Vector3.ZERO
		_camera_basis=camera.global_basis if _camera_valid else Basis.IDENTITY
		# Retain the original per-physics gate clock and camera basis. A camera
		# moving later in _process must not change this tick's presentation.
		diagnostic_started=PERF.begin(self)
		build_collective_field(_prepared_rendered,camera)
		PERF.end(self,"smoke_fusion",diagnostic_started)
		_prepared_ready=true

func refresh_doors() -> void:
	blocked_doors.clear()
	var live_ids: Dictionary={}
	for door in world.door_root.get_children():
		if not door.has_meta(&"door_edge") or door.get("is_destroyed")==true:continue
		var edge: Dictionary=door.get_meta(&"door_edge")
		blocked_doors[world._edge_key(edge)]=true
		live_ids[int(edge.get("door_id",-1))]=true
	for key in world.door_opening_edges:
		var opening: Dictionary=world.door_opening_edges[key]
		if live_ids.has(int(opening.get("door_id",-2))):blocked_doors[key]=true

func cache_links() -> void:
	var signature:="%d/%d/%d/%d/%d" % [world.floor_cells.size(),world.wall_edges.size(),world.glass_wall_edges.size(),world.window_wall_edges.size(),world.pit_cells.size()]
	if signature==links_signature and not _links_force_refresh:return
	_links_force_refresh=false
	links_signature=signature
	var blockers:Dictionary=world.wall_edges.duplicate()
	blockers.merge(world.glass_wall_edges,true)
	blockers.merge(world.window_wall_edges,true)
	var full:bool=_potential_links.size()!=world.floor_cells.size() or _potential_links.is_empty()
	var affected:Dictionary={}
	if full:
		link_full_rebuilds+=1
		_potential_links.clear();_edge_cells.clear();static_links.clear()
		for cell:Vector2i in world.floor_cells:
			var candidates:Array=[]
			for direction:Vector2i in DIRECTIONS:
				var to:=cell+direction
				if not world.floor_cells.has(to):continue
				var key:String=world._edge_key(world._edge_from_cell_direction(cell,direction))
				candidates.append([to,key])
				if not _edge_cells.has(key):_edge_cells[key]=[]
				_edge_cells[key].append(cell)
			_potential_links[cell]=candidates
			affected[cell]=true
	else:
		# Compare blocker keys only when topology changes. Reuse all precomputed
		# edge keys; do not allocate four edge Dictionaries/Strings per floor cell.
		for key in _cached_blockers:
			if not blockers.has(key):
				for cell in _edge_cells.get(key,[]):affected[cell]=true
		for key in blockers:
			if not _cached_blockers.has(key):
				for cell in _edge_cells.get(key,[]):affected[cell]=true
		for cell in _cached_pits:
			if not world.pit_cells.has(cell):_affect_pit_neighbors(cell,affected)
		for cell in world.pit_cells:
			if not _cached_pits.has(cell):_affect_pit_neighbors(cell,affected)
	for cell:Vector2i in affected:
		var links:Array=[]
		for link in _potential_links.get(cell,[]):
			if not world.pit_cells.has(link[0]) and not blockers.has(link[1]):links.append(link)
		static_links[cell]=links
		link_cell_updates+=1
	_cached_blockers=blockers
	_cached_pits=world.pit_cells.duplicate()

func _affect_pit_neighbors(cell:Vector2i,affected:Dictionary)->void:
	if world.floor_cells.has(cell):affected[cell]=true
	for direction:Vector2i in DIRECTIONS:
		if world.floor_cells.has(cell+direction):affected[cell+direction]=true

func invalidate_topology(floor_layout_changed:=false)->void:
	_links_force_refresh=true
	if floor_layout_changed:_potential_links.clear()

func can_cross(from: Vector2i,to: Vector2i) -> bool:
	if not world.floor_cells.has(to) or world.pit_cells.has(to):return false
	var edge: Dictionary=world._edge_from_cell_direction(from,to-from)
	var key: String=world._edge_key(edge)
	return not world.wall_edges.has(key) and not world.glass_wall_edges.has(key) and not world.window_wall_edges.has(key) and not blocked_doors.has(key)

func rebuild_field() -> void:
	var rebuild_started:=PERF.begin(self)
	refresh_doors()
	PERF.end(self,"smoke_rebuild_doors",rebuild_started)
	rebuild_started=PERF.begin(self)
	cache_links()
	PERF.end(self,"smoke_rebuild_links",rebuild_started)
	rebuild_started=PERF.begin(self)
	cells.clear()
	visual_strengths.clear()
	visual_path_cells.clear()
	for source_index in range(sources.size()-1,-1,-1):
		var source: Dictionary=sources[source_index]
		var origin: Vector2i=source.cell
		if not world.floor_cells.has(origin):continue
		var seeds: Array=[]
		for index in range(source.trail.size()-1,-1,-1):seeds.append(source.trail[index])
		seeds.append({"cell":origin,"born":0.0})
		var queue: Array[Dictionary]=[]
		var distances: Dictionary={}
		for seed_point in seeds:
			var seed_cell: Vector2i=seed_point.cell
			if distances.has(seed_cell):continue
			distances[seed_cell]=0
			queue.append({"cell":seed_cell,"origin":seed_cell,"born":seed_point.born,"distance":0})
		var cursor:=0
		var max_distance:=mini(coverage_radius*2,maxi(1,ceili(float(source.age)*26)))
		var fade:=clampf((DURATION-float(source.age))/1.2,0,1)
		while cursor<queue.size() and cursor<smallest_room_cells:
			var point:=queue[cursor];cursor+=1
			var cell: Vector2i=point.cell
			if float(point.born)>float(source.cleared.get(cell,-1.0)):
				if cells.size()<mini(MAX_CELLS,smallest_room_cells) or cells.has(cell):
					cells[cell]=maxf(float(cells.get(cell,0)),fade)
					# Appearance only: all candidate cells already passed the real
					# wall / door / clearing rules above. Main release is strongest;
					# travelled-path emissions make smaller local concentrations.
					var radius:=maxf(1.0,float(coverage_radius))
					var main_core:=1.0-smoothstep(0.0,radius,Vector2(cell).distance_to(Vector2(source.get("point",origin))))
					var trail_core:=0.0
					if Vector2i(point.origin)!=origin:
						trail_core=trail_core_strength*(1.0-smoothstep(0.0,maxf(1.5,radius*.55*trail_width_scale),float(point.distance)))
						visual_path_cells[cell]=true
					visual_strengths[cell]=maxf(float(visual_strengths.get(cell,0.0)),maxf(main_core,trail_core))
			if int(point.distance)>=max_distance:continue
			for link in static_links[cell]:
				var neighbor: Vector2i=link[0]
				if distances.has(neighbor) or blocked_doors.has(link[1]):continue
				var spread_radius:float=float(coverage_radius)*(trail_width_scale if Vector2i(point.origin)!=origin else 1.0)
				if Vector2(neighbor-Vector2i(point.origin)).length_squared()>spread_radius*spread_radius:continue
				distances[neighbor]=int(point.distance)+1
				queue.append({"cell":neighbor,"origin":point.origin,"born":point.born,"distance":int(point.distance)+1})
	mask_image.fill(Color.BLACK)
	for cell: Vector2i in cells:
		var pixel:=cell-mask_origin
		if pixel.x>=0 and pixel.y>=0 and pixel.x<mask_size.x and pixel.y<mask_size.y:mask_image.set_pixelv(pixel,Color(float(cells[cell]),0,0))
	var mask_submit_started:=PERF.begin(self)
	mask_texture.update(mask_image)
	PERF.end(self,"smoke_mask_upload",mask_submit_started)
	PERF.end(self,"smoke_rebuild_bfs_mask",rebuild_started)
	rebuild_started=PERF.begin(self)
	# Coverage alpha can change without changing its outline. Keep fitted
	# centers and clearance until the cell layout actually changes.
	var structure:=links_signature+str(hash(blocked_doors))+"/%d/%d" % [sources.size(),emission_revision]
	var same_layout:=visual_cells.size()==cells.size() and visual_structure==structure
	if same_layout:
		for cell: Vector2i in cells:
			if not visual_cells.has(cell):same_layout=false;break
	if same_layout:
		PERF.end(self,"smoke_rebuild_edges",rebuild_started)
		return
	visual_revision+=1
	visual_structure=structure
	visual_cells=cells.duplicate()
	visual_edges.clear()
	for cell: Vector2i in cells:
		for direction: Vector2i in DIRECTIONS:
			if cells.has(cell+direction) and can_cross(cell,cell+direction):continue
			var center:=Vector2(cell)+Vector2(direction)*.5
			var tangent:=Vector2(-direction.y,direction.x)*.5
			visual_edges.append([center-tangent,center+tangent])
	var keys:=cells.keys()
	if keys.size()>MAX_PUFFS-24:
		var player: Variant=world.get("player")
		var focus: Vector2=player.global_position/32.0 if is_instance_valid(player) else Vector2(sources[0].cell)
		# Coarse distance buckets avoid sorting the entire floor with thousands
		# of GDScript comparator calls every coverage update.
		var buckets: Dictionary={}
		for cell: Vector2i in keys:
			var bucket:=floori(Vector2(cell).distance_squared_to(focus)/4.0)
			if not buckets.has(bucket):buckets[bucket]=[]
			buckets[bucket].append(cell)
		var distances:=buckets.keys();distances.sort()
		keys=[]
		for distance in distances:
			keys.append_array(buckets[distance])
			if keys.size()>=(MAX_PUFFS-24)/2:break
	PERF.end(self,"smoke_rebuild_edges",rebuild_started)
	rebuild_started=PERF.begin(self)
	clouds.clear()
	fringe_clouds.clear()
	if keys.is_empty():
		PERF.end(self,"smoke_rebuild_clouds",rebuild_started)
		return
	# Fixed release budget, redistributed over reachable cells when walls take
	# space away. Empty/cut cells never receive a replacement cloud.
	var target_count:=mini(MAX_PUFFS-24,smallest_room_cells*2*maxi(1,sources.size()))
	var cumulative: Array[float]=[]
	var total_weight:=0.0
	for cell: Vector2i in keys:
		var core:=float(visual_strengths.get(cell,0.0))
		total_weight+=.25+core*core*4.0
		cumulative.append(total_weight)
	var occurrences: Dictionary={}
	var geometry_by_cell:Dictionary={}
	for index in target_count:
		# Keep one small fringe group on each represented cell, then allocate
		# the remaining fixed budget by smooth emission-centre weights.
		var selected:=index
		if index>=keys.size():
			var sample: float=(float(index-keys.size())+.5)/maxi(1,target_count-keys.size())*total_weight
			selected=0
			while selected<cumulative.size()-1 and sample>cumulative[selected]:selected+=1
		var cell: Vector2i=keys[selected]
		var core:=float(visual_strengths.get(cell,0.0))
		if not geometry_by_cell.has(cell):
			var inward:=Vector2.ZERO
			for direction: Vector2i in DIRECTIONS:
				if not cells.has(cell+direction) or not can_cross(cell,cell+direction):inward-=Vector2(direction)
			var cached_center:=Vector2(cell)+inward.normalized()*.28
			geometry_by_cell[cell]={"center":cached_center,"clearance":card_clearance(cached_center,cell)}
		var center:Vector2=geometry_by_cell[cell].center
		var clearance:float=geometry_by_cell[cell].clearance
		var layer:=int(occurrences.get(cell,0))
		occurrences[cell]=layer+1
		var seed_value:=float(posmod(cell.x*37+cell.y*71+layer*193,997))
		var cloud:Dictionary={"cell":cell,"center":center,"layer":layer,"seed":seed_value,"clearance":clearance,"core":core,"opacity":lerpf(.80,1.0,core),"height":.15+pow(fposmod(seed_value*.371,1.0),1.5)*lerpf(.40,1.50,core),"size":(.70+pow(fposmod(seed_value*.573,1.0),2.0)*1.55)*lerpf(.75,1.8,core),"life":4.0+2.0*fposmod(seed_value*.293,1.0)}
		if visual_path_cells.has(cell) and trail_visual_scale!=1.0:
			cloud.path_scale=trail_visual_scale
			cloud.size*=trail_visual_scale
			cloud.height*=trail_visual_scale
		clouds.append(cloud)
	# Sparse decorative wisps are OUTSIDE the authoritative silhouette field.
	# Never place them in a shot-cleared lane, across a wall, in a pit or void.
	var used_fringe: Dictionary={}
	for cell: Vector2i in keys:
		for direction: Vector2i in DIRECTIONS:
			var outside:=cell+direction
			if fringe_clouds.size()>=12:break
			if cells.has(outside) or used_fringe.has(outside) or not can_cross(cell,outside):continue
			var cleared:=false
			for source in sources:
				if source.cleared.has(outside):cleared=true;break
			if cleared:continue
			used_fringe[outside]=true
			var seed_value:=float(posmod(outside.x*137+outside.y*71,997))
			fringe_clouds.append({"cell":outside,"seed":seed_value,"size":.32+fposmod(seed_value*.37,1.0)*.30})
	PERF.end(self,"smoke_rebuild_clouds",rebuild_started)

func card_clearance(point: Vector2,origin: Vector2i) -> float:
	var clearance:=2.5
	# Fit whole cards inside coverage and structural edges, never slice them.
	if not cells.has(origin):return 0.0
	for edge in visual_edges:
		clearance=minf(clearance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,edge[0],edge[1])))
	return clearance

func contains(point: Vector2) -> bool:
	return float(cells.get(world._cell_for_gameplay_position(point),0))>.05

func blocks_sight(from: Vector2,to: Vector2) -> bool:
	if cells.is_empty():return false
	var a:=from/32.0+Vector2(.5,.5)
	var b:=to/32.0+Vector2(.5,.5)
	var cell:=Vector2i(a.floor())
	var finish:=Vector2i(b.floor())
	var direction:=b-a
	var step:=Vector2i(int(signf(direction.x)),int(signf(direction.y)))
	var delta:=Vector2(INF if step.x==0 else absf(1.0/direction.x),INF if step.y==0 else absf(1.0/direction.y))
	var next:=Vector2(INF if step.x==0 else (float(cell.x+(1 if step.x>0 else 0))-a.x)/direction.x,INF if step.y==0 else (float(cell.y+(1 if step.y>0 else 0))-a.y)/direction.y)
	for index in absi(finish.x-cell.x)+absi(finish.y-cell.y)+3:
		if float(cells.get(cell,0))>.05:return true
		if cell==finish:return false
		if absf(next.x-next.y)<.00001:
			if float(cells.get(cell+Vector2i(step.x,0),0))>.05 or float(cells.get(cell+Vector2i(0,step.y),0))>.05:return true
			cell+=step;next+=delta
		elif next.x<next.y:cell.x+=step.x;next.x+=delta.x
		else:cell.y+=step.y;next.y+=delta.y
	return false

func apply_coverage() -> void:
	var actors: Dictionary={}
	for group in [&"dream_player",&"dream_enemies",&"npcs",&"dialogue_npcs"]:
		for actor in get_tree().get_nodes_in_group(group):
			if actor is Node2D:actors[actor.get_instance_id()]=actor
	# NPC presentation need not belong to a combat group.
	for bridge in world.actor_depth_bridges_root.get_children():
		var actor: Variant=bridge.get("source_actor")
		if is_instance_valid(actor) and actor is Node2D and actor.has_node("CharacterVisual"):actors[actor.get_instance_id()]=actor
	var now: Dictionary={}
	for id in actors:
		var actor: Node2D=actors[id]
		if actor.get("hp")!=null or actor.get("drone")!=null:continue
		if not actor.can_process() or not contains(actor.global_position):continue
		now[id]=weakref(actor)
		actor.set_meta(&"extinguisher_smoke",true)
		set_silhouette(actor,true)
	for id in silhouettes:
		if now.has(id):continue
		var actor: Node2D=silhouettes[id].get_ref()
		if is_instance_valid(actor):
			actor.remove_meta(&"extinguisher_smoke")
			set_silhouette(actor,false)
	silhouettes=now
	var burn: Node=world.floor_root.get_node_or_null("BurningEffects")
	if burn!=null:
		for id in burn.burning.keys():
			var actor: Node=burn.burning[id].ref.get_ref()
			if is_instance_valid(actor) and contains(burn.flat_position(actor)):burn.remove_burn(id)
	for tank in get_tree().get_nodes_in_group(&"fire_extinguishers"):
		if tank.get("controller")==self and tank.has_method("set_smoke_silhouette"):
			tank.set_smoke_silhouette(contains(tank.global_position))
	update_enemy_visibility()

func update_enemy_visibility() -> void:
	var player: Variant=world.get("player")
	var now: Dictionary={}
	if is_instance_valid(player):
		for enemy in get_tree().get_nodes_in_group(&"dream_enemies"):
			if not enemy is Node2D or not enemy.can_process() or enemy.get("dead")==true:continue
			if not blocks_sight(player.global_position,enemy.global_position):continue
			var id: int=enemy.get_instance_id()
			if hidden_enemies.has(id):now[id]=hidden_enemies[id];continue
			enemy.set_meta(&"smoke_hidden_from_player",true)
			var nodes: Array=[]
			var reference: Variant=enemy.get_meta(&"depth_visual_bridge") if enemy.has_meta(&"depth_visual_bridge") else null
			var bridge: Variant=reference.get_ref() if reference is WeakRef else reference
			for visual in [bridge,enemy.get("visual"),enemy.get("drone")]:
				if visual is Node3D and is_instance_valid(visual):
					nodes.append({"ref":weakref(visual),"visible":visual.visible});visual.hide()
			now[id]={"ref":weakref(enemy),"nodes":nodes}
	for id in hidden_enemies:
		if not now.has(id):restore_enemy(hidden_enemies[id])
	hidden_enemies=now

func restore_enemy(record: Dictionary) -> void:
	var enemy: Node=record.ref.get_ref()
	if is_instance_valid(enemy):enemy.remove_meta(&"smoke_hidden_from_player")
	for entry in record.nodes:
		var visual: Node3D=entry.ref.get_ref()
		if is_instance_valid(visual):visual.visible=entry.visible

func set_silhouette(actor: Node2D,enabled: bool) -> void:
	if not actor.has_meta(&"depth_visual_bridge"):return
	var ref: Variant=actor.get_meta(&"depth_visual_bridge",null)
	var bridge: Node=ref.get_ref() if ref is WeakRef else ref
	if is_instance_valid(bridge) and bridge.has_method("set_smoke_silhouette"):bridge.set_smoke_silhouette(enabled)

func upload_puffs() -> void:
	var diagnostic_started:=PERF.begin(self)
	_presentation_pending=false
	for material in materials:material.set_shader_parameter("smoke_clock",clock*.5)
	var rendered:Array[Dictionary]=_prepared_rendered if _prepared_ready else _prepare_puffs()
	var camera:Camera3D=world.get("camera_3d")
	var valid:bool=_camera_valid if _prepared_ready else is_instance_valid(camera)
	var eye:Vector3=_camera_position if _prepared_ready else (camera.global_position if valid else Vector3.ZERO)
	var basis:Basis=_camera_basis if _prepared_ready else (camera.global_basis if valid else Basis.IDENTITY)
	if not _prepared_ready:build_collective_field(rendered,camera)
	_prepared_ready=false
	_flush_fusion_calculation()
	if _fusion_texture_pending:
		fusion_field_texture.update(fusion_field_image)
		_fusion_texture_pending=false
	_commit_puffs(rendered,valid,eye,basis)
	PERF.end(self,"smoke_upload",diagnostic_started)

func _prepare_puffs()->Array[Dictionary]:
	var rendered: Array[Dictionary]=[]
	for cloud in clouds:
		var cell: Vector2i=cloud.cell
		var seed_value:=float(cloud.seed)
		var life:=float(cloud.life)
		var elapsed:=clock+seed_value*.173
		var cycle:=floorf(elapsed/life)
		var age:=fposmod(elapsed,life)/life
		# Slow rolling body: retain volume through most of each 4-6s cycle.
		# Only the final part shrinks/fades; the source's 12s clock is unchanged.
		var envelope:=(.85+.15*smoothstep(0.0,.08,age))*(1.0-.7*smoothstep(.65,1.0,age))
		var motion:=clock*.4+seed_value
		var offset:=Vector2(sin(seed_value)*.10+sin(motion)*.08,cos(seed_value*.7)*.10+cos(motion*.83)*.08)
		var fade:=float(cells.get(cell,0))
		var fringe:=clampf(1.1-float(cloud.clearance),0,1)
		var roll:=1.0+sin(motion*.9)*.06
		var size:=minf(float(cloud.size)*roll,maxf(.1,float(cloud.clearance)-offset.length()-.025)*1.40)*sqrt(fade)*envelope
		size*=1.0-fringe*.08
		var at: Vector3=world.get_gameplay_world_position((Vector2(cloud.center)+offset)*32,float(cloud.height)+age*.12)
		var alpha:=1.0 if age<.75 else clampf((1.0-age)/.25,0,1)
		# Covered cells keep a stable opaque foundation. Only upper detail groups
		# recycle; their individual fade must not open holes in the sight volume.
		if int(cloud.layer)==0:
			size/=maxf(.01,envelope)
			alpha=1.0
			at=world.get_gameplay_world_position((Vector2(cloud.center)+offset)*32,maxf(.62*float(cloud.get("path_scale",1.0)),float(cloud.height))*1.5)
		else:at=world.get_gameplay_world_position((Vector2(cloud.center)+offset)*32,(float(cloud.height)+age*.12)*1.5)
		rendered.append({"at":at,"cell":cell,"size":size,"alpha":alpha*fade,"seed":fposmod(seed_value*.37+(0.0 if int(cloud.layer)==0 else cycle*.618),1)})
	for puff in puffs:
		var t:=float(puff.age)/float(puff.life)
		var cell: Vector2i=puff.cell
		var map_point:=Vector2(cell)+Vector2(puff.offset)
		if puff.has("jet"):map_point+=Vector2(puff.jet)*t*.45
		var at: Vector3=world.get_gameplay_world_position(map_point*32,float(puff.height)+t*.25)
		if not cells.has(Vector2i(map_point.round())):continue
		var size:=minf(float(puff.size)*lerpf(.65,1.3,t),card_clearance(map_point,Vector2i(map_point.round()))*1.40)
		rendered.append({"at":at,"cell":Vector2i(map_point.round()),"size":size,"alpha":minf(1,(1-t)*4),"seed":float(puff.kind)/6})
	var release_fade:=0.0
	for value in cells.values():release_fade=maxf(release_fade,float(value))
	for fringe_cloud in fringe_clouds:
		if rendered.size()>=MAX_PUFFS:break
		var seed_value:=float(fringe_cloud.seed)
		var age:=fposmod(clock+seed_value*.13,5.0)/5.0
		var position:=Vector2(fringe_cloud.cell)+Vector2(sin(clock*.35+seed_value),cos(clock*.31+seed_value))*.06
		var at: Vector3=world.get_gameplay_world_position(position*32,.35+age*.25)
		var size:=float(fringe_cloud.size)*release_fade*(.65+.35*sin(age*PI))
		rendered.append({"at":at,"cell":fringe_cloud.cell,"size":size,"alpha":release_fade*.55*sin(age*PI),"seed":fposmod(seed_value*.37,1),"fringe":true})
	for index in rendered.size():rendered[index].field_row=index
	return rendered

func _commit_puffs(rendered:Array[Dictionary],camera_valid:bool,eye:Vector3,camera_basis:Basis)->void:
	if camera_valid:
		var forward:=-camera_basis.z
		for cloud in rendered:cloud.depth=(Vector3(cloud.at)-eye).dot(forward)
		rendered.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return float(a.depth)>float(b.depth))
	var facing:=global_basis.inverse()*camera_basis if camera_valid else Basis.IDENTITY
	for index in rendered.size():
		var cloud: Dictionary=rendered[index]
		var size:=float(cloud.size)
		var transform:=Transform3D(facing*Basis.from_scale(Vector3(size,size,1)),to_local(cloud.at))
		var tint:=Color(float(cloud.seed),0.0 if cloud.get("fringe",false) else 1.0,1,float(cloud.alpha))
		banks[0].set_instance_transform(index,transform);banks[0].set_instance_color(index,tint)
		banks[0].set_instance_custom_data(index,Color((float(cloud.field_row)+.5)/MAX_PUFFS,0,0,0))
		outer_banks[0].set_instance_transform(index,transform);outer_banks[0].set_instance_color(index,tint)
		outer_banks[0].set_instance_custom_data(index,Color((float(cloud.field_row)+.5)/MAX_PUFFS,0,0,0))
	banks[0].visible_instance_count=rendered.size()
	outer_banks[0].visible_instance_count=rendered.size()

func build_collective_field(rendered: Array[Dictionary],camera: Camera3D,force_update:=false) -> void:
	# Bounded local scalar field, not disjoint pairs or painted bridge capsules.
	# Each group can contribute to several neighbours at once.
	var layout:="%d/%d" % [visual_revision,rendered.size()]
	var camera_basis:=camera.global_basis if is_instance_valid(camera) else Basis.IDENTITY
	# Slow visual rolling does not need a 60Hz neighbour search. Row IDs are
	# assigned BEFORE transparent sorting, so cached rows cannot swap clouds.
	if not force_update and layout==field_layout and camera_basis.is_equal_approx(field_camera_basis) and clock>=field_updated_at and clock-field_updated_at<.08:return
	field_updated_at=clock;field_layout=layout;field_camera_basis=camera_basis
	fusion_gate_passes+=1
	if _presentation_pending and coalesce_fusion_calculation_enabled:
		var started:=PERF.begin(self)
		# The last gate step and last presentation step are NOT interchangeable.
		# Keep independent immutable input, including topology decisions made at
		# this gate. Later bullets, doors and windows cannot change these decisions.
		_fusion_snapshot_rendered=rendered.duplicate(true)
		_fusion_snapshot_basis=camera_basis
		_fusion_snapshot_connectivity=_capture_fusion_connectivity(rendered)
		_fusion_calculation_pending=true
		PERF.end(self,"smoke_fusion_snapshot",started)
	else:
		_fusion_calculation_pending=false
		_fusion_snapshot_rendered.clear();_fusion_snapshot_connectivity.clear()
		_calculate_fusion_field(rendered,camera_basis,{},_presentation_pending)

func _capture_fusion_connectivity(rendered:Array[Dictionary])->Dictionary:
	var occupied:Dictionary={}
	for cloud in rendered:occupied[cloud.cell]=true
	var connectivity:Dictionary={}
	for cell:Vector2i in occupied:
		var mask:=0
		for dy in range(-1,2):
			for dx in range(-1,2):
				var neighbor:=cell+Vector2i(dx,dy)
				if occupied.has(neighbor) and fusion_can_cross(cell,neighbor):mask|=1<<((dy+1)*3+dx+1)
		connectivity[cell]=mask
	return connectivity

func _flush_fusion_calculation()->void:
	if not _fusion_calculation_pending:return
	_fusion_calculation_pending=false
	_calculate_fusion_field(_fusion_snapshot_rendered,_fusion_snapshot_basis,_fusion_snapshot_connectivity,true)
	_fusion_snapshot_rendered.clear();_fusion_snapshot_connectivity.clear()

func _calculate_fusion_field(rendered:Array[Dictionary],camera_basis:Basis,connectivity:Dictionary,defer_upload:bool)->void:
	var started:=PERF.begin(self)
	fusion_calculations+=1
	fusion_pairs=0
	fusion_field_image.fill(Color(0,0,0,0))
	var right:=camera_basis.x
	var up:=camera_basis.y
	var forward:=camera_basis.z
	var buckets: Dictionary={}
	for index in rendered.size():
		var at: Vector3=rendered[index].at
		rendered[index].plane=Vector2(at.dot(right),at.dot(up))
		var key: Vector2i=rendered[index].cell
		if not buckets.has(key):buckets[key]=[]
		buckets[key].append(index)
	var connected: Dictionary={}
	for cell: Vector2i in buckets:
		var candidates: Array=[]
		for y in range(cell.y-1,cell.y+2):
			for x in range(cell.x-1,cell.x+2):
				var other_cell:=Vector2i(x,y)
				if not buckets.has(other_cell):continue
				var offset:=other_cell-cell
				var allowed:bool=(int(connectivity.get(cell,0)) & (1<<((offset.y+1)*3+offset.x+1)))!=0 if not connectivity.is_empty() else fusion_can_cross(cell,other_cell)
				if allowed:candidates.append_array(buckets[other_cell])
		connected[cell]=candidates
	for index in rendered.size():
		var cloud:=rendered[index]
		if cloud.get("fringe",false) or float(cloud.size)<.12 or float(cloud.alpha)<.35:continue
		var nearest: Array=[]
		for other_index in connected[cloud.cell]:
			if other_index==index:continue
			var other:=rendered[int(other_index)]
			if other.get("fringe",false):continue
			var minimum:=minf(float(cloud.size),float(other.size))
			var offset:=Vector3(other.at)-Vector3(cloud.at)
			var separation:=absf(offset.dot(forward))
			if minimum<.12 or float(other.alpha)<.35 or separation>minimum*.65:continue
			var distance:=Vector2(cloud.plane).distance_squared_to(other.plane)
			var reach:=minf(1.8,(float(cloud.size)+float(other.size))*.64)
			if distance>reach*reach:continue
			if nearest.size()==FIELD_NEIGHBORS and distance>=float(nearest[-1].distance):continue
			var insertion:=0
			while insertion<nearest.size() and distance>=float(nearest[insertion].distance):insertion+=1
			nearest.insert(insertion,{"other":other,"distance":distance,"offset":offset,"depth":separation,"minimum":minimum})
			if nearest.size()>FIELD_NEIGHBORS:nearest.pop_back()
		for slot in mini(FIELD_NEIGHBORS,nearest.size()):
			var item: Dictionary=nearest[slot]
			var other: Dictionary=item.other
			var offset: Vector3=item.offset
			var strength:=smoothstep(.35,.75,minf(float(cloud.alpha),float(other.alpha)))
			strength*=1.0-smoothstep(float(item.minimum)*.35,float(item.minimum)*.65,float(item.depth))
			fusion_field_image.set_pixel(slot*2,index,Color(offset.dot(right)/float(cloud.size),-offset.dot(up)/float(cloud.size),float(other.size)/float(cloud.size),float(other.seed)))
			fusion_field_image.set_pixel(slot*2+1,index,Color(strength,0,0,0))
			if strength>.01:fusion_pairs+=1
	if defer_upload:_fusion_texture_pending=true
	else:fusion_field_texture.update(fusion_field_image)
	PERF.end(self,"smoke_fusion_calculate",started)

func fusion_can_cross(a: Vector2i,b: Vector2i) -> bool:
	if a==b:return true
	var delta:=b-a
	if absi(delta.x)>1 or absi(delta.y)>1:return false
	if delta.x==0 or delta.y==0:return can_cross(a,b)
	# A diagonal link must have BOTH corner routes open, so a short connector
	# cannot cut around the end of a real wall or through a closed door corner.
	var x:=a+Vector2i(delta.x,0);var y:=a+Vector2i(0,delta.y)
	return cells.has(x) and cells.has(y) and can_cross(a,x) and can_cross(a,y) and can_cross(x,b) and can_cross(y,b)

func link_fusion(rendered: Array[Dictionary],camera: Camera3D) -> void:
	fusion_pairs=0
	var right:=camera.global_basis.x if is_instance_valid(camera) else Vector3.RIGHT
	var up:=camera.global_basis.y if is_instance_valid(camera) else Vector3.UP
	var depth:=camera.global_basis.z if is_instance_valid(camera) else Vector3.BACK
	var buckets: Dictionary={}
	var available: Dictionary={}
	for index in rendered.size():
		var cloud:=rendered[index]
		cloud.link=Color(0,0,0,0)
		if float(cloud.alpha)<.35 or float(cloud.size)<.12:continue
		var at: Vector3=cloud.at
		var pixel:=Vector2(at.dot(right),at.dot(up))
		cloud.screen_plane=pixel
		var key:=Vector2i(pixel.floor())
		if not buckets.has(key):buckets[key]=[]
		buckets[key].append(index);available[index]=true
	for index in rendered.size():
		if not available.has(index):continue
		var cloud:=rendered[index]
		var key:=Vector2i(Vector2(cloud.screen_plane).floor())
		var best:=-1;var best_distance:=INF;var considered:=0
		for y in range(key.y-1,key.y+2):
			for x in range(key.x-1,key.x+2):
				for other_index in buckets.get(Vector2i(x,y),[]):
					if other_index==index or not available.has(other_index):continue
					if considered>=20:break
					considered+=1
					var other:=rendered[int(other_index)]
					var ratio:=float(other.size)/float(cloud.size)
					if ratio<.5 or ratio>2.0:continue
					var offset:=Vector3(other.at)-Vector3(cloud.at)
					if absf(offset.dot(depth))>minf(float(cloud.size),float(other.size))*.4:continue
					var distance:=Vector2(cloud.screen_plane).distance_to(other.screen_plane)
					var reach:=minf(.75,(float(cloud.size)+float(other.size))*.32+.035)
					if distance>reach or distance>=best_distance:continue
					if not fusion_can_cross(cloud.cell,other.cell):continue
					best=int(other_index);best_distance=distance
		if best<0:continue
		var other:=rendered[best]
		var reach:=minf(.75,(float(cloud.size)+float(other.size))*.32+.035)
		var amount:=1.0-smoothstep(reach*.7,reach,best_distance)
		var offset:=Vector3(other.at)-Vector3(cloud.at)
		amount*=smoothstep(.35,.65,minf(float(cloud.alpha),float(other.alpha)))
		amount*=1.0-smoothstep(minf(float(cloud.size),float(other.size))*.25,minf(float(cloud.size),float(other.size))*.4,absf(offset.dot(depth)))
		var ratio:=float(other.size)/float(cloud.size)
		amount*=smoothstep(.5,.7,ratio)*(1.0-smoothstep(1.5,2.0,ratio))
		cloud.link=Color(offset.dot(right)/float(cloud.size),-offset.dot(up)/float(cloud.size),float(other.size)/float(cloud.size),amount)
		other.link=Color(-offset.dot(right)/float(other.size),offset.dot(up)/float(other.size),float(cloud.size)/float(other.size),amount)
		available.erase(index);available.erase(best);fusion_pairs+=1

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_flush_before_draw):
		RenderingServer.frame_pre_draw.disconnect(_flush_before_draw)
	for record in hidden_enemies.values():restore_enemy(record)
	hidden_enemies.clear()
	if is_instance_valid(world):
		for tank in get_tree().get_nodes_in_group(&"fire_extinguishers"):
			if tank.get("controller")==self and tank.has_method("set_smoke_silhouette"):tank.set_smoke_silhouette(false)
	for ref in silhouettes.values():
		var actor: Node2D=ref.get_ref()
		if is_instance_valid(actor):
			actor.remove_meta(&"extinguisher_smoke")
			set_silhouette(actor,false)
