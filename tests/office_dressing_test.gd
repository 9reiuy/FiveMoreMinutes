extends SceneTree
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const LAYOUT = preload("res://scripts/dream/office_skeleton_world_base.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func frames(n: int) -> void:
	for i in n: await process_frame
func run() -> void:
	# Extra props must preserve the accepted seed's architecture, not merely its size.
	for skeleton in ["A1","B2","C3","V3"]:
		for seed in [1,7,42001]:
			var baseline := LAYOUT.new()
			baseline.native_skeleton_type=skeleton
			baseline.enhanced_room_dressing=false
			check(baseline.generate_layout_only(seed),"Baseline layout failed")
			var enriched := LAYOUT.new()
			enriched.native_skeleton_type=skeleton
			enriched.enhanced_room_dressing=true
			check(enriched.generate_layout_only(seed),"Enriched layout failed")
			check(baseline.skeleton_source.rooms==enriched.skeleton_source.rooms,"Architecture changed: %s/%d" % [skeleton,seed])
			check(baseline.skeleton_source.doors==enriched.skeleton_source.doors,"Doors changed: %s/%d" % [skeleton,seed])
			baseline.free()
			enriched.free()
	var world = WORLD.instantiate()
	world.generate_on_ready=false
	world.persist_profile=false
	world.enable_game_start_cab_exit=false
	world.native_skeleton_type="A1"
	AudioServer.set_bus_mute(0,true)
	var saved: Dictionary = root.get_node("SettingsManager").values.duplicate(true)
	root.get_node("SettingsManager").values["palette_enabled"]=false
	root.add_child(world)
	await frames(4)
	var original_count := 0
	var original_rooms := []
	var capture := "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://.runtime/room_dressing")
	for enabled in [false,true]:
		world.enhanced_room_dressing=enabled
		check(world.regenerate(42001),"Floor generation failed")
		await frames(12)
		var room_shapes := []
		for room in world.rooms: room_shapes.append([room.sample_key,room.grid_rect,room.shape_cells])
		if not enabled:
			original_count=world.furniture_root.get_child_count()
			original_rooms=room_shapes
		else:
			check(original_rooms==room_shapes,"Dressing changed room shapes")
			check(world.furniture_root.get_child_count()>original_count,"No added furniture")
			var details := 0
			for node in world.find_children("*","Node3D",true,false):
				if node.has_meta(&"visual_only_dressing"):
					details+=1
					check(node.find_children("*","CollisionObject3D",true,false).is_empty(),"Visual decoration has gameplay collision")
			check(details>10,"Missing desk or wall dressing")
			var metal_doors := 0
			var observation_windows := 0
			for door in world.door_root.get_children():
				if not door is PhysicalDoor3D: continue
				metal_doors+=1
				check(bool(door.get_meta(&"office_metal_door",false)),"Random room retained a wooden door")
				for visual in door._visuals:
					if not visual.visible: continue
					check(visual.scale==Vector3.ONE,"Metal panel uses authored wood geometry scaling")
					check(bool(visual.material_override.get_shader_parameter("office_metal")),"Metal shader disabled")
					if bool(door.get_meta(&"office_observation_window",false)):
						observation_windows+=1
						check(visual.get_node_or_null("ObservationGlass")!=null,"Missing observation glass")
			check(metal_doors>0 and observation_windows>0,"Missing metal/window door styles")
			var theme = preload("res://scripts/dream/dream_room_environment_theme.gd")
			for room in world.rooms:
				var key: String=theme.approved_key(room)
				if key.is_empty(): continue
				var floor_mat = theme.get_sample_base_floor_material(room)
				var pattern := "wet_tiles" if key in ["pantry","restroom"] else "office_tiles"
				check(floor_mat.get_shader_parameter("pixel_texture")==preload("res://scripts/dream/office_pixel_materials.gd").swatch(pattern),"Room base floor is not hard-surfaced")
				if key not in ["lounge"]:
					check(not theme.is_accent_cell(room.center_cell,room),"Carpet outside seating room")
				if key in ["lounge","manager","reception"] and room.sample_key!="smoking":
					var areas: Array=world.room_layout_plans[room.id].get("functional_areas",[])
					for area in areas:
						if area.get("category","")=="seating": check(theme.is_accent_cell(area.center_cell,room,areas),"Missing carpet under actual seating group")
			print("DRESSING furniture before=",original_count," after=",world.furniture_root.get_child_count()," detail_batches=",details)
		var planned := 0
		for plan in world.room_layout_plans.values(): planned+=plan.furniture_placements.size()
		check(planned==world.furniture_root.get_child_count(),"Physical furniture lost during build")
		check(world.rooms[world.spawn_room_id].grid_rect.size==Vector2i(14,10),"Reception resized")
		if capture:
			# Architectural comparisons must not drift because AI pushed a chair mid-shot.
			for enemy in world.enemy_root.get_children(): enemy.process_mode=Node.PROCESS_MODE_DISABLED
			world.player.invulnerability_left=0.0
			for key in ["entry","main","meeting","pantry","deep","ring"]:
				for room in world.rooms:
					if room.sample_key!=key: continue
					world.player.global_position=Vector2(room.center_cell)*32.0
					world.activate_room(int(room.id))
					await frames(25)
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://.runtime/room_dressing/%s_%s.png" % ["after" if enabled else "before",key])
			if enabled:
				for door in world.door_root.get_children():
					if not door is PhysicalDoor3D or not bool(door.get_meta(&"office_observation_window",false)): continue
					var point := Vector2(door.position.x,door.position.z)*32.0+Vector2(0,4)*32.0
					for room in world.rooms:
						if not room.shape_cells.has(Vector2i((point/32.0).round())): continue
						world.player.global_position=point
						world.activate_room(room.id)
						await frames(30)
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png("res://.runtime/room_dressing/metal_observation_door.png")
					break
			if enabled and "--motion" in OS.get_cmdline_user_args():
				world.player.global_position=Vector2(world.rooms[world.spawn_room_id].center_cell)*32.0
				world.activate_room(world.spawn_room_id)
				await frames(30)
				Input.action_press("move_up")
				for frame in 60:
					await physics_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://.runtime/room_dressing/motion_%03d.png" % frame)
				Input.action_release("move_up")
	for i in 3:
		check(world.regenerate(42002+i),"Cross-floor generation failed")
		await frames(5)
		check(world.floor_root.find_children("ApprovedRandomRoomFixtures_*","Node3D",false,false).size()==world.rooms.size(),"Old-room dressing leaked across floors")
	root.get_node("SettingsManager").values=saved
	world.queue_free()
	await frames(5)
	print("DRESSING_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
