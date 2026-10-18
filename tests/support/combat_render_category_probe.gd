extends Node
## Diagnostic only: freeze one actual post-combat state and isolate render work.
var states: Dictionary = {}
var groups: Dictionary = {"shells":[],"blood":[],"floor_objects":[],"transient_effects":[],"capture_viewports":[]}
func stats(values: Array) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"p95":values[floori(values.size()*.95)]}
func restore() -> void:
	for node in states:
		if node is SubViewport: node.render_target_update_mode = states[node]
		else: node.visible = states[node]
func run(world: Node3D) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tree := get_tree()
	var previously_paused := tree.paused
	tree.paused = true
	# Flush already-requested captures without advancing the gameplay state.
	for index in 4: await RenderingServer.frame_post_draw
	for bridge in world.find_children("*","Node3D",true,false):
		if not bridge.has_method("set_world_camera"): continue
		var source: Node2D = bridge.get("source_actor")
		var sprite: Sprite3D = bridge.get("actor_sprite")
		if not is_instance_valid(source) or not is_instance_valid(sprite): continue
		var category := ""
		if bridge.has_meta(&"shell_capture_pool_slot"): category = "shells"
		elif source is BlackBloodEffect: category = "blood"
		elif source.is_in_group(&"environment_debris") or source.is_in_group(&"weapon_pickups"): category = "floor_objects"
		elif bridge.has_meta(&"projectile_capture_pool_slot") or bridge.has_meta(&"muzzle_capture_pool_slot") or bridge.has_meta(&"feedback_capture_pool_slot"): category = "transient_effects"
		if not category.is_empty():
			groups[category].append(sprite); states[sprite] = sprite.visible
	for viewport in world.find_children("*","SubViewport",true,false):
		if viewport.get_parent().has_method("set_world_camera") or viewport.has_meta(&"shell_capture_atlas_page"):
			if viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
				groups.capture_viewports.append(viewport); states[viewport] = viewport.render_target_update_mode
	var counts: Dictionary = {}
	for category in groups: counts[category] = groups[category].size()
	print("COMBAT_RENDER_CATEGORY_COUNTS ",JSON.stringify(counts))
	var phase: Node = preload("res://tests/support/frame_phase_probe.gd").new()
	tree.root.add_child(phase)
	print("COMBAT_RENDER_PHASE_READY")
	for category in ["original","capture_viewports","shells","blood","floor_objects","transient_effects","original_repeat"]:
		restore()
		if groups.has(category):
			for node in groups[category]:
				if node is SubViewport: node.render_target_update_mode = SubViewport.UPDATE_DISABLED
				else: node.visible = false
		var start := Time.get_ticks_usec()
		while Time.get_ticks_usec()-start < 1000000: await RenderingServer.frame_post_draw
		start = Time.get_ticks_usec(); var previous := start
		var frames: Array = []; var draws: Array = []; phase.begin()
		while Time.get_ticks_usec()-start < 6000000:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec(); frames.append((now-previous)/1000.0); previous = now
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		print("COMBAT_RENDER_CATEGORY_COST ",JSON.stringify({"disabled":category,"frame_ms":stats(frames),"draw_calls":stats(draws),"phases":phase.finish(),"frozen_post_combat_state":true}))
	restore(); phase.queue_free(); tree.paused = previously_paused
	print("COMBAT_RENDER_CATEGORY_DONE restored=true")
