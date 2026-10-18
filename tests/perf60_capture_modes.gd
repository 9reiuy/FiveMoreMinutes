extends SceneTree
func _init(): call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	var display = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false
	root.add_child(display); seed(41001)
	assert(world.regenerate(41001))
	for i in 50: await process_frame
	var counts := {"ALWAYS":0,"ONCE":0,"DISABLED":0,"other":0,"character":0}
	for bridge in world.actor_depth_bridges_root.get_children():
		if bridge.get("character_projection") != true: continue
		counts["character"] += 1
		for vp in [bridge.get("render_viewport"), bridge.get("weapon_capture_root") and null]:
			pass
		var rvp = bridge.get("render_viewport")
		if rvp is SubViewport:
			var m = rvp.render_target_update_mode
			if m == SubViewport.UPDATE_ALWAYS: counts["ALWAYS"] += 1
			elif m == SubViewport.UPDATE_ONCE: counts["ONCE"] += 1
			elif m == SubViewport.UPDATE_DISABLED: counts["DISABLED"] += 1
			else: counts["other"] += 1
		for vp2 in bridge.get("layer_viewports") if bridge.get("layer_viewports")!=null else []:
			if vp2 is SubViewport:
				var m2 = vp2.render_target_update_mode
				if m2 == SubViewport.UPDATE_ALWAYS: counts["ALWAYS"] += 1
				elif m2 == SubViewport.UPDATE_ONCE: counts["ONCE"] += 1
				elif m2 == SubViewport.UPDATE_DISABLED: counts["DISABLED"] += 1
				else: counts["other"] += 1
	print("CAPTURE_MODES ", counts)
	quit(0)
