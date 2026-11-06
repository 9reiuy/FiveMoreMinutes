extends SceneTree
## Formal Main + real elevator; native Camera pixels, not only uniform readback.
var output:="res://.runtime/palette_switch_20261103/main"
var main:Node
var world:Node3D
var checks:=0
var failures:Array[String]=[]
var pixel_results:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func frames(n:int=6)->void:
	for i in n:await process_frame
func capture(label:String)->Image:
	await frames();await RenderingServer.frame_post_draw
	var im:Image=main.current_screen.world_viewport.get_texture().get_image()
	im.save_png(output.path_join(label+".png"));return im
func difference(a:Image,b:Image)->int:
	var different:=0
	for y in a.get_height():
		for x in a.get_width():
			var p:=a.get_pixel(x,y);var q:=b.get_pixel(x,y)
			if maxf(absf(p.r-q.r),maxf(absf(p.g-q.g),absf(p.b-q.b)))>4.01/255.:different+=1
	return different
func switch_check(label:String)->void:
	var settings:=root.get_node("SettingsManager")
	for room in world.rooms:
		if String(room.get("archetype",""))=="open_office":
			world.player.global_position=Vector2(room.center_cell)*32.;world.player.velocity=Vector2.ZERO
			world.activate_room(int(room.id));break
	world._update_camera_and_actor_projection();await frames(20)
	paused=true;Engine.time_scale=0.
	var mat:ShaderMaterial=main.current_screen.palette_material
	check(mat.shader.resource_path=="res://shaders/palette_quantize.gdshader",label+" uses production shader")
	check(bool(mat.get_shader_parameter("smooth_light_ramp")),label+" retains smooth lighting")
	settings.set_setting("palette_scheme",1);var one:=await capture(label+"_1")
	settings.set_setting("palette_scheme",2);var two:=await capture(label+"_2")
	check(int(mat.get_shader_parameter("palette_scheme"))==2,label+" live setting delivered")
	var changed:=difference(one,two)
	check(changed>1000,label+" actual Camera schemes differ, not only uniform")
	settings.set_setting("palette_scheme",1);var again:=await capture(label+"_return1")
	check(one.get_data()==again.get_data(),label+" 1-2-1 exact restoration")
	settings.set_setting("palette_enabled",false);var off:=await capture(label+"_off")
	check(difference(one,off)>1000,label+" off still restores natural colors")
	settings.set_setting("palette_enabled",true);settings.set_setting("palette_scheme",2)
	check(two.get_data()==(await capture(label+"_restore2")).get_data(),label+" off/on restores scheme 2")
	pixel_results.append({"label":label,"pixels_differ_over_four_levels":changed})
	Engine.time_scale=1.;paused=false
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(180,true,false,true).timeout.connect(func():quit(9))
	AudioServer.set_bus_mute(0,true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_size(Vector2i(1280,720));DisplayServer.window_set_position(Vector2i(-30000,-30000))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=120
	var settings:=root.get_node("SettingsManager")
	settings.set_setting("pixelation_enabled",true);settings.set_setting("palette_enabled",true);settings.set_setting("palette_scheme",1)
	node_added.connect(func(n:Node):
		if n.get_script()==preload("res://scripts/dream/office_skeleton_world_base.gd"):
			n.seed=2824175271;n.base_floor_seed=2824175271;n.persist_profile=false)
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);await frames(4)
	main._show_dream("assault_rifle")
	while main.transition_running:await process_frame
	world=main._supported_dream_world
	while not world.player_has_left_elevator_cab:await process_frame
	world.player.current_health=100000.
	await switch_check("first_floor")
	var floor_before:int=world.floor_index
	world.has_floor_badge=true;world.player.global_position=Vector2(world.elevator_anchor_cell)*32.
	world._begin_elevator_entry_transition()
	var began:=Time.get_ticks_usec()
	while (world.floor_index==floor_before or world.floor_transition_in_progress) and Time.get_ticks_usec()-began<30000000:await process_frame
	check(world.floor_index==floor_before+1 and not world.floor_transition_in_progress,"real elevator completes next floor")
	check(int(main.current_screen.palette_material.get_shader_parameter("palette_scheme"))==2,"scheme 2 survives elevator loading")
	await switch_check("next_floor")
	check(world.player.movement_enabled and world.player.attacking_enabled,"normal controls restored after elevator")
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"comparisons":pixel_results,"scope":"Actual Main and elevator visual/settings regression. Not FPS acceptance."},"\t"))
	main.free();await frames(2);print("PALETTE_MAIN checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
