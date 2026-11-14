extends "res://tests/rendering_backend_unification_camera_test.gd"
## Normal main entry, real elevator and two floors must use clean new materials.
var first_bounce_id:=0
var frame_samples:PackedFloat64Array=[]
var recording_frames:=false
var last_frame_usec:=0

func record_light_frame() -> void:
	var now:=Time.get_ticks_usec()
	if recording_frames and last_frame_usec>0:frame_samples.append(float(now-last_frame_usec)/1000.0)
	last_frame_usec=now if recording_frames else 0

func light_photo(world:Node,name:String) -> Image:
	await frames(5);await RenderingServer.frame_post_draw
	var image:Image=world.camera_3d.get_viewport().get_texture().get_image()
	image.save_png(out.path_join(name+".png"));return image

func light_delta(before:Image,after:Image) -> int:
	var changed:=0
	for y in before.get_height():
		for x in before.get_width():
			var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
			if maxf(b.r-a.r,maxf(b.g-a.g,b.b-a.b))>2.0/255.0:changed+=1
	return changed
func _initialize() -> void:
	out=OS.get_cmdline_user_args()[0];case_name="campaign";call_deferred("run")

func run() -> void:
	root.get_node("SettingsManager").settings_loaded.connect(func():
		if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2))
	await super.run()

func photo(label:String) -> void:
	await super.photo(label)
	if label not in ["office_floor_1","office_floor_2"]:return
	var world:Node=app._supported_dream_world
	var inspected:=0;var clean:=true;var outlines:=0
	for node in world.find_children("*","GeometryInstance3D",true,false):
		var candidates:Array=[]
		if node.material_override!=null:candidates.append(node.material_override)
		if node is MeshInstance3D and node.mesh!=null:
			for surface in node.mesh.get_surface_count():candidates.append(node.get_active_material(surface))
		for material in candidates:
			if not material is ShaderMaterial or material.shader==null:continue
			inspected+=1
			for field in material.shader.get_shader_uniform_list():
				if String(field.name).begins_with("edge_dither_"):clean=false
			for removed in ["light_boundary_dither.gdshaderinc","edge_light_attenuation","comparison_hatch"]:
				if material.shader.code.contains(removed):clean=false
	for bridge in world.actor_depth_bridges_root.get_children():
		if not bridge is Furniture3DVisual:continue
		for mesh in bridge.find_children("*","MeshInstance3D",true,false):
			var overlay:Material=mesh.material_overlay
			if overlay is ShaderMaterial and overlay.shader!=null and overlay.shader.resource_path.ends_with("furniture_pixel_outline.gdshader"):outlines+=1
	check(inspected>100 and clean,label+" actual generated materials have no boundary dither or hatch code")
	check(outlines==0,label+" actual furniture has no black outline overlay")
	var bounce:Node=world.ceiling_light_root.get_node_or_null("FurnitureBounceNightLighting")
	if not check(bounce!=null and bounce.records.size()>0,label+" owns the formal room-side lighting repair"):return
	if first_bounce_id==0:first_bounce_id=bounce.get_instance_id()
	else:check(first_bounce_id!=bounce.get_instance_id(),"Next floor builds its own bounce component instead of retaining old lights")
	paused=true
	bounce.set_enabled(false);var before:=await light_photo(world,label+"_side_before")
	bounce.set_enabled(true);var after:=await light_photo(world,label+"_side_after")
	var gains:=light_delta(before,after)
	check(gains>100,label+" actual Camera restores furniture side light")
	check(bounce.records.all(func(r:Dictionary)->bool:return r.light.light_cull_mask==(bounce.RECEIVER|bounce.ARCHITECTURE|bounce.ROOF) and r.light.shadow_enabled),label+" indirect lights retain room-shell shadows and restricted receivers")
	photos.append({"label":label+"_side_repair","positive_pixels":gains,"sources":bounce.records.size(),"receivers":bounce.receivers.size()})
	var cabinets:Array=get_nodes_in_group("floor_power_switches").filter(func(n:Node)->bool:return world.is_ancestor_of(n) and not n.broken)
	if not cabinets.is_empty():
		var cabinet:Node=cabinets[0];var old_power:bool=cabinet.powered
		cabinet.set_power(false)
		check(bounce.records.all(func(r:Dictionary)->bool:return r.light.light_energy==0.0),label+" floor power immediately disables new lights through the ceiling circuit")
		bounce.sync();await light_photo(world,label+"_power_off")
		cabinet.set_power(old_power);bounce.sync()
		check(bounce.records.any(func(r:Dictionary)->bool:return r.light.is_visible_in_tree() and r.light.light_energy>0.0),label+" power restoration restores indirect light")
	var bridge:Node=null
	for candidate in world.actor_depth_bridges_root.get_children():
		if candidate is Furniture3DVisual and is_instance_valid(candidate.source_actor):bridge=candidate;break
	if bridge!=null:
		var original:Vector2=bridge.source_actor.global_position
		var original_visual:Vector3=bridge.global_position
		bridge.source_actor.global_position+=Vector2(8,0);bridge._sync_transform()
		var moved:Vector3=bridge.global_position
		var extra:=MeshInstance3D.new();extra.mesh=BoxMesh.new();bridge.visual_instance.add_child(extra)
		await frames(3)
		check(moved.distance_to(original_visual)>.1,label+" moved furniture keeps a live visual bridge")
		check(bool(extra.layers&bounce.RECEIVER),label+" late furniture mesh receives indirect light")
		extra.free();bridge.source_actor.global_position=original;bridge._sync_transform()
	if label=="office_floor_1":
		var fps_before:=Engine.max_fps;Engine.max_fps=0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		process_frame.connect(record_light_frame);var trials:Array=[]
		for enabled:bool in [false,true,false]:
			bounce.set_enabled(enabled);await frames(45);frame_samples.clear();last_frame_usec=0;recording_frames=true
			await create_timer(1.5,true,false,true).timeout
			recording_frames=false;last_frame_usec=0
			trials.append({"enabled":enabled,"stats":preload("res://scripts/testing/lab_recorder.gd").stats(Array(frame_samples)),"raw_ms":Array(frame_samples)})
		process_frame.disconnect(record_light_frame);Engine.max_fps=fps_before
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED);bounce.set_enabled(true)
		FileAccess.open(out.path_join("lighting_trials.json"),FileAccess.WRITE).store_string(JSON.stringify(trials))
	paused=false
