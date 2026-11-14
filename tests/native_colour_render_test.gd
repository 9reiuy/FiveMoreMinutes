extends SceneTree
## GPU evidence that ordinary RGB passes unchanged through the shared display.
var out := "res://.runtime/tutorial_rebuild_20261107/native_rgb_gpu"
var checks: Array[Dictionary]=[]
func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):out=argument.trim_prefix("--artifact-dir=")
	call_deferred("_run")
func check(value: bool, title: String) -> void:
	checks.append({"pass":value,"description":title});print("PASS: " if value else "FAIL: ",title)
func snapshot(view: Viewport) -> Image:
	for frame in 6:await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func dark_stats(image: Image) -> Dictionary:
	var nonblack:=0;var maximum:=0.0
	for y in image.get_height():
		for x in image.get_width():
			var pixel:=image.get_pixel(x,y)
			var value:=maxf(pixel.r,maxf(pixel.g,pixel.b))
			maximum=maxf(maximum,value)
			if value>0.0:nonblack+=1
	return {"nonblack_pixels":nonblack,"max_channel":maximum}
func _run() -> void:
	await process_frame
	var master := AudioServer.get_bus_index(&"Master")
	if master<0 or not AudioServer.is_bus_mute(master):
		if master>=0:AudioServer.set_bus_mute(master,true)
		quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var view := SubViewport.new();view.size=Vector2i(512,64);view.world_2d=World2D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var gradient := ColorRect.new();gradient.size=Vector2(view.size)
	var source := ShaderMaterial.new();var shader := Shader.new()
	shader.code="shader_type canvas_item; render_mode unshaded; void fragment(){COLOR=vec4(UV.x,0.23+UV.y*0.42,0.41,1.0);}"
	source.shader=shader;gradient.material=source;view.add_child(gradient)
	var fire := ColorRect.new();fire.position=Vector2(0,48);fire.size=Vector2(32,16);fire.color=Color(1,0,.2);view.add_child(fire)
	var green := ColorRect.new();green.position=Vector2(32,48);green.size=Vector2(32,16);green.color=Color.GREEN;view.add_child(green)
	var before: Image=await snapshot(view);before.save_png(out.path_join("rgb_before.png"))
	var layer := CanvasLayer.new();layer.layer=18;view.add_child(layer)
	var resolve := ColorRect.new();resolve.size=Vector2(view.size);layer.add_child(resolve)
	var material := ShaderMaterial.new();material.shader=load("res://shaders/world_semantic_decode.gdshader");resolve.material=material
	var after: Image=await snapshot(view);after.save_png(out.path_join("rgb_after.png"))
	var max_error := 0.0;var colours := {}
	for y in 48:
		for x in 512:
			var a := before.get_pixel(x,y);var b := after.get_pixel(x,y)
			max_error=maxf(max_error,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
			colours[b.to_rgba32()]=true
	check(max_error<=2.0/255.0,"Ordinary RGB is unchanged by the shared colour resolver")
	check(colours.size()>128,"Rendered colours are not reduced to a fixed palette")
	check(after.get_pixel(48,56).is_equal_approx(before.get_pixel(48,56)),"Ordinary green RGB no longer uses the tutorial indicator remap")
	var flame := after.get_pixel(16,56)
	check(flame.r>.98 and absf(flame.g-.960784)<.02 and absf(flame.b-.698039)<.02,"Reserved combat fire code still resolves to its authored warm colour")
	view.queue_free()
	for frame in 4:await process_frame
	var display: Node=load("res://scenes/testing/TutorialMaintenanceDisplay.tscn").instantiate();root.add_child(display);current_scene=display
	for frame in 20:await process_frame
	var world: Node3D=display.world
	var training: Node=world.get_node("ChapterTraining")
	training.set_process(false);training.set_physics_process(false);world.player.set_physics_process(false);world.player.set_process(false)
	var camera_feed_checks: Array=[]
	for photo in [["registration",Vector2(3.625,20.5),0],["dash_room",Vector2(4,13.4),1],["range",Vector2(4.8,6.5),2],["gallery",Vector2(11,11),2]]:
		for zone in 3:
			world.set_training_zone_enabled(zone,zone<=int(photo[2]))
			world.monitor_feed.stations[zone].set_power_available(zone<=int(photo[2]))
		world.set_dash_strip_complete(int(photo[2])>=2)
		world.player.global_position=Vector2(photo[1])*32.0
		for frame in 25:await process_frame
		var actual: Image=await snapshot(root);actual.save_png(out.path_join(String(photo[0])+".png"))
		if world.monitor_feed.active_room>=0:
			world.set_process(false)
			var game_view: Image=await snapshot(display.world_viewport)
			for frame in 3:await process_frame
			var monitor_view: Image=world.monitor_feed.frame_cache.output.get_image()
			game_view.save_png(out.path_join(String(photo[0])+"_game_camera.png"))
			monitor_view.save_png(out.path_join(String(photo[0])+"_tv_feed.png"))
			var matching := 0
			for y in game_view.get_height():
				for x in game_view.get_width():
					var a:=game_view.get_pixel(x,y);var b:=monitor_view.get_pixel(x,y)
					if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()<.035:matching+=1
			var fraction:=float(matching)/float(game_view.get_width()*game_view.get_height())
			camera_feed_checks.append({"view":photo[0],"matching_fraction":fraction,"active_room":world.monitor_feed.active_room})
			check(fraction>.98,"Room "+str(world.monitor_feed.active_room+1)+" live television feed copies the current game Camera output")
			world.set_process(true)
	var light_checks: Array=[]
	var gate: Node3D=training._gate("EntryToDash")
	gate.set_indicator_power_enabled(true)
	world.player.global_position=Vector2(gate.global_position.x+1.0,gate.global_position.z+1.0)*32.0
	for frame in 25:await process_frame
	world.set_process(false)
	world.get_node("TutorialGeometry/ChapterLayout/Preparation/TelevisionDesk").set_process(false)
	world.player_depth_bridge.set_process(false)
	var actor_sprite: Sprite3D=world.player_depth_bridge.actor_sprite
	var actor_layers := actor_sprite.layers
	for open in [false,true]:
		gate.set_open(open)
		await create_timer(.4,true,false,true).timeout
		var state := "green" if open else "red"
		gate.status_light.visible=false
		var dark: Image=await snapshot(display.world_viewport)
		actor_sprite.layers=0
		var dark_background: Image=await snapshot(display.world_viewport)
		actor_sprite.layers=actor_layers
		gate.status_light.visible=true
		var lit: Image=await snapshot(display.world_viewport)
		actor_sprite.layers=0
		var lit_background: Image=await snapshot(display.world_viewport)
		actor_sprite.layers=actor_layers
		dark.save_png(out.path_join(state+"_light_off.png"));lit.save_png(out.path_join(state+"_light_on.png"))
		dark_background.save_png(out.path_join(state+"_background_off.png"));lit_background.save_png(out.path_join(state+"_background_on.png"))
		# Same emissive mesh, camera and geometry in each pair: only Light3D changes.
		var changed := 0;var max_tint_delta := 0.0;var actor_changed := 0;var actor_pixels := 0
		for y in lit.get_height():
			for x in lit.get_width():
				var a := dark.get_pixel(x,y);var b := lit.get_pixel(x,y)
				var delta := (b.g-a.g)-maxf(b.r-a.r,b.b-a.b) if open else (b.r-a.r)-maxf(b.g-a.g,b.b-a.b)
				if delta>.035:changed+=1
				max_tint_delta=maxf(max_tint_delta,delta)
				var a_back := dark_background.get_pixel(x,y);var b_back := lit_background.get_pixel(x,y)
				if Vector3(a.r-a_back.r,a.g-a_back.g,a.b-a_back.b).length()>.04 or Vector3(b.r-b_back.r,b.g-b_back.g,b.b-b_back.b).length()>.04:
					actor_pixels+=1
					if delta>.035:actor_changed+=1
		light_checks.append({"state":state,"receiver_pixels":changed,"max_tint_delta":max_tint_delta,"actor_mask_pixels":actor_pixels,"actor_lit_pixels":actor_changed})
		check(changed>100,"Real "+state+" indicator light colours surrounding geometry while the emissive strip stays unchanged")
		check(actor_changed>8,"Actual player interior receives the "+state+" scene light in the game Camera")
	# Turn off the actual room circuits, including emissive strips and televisions.
	for zone in 3:
		world.set_training_zone_enabled(zone,false)
		world.monitor_feed.stations[zone].set_power_available(false)
	for key in ["PreparationDoor","EntryToDash","DashToRange","Exit"]:training._gate(key).set_indicator_power_enabled(false)
	for frame in 30:await process_frame
	var active_lights: Array=[]
	for light in world.find_children("*","Light3D",true,false):
		if light.is_visible_in_tree() and light.light_energy>0.0:active_lights.append(str(light.get_path()))
	check(active_lights.is_empty(),"All tutorial lighting circuits can be fully powered off")
	var blackout: Image=await snapshot(display.world_viewport);blackout.save_png(out.path_join("all_lights_off.png"))
	var unarmed_dark:=dark_stats(blackout)
	check(unarmed_dark.nonblack_pixels==0,"With no light sources the entire game Camera, room and unarmed player are exactly black")
	world.player.equip_weapon("basic",world.config);world.player_depth_bridge.set_process(true)
	for frame in 12:await process_frame
	var armed_blackout: Image=await snapshot(display.world_viewport);armed_blackout.save_png(out.path_join("all_lights_off_armed.png"))
	var armed_dark:=dark_stats(armed_blackout)
	check(armed_dark.nonblack_pixels==0,"Held gun, hands and character outline retain no brightness without light")
	world.set_training_zone_enabled(1,true)
	var restored: Image=await snapshot(display.world_viewport);restored.save_png(out.path_join("cold_lights_restored.png"))
	check(dark_stats(restored).nonblack_pixels>500,"Switching the real cold-light circuit back on reveals the room again")
	var file := FileAccess.open(out.path_join("native-colour.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"checks":checks,"max_channel_error":max_error,"ordinary_colour_count":colours.size(),"indicator_light_pairs":light_checks,"live_camera_feed":camera_feed_checks,"frame_copy":world.monitor_feed.frame_cache.get_stats(),"blackout":{"active_lights":active_lights,"unarmed":unarmed_dark,"armed":armed_dark},"scope":"GPU ordinary RGB, checkpoint Camera art, exact game-viewport television frame copy, indicator-light-only off/on receiver comparisons and all-circuits-off camera readback. Art views hold lesson/player logic with checkpoint-specific indoor power. Full progression is checked separately by the real-input route. No performance benchmark."},"\t"));file.close()
	var failed := checks.filter(func(item):return not item.pass).size()
	current_scene=null;display.queue_free()
	for frame in 8:await process_frame
	quit(1 if failed else 0)
