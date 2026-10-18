extends RefCounted
## Test-only stock-material variant preparation; no formal floor mutation.
static func run(tree: SceneTree, world: Node3D) -> Dictionary:
	var started:=Time.get_ticks_usec()
	var viewport:=SubViewport.new(); viewport.size=Vector2i(32,32); viewport.own_world_3d=true
	viewport.set_meta(&"test_destruction_warm_viewport",true)
	viewport.positional_shadow_atlas_size=world.get_viewport().positional_shadow_atlas_size
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; tree.root.add_child(viewport)
	var scene:=Node3D.new(); viewport.add_child(scene)
	scene.get_world_3d().environment=world.get_world_3d().environment
	var camera:=Camera3D.new(); scene.add_child(camera); camera.position=Vector3(0,.5,2); camera.look_at(Vector3.ZERO); camera.current=true
	var key:=DirectionalLight3D.new(); scene.add_child(key); key.rotation_degrees=Vector3(-35,45,0)
	var sun:=DirectionalLight3D.new(); scene.add_child(sun); sun.rotation_degrees=Vector3(-50,-45,0); sun.shadow_enabled=true
	if is_instance_valid(world.shadow_manager) and is_instance_valid(world.shadow_manager.sun):
		sun.directional_shadow_mode=world.shadow_manager.sun.directional_shadow_mode
		sun.directional_shadow_blend_splits=world.shadow_manager.sun.directional_shadow_blend_splits
	var points: Array[OmniLight3D]=[]; var spots: Array[SpotLight3D]=[]
	for index in 2:
		var point:=OmniLight3D.new(); scene.add_child(point); point.position=Vector3(index*2-1,1,1); point.shadow_enabled=index==1; points.append(point)
		var spot:=SpotLight3D.new(); scene.add_child(spot); spot.position=Vector3(index*2-1,2,1); spot.look_at(Vector3.ZERO); spot.shadow_enabled=index==1; spots.append(spot)
	var caster:=MeshInstance3D.new(); var caster_box:=BoxMesh.new(); caster_box.size=Vector3(.2,.3,.2)
	caster.mesh=caster_box; caster.position=Vector3(0,-.1,0); scene.add_child(caster)
	var debris:=Furniture3DDebris.new(); debris.set_meta(&"test_debris_seed",1); debris._setup(null,0,Vector3.ZERO)
	var material: Material=debris.material_override; debris.free()
	var piece:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3(.0625,.0625,.0625)
	piece.mesh=box; piece.material_override=material; piece.position=Vector3(.15,.15,0); scene.add_child(piece)
	for point_state in 4:
		for spot_state in 4:
			points[0].visible=point_state in [1,3]; points[1].visible=point_state in [2,3]
			spots[0].visible=spot_state in [1,3]; spots[1].visible=spot_state in [2,3]
			for frame in 2: await RenderingServer.frame_post_draw
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; viewport.queue_free()
	for frame in 4: await tree.process_frame
	return {"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"viewport_released":not is_instance_valid(viewport),"states":16}
