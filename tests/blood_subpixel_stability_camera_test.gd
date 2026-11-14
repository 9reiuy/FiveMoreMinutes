extends SceneTree
const FREEZE=preload("res://tests/support/frozen_render_comparison.gd")
var out: String="user://blood_subpixel_stability"
var report: Dictionary={"worlds":[]}
func frames(count: int=4) -> void:
	for index in count:await process_frame
func save(label: String,view: Viewport) -> Image:
	await frames(3);await RenderingServer.frame_post_draw
	var picture:=view.get_texture().get_image();picture.save_png(out+"/"+label+".png");return picture
func probe(formal: bool) -> void:
	var label: String="formal" if formal else "level01"
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn" if formal else "res://scenes/testing/MegastructureWhitebox.tscn").instantiate()
	world.generate_on_ready=false;world.persist_profile=false;world.spawn_content=false;world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world;display.preview_mode=false;root.add_child(display);await frames(10)
	if not world.regenerate(42001):push_error("World generation failed");quit(2);return
	await frames(30)
	if not formal:world._finish_opening_time()
	world.transition_phase=&"IDLE"
	var point:=Vector2(5,6)*32.0
	if formal:
		for room in world.rooms:
			if String(room.get("archetype",""))=="open_office":point=Vector2(room.center_cell)*32.0;world.activate_room(int(room.id));break
	world.player.global_position=point+Vector2(-28,40);world.player.set_physics_process(false)
	await frames(40)
	world._content_rng.seed=550123
	world.spawn_death_blood_pool(point,world.current_room_id,1.5)
	world.spawn_blood_trail(point+Vector2(48,16),world.current_room_id,Vector2.RIGHT,1.2,0)
	var sequence: Array=[]
	for frame in 90:
		world.player.global_position=point+Vector2(-28+sin(maxi(frame-24,0)*TAU/60.0)*28,40)
		var picture: Image=await save(label+"_native_%03d"%frame,display.world_viewport)
		var states: Array=[];var warm_pixels:=0
		for y in picture.get_height():
			for x in picture.get_width():
				var color:=picture.get_pixel(x,y)
				if color.r>color.g*1.5 and color.r>color.b*1.5 and color.r>.1:warm_pixels+=1
		for blood in world.world_effects_root.get_children():
			if not blood is BlackBloodEffect or not blood.has_meta(&"depth_visual_bridge"):continue
			var reference: WeakRef=blood.get_meta(&"depth_visual_bridge");var bridge: Node3D=reference.get_ref()
			if not is_instance_valid(bridge):continue
			states.append({"source":blood.get_instance_id(),"pixels":blood.ground_pixels.size(),"pool":blood.office_pool_core,"settled":blood.is_visual_settled(),"source_visible":blood.visible,"sprite_visible":bridge.actor_sprite.visible,"capture_initialized":bridge.capture_initialized,"pending":bridge.furniture_capture_pending,"frozen":bridge.static_visual_frozen,"freeze_pending":bridge.freeze_pending,"processing":bridge.is_processing(),"room_active":bridge.room_presentation_active})
		sequence.append({"frame":frame,"warm_pixels":warm_pixels,"states":states,"camera":str(world.camera_3d.global_position)})
	report.worlds.append({"world":label,"point":point,"native_sequence":sequence})
	print("NATIVE_WORLD ",label," sources=",sequence.back().states.size()," visible_frames=",sequence.filter(func(row):return row.states.any(func(state):return state.sprite_visible)).size())
	await after_native(world,display,label)
	display.queue_free();await frames(10)

const OLD=preload("res://tests/fixtures/blood_point_alpha_reference.gdshader")
const NEW=preload("res://shaders/dream3d/blood_lit_carrier.gdshader")
var checks: Array=[]
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):out=argument.trim_prefix("--artifact-dir=")
	call_deferred("run_fix")
func check(ok: bool,label: String) -> void:
	checks.append({"pass":ok,"description":label});print("PASS " if ok else "FAIL ",label)
func run_fix() -> void:
	await process_frame
	var master:=AudioServer.get_bus_index(&"Master")
	if master<0 or not AudioServer.is_bus_mute(master):
		if master>=0:AudioServer.set_bus_mute(master,true)
		quit(1);return
	preload("res://tests/support/background_gpu.gd").start(self)
	DirAccess.make_dir_recursive_absolute(out)
	for formal in [false,true]:await probe(formal)
	report.pid=OS.get_process_id();report.audio=AudioServer.get_driver_name();report.renderer=RenderingServer.get_current_rendering_method();report.checks=checks
	report.failures=checks.filter(func(row):return not row.pass).size()
	FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("BLOOD_STABILITY checks=",checks.size()," failures=",report.failures);quit(1 if report.failures else 0)
func assign(carriers: Array,shader: Shader,mask: bool) -> void:
	for entry in carriers:
		var material: ShaderMaterial=entry.material.duplicate();material.shader=shader
		if mask:
			material.set_shader_parameter("blood_albedo",Color.WHITE)
			material.set_shader_parameter("dark_glow_strength",.5)
			material.set_shader_parameter("lit_glow_strength",0.0)
		entry.bridge.actor_sprite.material_override=material
func visible_pixels(image: Image) -> int:
	var count:=0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).r>.15:count+=1
	return count
func measure(camera: Camera3D,view: Viewport,points: Array[Vector3],origin: Vector3,label: String) -> Dictionary:
	var sequence: Array=[]
	for index in 32:
		camera.global_position=origin+Vector3(index*.02,0,index*.015)
		var image: Image=await save(label+"_%02d"%index,view)
		var values: Array=[];var visible: Array=[]
		for point in points:
			var at:=Vector2i(camera.unproject_position(point));var value:=0.0
			if Rect2i(Vector2i.ZERO,image.get_size()).has_point(at):value=image.get_pixelv(at).r
			values.append(value);visible.append(value>.15)
		sequence.append({"values":values,"visible":visible})
	var flips:=0;var unstable:=0;var stable_visible:=0;var pop_energy:=0.0;var jump_energy:=0.0;var large_jumps:=0
	for sample in points.size():
		var changes:=0
		for frame in range(1,sequence.size()):
			if sequence[frame].visible[sample]!=sequence[frame-1].visible[sample]:changes+=1
			var change: float=absf(sequence[frame].values[sample]-sequence[frame-1].values[sample])
			pop_energy+=change;jump_energy+=change*change
			if change>.5:large_jumps+=1
		flips+=changes
		if changes>0:unstable+=1
		elif sequence[0].visible[sample]:stable_visible+=1
	return {"samples":points.size(),"flips":flips,"unstable":unstable,"stable_visible":stable_visible,"temporal_delta":pop_energy,"jump_energy":jump_energy,"large_jumps":large_jumps,"sequence":sequence}
func after_native(world: Node3D,display: Control,label: String) -> void:
	var carriers: Array=[];var points: Array[Vector3]=[];var before_state: Array=[]
	for blood in world.world_effects_root.get_children():
		if not blood is BlackBloodEffect or not blood.has_meta(&"depth_visual_bridge"):continue
		var bridge: Node3D=(blood.get_meta(&"depth_visual_bridge") as WeakRef).get_ref()
		if not is_instance_valid(bridge):continue
		var image: Image=bridge.actor_sprite.texture.get_image()
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x,y).a>.999 and x%2==0 and y%2==0:
					var local: Vector3=Vector3(x+.5-image.get_width()*.5,image.get_height()*.5-y-.5,0)*bridge.actor_sprite.pixel_size
					points.append(bridge.actor_sprite.to_global(local))
		carriers.append({"bridge":bridge,"material":bridge.blood_material,"layers":bridge.actor_sprite.layers,"source":blood})
		before_state.append(hash([blood.ground_pixels,blood.ground_pixel_types,blood.content_version,blood.ground_visual_scale]))
	check(not points.is_empty(),label+" uses completed native blood captures")
	check(display.world_viewport.size==Vector2i(640,360),label+" retains the existing 640x360 render resolution")
	var frozen:=FREEZE.freeze(self)
	var camera: Camera3D=world.camera_3d;var origin: Vector3=camera.global_position
	# Actual lit game Camera at identical poses; these are the art comparison.
	for candidate in [false,true]:
		assign(carriers,NEW if candidate else OLD,false)
		for index in 12:
			camera.global_position=origin+Vector3(index*.04,0,index*.03)
			await save(label+("_new_art_" if candidate else "_old_art_")+"%02d"%index,display.world_viewport)
	var old_environment: Environment=camera.environment;var old_mask:=camera.cull_mask;var old_fov:=camera.fov
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_energy=0.0
	camera.environment=environment;camera.cull_mask=1<<20
	for entry in carriers:entry.bridge.actor_sprite.layers=1<<20
	assign(carriers,OLD,true)
	var baseline: Dictionary=await measure(camera,display.world_viewport,points,origin,label+"_old_mask")
	assign(carriers,NEW,true)
	var candidate: Dictionary=await measure(camera,display.world_viewport,points,origin,label+"_new_mask")
	check(baseline.flips>20,label+" baseline reproduces subpixel popping")
	check(candidate.flips==0 and candidate.stable_visible==points.size(),label+" fixed shader keeps every tracked blood texel visible while moving")
	check(candidate.jump_energy<baseline.jump_energy*.3 and candidate.large_jumps==0,label+" removes large brightness jumps and reduces temporal jump energy")
	# A physical foreground volume must still hide the blood behind it.
	camera.global_position=origin
	var center:=Vector3.ZERO
	for point in points:center+=point
	center/=points.size()
	var cover:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.65,.9,.65);cover.mesh=box;cover.layers=1<<20
	var black:=StandardMaterial3D.new();black.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;black.albedo_color=Color.BLACK;cover.material_override=black
	world.actor_depth_bridges_root.add_child(cover);cover.global_basis=Basis.IDENTITY;cover.global_position=center+Vector3.UP*.49
	var blocked: Image=await save(label+"_foreground_cover",display.world_viewport)
	var covered:=0;var leaks:=0
	for point in points:
		if absf(point.x-center.x)<.23 and absf(point.z-center.z)<.23:
			covered+=1
			if blocked.get_pixelv(Vector2i(camera.unproject_position(point))).r>.05:leaks+=1
	check(covered>3 and leaks==0,label+" real foreground geometry continues to occlude blood")
	cover.queue_free();await frames(3)
	# Magnified source pixels must retain their exact original hard outline.
	camera.global_position=origin;camera.fov=old_fov*.4
	assign(carriers,OLD,true);var near_old: Image=await save(label+"_near_old",display.world_viewport)
	assign(carriers,NEW,true);var near_new: Image=await save(label+"_near_new",display.world_viewport)
	var near_difference:=FREEZE.difference(near_old,near_new)
	check(near_difference.exact and visible_pixels(near_new)>200,label+" magnified blood pixels keep the exact nearest-neighbour mask")
	# The same shader also serves solid airborne droplets without a capture.
	for entry in carriers:entry.bridge.actor_sprite.hide()
	var solid:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.8,.8);solid.mesh=quad;solid.layers=1<<20
	world.actor_depth_bridges_root.add_child(solid);solid.global_basis=camera.global_basis
	solid.global_position=points[points.size()/2]+Vector3.UP*.6
	var images: Array=[]
	for shader in [OLD,NEW]:
		var material:=ShaderMaterial.new();material.shader=shader
		material.set_shader_parameter("use_captured_alpha",false);material.set_shader_parameter("blood_albedo",Color.WHITE);material.set_shader_parameter("dark_glow_strength",.5)
		solid.material_override=material;images.append(await save(label+("_air_old" if images.is_empty() else "_air_new"),display.world_viewport))
	var airborne_difference:=FREEZE.difference(images[0],images[1])
	check(airborne_difference.exact and visible_pixels(images[1])>100,label+" solid airborne blood retains its original pixels")
	solid.queue_free()
	var after_state: Array=[]
	for entry in carriers:
		entry.bridge.actor_sprite.show();entry.bridge.actor_sprite.layers=entry.layers;entry.bridge.actor_sprite.material_override=entry.material
		var blood: Node2D=entry.source;after_state.append(hash([blood.ground_pixels,blood.ground_pixel_types,blood.content_version,blood.ground_visual_scale]))
	check(before_state==after_state,label+" blood shape, growth payload and lifetime data are unchanged")
	camera.cull_mask=old_mask;camera.environment=old_environment;camera.fov=old_fov;camera.global_position=origin
	var costs: Array=await stress(world,display,carriers,label)
	FREEZE.restore(self,frozen)
	report.worlds.back()["stability"]={"baseline":baseline,"candidate":candidate,"near_difference":near_difference,"airborne_difference":airborne_difference,"viewport":str(display.world_viewport.size),"overdraw_cost":costs}
	print("STABILITY ",label," old_flips=",baseline.flips," new_flips=",candidate.flips," old_delta=",baseline.temporal_delta," new_delta=",candidate.temporal_delta," near=",near_difference.exact)
func stress(world: Node3D,display: Control,carriers: Array,label: String) -> Array:
	if carriers.is_empty():return []
	var sprites: Array[Sprite3D]=[]
	var template: Sprite3D=carriers[0].bridge.actor_sprite
	for index in 24:
		var sprite: Sprite3D=template.duplicate(0);world.actor_depth_bridges_root.add_child(sprite)
		sprite.global_position=template.global_position+Vector3((index%6-2.5)*.42,.0001*index,(index/6-1.5)*.42)
		sprites.append(sprite)
	var saved_fps:=Engine.max_fps;Engine.max_fps=0
	var costs: Array=[]
	for shader in [OLD,NEW,OLD]:
		var material: ShaderMaterial=carriers[0].material.duplicate();material.shader=shader
		for sprite in sprites:sprite.material_override=material
		await frames(32)
		var samples: Array[float]=[];var previous:=Time.get_ticks_usec()
		for index in 96:
			await process_frame
			var now:=Time.get_ticks_usec();samples.append(float(now-previous)/1000.0);previous=now
		samples.sort()
		costs.append({"candidate":shader==NEW,"p50_ms":samples[48],"p95_ms":samples[91],"max_ms":samples.back(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"count":sprites.size(),"scope":"Steady minimized actual-render frame intervals with 24 extra overlapping blood quads; no image readback during timing, not pure GPU time or full-game FPS."})
	Engine.max_fps=saved_fps
	for sprite in sprites:sprite.queue_free()
	check(float(costs[1].p95_ms)<maxf(16.7,maxf(costs[0].p95_ms,costs[2].p95_ms)+3.0),label+" bounded overdraw check has no material frame-time regression")
	check(costs[1].draw_calls==costs[0].draw_calls and costs[1].draw_calls==costs[2].draw_calls,label+" retains the original opaque render path without extra draw calls")
	print("OVERDRAW ",label," ",JSON.stringify(costs));return costs
