extends "res://scripts/dream/city/depth_shape_source.gd"
## Production adapter. Source art stays unchanged; only rigid modules and lots adapt.
const MODULE_LIBRARY=preload("res://art/Dream/CityDepthShape/rigid_modules.res")
const REFERENCE=preload("res://art/Dream/CityDepthShape/reference_layout.res")
const UPPER_PROFILES=preload("res://art/Dream/CityDepthShape/upper_seam_profiles.tres")
const CACHE_LIMIT:=4
static var _layouts:Dictionary={}
var _layout_key:=""
var _reference_layout:=false
var _module_records:Array=[]
var _reserved_plots:Array[Rect2]=[]
var _plot_grid:Dictionary={}
var _own_panels:Array=[]
var _own_target:Dictionary={}
var _air_anchors:Array[Vector2]=[]
var _cache_hit:=false
var _current_ad_host:=-1
var _ad_glow_nodes:Array=[]
var _hidden_camera_host:=-2

func _run_signature()->String:
	var values:Array=[]
	for run:Dictionary in main_runs:values.append([int(run.side),int(run.fixed),float(run.start),float(run.length)])
	return _br_digest_bytes(var_to_bytes(values))

func _br_plan(_rng:RandomNumberGenerator,rect:Rect2i)->void:
	assert(FileAccess.get_sha256(BR_BANK.resource_path).to_upper()==MODULE_LIBRARY.get_meta("source_bank_sha256"))
	assert(FileAccess.get_sha256(OWN_SOURCE_BANK.resource_path).to_upper()==MODULE_LIBRARY.get_meta("own_bank_sha256"))
	assert(UPPER_PROFILES.get_meta("source_bank_sha256")==MODULE_LIBRARY.get_meta("own_bank_sha256"))
	br_plans.clear();near_towers.clear();middle_towers.clear();_module_records.clear()
	_reserved_plots.clear();_plot_grid.clear();_own_panels.clear();_own_target={}
	_ad_glow_nodes.clear();_hidden_camera_host=-2
	_air_anchors=[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]
	var cells:Array=world.floor_cells.keys()
	cells.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.y<b.y or (a.y==b.y and a.x<b.x))
	_layout_key=_br_digest_bytes(var_to_bytes([world.active_seed,rect,cells,scene_root.global_basis,world.camera_3d.global_basis]))
	_reference_layout=world.active_seed==42001 and _run_signature()==MODULE_LIBRARY.get_meta("reference_runs_sha256")
	_cache_hit=false
	if _reference_layout:
		for plan:Dictionary in REFERENCE.get_meta("source_plans"):_restore_plan(plan)
		_module_records=REFERENCE.get_meta("installations").duplicate(true)
	elif _layouts.has(_layout_key):
		var cached:Dictionary=_layouts[_layout_key]
		for plan:Dictionary in cached.plans:_restore_plan(plan)
		_module_records=cached.records.duplicate(true);_cache_hit=true
	else:
		_build_adapted_lots(rect)
		if _layouts.size()>=CACHE_LIMIT:_layouts.erase(_layouts.keys()[0])
		_layouts[_layout_key]={"plans":br_plans.duplicate(true),"records":_module_records.duplicate(true)}
	if not _reference_layout:
		var eye_direction:Vector3=scene_root.global_basis.inverse()*world.camera_3d.global_basis.z
		var preferred_side:int=0 if eye_direction.x<0 else 3
		for run:Dictionary in main_runs:
			var outside:bool=(int(run.side)==0 and int(run.fixed)==rect.position.x) or (int(run.side)==3 and int(run.fixed)==rect.end.y-1)
			if outside and int(run.side)==preferred_side and float(run.length)>=8.0:
				_own_target=run;break
		for run:Dictionary in main_runs:
			if not _own_target.is_empty():break
			var outside:bool=(int(run.side)==0 and int(run.fixed)==rect.position.x) or (int(run.side)==3 and int(run.fixed)==rect.end.y-1)
			if outside and float(run.length)>=8.0:
				_own_target=run;break
	city_coverage["production_city"]={"layout_key":_layout_key,"reference_layout":_reference_layout,"plan_cache_hit":_cache_hit,"cache_entries":_layouts.size(),"runtime_triangle_search":false,"source_modules":"Approved FD99 native sources, rigid paired host/advert transforms","camera_clip":"Existing RoomVisibility ray/floor projection and soft retention","floor_cells":cells.size()}

func _restore_plan(plan:Dictionary)->void:
	_br_add_plan(plan.position,plan.size,int(plan.source_id),int(plan.turn),int(plan.tier),str(plan.get("density_role","production")))
	br_plans[-1].merge(plan,true)
	_reserve(Rect2(plan.footprint.position,plan.footprint.size))

func _reserve(plot:Rect2)->void:
	var index:int=_reserved_plots.size();_reserved_plots.append(plot)
	var low:=Vector2i(floori((plot.position.x-2.1)/20.0),floori((plot.position.y-2.1)/20.0))
	var high:=Vector2i(floori((plot.end.x+2.1)/20.0),floori((plot.end.y+2.1)/20.0))
	for y:int in range(low.y,high.y+1):
		for x:int in range(low.x,high.x+1):
			var key:=Vector2i(x,y)
			if not _plot_grid.has(key):_plot_grid[key]=[]
			_plot_grid[key].append(index)

func _lot_clear(plot:Rect2)->bool:
	var expanded:=plot.grow(3.75)
	if expanded.intersects(Rect2(world.building_rect)):
		var low:=Vector2i(floori(expanded.position.x-.5),floori(expanded.position.y-.5))
		var high:=Vector2i(ceili(expanded.end.x+.5),ceili(expanded.end.y+.5))
		for y:int in range(low.y,high.y+1):
			for x:int in range(low.x,high.x+1):
				if world.floor_cells.has(Vector2i(x,y)) and expanded.intersects(Rect2(Vector2(x-.5,y-.5),Vector2.ONE)):return false
		var center:=Vector2i(roundi(plot.get_center().x),roundi(plot.get_center().y))
		if world.building_rect.has_point(center) and not topology.external.has(center):return false
	var low:=Vector2i(floori((plot.position.x-2.1)/20.0),floori((plot.position.y-2.1)/20.0))
	var high:=Vector2i(floori((plot.end.x+2.1)/20.0),floori((plot.end.y+2.1)/20.0))
	var checked:Dictionary={}
	for y:int in range(low.y,high.y+1):
		for x:int in range(low.x,high.x+1):
			for index:int in _plot_grid.get(Vector2i(x,y),[]):
				if checked.has(index):continue
				checked[index]=true
				if plot.grow(2.1).intersects(_reserved_plots[index]):return false
	return true

func _add_lot(at:Vector3,size:Vector3,id:int,turn:int,tier:int,role:String)->bool:
	var plot:=Rect2(Vector2(at.x-size.x*.5,at.z-size.z*.5),Vector2(size.x,size.z))
	if not _lot_clear(plot):return false
	_br_add_plan(at,size,id,turn,tier,role);_reserve(plot);return true

func _build_adapted_lots(rect:Rect2i)->void:
	var modules:Array=MODULE_LIBRARY.get_meta("modules")
	# Rank only rigid placements, using each actual advert normal and a reachable
	# window viewer in the unchanged game Camera basis. At most three runs/side.
	var back:Vector3=scene_root.global_basis.inverse()*world.camera_3d.global_basis.z
	back.y=0;back=back.normalized()
	# Keep the readable hosts already chosen for the normal west/south views;
	# the tall picture panel gets a bounded fallback over the other outer sides.
	for index:int in [1,2,3,4,0]:
		var module:Dictionary=modules[index]
		var desired_side:int=[0,3,0,1,2][index]
		var candidates:Array=[]
		for offset:int in 4:
			var side:int=posmod(desired_side+offset,4)
			var side_runs:Array=main_runs.filter(func(r:Dictionary)->bool:return int(r.side)==side and float(r.length)>=5.0)
			candidates.append_array(side_runs.slice(0,3))
		var chosen:Dictionary={};var best:=-INF
		for run:Dictionary in candidates:
			var axes:Array[Vector3]=_run_axes(run)
			var forward_shift:float=-signf(back.dot(axes[1]))
			for fraction:float in [.5,.22,.78]:
				var window_along:float=float(run.start)+float(run.length)*fraction
				var standing:Vector3=axes[2]+axes[1]*window_along-axes[0]*2.0
				var viewer:Vector3=standing+back*9.0+axes[0]*3.5;viewer.y=15.6
				for quarter:int in 4:
					var rotation:=Basis(Vector3.UP,float(quarter)*PI*.5)
					var old:Dictionary=module.plan
					var size:Vector3=old.size if quarter%2==0 else Vector3(old.size.z,old.size.y,old.size.x)
					var radial:float=size.x if int(run.side)<2 else size.z
					for advance:float in [0.0,4.0,8.0,12.0,16.0,20.0,24.0]:
						for gap:float in [4.25,7.5,11.5]:
							var at:Vector3=axes[2]+axes[1]*(window_along+forward_shift*advance)+axes[0]*(gap+radial*.5);at.y=old.position.y
							var mount:Dictionary=module.record.mount.duplicate(true)
							mount.position=at+rotation*(mount.position-old.position);mount.normal=rotation*mount.normal
							var facing:float=mount.normal.dot((viewer-mount.position).normalized())
							if facing<.15:continue
							var visible:Dictionary=_advert_projection(mount,int(module.record.poster),viewer)
							if float(visible.score)<=0:continue
							var envelope:AABB=Transform3D(rotation,at)*(module.envelope_relative as AABB)
							var plot:=Rect2(Vector2(envelope.position.x,envelope.position.z),Vector2(envelope.size.x,envelope.size.z))
							if not _lot_clear(plot):continue
							var score:float=visible.score+facing*100.0-gap
							# Prefer the intended distribution whenever its side fits.
							if int(run.side)==desired_side:score+=1000000.0
							if score<=best:continue
							best=score;chosen={"at":at,"size":size,"quarter":quarter,"plot":plot,"mount":mount,"envelope":envelope,"viewer":viewer,"projection":visible}
		if chosen.is_empty():chosen=_outer_rigid_module(module,rect)
		if chosen.is_empty():push_error("No physical rigid city module fits current perimeter: "+str(index));continue
		var old:Dictionary=module.plan
		_br_add_plan(chosen.at,chosen.size,int(old.source_id),posmod(int(old.turn)+int(chosen.quarter),4),0,"rigid_ad_host");_reserve(chosen.plot)
		var record:Dictionary=module.record.duplicate(true);var mount:Dictionary=chosen.mount
		mount.source_face_plane=mount.normal.dot(mount.position-mount.normal*float(mount.support_offset))
		mount.host_id=br_plans.size()-1;mount.host_transform=_br_plan_transform(br_plans[-1])
		mount["rigid_module_certificate"]=index;mount["placement_envelope"]=chosen.envelope
		mount["adaptation_viewer"]=chosen.viewer;mount["adaptation_projection"]=chosen.projection
		record.mount=mount;_module_records.append(record)
	var rng:=RandomNumberGenerator.new();rng.seed=world.active_seed+88211
	for run:Dictionary in main_runs:
		if float(run.length)<5:continue
		var axes:Array[Vector3]=_run_axes(run)
		var count:int=maxi(1,ceili(float(run.length)/17.0))
		for i:int in count:
			var size:Vector3=_lot_size(rng,0)
			var radial:float=size.x if int(run.side)<2 else size.z
			var at:Vector3=axes[2]+axes[1]*(float(run.start)+float(run.length)*(float(i)+.5)/float(count))+axes[0]*(16.0+radial*.5)
			at.y=STREET_LEVEL+size.y*.5
			var id:int=[0,1,5,7,10,11,12,15][rng.randi_range(0,7)]
			var turn:int=rng.randi_range(0,3)
			for source:Dictionary in modules:
				if int(source.plan.source_id)!=id:continue
				var local_normal:Vector3=Basis(Vector3.UP,float(source.plan.turn)*PI*.5).transposed()*source.record.mount.normal
				turn=_facing_quarter(local_normal,-axes[0]);break
			for extra:float in [0.0,7.5,15.0]:
				if _add_lot(at+axes[0]*extra,size,id,turn,0,"near_source"):break
	for z:int in range(rect.position.y-72,rect.end.y+73,15):
		for x:int in range(rect.position.x-72,rect.end.x+73,15):
			var size:Vector3=_lot_size(rng,1)
			var at:=Vector3(x+rng.randf_range(-3,3),STREET_LEVEL+size.y*.5,z+rng.randf_range(-3,3))
			_add_lot(at,size,rng.randi_range(0,16),rng.randi_range(0,3),1,"middle_source")
	for z:int in range(rect.position.y-180,rect.end.y+181,17):
		for x:int in range(rect.position.x-180,rect.end.x+181,17):
			if rect.grow(47).has_point(Vector2i(x,z)) or rng.randf()<.05:continue
			var size:Vector3=_lot_size(rng,2)
			var at:=Vector3(x+rng.randf_range(-3,3),STREET_LEVEL+size.y*.5,z+rng.randf_range(-3,3))
			_add_lot(at,size,[3,6,8,9,16][rng.randi_range(0,4)],rng.randi_range(0,3),2,"far_source")

func _outer_rigid_module(module:Dictionary,rect:Rect2i)->Dictionary:
	# Some non-convex/staged floors have no single-view fit in the first twelve
	# wall runs. Keep the same certified rigid host outside the real outer bounds.
	# This fallback preserves physical rules; it makes no Camera-readability claim.
	var chosen:Dictionary={};var best:=-INF
	for side:int in 4:
		var fixed:int=rect.position.x if side==0 else rect.end.x-1 if side==1 else rect.position.y if side==2 else rect.end.y-1
		var run:Dictionary={"side":side,"fixed":fixed}
		var axes:Array[Vector3]=_run_axes(run)
		var start:float=rect.position.y-.5 if side<2 else rect.position.x-.5
		var length:float=rect.size.y if side<2 else rect.size.x
		for fraction:float in [.22,.5,.78]:
			var building_point:Vector3=axes[2]+axes[1]*(start+length*fraction)-axes[0]*2.0
			for quarter:int in 4:
				var rotation:=Basis(Vector3.UP,float(quarter)*PI*.5)
				var old:Dictionary=module.plan
				var size:Vector3=old.size if quarter%2==0 else Vector3(old.size.z,old.size.y,old.size.x)
				var radial:float=size.x if side<2 else size.z
				for gap:float in [9.0,18.0,30.0,44.0]:
					var at:Vector3=axes[2]+axes[1]*(start+length*fraction)+axes[0]*(gap+radial*.5);at.y=old.position.y
					var mount:Dictionary=module.record.mount.duplicate(true)
					mount.position=at+rotation*(mount.position-old.position);mount.normal=rotation*mount.normal
					var viewer:Vector3=building_point;viewer.y=15.6
					var facing:float=mount.normal.dot((viewer-mount.position).normalized())
					if facing<.15:continue
					var envelope:AABB=Transform3D(rotation,at)*(module.envelope_relative as AABB)
					var plot:=Rect2(Vector2(envelope.position.x,envelope.position.z),Vector2(envelope.size.x,envelope.size.z))
					if not _lot_clear(plot):continue
					var score:float=facing*100.0-gap
					if score<=best:continue
					best=score;chosen={"at":at,"size":size,"quarter":quarter,"plot":plot,"mount":mount,"envelope":envelope,"viewer":viewer,"projection":{"score":0.0,"camera_view_certified":false,"placement_fallback":"bounded_outer_perimeter_physical_fit"}}
	return chosen

func _facing_quarter(normal:Vector3,desired:Vector3)->int:
	var best:=0;var score:=-INF
	for quarter:int in 4:
		var facing:Vector3=Basis(Vector3.UP,float(quarter)*PI*.5)*normal
		var current:float=facing.dot(desired)
		if current>score:score=current;best=quarter
	return best

func _lot_size(rng:RandomNumberGenerator,tier:int)->Vector3:
	var aspect:float=[.48,.66,1.0,1.95,2.5][rng.randi_range(0,4)]*rng.randf_range(.94,1.06)
	var area:float=rng.randf_range(70.0,145.0)
	var height:float=rng.randf_range(88,132) if tier==0 else (rng.randf_range(52,100) if tier==1 else rng.randf_range(34,74))
	return Vector3(sqrt(area*aspect),height,sqrt(area/aspect))

func _city_shape01_layout()->void:
	var ratios:Array=[]
	for p:Dictionary in br_plans:ratios.append(maxf(p.size.x,p.size.z)/minf(p.size.x,p.size.z))
	ratios.sort()
	city_coverage["shape_variation"]={"count":br_plans.size(),"fixed_per_map":true,"runtime_mode":"portable_reference" if _reference_layout else ("bounded_layout_cache" if _cache_hit else "bounded_floor_adaptation"),"median_aspect":ratios[ratios.size()/2],"cache_entries":_layouts.size()}

func _own_r3_shell(solid:SurfaceTool,run:Dictionary)->void:
	if _reference_layout or run!=_own_target:
		super._own_r3_shell(solid,run);return
	if not city_coverage.has("own_full05"):
		city_coverage["own_full05"]={"runs":[],"bank_sha256":FileAccess.get_sha256(OWN_SOURCE_BANK.resource_path).to_upper(),"material_ids":OWN_SOURCE_BANK.get_meta("source_material_ids"),"per_frame_geometry_search":false,"source_bound_sha256":OWN_SOURCE_BANK.get_meta("source_bound_sha256"),"merged_carriers":1,"extra_lights":0}
	var zones:Array=[]
	zones.append({"start":run.start,"length":8.0,"pieces":_own_full_zone(solid,run,float(run.start),8.0,0)})
	if float(run.length)>8.0:zones.append({"start":run.start+8.0,"length":run.length-8.0,"pieces":_own_full_zone(solid,run,float(run.start)+8.0,float(run.length)-8.0,2)})
	_own_adapter_box(solid,run,run.start,run.length,-.04,.28,-.24,-.06,9)
	_own_adapter_box(solid,run,run.start,run.length,-.20,.34,continuity_base_y,-48.24,9)
	city_coverage.own_full05.runs.append({"side":run.side,"fixed":run.fixed,"start":run.start,"length":run.length,"zones":zones})

func _own_full_zone(solid:SurfaceTool,run:Dictionary,start:float,length:float,preferred:int)->Array:
	var pieces:Array=super._own_full_zone(solid,run,start,length,preferred)
	var cursor:float=start
	for piece:Dictionary in pieces:
		if int(piece.get("bank_id",-1))==9 and absf(float(piece.get("inset",1)))<.00001 and absf(float(piece.length)-8.0)<.00001 and int(run.side) in [0,3]:
			var axes:Array[Vector3]=_run_axes(run)
			_own_panels.append({"transform":Transform3D(Basis(axes[1],Vector3.UP,axes[0]),axes[2]+axes[1]*cursor),"run":run})
		cursor+=float(piece.length)
	return pieces

func _own_r3_close_underdeck(solid:SurfaceTool)->void:
	super._own_r3_close_underdeck(solid)
	# The complete source curtain can stand outside the occupied floor. Its
	# profile caps did not bridge that offset back to the actual floor edge.
	# Close only that upper seam below the playable plane; retain source arrays.
	var joins:=SurfaceTool.new();joins.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections:=0;var maximum_outward:=0.0
	for run:Dictionary in city_coverage.own_full05.runs:
		for zone:Dictionary in run.zones:
			var cursor:float=zone.start
			for piece:Dictionary in zone.pieces:
				var width:float=piece.length
				var id:int=int(piece.get("bank_id",-1))
				if id>=0:
					var profile:=PackedVector2Array([Vector2.ZERO,Vector2(width,0.0)])
					for point:Vector2 in UPPER_PROFILES.get_meta("profiles")[id]:
						var p:=Vector2(clampf(point.x,0.0,width),maxf(0.0,point.y+float(piece.inset)))
						profile.append(p);maximum_outward=maxf(maximum_outward,p.y)
					profile=Geometry2D.convex_hull(profile)
					if profile.size()>3:
						profile.remove_at(profile.size()-1)
						_own_upper_prism(joins,run,cursor,profile);sections+=1
				cursor+=width
	if sections>0:
		joins.index()
		var material:=_scenery_material(true)
		material.set_shader_parameter("pilot_geometry",true)
		material.set_shader_parameter("own_reference_material",true)
		_add_city_carrier(joins.commit(),material,"CurrentBuildingUpperSeamClosure")
	city_coverage["own_upper_seam"]={"sections":sections,"maximum_outward":maximum_outward,"y_min":-0.24,"y_max":-0.06,"closed_geometry":true,"source_arrays_unchanged":true,"collision_nodes":0,"new_lights":0}

func _own_upper_prism(tool:SurfaceTool,run:Dictionary,start:float,polygon:PackedVector2Array)->void:
	var axes:Array[Vector3]=_run_axes(run)
	var lower:=PackedVector3Array();var upper:=PackedVector3Array()
	for p:Vector2 in polygon:
		var at:Vector3=axes[2]+axes[1]*(start+p.x)+axes[0]*p.y
		at.y=-0.24;lower.append(at);at.y=-0.06;upper.append(at)
	for i:int in range(1,polygon.size()-1):
		_own_upper_triangle(tool,upper[0],upper[i],upper[i+1],Vector3.UP)
		_own_upper_triangle(tool,lower[0],lower[i],lower[i+1],Vector3.DOWN)
	for i:int in polygon.size():
		var next:int=(i+1)%polygon.size()
		var edge:Vector2=polygon[next]-polygon[i]
		var normal:Vector3=(axes[1]*edge.y-axes[0]*edge.x).normalized()
		_own_upper_triangle(tool,lower[i],upper[i],upper[next],normal)
		_own_upper_triangle(tool,lower[i],upper[next],lower[next],normal)

func _own_upper_triangle(tool:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,normal:Vector3)->void:
	var points:Array[Vector3]=[a,b,c]
	if (b-a).cross(c-a).dot(normal)>0.0:points.reverse()
	for p:Vector3 in points:
		tool.set_normal(normal);tool.set_uv(Vector2(p.x,p.z)*0.125)
		tool.set_uv2(Vector2.ZERO);tool.set_color(Color(0.4,0.45,0.5,3.0/64.0));tool.add_vertex(p)

func _own_reuse_verified_space()->void:
	var own_hash:String=_own_r3_geometry_digest()
	var reference_ok:bool=not _reference_layout or own_hash==MODULE_LIBRARY.get_meta("reference_own_sha256")
	var bounds_ok:=true
	for run:Dictionary in city_coverage.own_full05.runs:
		for zone:Dictionary in run.zones:
			for piece:Dictionary in zone.pieces:
				if float(piece.get("finished_outward",0))>2.561:bounds_ok=false
	var seam:Dictionary=city_coverage.get("own_upper_seam",{})
	if float(seam.get("maximum_outward",0.0))>2.561:bounds_ok=false
	city_coverage["own_full_space"]={"ok":reference_ok and bounds_ok,"own_mesh_sha256":own_hash,"exact_triangle_hit_plans":[],"exact_triangle_test_performed":false,"mode":"approved_reference_local_geometry" if _reference_layout else "disjoint_certified_module_envelopes","runtime_triangle_search":false,"floor_clearance":3.75,"maximum_own_outward":2.561,"upper_seam":seam,"unchanged_plans":br_plans.size(),"binding":_br_cache_binding()}
	if not reference_ok or not bounds_ok:push_error("Production city geometry exceeds its certified placement envelope")

func _own_full_space_audit()->void:
	_own_reuse_verified_space()

func _br_advertisements()->void:
	br_frozen_ad_records.clear();city_coverage["advertisements"]=[]
	var records:Array=_module_records.duplicate(true)
	if not _reference_layout:
		var attached:=false
		for panel:Dictionary in _own_panels:
			var run:Dictionary=panel.run
			var exterior:bool=(int(run.side)==0 and int(run.fixed)==world.building_rect.position.x) or (int(run.side)==3 and int(run.fixed)==world.building_rect.end.y-1)
			if not exterior:continue
			var record:Dictionary=MODULE_LIBRARY.get_meta("own_record").duplicate(true)
			var mount:Dictionary=record.mount
			mount.position=panel.transform*mount.position;mount.normal=panel.transform.basis*mount.normal
			mount.source_face_plane=mount.normal.dot(mount.position-mount.normal*float(mount.support_offset))
			mount["rigid_own_bank_id"]=9;mount["rigid_panel_transform"]=panel.transform
			records.append(record);attached=true;break
		if not attached:push_error("Production exterior has no complete approved own106 host panel")
	for record:Dictionary in records:
		var mount:Dictionary=record.mount.duplicate(true)
		var along:=Vector3(mount.normal.z,0,-mount.normal.x)
		var transform:=Transform3D(Basis(along,Vector3.UP,mount.normal)*Basis.from_scale(Vector3.ONE*float(mount.scale)),mount.position)
		if not _reference_layout:
			mount.installation["transform"]=transform
			mount.installation["method"]="Approved rigid host/carrier certificate plus current disjoint placement envelopes"
			mount["visibility"]={"ok":true,"camera_view_certified":false,"scope":"Physical module placement only; real production Camera readability reviewed separately"}
			if int(mount.host_id)<0:
				var bounds:AABB=transform*BR_BANK.get_item_mesh(int(record.poster)).get_aabb()
				var plot:=Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))
				for other:Rect2 in _reserved_plots:assert(not plot.grow(.02).intersects(other))
		mount["_frozen_installation_verified"]=true
		mount["verification_scope"]="Exact approved rigid source+carrier module; placement envelopes checked against current floor and neighbours"
		_br_poster(int(record.poster),mount,record.owner,record.kind)
		var slot:int={100:0,102:1,104:2,106:3}.get(int(record.poster),-1)
		if slot>=0:_air_anchors[slot]=Vector2(mount.position.x,mount.position.z)
	_br_aviation_markers()
	city_coverage["advert_cache"]={"ok":records.size()==6,"records":records.size(),"mode":"portable_reference" if _reference_layout else "certified_rigid_modules","runtime_search":false,"runtime_triangle_validation":false,"authored_records_exact":_reference_layout,"records_sha256":_br_digest_bytes(var_to_bytes(br_frozen_ad_records)),"binding":_br_cache_binding()}
	city_coverage["advert_authoring"]={"runtime_search":false,"source":"FD99 rigid certificates and conservative current-floor envelopes"}
	city_coverage.production_city["air_anchors"]=_air_anchors.duplicate()
	if records.size()!=6:push_error("Production city requires all six original advertisements")

func _sync_render_snapshot()->void:
	super._sync_render_snapshot()
	if _air_anchors.size()!=4:return
	for material:ShaderMaterial in render_materials:
		if material.get_meta(&"production_air_layout","")==_layout_key:continue
		for i:int in 4:material.set_shader_parameter("city_air_ad_anchor"+str(i),_air_anchors[i])
		material.set_meta(&"production_air_layout",_layout_key)
	_update_camera_cutaway()

func _br_poster(poster:int,mount:Dictionary,owner:String,kind:String)->void:
	_current_ad_host=int(mount.host_id)
	super._br_poster(poster,mount,owner,kind)
	_current_ad_host=-1

func _br_mesh_instance(id:int,mesh:ArrayMesh,transform:Transform3D,slot:int,roof:float)->void:
	# The existing hidden_tower_tag must also remove the attached sign, not leave it floating.
	var owner_slot:int=_current_ad_host if id>=100 and _current_ad_host>=0 else slot
	super._br_mesh_instance(id,mesh,transform,owner_slot,roof)

func _br_add_ad_glow(poster:int,center:Vector3,along:Vector3,normal:Vector3,aperture_size:Vector2)->void:
	var key:String="%d_%d"%[poster,_current_ad_host]
	if not br_ad_glow_batches.has(key):
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		br_ad_glow_batches[key]={"tool":tool,"poster":poster,"host":_current_ad_host}
	var st:SurfaceTool=br_ad_glow_batches[key].tool
	var size:Vector2=aperture_size+Vector2(1.2,1.2);var ratio:Vector2=aperture_size/size
	var intensity:float=.20 if poster>=106 else .14
	for uv:Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2.DOWN]:
		var offset:Vector2=(uv-Vector2(.5,.5))*size
		st.set_uv(uv);st.set_uv2(ratio);st.set_normal(normal);st.set_color(Color(1,1,1,intensity))
		st.add_vertex(center+normal*.025+along*offset.x+Vector3.UP*offset.y)

func _br_commit_ad_glows()->void:
	var shader:=Shader.new();shader.code=BR_AD_GLOW_SHADER
	for key:String in br_ad_glow_batches:
		var batch:Dictionary=br_ad_glow_batches[key];var poster:int=int(batch.poster)
		var mat:=ShaderMaterial.new();mat.shader=shader
		var original:StandardMaterial3D=BR_BANK.get_item_mesh(poster).surface_get_material(1)
		mat.set_shader_parameter("emission_texture",original.emission_texture)
		mat.set_shader_parameter("emission_gain",BR_EMITTER_GAINS[poster]);mat.set_shader_parameter("emission_tint",BR_EMITTER_TINTS[poster])
		mat.set_shader_parameter("city_void",ImageTexture.create_from_image(topology.image))
		mat.set_shader_parameter("city_origin",Vector2(topology.bounds.position));mat.set_shader_parameter("city_grid_size",Vector2(topology.bounds.size))
		render_materials.append(mat)
		var node:MeshInstance3D=_add_city_carrier(batch.tool.commit(),mat,"OriginalAdvertGlow_"+key)
		_ad_glow_nodes.append({"node":node,"host":batch.host})
	city_coverage["advert_glow"]={"batches":br_ad_glow_batches.size(),"method":"Same calibrated9tap glow, grouped by physical host for camera-cut restoration","new_lights":0,"new_render_passes":0}

func _update_camera_cutaway()->void:
	if not is_instance_valid(scene_root) or not is_instance_valid(world.camera_3d):return
	if production_mode and get_parent().get_parent()!=world.office_art_root:return
	var eye:Vector3=scene_root.to_local(world.camera_3d.get_camera_transform().origin)
	var key:=Vector2i(floori(eye.x/20.0),floori(eye.z/20.0));var hidden:=-1
	for index:int in _plot_grid.get(key,[]):
		var plan:Dictionary=br_plans[index]
		if eye.y<STREET_LEVEL or eye.y>float(plan.top)+.2:continue
		if (plan.footprint as Rect2).grow(.15).has_point(Vector2(eye.x,eye.z)):hidden=int(plan.plan_id);break
	if hidden==_hidden_camera_host:return
	var tag:float=float(posmod(hidden*1103+1901,65521))/65521.0 if hidden>=0 else -1.0
	for material:ShaderMaterial in render_materials:
		if material.shader==CITY_SHADER:material.set_shader_parameter("hidden_tower_tag",tag)
	for glow:Dictionary in _ad_glow_nodes:
		if is_instance_valid(glow.node):glow.node.visible=hidden<0 or int(glow.host)!=hidden
	_hidden_camera_host=hidden
	if not city_coverage.has("camera_clipping"):city_coverage["camera_clipping"]={"events":[],"method":"Existing per-tower shader tag plus existing RoomVisibility floor/ray retention; attached sign/glow follows host"}
	var events:Array=city_coverage.camera_clipping.events
	events.append({"frame":Engine.get_process_frames(),"host":hidden,"eye_map":eye,"restored":hidden<0})
	if events.size()>32:events.pop_front()

func _advert_projection(mount:Dictionary,poster:int,viewer:Vector3)->Dictionary:
	var camera_basis:Basis=world.camera_3d.get_camera_transform().basis.inverse()*scene_root.global_basis
	var extent:AABB=BR_BANK.get_item_mesh(poster).get_aabb()
	var along:=Vector3(mount.normal.z,0,-mount.normal.x)
	var low:=Vector2.INF;var high:=-Vector2.INF
	var focal:float=180.0/tan(deg_to_rad(world.camera_3d.fov*.5))
	for x:float in [-.5,.5]:
		for y:float in [-.5,.5]:
			var point:Vector3=mount.position+along*(extent.size.x*float(mount.scale)*x)+Vector3.UP*(extent.size.y*float(mount.scale)*y)
			var view:Vector3=camera_basis*(point-viewer)
			if view.z>=-.1:return {"score":0.0}
			var pixel:=Vector2(320.0+view.x*focal/(-view.z),180.0-view.y*focal/(-view.z))
			low=low.min(pixel);high=high.max(pixel)
	var rectangle:=Rect2(low,high-low)
	var visible:Rect2=rectangle.intersection(Rect2(8,8,624,344))
	var fraction:float=visible.get_area()/maxf(rectangle.get_area(),.001)
	if fraction<.85 or minf(rectangle.size.x,rectangle.size.y)<10:return {"score":0.0}
	return {"score":visible.get_area()*fraction,"rectangle":rectangle,"frame_fraction":fraction,"normal_faces_viewer":true}
