extends SceneTree
var out:String
var main:Node
var room:Node
var metrics:Dictionary={}
var checks:Array[Dictionary]=[]
func check(ok:bool,label:String)->void:
	checks.append({"pass":ok,"description":label});print("PASS " if ok else "FAIL ",label)
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="):out=arg.trim_prefix("--artifact-dir=")
	call_deferred("run")
func frames(n:=6)->void:
	for i in n:await process_frame
func photo(label:String)->Image:
	await frames();await RenderingServer.frame_post_draw
	var im:Image=main.current_screen.world_viewport.get_texture().get_image();im.save_png(out.path_join(label+".png"))
	if label.ends_with("_normal"):root.get_texture().get_image().save_png(out.path_join(label+"_ui.png"))
	return im
func count_marker(im:Image)->Dictionary:
	var count:=0;var bottom:=0;var area:=Rect2i()
	for y in im.get_height():
		for x in im.get_width():
			var c:=im.get_pixel(x,y)
			if c.g>.5 and c.r<.25 and c.b<.31:
				area=area.merge(Rect2i(x,y,1,1)) if count>0 else Rect2i(x,y,1,1);count+=1;bottom=maxi(bottom,y)
	return {"pixels":count,"bottom":bottom,"bounds":str(area)}
func floors(visible:bool)->void:
	room.floor_root.visible=visible
	for name in ["ArrivalRunner","LiftHallCarpet"]:room.props_root.get_node(name).visible=visible
func run()->void:
	await process_frame
	if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2);return
	preload("res://tests/support/background_gpu.gd").start(self)
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);current_scene=main
	await frames(30);main.persistent_day_state=main._create_initial_state();main.persistent_day_state.erase("chapter_one");main._show_reception("basic");await frames()
	while main.transition_running:await process_frame
	room=main._supported_dream_world;room.set_process(false);room.player.set_physics_process(false);room.player.set_process(false)
	var npc=room.waitress_npc;npc.set_process(false)
	var b=room.player_depth_bridge
	var shader:=Shader.new();shader.code="""shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_opaque;
#include "res://shaders/dream3d/character_reference_depth.gdshaderinc"
uniform sampler2D capture_texture:filter_nearest;
void fragment(){vec4 p=texture(capture_texture,UV);ALBEDO=vec3(.01,.6,.025);ALPHA=p.a;ALPHA_SCISSOR_THRESHOLD=.05;vec3 v=reference_view_position(VERTEX,INV_VIEW_MATRIX,VIEW_MATRIX);DEPTH=reference_fragment_depth(v,FRAGCOORD.z,PROJECTION_MATRIX);}
"""
	var original:Material=b.actor_sprite.material_override
	var marker:=ShaderMaterial.new();marker.shader=shader;marker.set_shader_parameter("capture_texture",b.render_viewport.get_texture())
	for pose in [["arrival",Vector2(17.5,19.2)],["stone",Vector2(13,16)],["counter",Vector2(7.2,19.1)],["near_edge",Vector2(17.5,20.2)],["stair_bottom",Vector2(12,12.85)],["stair_middle",Vector2(12,11.7)],["stair_top",Vector2(12,10.55)],["upper",Vector2(12,7)]]:
		room.player.global_position=pose[1]*32.;room.camera_aim_offset=Vector3.ZERO;room._update_camera_and_projection(0);await frames()
		await photo(pose[0]+"_normal")
		b.actor_sprite.material_override=marker
		marker.set_shader_parameter("reference_depth_enabled",true);marker.set_shader_parameter("reference_plane_origin",b.body_reference_origin);marker.set_shader_parameter("reference_plane_normal",b.body_reference_normal)
		var with_floor:Dictionary=count_marker(await photo(pose[0]+"_marker_floor"))
		floors(false);var without_floor:Dictionary=count_marker(await photo(pose[0]+"_marker_no_floor"))
		room.wall_root.hide();room.props_root.hide();room.door_root.hide()
		var without_geometry:Dictionary=count_marker(await photo(pose[0]+"_marker_no_geometry"))
		room.wall_root.show();room.props_root.show();room.door_root.show();floors(true)
		var feet:Dictionary={}
		for name in ["left_leg","right_leg"]:
			var foot:Sprite2D=room.player.get(name);feet[name]={"position":str(foot.position),"global_position":str(foot.global_position),"region":str(foot.texture.region),"visible":foot.visible}
		metrics[pose[0]]={"with_floor":with_floor,"without_floor":without_floor,"without_geometry":without_geometry,"reference_origin":str(b.body_reference_origin),"contact_local":str(b.body_contact_local),"colour_origin":str(b.actor_sprite.global_position),"character_visual":str(room.player.visual.position),"feet":feet}
		b.actor_sprite.material_override=original
	# NPC uses the same floor comparison but remains a peaceful presentation plane.
	var n=npc.get_meta(&"depth_visual_bridge").get_ref();var n_orig:Material=n.actor_sprite.material_override
	room.player.global_position=Vector2(7.2,19.1)*32;room._update_camera_and_projection(0);await frames()
	marker.set_shader_parameter("reference_depth_enabled",false);marker.set_shader_parameter("capture_texture",n.render_viewport.get_texture());n.actor_sprite.material_override=marker
	var n_floor:=count_marker(await photo("npc_marker_floor"));floors(false);var n_no_floor:=count_marker(await photo("npc_marker_no_floor"));floors(true);n.actor_sprite.material_override=n_orig
	metrics.npc={"with_floor":n_floor,"without_floor":n_no_floor,"origin":str(n.actor_sprite.global_position),"contact_local":str(n.body_contact_local)}
	check(RenderingServer.get_current_rendering_method()=="forward_plus" and RenderingServer.get_current_rendering_driver_name()=="vulkan","Actual Main remains Forward+ / Vulkan")
	check(main.current_screen.world_viewport.size==Vector2i(640,360),"Original 640x360 game Camera remains")
	for pose in metrics:
		var m:Dictionary=metrics[pose]
		var complete:Dictionary=m.get("without_geometry",m.without_floor)
		check(complete.pixels>400,"Nonempty actual body mask at "+str(pose))
		check(m.with_floor.pixels>=complete.pixels*.99,"Final geometry retains the complete body at "+str(pose))
		check(m.with_floor.bottom>=complete.bottom-1,"Final foot pixels remain visible at "+str(pose))
	var low_edges:=0;var shadows:=0
	for wall in room.wall_root.get_children():
		if not wall.cutaway_mode:continue
		if absf(wall.wall_mesh.mesh.get_aabb().size.y-.18)<.001:low_edges+=1
		if absf(wall.shadow_mesh.mesh.get_aabb().size.y-5.)<.001:shadows+=1
	check(low_edges>=30 and low_edges==shadows,"Cutaway walls have low visible edges and full-height shadow casters")
	var caps:=0
	for cap in room.reception_desk.get_node("Structure").get_children():
		if not String(cap.name).begins_with("TopCap"):continue
		if absf(cap.position.y+cap.get_aabb().end.y-.78)<.001 and absf(cap.get_aabb().size.y-.16)<.001:caps+=1
	check(caps==4,"All four ring counter caps are 0.78m high and retain 0.16m thickness")
	var lamp:MeshInstance3D=room.props_root.get_node("DeskLampBase")
	check(not room.props_root.has_node("TarotDeskMat") and room.props_root.find_children("OriginalTarotCard*","MeshInstance3D",false,false).is_empty(),"Tabletop tarot cards and their display mat are removed")
	check(absf(lamp.position.y+lamp.get_aabb().position.y-.7925)<.001,"Lamp base follows the lowered counter")
	check(room.floor_cells.size()==383 and room.elevator_doors.size()==6,"Lobby layout and six lifts remain")
	check(absf(room.get_lobby_surface_height(Vector2(17.5,19.2))-.034)<.001 and absf(room.get_lobby_surface_height(Vector2(12,7))-.634)<.001,"Lower and upper carpet thickness enters foot contact")
	check(AudioServer.is_bus_mute(0),"Private validation remains muted")
	var failures=checks.filter(func(c):return not c["pass"])
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"metrics":metrics,"checks":checks,"failures":failures},"\t"))
	print("RECEPTION_GROUND_VISIBILITY checks=",checks.size()," failures=",failures.size())
	main.queue_free();room=null;main=null;b=null;n=null;original=null;n_orig=null;marker=null;await frames(15);preload("res://scripts/audio/sfx_manager.gd").stop_music(0);await frames();quit(0 if failures.is_empty() else 1)
