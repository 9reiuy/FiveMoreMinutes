extends SceneTree
## Native Forward+ test: real gameplay adapters, GPU particle motion and lifecycle.
const OUT:="res://.runtime/interactive_gas_cloud_20261117"
const GPU:=preload("res://scripts/testing/interactive_gas_gpu.gd")
const STEP:=1.0/30.0
var lab:Control
var gas:Node3D
var player:CharacterBody2D
var failures:Array[String]=[]
var checks:=0
var aim:=Vector2(6,4)*32.0
var evidence:Dictionary={}

func _initialize()->void:call_deferred("run")

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
	print("PASS " if ok else "FAIL ",label)

func frames(count:int)->void:
	for i in count:await process_frame

func shot(name:String)->void:
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+name+".png")

func key(code:Key)->void:
	var event:=InputEventKey.new()
	event.pressed=true
	event.physical_keycode=code
	lab._input(event)

func dump()->Dictionary:
	gas.solver.sample_field()
	var state:Dictionary=await gas.solver.field_sampled
	var total:=0.0
	var blocked:=0
	var nonfinite:=0
	for i in state.density.size():
		var value:float=state.density[i]
		total+=value
		if not is_finite(value) or value<0:nonfinite+=1
		if state.solid[i]>.5 and value>.0001:blocked+=1
	for value:float in state.velocity:
		if not is_finite(value):nonfinite+=1
	check(state.density.size()==GPU.GRID.x*GPU.GRID.y*GPU.GRID.z and total>1 and nonfinite==0,"GPU density and velocity are finite and occupied")
	check(blocked==0,"room solids retain zero smoke")
	state["total"]=total
	return state

func fixed_steps(count:int)->void:
	for i in count:
		var before:int=gas.solver.steps
		while not gas.solver.advance(STEP,PackedFloat32Array(),false):await process_frame
		while gas.solver.steps==before:await process_frame

func reset_at(point:Vector2)->void:
	player.remove_meta(&"force_weapon_attack")
	player.cancel_dash()
	player.clear_scripted_locomotion()
	player.global_position=point*32.0
	player.velocity=Vector2.ZERO
	player.dash_charges=player.max_dash_charges
	player.dash_cooldown_left=0.0
	lab.world._update_camera_and_actor_projection(10.0)
	gas.paused=false
	gas.reset()
	await frames(5)

func clip(name:String,seconds:float)->void:
	var directory:=OUT+"/"+name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var times:Array[int]=[]
	for index in ceili(seconds*12.0):
		await create_timer(1.0/12.0,true,false,true).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory+"/%03d.png"%index)
		times.append(Time.get_ticks_msec())
	FileAccess.open(directory+"/timestamps.json",FileAccess.WRITE).store_string(JSON.stringify(times))

func texture3d(fill:Color,wall:bool=false)->ImageTexture3D:
	var slices:Array[Image]=[]
	for z in 16:
		var image:=Image.create(16,16,false,Image.FORMAT_RGBAF)
		image.fill(fill)
		if wall:
			for y in 16:
				for x in range(8,16):image.set_pixel(x,y,Color.WHITE)
		slices.append(image)
	var result:=ImageTexture3D.new()
	result.create(Image.FORMAT_RGBAF,16,16,16,false,slices)
	return result

func verify_native_advection()->void:
	# Reading bounds of two actual GPU particles proves field-driven motion.
	var density:=texture3d(Color.WHITE)
	var solid:=texture3d(Color.BLACK,true)
	var flowing:=texture3d(Color(2,0,0,1))
	var still:=texture3d(Color.BLACK)
	var probes:Array[GPUParticles3D]=[]
	for index in 2:
		var probe:=GPUParticles3D.new()
		probe.top_level=true
		probe.amount=1
		probe.lifetime=.75
		probe.explosiveness=1.0
		probe.fixed_fps=30
		probe.local_coords=false
		probe.use_fixed_seed=true
		probe.seed=28711
		probe.visibility_aabb=gas.bounds.grow(2.0)
		probe.draw_pass_1=gas.extinguisher.mesh
		probe.material_override=gas.extinguisher.material
		probe.layers=gas.extinguisher.SMOKE_LAYER
		var process:ShaderMaterial=gas.extinguisher.field_material.duplicate()
		process.set_shader_parameter("gas_to_world",Transform3D.IDENTITY)
		process.set_shader_parameter("world_to_gas",Transform3D.IDENTITY)
		process.set_shader_parameter("gas_density",density)
		process.set_shader_parameter("gas_solids",solid)
		process.set_shader_parameter("gas_velocity",flowing if index==0 else still)
		process.set_shader_parameter("gas_minimum",Vector3.ZERO)
		process.set_shader_parameter("gas_extent",Vector3(14,2.8,14))
		process.set_shader_parameter("gas_cell_size",Vector3(14,2.8,14)/16.0)
		process.set_shader_parameter("spawn_center",Vector3(5,1.4,5))
		process.set_shader_parameter("spawn_half_extent",Vector3.ZERO)
		process.set_shader_parameter("anchor_return",0.0)
		process.set_shader_parameter("scale_range",Vector2(.7,.7))
		probe.process_material=process
		gas.add_child(probe)
		probe.restart(true)
		probes.append(probe)
	await create_timer(1.0,true,false,true).timeout
	var moved:Vector3=probes[0].capture_aabb().get_center()
	var stationary:Vector3=probes[1].capture_aabb().get_center()
	check(moved.x-stationary.x>.6,"native GPU mesh particles advect with sampled velocity")
	await create_timer(2.0,true,false,true).timeout
	var stopped:Vector3=probes[0].capture_aabb().get_center()
	check(stopped.x>6.5 and stopped.x<7.15,"GPU particle motion stops at solid voxels without tunnelling")
	evidence["native_advection"]={"moving_center":str(moved),"static_center":str(stationary),"blocked_center":str(stopped)}
	for probe in probes:probe.free()
	await frames(3)

func verify_persistent_parcel()->void:
	# A private Camera observes ONE live GPU parcel over several native cycles.
	# A frozen drawing would also fail the following density and flow checks.
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(192,192)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene:=Node3D.new()
	viewport.add_child(scene)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("20272e")
	scene.add_child(environment)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.0
	scene.add_child(camera)
	camera.position=Vector3(5,1.4,10)
	camera.look_at(Vector3(5,1.4,5))
	camera.current=true
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-50,-30,0)
	light.light_energy=preload("res://scripts/testing/stylized_smoke_column.gd").LIGHT_GAIN/PI
	scene.add_child(light)
	var full:=texture3d(Color.WHITE)
	var zero:=texture3d(Color.BLACK)
	var flowing:=texture3d(Color(1,0,0,1))
	var probe:=GPUParticles3D.new()
	probe.amount=1
	probe.lifetime=.5
	probe.explosiveness=1.0
	probe.fixed_fps=30
	probe.local_coords=false
	probe.use_fixed_seed=true
	probe.seed=28711
	probe.visibility_aabb=AABB(Vector3.ZERO,Vector3(14,2.8,14))
	probe.draw_pass_1=gas.extinguisher.mesh
	var surface:ShaderMaterial=gas.extinguisher.material.duplicate()
	surface.set_shader_parameter("gas_solids",zero)
	surface.set_shader_parameter("world_to_gas",Transform3D.IDENTITY)
	surface.set_shader_parameter("gas_minimum",Vector3.ZERO)
	surface.set_shader_parameter("gas_extent",Vector3(14,2.8,14))
	probe.material_override=surface
	var process:ShaderMaterial=gas.extinguisher.field_material.duplicate()
	process.set_shader_parameter("gas_to_world",Transform3D.IDENTITY)
	process.set_shader_parameter("world_to_gas",Transform3D.IDENTITY)
	process.set_shader_parameter("gas_density",full)
	process.set_shader_parameter("gas_solids",zero)
	process.set_shader_parameter("gas_velocity",zero)
	process.set_shader_parameter("gas_minimum",Vector3.ZERO)
	process.set_shader_parameter("gas_extent",Vector3(14,2.8,14))
	process.set_shader_parameter("gas_cell_size",Vector3(14,2.8,14)/16.0)
	process.set_shader_parameter("spawn_center",Vector3(5,1.4,5))
	process.set_shader_parameter("spawn_half_extent",Vector3.ZERO)
	process.set_shader_parameter("scale_range",Vector2(.7,.7))
	probe.process_material=process
	scene.add_child(probe)
	probe.restart(true)
	await frames(10)
	await RenderingServer.frame_post_draw
	var baseline:Image=viewport.get_texture().get_image()
	baseline.save_png(OUT+"/persistent_parcel_before.png")
	var anchor:Vector3=probe.capture_aabb().get_center()
	var differing:=0
	var positions:Array[String]=[]
	var started:=Time.get_ticks_msec()
	for i in 16:
		await create_timer(.2,true,false,true).timeout
		await RenderingServer.frame_post_draw
		if viewport.get_texture().get_image().get_data()!=baseline.get_data():differing+=1
		positions.append(str(probe.capture_aabb().get_center()))
	viewport.get_texture().get_image().save_png(OUT+"/persistent_parcel_after.png")
	check(differing==0,"an undisturbed cloud parcel keeps identical Camera pixels across native lifetime cycles")
	process.set_shader_parameter("gas_density",zero)
	await frames(6)
	await RenderingServer.frame_post_draw
	var empty:Image=viewport.get_texture().get_image()
	check(empty.get_data()!=baseline.get_data(),"the persistent parcel still responds to a cleared density field")
	process.set_shader_parameter("gas_density",full)
	await frames(6)
	await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().get_data()==baseline.get_data(),"density recovery restores the same parcel without a new lifetime animation")
	process.set_shader_parameter("gas_velocity",flowing)
	await create_timer(.6,true,false,true).timeout
	var pushed:Vector3=probe.capture_aabb().get_center()
	process.set_shader_parameter("gas_velocity",zero)
	await create_timer(1.4,true,false,true).timeout
	var returned:Vector3=probe.capture_aabb().get_center()
	check(pushed.distance_to(anchor)>.2 and returned.distance_to(anchor)<pushed.distance_to(anchor)*.85,"a disturbed persistent parcel moves, then gradually rejoins its cloud")
	process.set_shader_parameter("reset_generation",2.0)
	await frames(6)
	var reset_point:Vector3=probe.capture_aabb().get_center()
	check(reset_point.distance_to(anchor)<.03,"an explicit reset generation clears the parcel's displacement")
	evidence["parcel_persistence"]={"native_lifetime_s":.5,"observed_ms":Time.get_ticks_msec()-started,"differing_idle_images":differing,"idle_centers":positions,"anchor":str(anchor),"pushed":str(pushed),"returned":str(returned),"reset":str(reset_point)}
	viewport.free()
	await frames(3)

func verify_resting_cloud()->void:
	await reset_at(Vector2(6,10))
	await frames(15)
	var before:Dictionary=await dump()
	var shape:AABB=gas.extinguisher.particles.capture_aabb()
	await clip("idle",6.0)
	var after:Dictionary=await dump()
	var drift:float=gas.extinguisher.particles.capture_aabb().get_center().distance_to(shape.get_center())
	var ratio:float=after.total/before.total
	check(ratio>.85 and ratio<1.15 and drift<.4,"the resting cloud keeps its mass and location without rising or cyclic replacement")
	evidence["resting_cloud"]={"mass_before":before.total,"mass_after":after.total,"mass_ratio":ratio,"center_drift_m":drift,"shots":gas.shots,"walks":gas.walks,"rolls":gas.rolls}

func verify_reference_and_pause()->void:
	key(KEY_P)
	await frames(5)
	var steps:int=gas.solver.steps
	var frozen:AABB=gas.extinguisher.particles.capture_aabb()
	await frames(8)
	check(gas.paused and gas.solver.steps==steps and gas.extinguisher.particles.capture_aabb().is_equal_approx(frozen),"P freezes both the fluid solver and native particle motion")
	var original_mode:int=lab.world.process_mode
	var original_update:int=lab.display.world_viewport.render_target_update_mode
	key(KEY_F2)
	await frames(8)
	var preview:Control=lab.reference_preview
	var held:WeakRef=weakref(preview)
	check(is_instance_valid(preview) and lab.world.process_mode==Node.PROCESS_MODE_DISABLED,"F2 opens the preserved reference and suspends the hidden world")
	preview.smoke.reference_paused=true
	await frames(5)
	await RenderingServer.frame_post_draw
	var updated:Image=preview.viewport.get_texture().get_image()
	updated.save_png(OUT+"/reference_updated.png")
	var material:ShaderMaterial=preview.smoke.material
	var shader:=material.shader
	var original:=Shader.new()
	original.code=FileAccess.get_file_as_string(OUT+"/baseline/stylized_smoke_column.gdshader")
	var parameters:Dictionary={}
	for name in ["Color_1D_Gradient","Dissolve_Texture","dissolve_enabled","particle_age_from_custom"]:parameters[name]=material.get_shader_parameter(name)
	material.shader=original
	for name in parameters:material.set_shader_parameter(name,parameters[name])
	await frames(5)
	await RenderingServer.frame_post_draw
	var baseline:Image=preview.viewport.get_texture().get_image()
	baseline.save_png(OUT+"/reference_baseline.png")
	var parity:=updated.get_data()==baseline.get_data()
	check(parity,"reference Camera is byte-identical after optional field support was added")
	material.shader=shader
	for name in parameters:material.set_shader_parameter(name,parameters[name])
	key(KEY_F2)
	preview=null
	await frames(5)
	check(held.get_ref()==null and lab.world.process_mode==original_mode and lab.display.world_viewport.render_target_update_mode==original_update,"reference close releases its world and restores the previous rendering state")
	check(gas.paused and gas.extinguisher.particles.speed_scale==0.0,"reference close preserves an existing pause")
	key(KEY_P)
	await frames(8)
	check(not gas.paused and gas.solver.steps>steps and gas.extinguisher.particles.speed_scale==1.0,"P resumes the linked simulation and particles")
	evidence["reference_pixel_parity"]=parity

func verify_field()->void:
	gas.set_physics_process(false)
	gas.reset()
	await frames(4)
	var initial:Dictionary=await dump()
	gas.push_shot(Vector2(3,6.5)*32.0,Vector2(10.5,6.5)*32.0)
	var events:PackedFloat32Array=gas._events.duplicate()
	gas._events=PackedFloat32Array()
	var before:int=gas.solver.steps
	while not gas.solver.advance(STEP,events,false):await process_frame
	while gas.solver.steps==before:await process_frame
	var cleared:Dictionary=await dump()
	var indices:=PackedInt32Array()
	var initial_lane:=0.0
	var cleared_lane:=0.0
	var grid:Vector3i=GPU.GRID
	for z in grid.z:
		for y in grid.y:
			for x in grid.x:
				var point:Vector3=gas.bounds.position+(Vector3(x,y,z)+Vector3.ONE*.5)*gas.bounds.size/Vector3(grid)
				if point.x<3 or point.x>10.5 or absf(point.z-6.5)>.22 or absf(point.y-.65)>.3:continue
				var i:=x+grid.x*(y+grid.y*z)
				indices.append(i)
				initial_lane+=initial.density[i]
				cleared_lane+=cleared.density[i]
	check(cleared_lane<initial_lane*.6,"a bullet-segment impulse clears a narrow lane")
	await fixed_steps(24)
	var recovered:Dictionary=await dump()
	var recovered_lane:=0.0
	for i in indices:recovered_lane+=recovered.density[i]
	check(recovered_lane>cleared_lane+initial_lane*.04,"surrounding smoke gradually refills the cleared lane")
	evidence["lane"]={"initial":initial_lane,"cleared":cleared_lane,"recovered":recovered_lane}
	gas.set_physics_process(true)

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/") or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	create_timer(180,true,false,true).timeout.connect(func():quit(2))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var previous:Array[int]=[Time.get_ticks_usec()]
	process_frame.connect(func()->void:
		var now:=Time.get_ticks_usec()
		var delta:=clampf(float(now-previous[0])/1000000.0,0.0,.05)
		previous[0]=now
		RenderingServer.force_draw(false,delta))
	root.size=Vector2i(1280,720)
	lab=load("res://scenes/testing/InteractiveGasWhitebox.tscn").instantiate()
	root.add_child(lab)
	while not lab.ready_world or lab._gas_rebuilding:await process_frame
	gas=lab.gas
	player=lab.world.player
	lab.hud.hide()
	player.set_meta(&"presentation_pointer_position",func()->Vector2:return lab.world.camera_3d.unproject_position(lab.world.get_gameplay_world_position(aim,.65)))
	check(RenderingServer.get_current_rendering_method()=="forward_plus" and gas.solver.ready,"native Forward+ GPU pipeline initialized")
	check(not is_instance_valid(lab.reference_preview) and gas.active_visual()==gas.extinguisher and not gas.fog.visible,"default entry is the linked interactive room")
	check(gas.extinguisher.particles is GPUParticles3D and gas.extinguisher.particles.amount==gas.extinguisher.PUFF_COUNT and gas.extinguisher.mesh is ArrayMesh,"interactive room uses bounded native mesh particles")
	check(gas.extinguisher.field_material.get_shader_parameter("gas_density")==gas.solver.output and gas.extinguisher.field_material.get_shader_parameter("gas_velocity")==gas.solver.velocity_output,"native particles sample the live fluid density and velocity")
	check(not gas.world.camera_3d.environment.volumetric_fog_enabled,"the realistic fog overlay remains disabled")
	var smoke_layer:int=gas.extinguisher.SMOKE_LAYER
	for light:Light3D in gas._volume_lights:
		check(light.shadow_enabled and (light.light_cull_mask & smoke_layer)==0 and (light.shadow_caster_mask & smoke_layer)!=0,"room lights retain smoke shadows without washing out its palette")
	await shot("entry")
	await verify_native_advection()
	await verify_persistent_parcel()
	await verify_reference_and_pause()
	await verify_field()
	await verify_resting_cloud()
	await reset_at(Vector2(6,10))
	var before:int=lab.shot_count
	player.set_meta(&"force_weapon_attack",true)
	await clip("shoot",2.5)
	player.remove_meta(&"force_weapon_attack")
	check(lab.shot_count>before and gas.shots>0,"production firearm and live projectile sweeps drive smoke impulses")
	evidence["shooting"]={"shots":lab.shot_count-before,"segments":gas.shots}
	await shot("shoot_after")
	await reset_at(Vector2(6,10))
	var from:=player.global_position
	player.set_scripted_locomotion(Vector2.UP,player.movement_speed)
	await clip("walk",.65)
	player.clear_scripted_locomotion()
	check(player.global_position.distance_to(from)>45 and gas.walks>0,"real walking creates fluid impulses while traversing smoke")
	evidence["walking"]={"distance_px":player.global_position.distance_to(from),"impulses":gas.walks}
	await clip("walk_recovery",1.0)
	await reset_at(Vector2(6,10))
	from=player.global_position
	var rolled:bool=player.try_start_phase_dash(Vector2.UP,true)
	await clip("roll",1.6)
	check(rolled and not player.dashing and player.global_position.distance_to(from)>45 and gas.rolls>0,"existing dive roll completes and creates its wider wake")
	evidence["rolling"]={"distance_px":player.global_position.distance_to(from),"impulses":gas.rolls}
	await shot("roll_after")
	key(KEY_P)
	key(KEY_G)
	await frames(5)
	var fresh:Dictionary=await dump()
	check(fresh.steps==0 and gas.paused and gas.extinguisher.particles.speed_scale==0.0,"G resets both systems without losing pause state")
	key(KEY_P)
	await reset_at(Vector2(6,10))
	player.set_physics_process(false)
	var metrics:=FileAccess.open(OUT+"/frame_times.csv",FileAccess.WRITE)
	metrics.store_line("pass,simulation,frame,wall_ms")
	for pass_index in 2:
		for running:bool in ([false,true] if pass_index==0 else [true,false]):
			gas.paused=not running
			await frames(40)
			var last:=Time.get_ticks_usec()
			for tick in 180:
				await process_frame
				var now:=Time.get_ticks_usec()
				metrics.store_line("%d,%s,%d,%.3f"%[pass_index,running,tick,(now-last)/1000.0])
				last=now
	metrics.close()
	# Same layout with production materials; no campaign integration.
	var old:WeakRef=weakref(gas)
	var old_solver:RefCounted=gas.solver
	lab.mode.select(1)
	lab.checks.furniture.button_pressed=true
	await lab.rebuild()
	await frames(5)
	# RID.is_valid only means a nonzero handle. Ask the owning device whether
	# the old texture still exists after its render-thread release callback.
	var release_state:Dictionary={"done":false,"density_alive":true,"velocity_alive":true,"solid_alive":true}
	RenderingServer.call_on_render_thread(func()->void:
		release_state.density_alive=old_solver._device.texture_is_valid(old_solver.output.texture_rd_rid)
		release_state.velocity_alive=old_solver._device.texture_is_valid(old_solver.velocity_output.texture_rd_rid)
		release_state.solid_alive=old_solver._device.texture_is_valid(old_solver.solid_output.texture_rd_rid)
		release_state.done=true)
	while not release_state.done:await process_frame
	evidence["rebuild_release"]={"old_node_released":old.get_ref()==null,"old_textures":release_state,"old_ready":old_solver.ready,"old_running":old_solver._running,"old_owned_rids":old_solver._owned.size(),"new_ready":lab.gas.solver.ready}
	check(old.get_ref()==null and not release_state.density_alive and not release_state.velocity_alive and not release_state.solid_alive and old_solver._owned.is_empty() and lab.gas.solver.ready,"rebuild releases old GPU grids and initializes the linked renderer")
	gas=lab.gas
	await frames(30)
	await shot("production_art_fixture")
	check(gas.extinguisher.particles.process_material is ShaderMaterial and gas.extinguisher.is_visible_in_tree(),"particle adapter also loads in the production-art lab fixture")
	evidence["checks"]=checks
	evidence["failures"]=failures
	evidence["gpu"]=RenderingServer.get_video_adapter_name()
	evidence["renderer"]=RenderingServer.get_current_rendering_method()
	evidence["world_viewport"]=str(lab.display.world_viewport.size)
	evidence["audio_driver"]=AudioServer.get_driver_name()
	evidence["master_muted"]=AudioServer.is_bus_mute(0)
	evidence["pid"]=OS.get_process_id()
	evidence["scope"]="interactive gas lab only; not whole-game certification"
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t"))
	lab.free()
	await frames(12)
	print("INTERACTIVE_GAS_NATIVE checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
