extends "res://tests/h06_hangar_crew_test.gd"
const OUT:="res://.runtime/h06_glass_staff_20261117"
const WINDOWS:=preload("res://scripts/testing/h06_chapter/observation_window.gd")
const OLD_STAFF:=preload("res://art/Dream/enemy/Employee_men_32x32.png")
const OLD_TECH:=preload("res://art/Dream/enemy/npc1.png")
var timings:Array[Dictionary]=[]
var observations:Array[Dictionary]=[]

func _initialize()->void:call_deferred("run")

func sample(label:String,count:int)->void:
	var stamp:=Time.get_ticks_usec()
	for frame in count:
		await process_frame
		var now:=Time.get_ticks_usec()
		timings.append({"stage":label,"frame":frame,"wall_ms":(now-stamp)/1000.0})
		stamp=now

func stop_combat()->void:
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for unit:Node in get_nodes_in_group(&"dream_enemies"):unit.set_physics_process(false)

func show_window(window:Node3D)->void:
	var target:Vector3=window.global_position+Vector3(0,1.0,-2.0)
	world.camera_3d.global_position=target+Vector3(0,4.0,14.0)
	world.camera_3d.look_at(target,Vector3.UP)

func inspect_window(key:String)->void:
	var window=world.blockout.windows[key]
	var roof:MeshInstance3D=window.get_node("TopBlackCeiling")
	var back:MeshInstance3D=window.get_node("BackWall")
	var roof_bounds:AABB=roof.transform*roof.get_aabb()
	var back_bounds:AABB=back.transform*back.get_aabb()
	var bay:Rect2=WINDOWS.WINDOWS[key]
	check(roof.get_active_material(0)==world.blockout.cutout.top_black and roof.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,key+" has a real TopBlack ceiling without changing the room's light/shadow sources")
	check(is_equal_approx(roof_bounds.end.y,back_bounds.end.y) and roof_bounds.size.x>=bay.size.x and roof_bounds.size.z>=bay.size.y,key+" ceiling covers the complete compartment and seals flush to the wall crown")
	check(roof_bounds.position.y>2.46 and window.get_node("Glass").visible,key+" roof leaves the glass viewing aperture open")
	if key=="transfer_floor":
		var motor:MeshInstance3D=window.get_node("HoistMotor")
		check((motor.transform*motor.get_aabb()).end.y<roof_bounds.position.y,"transfer ceiling clears the original overhead gantry motor")
	check(window.actors.size()==2 and window.actors[0].texture==WINDOWS.ENGINEER and window.actors[1].texture in WINDOWS.SCIENTISTS,key+" has one engineer and one scientist, without the old staff portraits")
	for actor:Sprite3D in window.actors:
		var portrait:Rect2=actor.region_rect
		var used:Rect2i=actor.texture.get_image().get_region(Rect2i(0,0,32,64)).get_used_rect()
		check(portrait.position.y==used.position.y and portrait.end.y==used.end.y,key+" "+str(actor.name)+" keeps the complete authored helmet/hair/body/hands/feet")
		var normal_pixels:float=world.player.character_visual_scale/32.0
		check(is_equal_approx(actor.pixel_size,normal_pixels) and actor.scale.is_equal_approx(Vector3.ONE),key+" "+str(actor.name)+" uses the same pixel-to-world proportions as ordinary characters")
		check(absf(actor.get_item_rect().position.y)<.002 and absf(actor.position.y)<.025,key+" "+str(actor.name)+" keeps both soles on the floor rather than floating or sinking")
		check(not actor.is_in_group(&"dream_enemies") and actor.find_children("*","CollisionObject2D",true,false).is_empty(),key+" "+str(actor.name)+" remains a noncombat performer")
		observations.append({"room":key,"role":str(actor.name),"atlas":actor.texture.resource_path,"pixel_size":actor.pixel_size,"height_metres":portrait.size.y*actor.pixel_size})
	var before:Array=window.actors.map(func(actor:Sprite3D):return actor.position)
	window.approach()
	await frames(70)
	check(window.started and window.elapsed>.5 and window.actors[0].position.distance_to(before[0])>.01,key+" original work/walking sequence still advances")
	show_window(window)
	await frames(4)
	await photograph(key+"-normal-staff")
	var target:Vector3=window.global_position+Vector3(0,1,-2)
	world.camera_3d.global_position=target+Vector3(6,9,16)
	world.camera_3d.look_at(target,Vector3.UP)
	await frames(2)
	await photograph(key+"-topblack")
	window.finish()
	check(is_equal_approx(window.elapsed,4.5) and not window.is_physics_processing(),key+" presentation still finishes without entering combat")
	if key=="west_bank":check(window.actors.all(func(actor:Sprite3D):return not actor.visible),"dispatch performers still leave through their original exit")

func compare_cost()->void:
	var saved:Array[Dictionary]=[]
	for window:Node3D in world.blockout.windows.values():
		window.get_node("TopBlackCeiling").visible=false
		for index in window.actors.size():
			var actor:Sprite3D=window.actors[index]
			saved.append({"actor":actor,"texture":actor.texture,"region":actor.region_rect,"pixel_size":actor.pixel_size,"offset":actor.offset})
			actor.texture=OLD_TECH if index==0 else OLD_STAFF
			actor.region_rect=Rect2(0,4,32,37) if index==0 else Rect2(0,0,32,32)
			actor.pixel_size=.86/actor.region_rect.size.y
			actor.offset=Vector2(0,actor.region_rect.size.y*.5)
	await frames(30)
	await sample("same_camera_old_staff",180)
	for window:Node3D in world.blockout.windows.values():window.get_node("TopBlackCeiling").visible=true
	for record:Dictionary in saved:
		record.actor.texture=record.texture
		record.actor.region_rect=record.region
		record.actor.pixel_size=record.pixel_size
		record.actor.offset=record.offset
	await frames(30)
	await sample("same_camera_normal_engineer_scientist",180)
	await sample("same_camera_normal_engineer_scientist_repeat",180)

func dispose()->void:
	display.queue_free()
	await frames(6)

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/") or not AudioServer.is_bus_mute(0):quit(2);return
	create_timer(120,true,false,true).timeout.connect(func():quit(3))
	var stamp:Array[int]=[Time.get_ticks_usec()]
	process_frame.connect(func()->void:
		var now:=Time.get_ticks_usec()
		RenderingServer.force_draw(false,clampf((now-stamp[0])/1000000.0,0.0,.05))
		stamp[0]=now)
	root.size=Vector2i(1280,720)
	evidence=ProjectSettings.globalize_path(OUT)
	await enter(CHAPTER.Save.CALIBRATED,false)
	stop_combat()
	check(world.blockout.windows.size()==2,"the warehouse owns both of its glass compartments")
	for key:String in ["calibration","inspection"]:await inspect_window(key)
	await compare_cost()
	var old:WeakRef=weakref(world.blockout.windows.inspection.actors[0])
	await dispose()
	check(old.get_ref()==null,"leaving the warehouse releases its glass-compartment performers")
	await enter(CHAPTER.Save.CHASE,false)
	stop_combat()
	check(world.blockout.windows.size()==2,"the freight area owns the other two glass compartments")
	for key:String in ["west_bank","transfer_floor"]:await inspect_window(key)
	var retired:WeakRef=weakref(world.blockout.windows.transfer_floor.actors[1])
	await dispose()
	check(retired.get_ref()==null,"leaving freight releases the remaining glass-compartment performers")
	await enter(CHAPTER.Save.CALIBRATED,false)
	stop_combat()
	# The calibrated spawn is already inside its window trigger, so that
	# freshly rebuilt performance may naturally start during enter().
	check(world.blockout.windows.values().all(func(window:Node3D):return window.elapsed<.5 and window.actors[0].texture==WINDOWS.ENGINEER and window.actors[1].texture in WINDOWS.SCIENTISTS),"retry rebuilds the normal engineer/scientist pair and resets each presentation")
	await dispose()
	var failures:Array=checks.filter(func(row:Dictionary):return not row.pass)
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"actors":observations,"timings":timings,"pid":OS.get_process_id(),"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"muted":AudioServer.is_bus_mute(0),"scope":"all four authored glass compartments, actual scene Camera at staged inspection angles, unchanged work sequences and noncombat boundaries, same-camera warmed comparison, reload/cleanup; not whole-game performance certification"},"\t"))
	print("GLASS_STAFF checks=",checks.size()," failures=",failures.size()," pid=",OS.get_process_id())
	quit(0 if failures.is_empty() else 1)
