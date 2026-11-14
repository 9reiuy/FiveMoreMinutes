extends SceneTree
## Real Camera regression: stone-cap self-shadow and actual floor cast shadows.
var out:="user://reception_counter_shadow"
var main:Node
var room:Node
var checks:Array[Dictionary]=[]
var metrics:Dictionary={}
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
	var im:Image=main.current_screen.world_viewport.get_texture().get_image();im.save_png(out.path_join(label+".png"))
	if label in ["fixed","legacy_reproduced","restored","arrival","upper_hall"]:root.get_texture().get_image().save_png(out.path_join(label+"_ui.png"))
	return im
func bounds(mesh:MeshInstance3D)->Rect2i:
	var rect:=Rect2();var aabb:=mesh.get_aabb()
	for i in 8:
		var p:Vector2=room.camera_3d.unproject_position(mesh.global_transform*aabb.get_endpoint(i))
		rect=Rect2(p,Vector2.ZERO) if i==0 else rect.expand(p)
	return Rect2i(rect.grow(1)).intersection(Rect2i(0,0,640,360))
func delta(a:Image,b:Image,area:Rect2i,exclude:=Rect2i())->Dictionary:
	var changed:=0;var total:=0.;var pixels:=0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			if exclude.has_point(Vector2i(x,y)):continue
			var ca:=a.get_pixel(x,y);var cb:=b.get_pixel(x,y)
			var d:=Vector3(ca.r-cb.r,ca.g-cb.g,ca.b-cb.b).length();total+=d;pixels+=1
			if d>.025:changed+=1
	return {"changed_pixels":changed,"mean_delta":total/maxi(pixels,1)}
func cap_samples(image:Image)->Array[float]:
	var samples:Array[float]=[]
	var points:Array[Vector3]=[]
	for x in [4.0,4.8,5.6,6.4,8.0,8.8,9.6,10.4]:
		points.append(Vector3(x,.78,17.58));points.append(Vector3(x,.78,14.82))
	for z in [15.5,16.,16.5,17.]:points.append(Vector3(3.9,.78,z));points.append(Vector3(10.5,.78,z))
	for p in points:
		var screen:Vector2=room.camera_3d.unproject_position(p)
		var c:=image.get_pixelv(Vector2i(screen.round()))
		samples.append(c.r*.2126+c.g*.7152+c.b*.0722)
	return samples
func loss(lit:Array[float],control:Array[float])->Dictionary:
	var sum:=0.;var dark:=0
	for i in lit.size():
		var value:=maxf(control[i]-lit[i],0.);sum+=value
		if value>.10:dark+=1
	return {"mean_shadow_loss":sum/lit.size(),"dark_samples":dark}
func run()->void:
	await process_frame
	if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2);return
	DirAccess.make_dir_recursive_absolute(out);preload("res://tests/support/background_gpu.gd").start(self)
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);current_scene=main
	await frames(30);main.persistent_day_state=main._create_initial_state();main.persistent_day_state.erase("chapter_one");main._show_reception("basic");await frames()
	while main.transition_running:await process_frame
	room=main._supported_dream_world;room.set_process(false);room.player.set_physics_process(false);room.player.set_process(false);room.waitress_npc.set_process(false)
	room.player.global_position=Vector2(7.2,19.1)*32;room.camera_aim_offset=Vector3.ZERO;room._update_camera_and_projection(0)
	check(RenderingServer.get_current_rendering_method()=="forward_plus" and RenderingServer.get_current_rendering_driver_name()=="vulkan","Actual Main uses Forward+ / Vulkan")
	check(main.current_screen.world_viewport.size==Vector2i(640,360),"Original native 640x360 Camera")
	var lights:Array[SpotLight3D]=[]
	for name in ["LobbyCeilingWest","LobbyCeilingEast","RearCeilingWest","RearCeilingEast"]:
		var light:SpotLight3D=room.lighting_root.get_node(name+"/SoftCeilingWash");lights.append(light)
		check(light.shadow_enabled and light.shadow_reverse_cull_face and light.shadow_caster_mask==131072 and light.spot_angle==55.,name+" retains furniture shadows with corrected caster faces")
	var fixed:Image=await photo("fixed")
	for light in lights:light.shadow_reverse_cull_face=false;light.shadow_bias=.5;light.shadow_normal_bias=1.2
	var legacy:Image=await photo("legacy_reproduced")
	for light in lights:light.shadow_reverse_cull_face=true;light.shadow_bias=.5;light.shadow_normal_bias=1.2
	var restored:Image=await photo("restored")
	var area:=Rect2i(195,45,250,115)
	metrics.restore=delta(fixed,restored,area)
	check(metrics.restore.changed_pixels<=2,"Same Camera returns to the fixed picture after old settings")
	for light in lights:light.shadow_enabled=false
	var no_shadow:Image=await photo("control_shadows_off")
	for light in lights:light.shadow_enabled=true
	metrics.legacy_cap=loss(cap_samples(legacy),cap_samples(no_shadow))
	metrics.fixed_cap=loss(cap_samples(fixed),cap_samples(no_shadow))
	check(metrics.legacy_cap.dark_samples>=6 and metrics.legacy_cap.mean_shadow_loss>.08,"Actual Camera reproduces the old circular self-shadow")
	check(metrics.fixed_cap.dark_samples<=2 and metrics.fixed_cap.mean_shadow_loss<.025,"Stone caps retain lighting without the circular self-shadow")
	# An independent closed caster must still create a real shadow on the floor.
	var caster:=MeshInstance3D.new();caster.name="ValidationCaster";var box:=BoxMesh.new();box.size=Vector3(.5,1.2,.5);caster.mesh=box
	var material:=StandardMaterial3D.new();material.albedo_color=Color("657570");caster.material_override=material
	caster.layers=131073;caster.position=Vector3(5.4,.6,19.35);room.props_root.add_child(caster)
	var cast_on:Image=await photo("caster_on");var object_area:=bounds(caster)
	caster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cast_off:Image=await photo("caster_off")
	metrics.real_cast=delta(cast_on,cast_off,Rect2i(220,145,95,85),object_area)
	check(metrics.real_cast.changed_pixels>=12,"Furniture still casts visible floor shadows outside its own silhouette")
	caster.queue_free();await frames()
	for pose in [["arrival",Vector2(17.5,19.2)],["upper_hall",Vector2(12,7)]]:
		room.player.global_position=pose[1]*32;room._update_camera_and_projection(0);await photo(pose[0])
		if pose[0]=="upper_hall":
			for light in lights:light.shadow_reverse_cull_face=false
			await photo("legacy_upper_hall")
			for light in lights:light.shadow_reverse_cull_face=true
			await photo("restored_upper_hall")
	check(lights.all(func(light):return light.shadow_enabled and light.shadow_reverse_cull_face),"All four production ceiling shadow sources remain enabled")
	check(AudioServer.is_bus_mute(0),"Private validation remains muted")
	var failures=checks.filter(func(c):return not c["pass"])
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	print("RECEPTION_COUNTER_SHADOW checks=",checks.size()," failures=",failures.size())
	main.queue_free();room=null;main=null;lights.clear();await frames(16);preload("res://scripts/audio/sfx_manager.gd").stop_music(0);await frames();quit(0 if failures.is_empty() else 1)
