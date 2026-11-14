extends SceneTree
## Real Main/Camera admission for lobby materials, volume and clean furniture.
const ART=preload("res://scripts/dream/office_room_low_pixel_art.gd")
var out := "user://reception_lobby_camera"
var checks: Array[Dictionary]=[]
var main: Node
var room: Node
var metrics: Dictionary={}
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):out=argument.trim_prefix("--artifact-dir=")
	call_deferred("run")
func frames(count: int=8) -> void:
	for index in count:await process_frame
func check(ok: bool, label: String) -> void:
	checks.append({"pass":ok,"description":label});print("PASS " if ok else "FAIL ",label)
func photograph(label: String) -> Image:
	await frames(8);await RenderingServer.frame_post_draw
	var picture: Image=main.current_screen.world_viewport.get_texture().get_image()
	picture.save_png(out.path_join(label+".png"))
	root.get_texture().get_image().save_png(out.path_join(label+"_ui.png"))
	return picture
func projected_bounds(mesh: MeshInstance3D) -> Rect2i:
	var bounds:=mesh.get_aabb();var rectangle:=Rect2()
	for index in 8:
		var local:=bounds.position+bounds.size*Vector3(index&1,(index>>1)&1,(index>>2)&1)
		var point: Vector2=room.camera_3d.unproject_position(mesh.global_transform*local)
		rectangle=Rect2(point,Vector2.ZERO) if index==0 else rectangle.expand(point)
	return Rect2i(rectangle.grow(1)).intersection(Rect2i(Vector2i.ZERO,main.current_screen.world_viewport.size))
func compare(a: Image,b: Image,area: Rect2i) -> Dictionary:
	var total:=0.0;var changed:=0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var ca:=a.get_pixel(x,y);var cb:=b.get_pixel(x,y)
			var delta:=Vector3(ca.r-cb.r,ca.g-cb.g,ca.b-cb.b).length()
			total+=delta
			if delta>.012:changed+=1
	return {"changed_pixels":changed,"mean_rgb_delta":total/maxi(area.size.x*area.size.y,1),"roi":str(area)}
func run() -> void:
	await process_frame
	if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	preload("res://tests/support/background_gpu.gd").start(self)
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);current_scene=main
	await frames(30);main.persistent_day_state=main._create_initial_state();main.persistent_day_state.erase("chapter_one")
	main._show_reception("basic");await frames(8)
	while main.transition_running:await process_frame
	room=main._supported_dream_world
	check(RenderingServer.get_current_rendering_method()=="forward_plus","Actual reception uses Forward+")
	check(RenderingServer.get_current_rendering_driver_name()=="vulkan","Actual project-selected driver is Vulkan")
	check(main.current_screen.world_viewport.size==Vector2i(640,360),"Reception retains the 640x360 game Camera")
	check(room.floor_cells.size()==383,"Reference atrium replaces the old compact hallway floorplan")
	check(room.elevator_doors.size()==6 and room.door_root.get_child_count()==6,"Actual atrium has three lifts on each inner side wall")
	check(room.reception_desk.get_node("Structure").get_children().filter(func(mesh):return mesh.has_meta(&"ring_counter_segment")).size()==4,"Reception is a four-sided ring with an open staff well")
	check(room.WALL_THICKNESS>=.3,"Stone walls have real structural thickness")
	check(room.floor_root.get_node("LobbyFoundation").get_aabb().size.y>=.27,"Lobby floor has a solid foundation")
	check(room.reception_desk.get_node("Structure/TopCapCounter").get_aabb().size.y>=.10,"Counter has a substantial stone slab")
	var runner: ShaderMaterial=room.props_root.get_node("ArrivalRunner").material_override
	var upper: ShaderMaterial=room.props_root.get_node("LiftHallCarpet").material_override
	check(runner.get_shader_parameter("fabric_colour")==upper.get_shader_parameter("fabric_colour") and not room.props_root.has_node("WaitingRug"),"Marked upper and right regions share burgundy cloth; lower-left carpet is removed")
	var carpets:=0
	for rug in room.props_root.get_children():
		if not rug is MeshInstance3D or not rug.material_override is ShaderMaterial or rug.material_override.shader.resource_path!="res://shaders/dream3d/reception_lobby_carpet.gdshader":continue
		var material: ShaderMaterial=rug.material_override
		var photograph: Texture2D=material.get_shader_parameter("carpet_albedo")
		if material.shader.resource_path.ends_with("reception_lobby_carpet.gdshader") and photograph!=null and photograph.resource_path.ends_with("keith333_red_carpet/RedCarpet_S.jpg") and photograph.get_width()==2048:carpets+=1
	check(carpets==2,"Both continuous marked regions use the complete original photographic carpet map")
	check(room.lobby_art.fixtures.size()==4 and room.lighting_root.has_node("ReferenceCeilingGrid"),"Reference ceiling grid and four integrated soffit lights")
	var shadow_lights:=0
	for name in ["LobbyCeilingWest","LobbyCeilingEast","RearCeilingWest","RearCeilingEast"]:
		var light: SpotLight3D=room.lighting_root.get_node(String(name)+"/SoftCeilingWash")
		if light.shadow_enabled and light.spot_angle<=55:shadow_lights+=1
	check(shadow_lights==4,"All four architectural downlights retain real shadows with bounded cones")
	check(room.lighting_root.get_node("LobbyCeilingWest/SoftCeilingWash").is_visible_in_tree() and room.lighting_root.get_node("LobbyCeilingEast/SoftCeilingWash").is_visible_in_tree(),"Cut-away ceiling keeps its spaced main lighting active")
	check(room.get_node_or_null("OfficeDitherLighting")==null,"Lobby finishes are not replaced by office presentation adapters")
	room.set_process(false);room.player.set_physics_process(false);room.player.set_process(false);room.waitress_npc.set_process(false)
	for pose in [["arrival",Vector2(17.5,19.2)],["counter",Vector2(7.2,19.1)],["elevator",Vector2(7,8.4)],["waiting",Vector2(8,7)]]:
		room.player.global_position=pose[1]*32.0;room.camera_aim_offset=Vector3.ZERO;room._update_camera_and_projection(0.);await frames(18);await photograph(pose[0])
	room.set_process(false)
	# The reference redesign keeps the same production Camera while hints share
	# one dialogue bubble and the requested npc1 atlas.
	check(room.waitress_npc.character_atlas.resource_path.ends_with("enemy/npc1.png"),"Reception uses the requested npc1 character")
	room.player.global_position=Vector2(17,19.1)*32;room._update_camera_and_projection(0)
	room.interaction_resolver.update_target();room.npc_hint_was_near=false;room.npc_hint_cycle_seconds=0
	room._update_interaction_prompt(0);await frames(16);await photograph("npc_idle_emotion")
	check(room.npc_hint_bubble.hint_kind==&"emotion" and not room.npc_hint_bubble.face.draw_frame,"Distant emotion uses the formal dialogue bubble without another frame")
	room._update_interaction_prompt(2.5);await frames(16);await photograph("npc_idle_exchange")
	check(room.npc_hint_bubble.hint_kind==&"word" and room.npc_hint_bubble.hint_text=="交流" and not room.npc_hint_bubble.face.visible,"The same bubble alternates to 交流")
	room.player.global_position=Vector2(7.2,19.1)*32;room._update_camera_and_projection(0)
	room.interaction_resolver.update_target();room._update_interaction_prompt(0)
	await frames(16);await photograph("npc_near_talk")
	check(room.npc_hint_bubble.hint_text=="交谈" and not room.interaction_prompt.visible,"Approaching shows only 交谈 inside the dialogue bubble")
	room.player.global_position=Vector2(3.8,14)*32;room._update_camera_and_projection(0)
	room.interaction_resolver.update_target();room._update_interaction_prompt(0)
	var sofa: MeshInstance3D=room.props_root.get_node("WaitingBench/AuthoredSurfaceMesh")
	var saved: Material=sofa.material_override
	check(saved is ShaderMaterial and saved.shader.resource_path.ends_with("reception_upholstery.gdshader") and saved.get_shader_parameter("atlas")==ART.texture(),"Sofa preserves its authored atlas with lit cloth detail and wear")
	var area:=projected_bounds(sofa)
	var cloth:=saved as ShaderMaterial
	var finished:Image=await photograph("cloth_and_wear")
	cloth.set_shader_parameter("detail_amount",0.);cloth.set_shader_parameter("wear_amount",0.)
	var plain:Image=await photograph("authored_atlas_only")
	cloth.set_shader_parameter("detail_amount",1.);cloth.set_shader_parameter("wear_amount",.85)
	var restored:Image=await photograph("cloth_restored")
	metrics.furniture_detail=compare(finished,plain,area);metrics.native=compare(finished,restored,area)
	check(metrics.furniture_detail.changed_pixels>8,"Actual Camera shows cloth texture and local wear over the original atlas")
	check(metrics.native.changed_pixels<=2 and metrics.native.mean_rgb_delta<.002,"Furniture material restores the same stable picture without retired noise globals")
	# Inspect A2, whose panels stay clear of the near corner pier. A3's
	# grazing view was partly occluded and depended on the desktop mouse aim.
	var inspection_door: Node=room.elevator_doors[1]
	room.player.global_position=inspection_door.get_corridor_approach_position_2d()
	await frames(25)
	room.set_process(false)
	room.camera_aim_offset=Vector3.ZERO;room._update_camera_and_projection(0)
	var lift_door: Node=inspection_door
	# The gameplay heading now views side-wall doors almost edge-on. Check
	# reflection/motor behaviour in a labelled diagnostic pose of this same
	# Main Camera, then restore it; normal framing is covered separately.
	var gameplay_transform:Transform3D=room.camera_3d.global_transform
	room.camera_3d.global_position=lift_door.global_transform*Vector3(1.,2.1,5.2)
	room.camera_3d.look_at(lift_door.global_position+Vector3.UP*1.4,Vector3.UP)
	metrics.lift_camera_scope="Controlled side-facing inspection in Main; not ordinary gameplay framing"
	var lift_area:=projected_bounds(lift_door.left_door_mesh).merge(projected_bounds(lift_door.right_door_mesh))
	var closed: Image=await photograph("lift_closed")
	var game_camera: Camera3D=room.camera_3d
	var lobby_environment: Environment=game_camera.environment if game_camera.environment!=null else game_camera.get_world_3d().environment
	check(lobby_environment.ssr_enabled,"Lobby steel receives the actual room's screen-space reflections")
	var steel: ShaderMaterial=lift_door.left_door_mesh.material_override
	check(steel.get_shader_parameter("steel_metallic")!=null and steel.get_shader_parameter("steel_roughness")!=null and steel.get_shader_parameter("steel_normal")!=null,"Door uses the supplied metalness, roughness and normal material maps")
	# Freeze the real Camera and compare only the steel leaf bounds. The
	# material's source maps and every light stay unchanged in this A/B pair.
	lobby_environment.ssr_enabled=false
	var reflection_off: Image=await photograph("lift_reflection_off")
	lobby_environment.ssr_enabled=true
	var reflection_on: Image=await photograph("lift_reflection_on")
	metrics.steel_reflection=compare(reflection_off,reflection_on,lift_area)
	check(metrics.steel_reflection.changed_pixels>40,"Controlled Main Camera inspection shows real steel reflections")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.path_join("lift_motion")))
	lift_door.open_doors(.75)
	for frame in 50:
		await process_frame
		if frame%3==0:
			await RenderingServer.frame_post_draw
			main.current_screen.world_viewport.get_texture().get_image().save_png(out.path_join("lift_motion/%03d.png"%frame))
	var opened: Image=await photograph("lift_open")
	metrics.lift_camera=compare(closed,opened,lift_area)
	check(lift_door.left_door_mesh.position.x>0 and is_equal_approx(lift_door.left_door_mesh.position.x,lift_door.right_door_mesh.position.x),"Actual Camera shows the two panels collected in the right pocket")
	check(metrics.lift_camera.changed_pixels>80,"Rendered aperture opens in the controlled side-facing inspection")
	await lift_door.close_doors(.2);await photograph("lift_closed_again")
	room.camera_3d.global_transform=gameplay_transform
	check(AudioServer.is_bus_mute(0),"Private test audio remains muted")
	var failures:=checks.filter(func(row):return not row.pass).size()
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"audio":AudioServer.get_driver_name(),"checks":checks,"failures":failures,"noise_comparison":metrics},"\t"))
	Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW);Input.set_custom_mouse_cursor(null,Input.CURSOR_POINTING_HAND)
	main.queue_free();await frames(10);preload("res://scripts/audio/sfx_manager.gd").stop_music(0.0);await frames(3);print("RECEPTION_LOBBY_CAMERA checks=",checks.size()," failures=",failures);quit(1 if failures else 0)
