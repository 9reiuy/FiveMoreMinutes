extends RefCounted
## Diagnostic: actual floor lighting, not a guessed private-light approximation.
static func run(tree: SceneTree, world: Node3D, shadow_variants:=false) -> Dictionary:
	var started:=Time.get_ticks_usec()
	var viewport:=SubViewport.new(); viewport.size=Vector2i(64,36)
	viewport.world_3d=world.get_world_3d()
	viewport.positional_shadow_atlas_size=world.get_viewport().positional_shadow_atlas_size
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var camera:=Camera3D.new(); viewport.add_child(camera)
	var formal: Camera3D=world.camera_3d
	camera.projection=formal.projection; camera.fov=formal.fov; camera.size=formal.size
	camera.near=formal.near; camera.far=formal.far; camera.keep_aspect=formal.keep_aspect
	camera.cull_mask=formal.cull_mask; camera.current=true
	var meshes: Array[Node3D]=[]
	var positions: Array[Vector3]=[]
	var room_positions: Dictionary={}
	var debris:=Furniture3DDebris.new()
	debris.set_meta(&"test_debris_seed",4300); debris._setup(null,0,Vector3.ZERO)
	var material: Material=debris.material_override
	debris.free()
	for visual in world.actor_depth_bridges_root.get_children():
		if not visual is Furniture3DVisual: continue
		var mesh:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3(.0625,.0625,.0625)
		mesh.mesh=box; mesh.material_override=material
		world.actor_depth_bridges_root.add_child(mesh)
		mesh.position=visual.position+Vector3(0,.2,0); meshes.append(mesh)
		var room_id: int=int(visual.get_meta(&"dream_room_id",-1))
		if not room_positions.has(room_id): room_positions[room_id]=mesh.global_position
	for position in room_positions.values(): positions.append(position)
	# Include the established combat fixture position, without moving gameplay.
	positions.append(world.actor_depth_bridges_root.to_global(Vector3(25,.2,48)))
	var focus: Vector3=world.actor_depth_bridges_root.to_global(Vector3(world.player.global_position.x/32.0,0,world.player.global_position.y/32.0))
	var offset:=formal.global_position-focus
	var lights: Array=[]
	if shadow_variants:
		for light in world.shadow_manager.candidates:
			lights.append([light,light.shadow_enabled,light.shadow_opacity,light.visible])
		var sun: DirectionalLight3D=world.shadow_manager.sun
		if is_instance_valid(sun): lights.append([sun,sun.shadow_enabled,sun.shadow_opacity,sun.visible])
	for phase in ([0,1,2,3] if shadow_variants else [0]):
		if shadow_variants:
			for index in lights.size():
				var state: Array=lights[index]
				var shadowed: bool=phase==1 or (phase>=2 and (index%2==phase-2 or state[0] is DirectionalLight3D))
				state[0].shadow_enabled=shadowed; state[0].shadow_opacity=1.0; state[0].visible=true
		for position in positions:
			camera.global_transform=Transform3D(formal.global_basis,position+offset)
			for frame in 2: await RenderingServer.frame_post_draw
	for state in lights:
		state[0].shadow_enabled=state[1]; state[0].shadow_opacity=state[2]; state[0].visible=state[3]
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	for mesh in meshes: mesh.queue_free()
	viewport.queue_free()
	for frame in 4: await tree.process_frame
	return {"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"meshes":meshes.size(),"views":positions.size(),"shadow_variants":shadow_variants,"viewport_released":not is_instance_valid(viewport)}
