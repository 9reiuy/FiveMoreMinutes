extends SceneTree
## Furniture detail/wear in the real Main Camera, with original geometry and light.
const FINISH=preload("res://scripts/dream/reception_furniture_materials.gd")
var out:="user://reception_furniture_age"
var main:Node
var room:Node
var checks:Array[Dictionary]=[]
var metrics:Dictionary={}
var ages:Dictionary={}
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="):out=arg.trim_prefix("--artifact-dir=")
	call_deferred("run")
func frames(n:=10)->void:
	for i in n:await process_frame
func check(ok:bool,label:String)->void:
	checks.append({"pass":ok,"description":label});print("PASS " if ok else "FAIL ",label)
func photo(label:String)->Image:
	await frames();await RenderingServer.frame_post_draw
	var image:Image=main.current_screen.world_viewport.get_texture().get_image()
	image.save_png(out.path_join(label+".png"));root.get_texture().get_image().save_png(out.path_join(label+"_ui.png"))
	return image
func bounds(mesh:MeshInstance3D)->Rect2i:
	var rect:=Rect2();var box:=mesh.get_aabb()
	for i in 8:
		var p:Vector2=room.camera_3d.unproject_position(mesh.global_transform*box.get_endpoint(i))
		rect=Rect2(p,Vector2.ZERO) if i==0 else rect.expand(p)
	return Rect2i(rect.grow(1)).intersection(Rect2i(0,0,640,360))
func difference(a:Image,b:Image,area:Rect2i)->Dictionary:
	var changed:=0;var total:=0.;var peak:=0.
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var ca:=a.get_pixel(x,y);var cb:=b.get_pixel(x,y)
			var delta:=Vector3(ca.r-cb.r,ca.g-cb.g,ca.b-cb.b).length()
			total+=delta;peak=maxf(peak,delta)
			if delta>.008:changed+=1
	return {"changed_pixels":changed,"mean_delta":total/maxi(area.size.x*area.size.y,1),"peak_delta":peak,"roi":str(area)}
func layers(enabled:bool)->void:
	var cloth:=FINISH.upholstery()
	cloth.set_shader_parameter("detail_amount",1. if enabled else 0.)
	cloth.set_shader_parameter("wear_amount",.85 if enabled else 0.)
	for material in ages:material.set_shader_parameter("furniture_age",ages[material] if enabled else 0.)
func move_camera(point:Vector2)->void:
	room.player.global_position=point*32.;room.camera_aim_offset=Vector3.ZERO;room._update_camera_and_projection(0.)
	room.interaction_resolver.update_target();room._update_interaction_prompt(0.)
func run()->void:
	await process_frame
	if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2);return
	DirAccess.make_dir_recursive_absolute(out);preload("res://tests/support/background_gpu.gd").start(self)
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);current_scene=main
	await frames(30);main.persistent_day_state=main._create_initial_state();main.persistent_day_state.erase("chapter_one");main._show_reception("basic");await frames()
	while main.transition_running:await process_frame
	room=main._supported_dream_world;room.set_process(false);room.player.set_physics_process(false);room.player.set_process(false);room.waitress_npc.set_process(false)
	check(RenderingServer.get_current_rendering_method()=="forward_plus" and RenderingServer.get_current_rendering_driver_name()=="vulkan","Actual Main uses Forward+ / Vulkan")
	check(main.current_screen.world_viewport.size==Vector2i(640,360),"640x360 gameplay resolution is preserved")
	var cloth:=FINISH.upholstery()
	check(cloth.get_shader_parameter("atlas")==FINISH.BASE.ART.texture() and cloth.get_shader_parameter("upholstery_tint")==Color("666e69"),"Sofas retain the authored atlas and established grey-green tint")
	for parameter in ["fabric_albedo","fabric_normal","fabric_roughness"]:
		var texture:Texture2D=cloth.get_shader_parameter(parameter)
		check(texture.get_image().has_mipmaps(),parameter+" has prefiltered levels for camera movement")
	for channel in ["Color","NormalGL","Roughness","Metalness"]:
		var texture:=FINISH.metal_map(channel)
		check(texture.get_image().has_mipmaps() and not texture.resource_path.is_empty(),channel+" metal map is an imported exportable resource with prefiltered levels")
	check(FINISH.material("table_wood").get_shader_parameter("finish_albedo")==FINISH.BASE.WALNUT_ALBEDO,"Tables retain the original walnut photograph")
	for profile in ["table_wood","table_frame","counter_wood","counter_top","gate_steel","gate_kick","gate_reader"]:
		var material:=FINISH.material(profile);ages[material]=material.get_shader_parameter("furniture_age")
	var original:Node3D=FINISH.BASE.ART.make_visual("sofa")
	var original_mesh:Mesh=original.get_node("AuthoredSurfaceMesh").mesh;original.free()
	for name in ["WaitingBench","EastWaitingBench"]:
		var sofa:MeshInstance3D=room.props_root.get_node(name+"/AuthoredSurfaceMesh")
		check(sofa.mesh==original_mesh and sofa.material_override==cloth,name+" retains its complete original mesh and UVs")
	for entry in [["west",Vector2(3.8,14.),"WaitingBench","WaitingTable"],["east",Vector2(19.6,14.),"EastWaitingBench","EastWaitingTable"]]:
		move_camera(entry[1]);await frames()
		var sofa:MeshInstance3D=room.props_root.get_node(entry[2]+"/AuthoredSurfaceMesh")
		var table:MeshInstance3D=room.props_root.get_node(entry[3]+"/StoneTableCap")
		var sofa_roi:=bounds(sofa);var table_roi:=bounds(table)
		layers(true);var active:Image=await photo(entry[0]+"_aged")
		layers(false);var plain:Image=await photo(entry[0]+"_layers_off")
		layers(true);var restored:Image=await photo(entry[0]+"_restored")
		var sofa_change:=difference(active,plain,sofa_roi);var table_change:=difference(active,plain,table_roi)
		var restore:=difference(active,restored,sofa_roi.merge(table_roi))
		metrics[entry[0]]={"sofa":sofa_change,"table":table_change,"restore":restore}
		check(sofa_change.changed_pixels>=40,entry[0]+" sofa detail and wear are visible in the game Camera")
		check(table_change.changed_pixels>=5,entry[0]+" table finish wear is visible in the game Camera")
		check(restore.peak_delta<.005,entry[0]+" furniture returns to identical stable pixels")
		cloth.set_shader_parameter("wear_amount",0.);var no_wear:Image=await photo(entry[0]+"_cloth_without_wear")
		var pressure:=difference(active,no_wear,sofa_roi);metrics[entry[0]].seat_wear=pressure
		check(pressure.changed_pixels>=20,entry[0]+" worn cushions are distinct from plain fabric")
		layers(true)
	# The gates keep their geometry, green indicators and retracted glass.
	move_camera(Vector2(12,8));await frames()
	var gate_meshes:Dictionary={};var gate_areas:Array[Rect2i]=[]
	var old_steel:=FINISH.BASE.metal(Color("aab4b3"),.3);old_steel.metallic=.72
	var old_dark:=FINISH.BASE.metal(Color("252a2d"),.70)
	for index in 4:
		var gate:Node=room.props_root.get_node("AccessGate%d"%index)
		gate_areas.append(bounds(gate.get_node("BrushedGateBody")))
		var ready:StandardMaterial3D=gate.get_node("ReadyStrip").material_override
		var glass:StandardMaterial3D=gate.get_node("RetractedGlassWing").material_override
		check(ready.emission_enabled and glass.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"Gate %d retains its green emitter and transparent retracted wing"%index)
		for part in ["BrushedGateBody","GatePlinth","DarkReader"]:
			var mesh:MeshInstance3D=gate.get_node(part);gate_meshes[mesh]=mesh.material_override
	var gates_aged:Image=await photo("gates_aged")
	for mesh in gate_meshes:mesh.material_override=old_steel if mesh.name==&"BrushedGateBody" else old_dark
	var gates_original:Image=await photo("gates_plain_original")
	for mesh in gate_meshes:mesh.material_override=gate_meshes[mesh]
	var gates_restored:Image=await photo("gates_restored")
	metrics.gates=[]
	for index in 4:
		var change:=difference(gates_aged,gates_original,gate_areas[index]);var restore:=difference(gates_aged,gates_restored,gate_areas[index])
		metrics.gates.append({"change":change,"restore":restore})
		check(change.changed_pixels>=12,"Gate %d shows its brushed metal and wear in the game Camera"%index)
		check(restore.peak_delta<.005,"Gate %d restores the same stable pixels"%index)
	gate_meshes.clear()
	move_camera(Vector2(3.8,14));await frames()
	var sofa:MeshInstance3D=room.props_root.get_node("WaitingBench/AuthoredSurfaceMesh")
	var roi:=bounds(sofa);var lit:Image=await photo("lit_furniture")
	var wash:OmniLight3D=room.lighting_root.get_node("LoungeWallWash/WallAndSeatWash")
	var energy:=wash.light_energy;wash.light_energy=0.
	var wash_off:Image=await photo("wall_light_off");wash.light_energy=energy
	metrics.real_light=difference(lit,wash_off,roi)
	check(metrics.real_light.changed_pixels>=30,"Cloth still receives the real local wall light")
	var lights:Dictionary={}
	for light in room.find_children("*","Light3D",true,false):lights[light]=light.light_energy;light.light_energy=0.
	var dark:Image=await photo("all_lights_off");var total:=0.
	for y in range(roi.position.y,roi.end.y):
		for x in range(roi.position.x,roi.end.x):
			var c:=dark.get_pixel(x,y);total+=maxf(c.r,maxf(c.g,c.b))
	metrics.dark_sofa_mean=total/(roi.size.x*roi.size.y)
	check(metrics.dark_sofa_mean<.015,"Upholstery stays dark without lights")
	for light in lights:light.light_energy=lights[light]
	var old_room:WeakRef=weakref(room)
	main._show_reception("basic");await frames()
	while main.transition_running:await process_frame
	room=main._supported_dream_world
	check(old_room.get_ref()==null and room.props_root.get_node("WaitingBench/AuthoredSurfaceMesh").material_override==FINISH.upholstery(),"Room reload frees old fixtures and reuses healthy furniture materials")
	check(room.elevator_doors.size()==6 and room.floor_cells.size()==383,"Reload retains six elevators and the approved layout")
	check(AudioServer.is_bus_mute(0),"Private validation stays muted after reload")
	var failures=checks.filter(func(c):return not c["pass"])
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	print("RECEPTION_FURNITURE_AGE checks=",checks.size()," failures=",failures.size())
	ages.clear();lights.clear();main.queue_free();main=null;room=null;await frames(16)
	preload("res://scripts/audio/sfx_manager.gd").stop_music(0.);await frames();quit(0 if failures.is_empty() else 1)
