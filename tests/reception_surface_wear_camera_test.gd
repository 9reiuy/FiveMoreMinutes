extends SceneTree
## Same Main Camera: original source bindings, reversible wear, contact and darkness.
var out:="user://reception_surface_wear"
var main:Node
var room:Node
var checks:Array[Dictionary]=[]
var metrics:Dictionary={}
var materials:Dictionary={}
const SURFACE="res://shaders/dream3d/reception_lobby_surface.gdshader"
const FURNITURE="res://shaders/dream3d/reception_furniture_pbr.gdshader"
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
	image.save_png(out.path_join(label+".png"))
	root.get_texture().get_image().save_png(out.path_join(label+"_ui.png"))
	return image
func difference(a:Image,b:Image,area:Rect2i)->Dictionary:
	var changed:=0;var total:=0.;var peak:=0.
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var ca:=a.get_pixel(x,y);var cb:=b.get_pixel(x,y)
			var delta:=Vector3(ca.r-cb.r,ca.g-cb.g,ca.b-cb.b).length()
			total+=delta;peak=maxf(peak,delta)
			if delta>.008:changed+=1
	return {"changed_pixels":changed,"mean_delta":total/(area.size.x*area.size.y),"peak_delta":peak,"roi":str(area)}
func wear(enabled:bool)->void:
	for material in materials:material.set_shader_parameter("wear_amount",materials[material] if enabled else 0.)
func run()->void:
	await process_frame
	if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2);return
	DirAccess.make_dir_recursive_absolute(out);preload("res://tests/support/background_gpu.gd").start(self)
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);current_scene=main
	await frames(30);main.persistent_day_state=main._create_initial_state();main.persistent_day_state.erase("chapter_one");main._show_reception("basic");await frames()
	while main.transition_running:await process_frame
	room=main._supported_dream_world;room.set_process(false);room.player.set_physics_process(false);room.player.set_process(false);room.waitress_npc.set_process(false)
	check(RenderingServer.get_current_rendering_method()=="forward_plus" and RenderingServer.get_current_rendering_driver_name()=="vulkan","Actual Main uses Forward+ / Vulkan")
	check(main.current_screen.world_viewport.size==Vector2i(640,360),"Native 640x360 resolution is preserved")
	var art:RefCounted=room.lobby_art
	check(art.floor_material.get_shader_parameter("surface_albedo")==art.STONE_FLOOR_ALBEDO and art.floor_material.get_shader_parameter("tile_metres")==Vector2(4,10),"Original GreyMatteTiles map and physical mapping remain")
	check(art.wall_material.get_shader_parameter("surface_albedo")==art.STONE_WALL_ALBEDO and art.wall_material.get_shader_parameter("tile_metres")==Vector2(2.4,2.4),"Original NaturalStone cladding and mapping remain")
	check(art.wood_material.get_shader_parameter("surface_albedo")==art.WALNUT_ALBEDO,"Original walnut map remains")
	for mesh in room.find_children("*","MeshInstance3D",true,false):
		var material:ShaderMaterial=mesh.material_override as ShaderMaterial
		if material==null or material.shader.resource_path not in [SURFACE,FURNITURE] or materials.has(material):continue
		var amount=material.get_shader_parameter("wear_amount")
		materials[material]=float(amount) if amount!=null else .7 if material.shader.resource_path==SURFACE else .6
	check(materials.size()>=9,"Wear reaches existing architecture and separate furniture finishes")
	var cap:MeshInstance3D=room.reception_desk.get_node("Structure/TopCapCounter")
	check(is_equal_approx(cap.get_aabb().size.y,.16) and is_equal_approx(cap.position.y+cap.get_aabb().end.y,.78),"Chamfered stone cap preserves approved height and thickness")
	check(not room.props_root.has_node("TarotDeskMat") and room.props_root.find_children("OriginalTarotCard*","MeshInstance3D",true,false).is_empty(),"Decorative tarot cards and mat remain removed")
	for entry in [["counter",Vector2(7.2,19.1),Rect2i(180,183,100,24)],["waiting_west",Vector2(2.4,14),Rect2i(265,75,110,25)],["arrival",Vector2(17.5,19.2),Rect2i(75,190,75,20)]]:
		room.player.global_position=entry[1]*32;room.camera_aim_offset=Vector3.ZERO;room._update_camera_and_projection(0)
		await frames()
		wear(true);var active:Image=await photo(entry[0]+"_wear")
		wear(false);var clean:Image=await photo(entry[0]+"_without_wear")
		wear(true);var restored:Image=await photo(entry[0]+"_restored")
		metrics[entry[0]]={"wear":difference(active,clean,entry[2]),"restore":difference(active,restored,entry[2])}
		check(metrics[entry[0]].wear.changed_pixels>=20,entry[0]+" wear visibly changes the intended surface in Main Camera")
		check(metrics[entry[0]].restore.peak_delta<.005,entry[0]+" wear returns to the same stable surface pixels")
	# Freeze only the carrier while checking its small authored contact shadow.
	room.player.global_position=Vector2(7.2,19.1)*32;room._update_camera_and_projection(0);await frames()
	var bridge:Node=room.player_depth_bridge;bridge.set_process(false)
	var contact:MeshInstance3D=bridge.contact_shadow
	var screen:Vector2=room.camera_3d.unproject_position(contact.global_position)
	var contact_roi:=Rect2i(Vector2i(screen.round())-Vector2i(12,8),Vector2i(24,16))
	var contact_on:Image=await photo("contact_on")
	contact.visible=false;var contact_off:Image=await photo("contact_off")
	contact.visible=true;metrics.contact=difference(contact_on,contact_off,contact_roi)
	check(metrics.contact.changed_pixels>=3,"Foot contact produces a small visible grounded shadow")
	check(contact.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and contact.get_aabb().size.x<.5,"Contact uses the existing small shadow art without an extra light")
	bridge.set_process(true)
	var lights:Dictionary={}
	for light in room.find_children("*","Light3D",true,false):lights[light]=light.light_energy;light.light_energy=0.
	var dark:Image=await photo("all_lights_off")
	var dark_peak:=0.
	for y in range(187,207):
		for x in range(180,280):
			var colour:=dark.get_pixel(x,y);dark_peak=maxf(dark_peak,maxf(colour.r,maxf(colour.g,colour.b)))
	metrics.dark_floor_peak=dark_peak
	check(dark_peak<.015,"Surface wear stays dark without lights; no fake emission")
	for light in lights:light.light_energy=lights[light]
	await photo("final_counter")
	check(AudioServer.is_bus_mute(0),"Private validation stays muted")
	var failures=checks.filter(func(c):return not c["pass"])
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	print("RECEPTION_SURFACE_WEAR checks=",checks.size()," failures=",failures.size())
	materials.clear();lights.clear();main.queue_free();main=null;room=null;bridge=null;await frames(16)
	preload("res://scripts/audio/sfx_manager.gd").stop_music(0);await frames();quit(0 if failures.is_empty() else 1)
