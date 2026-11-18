extends "res://tests/h06_hangar_crew_test.gd"

func run() -> void:
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	preload("res://tests/support/background_gpu.gd").start(self)
	await enter(CHAPTER.Save.ENTRANCE)
	world._place_feet(Vector2(5.3,0.7))
	await frames(50)
	var crew: Node3D=world.blockout.hangar_crew
	crew.set_process(false)
	for time: float in [0.0,1.0,4.0,7.0,8.0,10.0,13.0]:
		for actor in crew.actors:
			actor.work_activity.age=time
			actor.work_activity.present()
		await frames(5)
		await photograph("work-%02d"%int(time))
		await RenderingServer.frame_post_draw
		crew.bridges[2].render_viewport.get_texture().get_image().save_png(evidence.path_join("capture-%02d.png"%int(time)))
	await unload()
	await enter(CHAPTER.Save.RETURN_BAY)
	world._place_feet(Vector2(3.4,1.5))
	await frames(40)
	var rows: Array=[]
	for effect in world.world_effects_root.get_children():
		if not effect is BlackBloodEffect or not effect.get_meta(&"hangar_crew_scenery",false) or effect.is_queued_for_deletion():continue
		var bridge: Node3D=effect.get_meta(&"depth_visual_bridge").get_ref()
		var origin: Vector2=effect.global_position/32
		var under: Array=[]
		for mesh: MeshInstance3D in world.blockout.floor_root.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh==null:continue
			var bounds: AABB=mesh.global_transform*mesh.get_aabb()
			if origin.x>=bounds.position.x and origin.x<=bounds.end.x and origin.y>=bounds.position.z and origin.y<=bounds.end.z and bounds.end.y<0.4:
				under.append({"name":str(mesh.name),"top_y":bounds.end.y})
		rows.append({"origin":str(origin),"pixels":effect.ground_pixels.size(),"height":bridge.actor_center_height,"sprite":str(bridge.actor_sprite.global_position),"under":under})
	for y: float in [0.045,0.08,0.16,0.20]:
		for effect in world.world_effects_root.get_children():
			if not effect is BlackBloodEffect or not effect.get_meta(&"hangar_crew_scenery",false) or effect.is_queued_for_deletion():continue
			var bridge: Node3D=effect.get_meta(&"depth_visual_bridge").get_ref()
			bridge.actor_center_height=y
			bridge.request_capture_refresh()
		await frames(6)
		await photograph("blood-%03d"%int(y*1000))
	FileAccess.open(evidence.path_join("surface-probe.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	await unload()
	quit()
