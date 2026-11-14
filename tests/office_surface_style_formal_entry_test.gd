extends "res://tests/rendering_backend_unification_camera_test.gd"
## User-approved floor style through the actual Main/elevator/lifecycle paths.
var first_style:WeakRef
var style_measurements:Dictionary={}
var raw:PackedFloat64Array=[]
var recording:=false
var last_usec:=0

func _initialize() -> void:
	out=OS.get_cmdline_user_args()[0];case_name="campaign";call_deferred("run")

func run() -> void:
	root.get_node("SettingsManager").settings_loaded.connect(func():
		if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2))
	await super.run()

func style_photo(world:Node,label:String) -> Image:
	await frames(5);await RenderingServer.frame_post_draw
	var picture:Image=world.camera_3d.get_viewport().get_texture().get_image()
	picture.save_png(out.path_join(label+".png"));return picture

func image_delta(before:Image,after:Image) -> int:
	var changed:=0
	for y in before.get_height():
		for x in before.get_width():
			var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>2.0/255.0:changed+=1
	return changed

func record_frame() -> void:
	var now:=Time.get_ticks_usec()
	if recording and last_usec>0:raw.append(float(now-last_usec)/1000.0)
	last_usec=now if recording else 0

func photo(label:String) -> void:
	await super.photo(label)
	if label in ["reception","chapter_bedroom"]:
		var scene:Node=app._supported_dream_world
		if is_instance_valid(scene):check(scene.find_children("OfficeSurfaceStyle","Node",true,false).is_empty(),label+" retains its independent approved art")
		if label=="chapter_bedroom":
			check(first_style==null or not is_instance_valid(first_style.get_ref()),"Leaving the office retires the previous floor style")
		return
	if label not in ["office_floor_1","office_floor_2"]:return
	var world:Node=app._supported_dream_world
	var style:Node=world.floor_root.get_node_or_null("OfficeSurfaceStyle")
	if not check(style!=null and style.enabled,label+" automatically enables the approved four-effect owner"):return
	if first_style==null:first_style=weakref(style)
	else:
		check(not is_instance_valid(first_style.get_ref()) and first_style.get_ref()!=style,"Next floor retires old resources and creates exactly one fresh style")
		first_style=weakref(style)
	check(world.floor_root.find_children("OfficeSurfaceStyle","Node",true,false).size()==1,label+" owns one style instance")
	world.elevator_floor_door.industrial_facade._process(0.0)
	check(is_finite(world.elevator_floor_door.industrial_facade.opening_fraction),label+" freight doorway reads the decorated mesh dimensions correctly")
	check(style.materials.records.size()>3 and style.composition.statistics.furniture>3 and style.composition.statistics.edge>10,label+" contains material enhancement toon brushed metal and lit rims")
	var clean:=true;var count:=0;var bounds_ok:=true
	var active_materials:Dictionary={};var stale_records:Array=[]
	for mesh in world.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null or mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:continue
		var current:Array=[]
		if mesh.material_override!=null:current.append(mesh.material_override)
		else:
			for surface in mesh.mesh.get_surface_count():current.append(mesh.get_active_material(surface))
		for material in current:
			if not active_materials.has(material):active_materials[material]=[]
			active_materials[material].append(str(mesh.get_path()))
	for record:Dictionary in style.composition.records:
		var material:ShaderMaterial=record.material;var code:String=material.shader.code
		if not active_materials.has(material):continue
		count+=1
		for removed in ["light_boundary_dither.gdshaderinc","edge_light_attenuation","comparison_hatch","edge_style_dark"]:
			if code.contains(removed):clean=false
		if material.get_shader_parameter("stack_toon_enabled")!=true:
			clean=false;stale_records.append({"nodes":active_materials[material],"edge":record.edge,"furniture":record.furniture,"shader":material.shader.resource_path,"code_head":code.left(260)})
		if record.furniture and material.get_shader_parameter("comparison_brush_enabled")!=true:clean=false
		if record.edge and material.get_shader_parameter("edge_style_rim")!=true:clean=false
	FileAccess.open(out.path_join(label+"_material_inventory.json"),FileAccess.WRITE).store_string(JSON.stringify({"active":active_materials.size(),"styled":count,"stale":stale_records}))
	for record:Dictionary in style.materials.bindings.values():
		var mesh:MeshInstance3D=record.mesh.get_ref()
		if is_instance_valid(mesh):bounds_ok=bounds_ok and mesh.get_instance_shader_parameter("material_bounds_size")!=null
	check(count>100 and clean,label+" uses all approved layers without removed hatch dither or dark edges")
	check(bounds_ok,label+" keeps per-mesh material coordinates")
	var hulls:=0
	for bridge in world.actor_depth_bridges_root.get_children():
		if not bridge is Furniture3DVisual:continue
		for mesh in bridge.find_children("*","MeshInstance3D",true,false):
			if mesh.material_overlay is ShaderMaterial and mesh.material_overlay.shader.resource_path.ends_with("furniture_pixel_outline.gdshader"):hulls+=1
	check(hulls==0,label+" does not restore black furniture hulls")
	var actor_shader:Shader=world.player_depth_bridge.actor_sprite.material_override.shader
	check(not actor_shader.code.contains("office_style_"),label+" leaves the player carrier and original outline outside the floor style")
	var old_shine:bool=world.config.world_weapon_shine_enabled
	var shared_config:Resource=preload("res://resources/demo_config.tres")
	var old_shared_shine:bool=shared_config.world_weapon_shine_enabled
	world.config.world_weapon_shine_enabled=false
	shared_config.world_weapon_shine_enabled=false
	check(style.materials.focus("metal"),label+" reaches actual furnished room through production focus coordinates")
	await frames(30);paused=true
	var live_values:Array=[]
	for record:Dictionary in style.materials.records:
		live_values.append({"material":record.material,"cutout":record.material.get_shader_parameter("occlusion_cutout_enabled"),"eye":record.material.get_shader_parameter("sample_primary_eye")})
	style.set_enabled(false);var before:=await style_photo(world,label+"_original")
	style.set_enabled(true);var after:=await style_photo(world,label+"_promoted")
	var changed:=image_delta(before,after)
	check(changed>100,label+" actual Camera visibly shows the promoted combination")
	style.set_enabled(false);var restored:=await style_photo(world,label+"_restored")
	check(before.get_data()==restored.get_data(),label+" disabling restores exact original Camera pixels")
	style.set_enabled(true);var repeated:=await style_photo(world,label+"_repeated")
	check(after.get_data()==repeated.get_data(),label+" repeated activation restores exact promoted Camera pixels")
	check(live_values.all(func(r:Dictionary)->bool:return r.material.get_shader_parameter("occlusion_cutout_enabled")==r.cutout and r.material.get_shader_parameter("sample_primary_eye")==r.eye),label+" style toggles preserve live cutaway and reflection-camera uniforms")
	var cut_checked:=false
	for wall in world.wall_root.get_children():
		if wall.get("office_full_mesh")==null or wall.get("office_cut_mesh")==null:continue
		var old_mode:bool=wall.cutaway_mode;var full:Mesh=wall.office_full_mesh;var refreshes:int=style.refresh_count
		wall.set_cutaway_mode(not old_mode)
		check(style.refresh_count>refreshes and wall.wall_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]!=null,label+" synchronously styles live full/U-cut wall geometry")
		check(wall.office_full_mesh==full and wall.shadow_mesh.mesh==full,label+" retains the original full-height wall shadow source")
		wall.set_cutaway_mode(old_mode);cut_checked=true;break
	check(cut_checked and style.rim.statistics.geometry_parity,label+" preserves original positions UVs triangles and packed-normal tolerance")
	var cabinets:Array=get_nodes_in_group("floor_power_switches").filter(func(n:Node)->bool:return world.is_ancestor_of(n) and not n.broken)
	var bounce:Node=world.ceiling_light_root.get_node_or_null("FurnitureBounceNightLighting")
	if check(not cabinets.is_empty() and bounce!=null,label+" has the production power circuit and side-light component"):
		var cabinet:Node=cabinets[0];var powered:bool=cabinet.powered
		cabinet.set_power(false);bounce.sync()
		check(style.enabled and bounce.records.all(func(r:Dictionary)->bool:return r.light.light_energy==0.0),label+" power-off removes room-side illumination without losing the style")
		await style_photo(world,label+"_power_off")
		cabinet.set_power(powered);bounce.sync()
		check(bounce.records.any(func(r:Dictionary)->bool:return r.light.light_energy>0.0),label+" power restoration restores real room-side illumination")
	style_measurements[label]={"setup_ms":style.setup_ms,"materials":style.materials.records.size(),"rim_meshes":style.rim.mesh_records.size(),"composition":style.composition.statistics.duplicate(),"changed_pixels":changed}
	if label=="office_floor_1":
		var fps_before:=Engine.max_fps;Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		process_frame.connect(record_frame);var trials:Array=[]
		for value:bool in [false,true,false]:
			style.set_enabled(value);await frames(45);raw.clear();last_usec=0;recording=true
			await create_timer(2.0,true,false,true).timeout
			recording=false;last_usec=0
			trials.append({"enabled":value,"stats":preload("res://scripts/testing/lab_recorder.gd").stats(Array(raw)),"raw_ms":Array(raw)})
		process_frame.disconnect(record_frame);Engine.max_fps=fps_before;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED);style.set_enabled(true)
		style_measurements.frozen_trials=trials
	FileAccess.open(out.path_join("style_measurements.json"),FileAccess.WRITE).store_string(JSON.stringify(style_measurements))
	paused=false;world.config.world_weapon_shine_enabled=old_shine;shared_config.world_weapon_shine_enabled=old_shared_shine
