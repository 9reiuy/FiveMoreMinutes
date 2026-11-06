extends SceneTree
## Actual Main -> generated floor. Fixed seed and identical Camera for light ablations.
const OUT := "res://.runtime/window_drone_lighting_20261102"
var main: Node
var world: Node
var tag := "before"
var records: Array = []
var checks := 0
var failures := 0
var metrics: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func frames(n := 8) -> void:
	for i in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func shot(label: String) -> Image:
	await frames(12); await RenderingServer.frame_post_draw
	var image: Image = world.camera_3d.get_viewport().get_texture().get_image()
	image.save_png(OUT + "/" + tag + "_" + label + ".png")
	return image
func difference(a: Image,b: Image) -> int:
	var changed := 0
	for y in range(2,358,2):
		for x in range(2,638,2):
			if b.get_pixel(x,y).get_luminance()-a.get_pixel(x,y).get_luminance() > 0.02: changed+=1
	return changed
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps = 60; AudioServer.set_bus_mute(0, true)
	create_timer(240., true, false, true).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	if not OS.get_environment("FMM_LIGHTING_TAG").is_empty(): tag = OS.get_environment("FMM_LIGHTING_TAG")
	main = load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(70)
	main.persistent_day_state = main._create_initial_state()
	seed(424242); main._show_dream("basic")
	while main.transition_running: await frames(1)
	world = main._supported_dream_world
	while world.floor_transition_in_progress: await frames(1)
	await frames(40)
	world.player.invulnerability_left = 999.; world.player.set_physics_process(false)
	print("AUDIT seed=", world.active_seed, " drones=", world._exterior_drone_root.get_child_count())
	var drone: Node3D = world._exterior_drone_root.get_child(0)
	var rid: int = int(drone.get_meta(&"dream_room_id"))
	var bounds: Rect2 = world._room_bounds_pixels(rid, 0.)
	world.set_current_room_id(rid); world._rebuild_active_room_presentation(); world.activate_room(rid)
	world.player.global_position = bounds.get_center()
	await frames(40)
	for enemy in world.enemy_root.get_children():
		if enemy is EmployeeEnemy: enemy.set_physics_process(false); enemy.set_process(false)
	for unit in world._exterior_drone_root.get_children(): unit.set_physics_process(false)
	world.camera_aim_offset = Vector3.ZERO
	world._update_camera_and_actor_projection(0.)
	world.set_process(false); world.set_physics_process(false)
	var overview := await shot("room")
	var dither: Node = world.get_node("OfficeDitherLighting")
	var walls := 0; var furniture_classified := 0; var windows := 0; var lit_windows := 0
	for wall in world.wall_root.get_children():
		if not wall.has_method("set_window_variant"): continue
		walls += 1
		var mesh: MeshInstance3D = wall.wall_mesh
		if dither._is_furniture_occluder(mesh): furniture_classified += 1
		var mats: Array = []
		for s in mini(mesh.mesh.get_surface_count(), 2):
			var m: Material = mesh.get_active_material(s)
			if m is ShaderMaterial:
				mats.append({"shader": m.shader.resource_path, "ambient_disabled": m.shader.code.contains("ambient_light_disabled"), "tonal": m.get_shader_parameter("office_tonal_sample"), "atlas": str(m.get_shader_parameter("atlas"))})
		if records.size() < 8: records.append({"wall": str(wall.name), "edge": wall.get_meta(&"edge"), "materials": mats})
		if wall.window_variant:
			windows += 1
			if is_instance_valid(wall.window_light) and wall.window_light.is_visible_in_tree(): lit_windows += 1
	print("AUDIT walls=", walls, " classified_furniture=", furniture_classified, " windows=", windows, " active_window_lights=", lit_windows, " room=", rid)
	print("AUDIT drone_energy=", drone._spot_light.light_energy, " shadow=", drone._spot_light.shadow_enabled)
	metrics={"seed":world.active_seed,"room":rid,"walls":walls,"windows":windows,"active_window_lights":lit_windows,"materials":records}
	if tag != "before":
		check(lit_windows>0 and lit_windows<=world.shadow_manager.WINDOW_LIMITS[world.shadow_manager.quality],"real room uses bounded exterior aperture lights")
		var aligned := true
		for wall in world.wall_root.get_children():
			if wall.get("office_full_mesh") != null: aligned = aligned and wall.shadow_mesh.mesh == wall.office_full_mesh
		check(aligned,"full-height wall blockers match approved thickness/joints across the floor")
		check(drone._spot_light.shadow_enabled and drone._spot_light.light_energy>0.5,"actual spawned drone keeps a shadowed patrol searchlight")
		var material: ShaderMaterial = drone._body.get_node("Body").material_override
		check(float(material.get_shader_parameter("roughness_amount"))>=0.8 and float(material.get_shader_parameter("metallic_amount"))<=0.05,"formal drone retains pixel texture with matte diffuse response")
		check(drone._spot_light.shadow_caster_mask&4==0,"drone does not duplicate the chosen player body shadow")
		check(not drone.outline.records.any(func(record: Dictionary) -> bool: return record.source.get_ref()==drone._beam),"air scattering is excluded from the model silhouette")
		var bounce_ok := true; var bounce_on := 0
		for lamp in world.ceiling_light_root.find_children("*","Light3D",true,false):
			if not bool(lamp.get_meta(&"fixture_bounce",false)) or not lamp.is_visible_in_tree(): continue
			bounce_on+=1
			bounce_ok=bounce_ok and lamp.shadow_enabled and controller_owns_shadow(lamp) and int(lamp.get_meta(&"shadow_room_id",-1))==rid
		check(bounce_ok and bounce_on==1,"only the current room has reflected fixture light, with a real allocated shadow")
	# Real scene sources only; compare the original exterior and interior groups.
	var controller: Node = world.shadow_manager
	controller.set_process(false)
	var interior: Array = []
	for lamp in world.ceiling_light_root.find_children("*", "Light3D", true, false):
		interior.append([lamp, lamp.visible]); lamp.hide()
	var exterior := await shot("exterior_only")
	# Isolate actual per-window sky sources from the existing shared moon light.
	var sources: Array=[]
	for source in controller.window_sources:
		if source.light.visible: sources.append(source.light); source.light.hide()
	var moon_only := await shot("moon_only")
	for lamp in sources: lamp.show()
	if tag != "before":
		metrics.window_changed_samples=difference(moon_only,exterior)
		check(metrics.window_changed_samples>80,"window source alone changes real room receivers (%d samples)"%metrics.window_changed_samples)
		# Close the ACTUAL exterior apertures using their own solid-wall variant.
		# This must suppress the light on floor receivers, not just hide an effect.
		var apertures: Array=[]
		for wall in world.wall_root.get_children():
			if wall.get("window_variant") != true: continue
			apertures.append([wall.shadow_mesh,wall.shadow_mesh.mesh])
			wall.shadow_mesh.mesh=wall.get("_base_wall_mesh")
		var blocked:=await shot("windows_blocked")
		for pair in apertures: pair[0].mesh=pair[1]
		var open_total:=0.0; var closed_total:=0.0; var samples:=0
		for cell in world.rooms[rid].get("usable_cells",[]):
			var point:=Vector2(cell)*32.0
			if not world._content_position_is_clear(point,22.0,false): continue
			var p: Vector2=world.camera_3d.unproject_position(world.get_gameplay_world_position(point,0.035))
			if not Rect2(3,3,634,354).has_point(p): continue
			open_total+=exterior.get_pixelv(p).get_luminance(); closed_total+=blocked.get_pixelv(p).get_luminance(); samples+=1
		metrics.window_open_mean=open_total/maxi(samples,1); metrics.window_blocked_mean=closed_total/maxi(samples,1)
		check(metrics.window_open_mean>metrics.window_blocked_mean+0.025,"closing real apertures blocks exterior light on %d clear floor receivers (%.3f -> %.3f)"%[samples,metrics.window_open_mean,metrics.window_blocked_mean])
	world.shadow_manager.sun.hide()
	for wall in world.wall_root.get_children():
		if wall.get("window_light") is Light3D: wall.window_light.hide()
	var dark_lights: Array=[]
	for light in world.find_children("*","Light3D",true,false):
		dark_lights.append([light,light.visible]); light.hide()
	await shot("ambient_only")
	for pair in dark_lights: pair[0].visible=pair[1]
	for pair in interior: pair[0].visible = pair[1]
	world.shadow_manager.sun.show()
	for wall in world.wall_root.get_children():
		if wall.has_method("_update_window_light"): wall._update_window_light()
	await shot("restored")
	controller.set_process(true)
	# Face the actual window patrol, then let its normal detection aim the lamp.
	world.player.global_position = drone.boundary_2d+drone.inward_normal*64.0
	world._update_camera_and_actor_projection(0.)
	drone._aim_target=world.player.global_position; drone._spot_elapsed=0.1
	drone._apply_facing(); drone._update_beam_length()
	var normal_energy: float=drone._spot_light.light_energy
	drone._set_light(0.0); await frames(30)
	var drone_off:=await shot("drone_off")
	drone._set_light(normal_energy); await frames(30)
	var drone_on:=await shot("drone_on")
	metrics.drone_changed_samples=difference(drone_off,drone_on)
	print("DRONE pixel=",world.camera_3d.unproject_position(drone.global_position)," beam=",drone._beam_material.get_shader_parameter("visible_length")," changed=",metrics.drone_changed_samples)
	if tag!="before": check(metrics.drone_changed_samples>12,"real patrol light projects onto the room (%d samples)"%metrics.drone_changed_samples)
	if tag!="before":
		# Real patrol/acquisition/fire; capture at elapsed wall-clock cadence.
		# Readback frames are visual evidence, never performance measurements.
		drone.set_physics_process(true)
		var capture_times: Array=[]
		DirAccess.make_dir_recursive_absolute(OUT+"/motion")
		for i in 90:
			await frames(2); await RenderingServer.frame_post_draw
			capture_times.append(Time.get_ticks_msec())
			world.camera_3d.get_viewport().get_texture().get_image().save_png(OUT+"/motion/%03d.png"%i)
		FileAccess.open(OUT+"/motion/times.json",FileAccess.WRITE).store_string(JSON.stringify(capture_times))
		drone.set_physics_process(false)
	# Another real archetype confirms this does not replace per-room pixel art.
	for room in world.rooms:
		if preload("res://scripts/dream/office_art_room_style.gd").key(room) != "office": continue
		var office_id:=int(room.id)
		world.set_current_room_id(office_id); world.activate_room(office_id)
		world.player.global_position=world._room_bounds_pixels(office_id,0.).get_center()
		world._update_camera_and_actor_projection(0.)
		await shot("office")
		break
	if tag!="before":
		for quality in ["low","high","standard"]:
			controller.set_quality(quality); await frames(22)
			var count:=0
			for source in controller.window_sources:
				if source.light.is_visible_in_tree(): count+=1
			check(count<=controller.WINDOW_LIMITS[quality],"%s window shadow-source cap (%d)"%[quality,count])
		controller.set_suspended(true); await frames(2)
		check(controller.window_sources.all(func(source: Dictionary) -> bool: return not source.light.is_visible_in_tree()),"elevator suspension hides all exterior aperture sources")
		controller.set_suspended(false)
		controller.prepare_loading_selection()
		var pending_bounce: Array=controller.active.keys().filter(func(lamp: Light3D) -> bool: return bool(lamp.get_meta(&"fixture_bounce",false)))
		check(pending_bounce.size()==1 and pending_bounce.all(func(lamp: Light3D) -> bool: return lamp.shadow_opacity>=0.999 and lamp.light_energy<=0.001),"new reflected source starts at zero energy with full occlusion, never transparent shadows")
		await frames(22)
	metrics.checks=checks; metrics.failures=failures
	FileAccess.open(OUT + "/" + tag + "_audit.json", FileAccess.WRITE).store_string(JSON.stringify(metrics,"\t"))
	print("WINDOW_DRONE_LIGHTING checks=",checks," failures=",failures)
	main.queue_free(); await frames(8); quit(1 if failures else 0)

func controller_owns_shadow(lamp: Light3D) -> bool:
	return world.shadow_manager.active.has(lamp)
