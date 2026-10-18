extends RefCounted
## Loading-only experiment using the actual viewport and existing shadow cap.
static func run(tree: SceneTree,world: Node3D,reset_atlas: bool=false) -> Dictionary:
	if not tree.paused: return {"skipped":"not_paused"}
	var token: int=world.get_current_floor_token()
	var manager: Node=world.shadow_manager
	var camera: Camera3D=world.camera_3d
	var saved_camera:=camera.transform
	var owned_camera:=saved_camera
	var saved_selected: Array=manager.selected.duplicate()
	var saved_active: Dictionary=manager.active.duplicate()
	var lights: Array=[]
	for light in manager.candidates: lights.append([light,light.shadow_enabled,light.shadow_opacity])
	var focus: Vector3=world.get_gameplay_world_position(world.player.global_position,0.0)
	var offset:=camera.global_position-focus
	var covered: Dictionary={}
	var views:=0; var peak:=0
	var started:=Time.get_ticks_usec()
	var cancelled:=false
	for target in manager.candidates.duplicate():
		if not is_instance_valid(target) or covered.has(target.get_instance_id()): continue
		for row in lights:
			if is_instance_valid(row[0]): row[0].shadow_enabled=false; row[0].shadow_opacity=0.0
		manager.selected.clear(); manager.active.clear()
		var point: Vector3=target.global_position
		point.y=focus.y
		camera.global_position=point+offset
		owned_camera=camera.transform
		manager.prepare_loading_selection()
		peak=maxi(peak,manager.active.size())
		for light in manager.active:
			light.shadow_opacity=1.0
			covered[light.get_instance_id()]=true
		for frame in range(2): await RenderingServer.frame_post_draw
		views+=1
		if not is_instance_valid(world) or not world.is_inside_tree() or world.get_current_floor_token()!=token:
			cancelled=true; break
	# A regenerated floor reuses Camera3D but moves its rig, not this local
	# transform. Restore only our own last write, never another owner's pose.
	if is_instance_valid(camera) and camera.transform==owned_camera:
		camera.transform=saved_camera
	if not cancelled:
		world.camera_3d.get_viewport().get_texture().get_image()
		manager.selected.assign(saved_selected); manager.active=saved_active
		for row in lights:
			if is_instance_valid(row[0]): row[0].shadow_enabled=row[1]; row[0].shadow_opacity=row[2]
		if reset_atlas:
			# Test-only allocator isolation. Preserve the actual configured size.
			var viewport:=camera.get_viewport()
			var atlas_size:=viewport.positional_shadow_atlas_size
			viewport.positional_shadow_atlas_size=0
			viewport.positional_shadow_atlas_size=atlas_size
		for frame in range(2): await RenderingServer.frame_post_draw
	return {"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"cancelled":cancelled,"views":views,"covered_lights":covered.size(),"candidates":lights.size(),"peak_shadow_lights":peak,"reset_atlas":reset_atlas,"limit":manager.LIMITS[manager.quality] if is_instance_valid(manager) else -1}
