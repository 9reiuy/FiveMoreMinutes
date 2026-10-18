extends SceneTree
const OUTPUT := "res://.runtime/approved_art_capture"
var checks := 0
var failures := 0
var display: Control
var world: Node3D
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func capture(name: String) -> void:
	await frames(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+name+".png")
func focus_room(room: Dictionary) -> bool:
	for cell in room.usable_cells:
		var point := Vector2(cell)*32.0
		if world._content_position_is_clear(point,12.0):
			world.player.global_position=point
			world.activate_room(int(room.id))
			world._update_camera_and_actor_projection()
			return true
	return false
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var settings: Node=root.get_node("SettingsManager")
	var saved: Dictionary=settings.values.duplicate(true)
	world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.enable_game_start_cab_exit=false; world.persist_profile=false
	display=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false
	root.add_child(display); root.size=Vector2i(1280,720)
	for type in ["A1","B2","C3","V3"]:
		world.native_skeleton_type=type
		check(world.regenerate(42001),"Formal floor "+type)
		await frames(15)
		world.transition_phase=&"IDLE"
		world.player.invulnerability_left=10000
		for enemy in world.enemy_root.get_children(): enemy.process_mode=Node.PROCESS_MODE_DISABLED
		paused=true
		var art = world.office_art_root.get_node("ApprovedOfficeArt")
		check(art.furniture.records.size()>0 and art.city.buildings>0,"Rendered approved art available")
		for pixel in [false,true]:
			for palette in [0,1]:
				settings.values["pixelation_enabled"]=pixel
				settings.values["palette_enabled"]=palette==1
				display.set_selective_enabled(pixel)
				display.set_palette_enabled(palette==1)
				check(display.selective_enabled==pixel and display.palette_enabled==(palette==1),"Display setting combinations")
				focus_room(world.rooms[world.spawn_room_id])
				paused=false
				await frames(18)
				paused=true
				await capture(type+"_entry_p"+str(pixel)+"_pal"+str(palette))
		for room in world.rooms:
			if String(room.archetype)=="open_office":
				check(focus_room(room),"Office reachable camera point")
				paused=false
				await frames(24)
				paused=true
				await capture(type+"_office")
				break
		check(art.city.window_lights.size()<=4,"City illumination budget")
		world.transition_phase=&"CAB_RIDE"
		art.city._sync_render_snapshot()
		check(not art.city.scene_root.visible,"City hidden in cab")
		world.transition_phase=&"IDLE"
		art.city._sync_render_snapshot()
		var geometry=art.city.scene_root
		art.furniture.refresh_assets(); art.walls.refresh_assets(); art.floors.refresh_assets()
		check(geometry==art.city.scene_root,"Periodic refresh does not rebuild city")
		paused=false
	settings.values=saved
	display.queue_free(); await frames(4)
	print("APPROVED_ART_GPU_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
