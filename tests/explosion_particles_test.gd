extends SceneTree
const BURNING := preload("res://scripts/dream/burning_effects.gd")
var lab: Node
var world: Node
var controller: Node
var effects: Node
var native := false
var output := ""
var case_name := ""
var model := ""
const ORIGINAL := preload("res://scripts/dream/elemental_particles_3d.gd")
var checks := 0
var failures: Array[String] = []
var events: Array[Dictionary] = []
var samples: Array[Dictionary] = []


func _initialize() -> void: call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)


func frames(count: int) -> void:
	for i in count: await process_frame


func capture(label: String) -> void:
	if not native: return
	await frames(2)
	await RenderingServer.frame_post_draw
	var started := Time.get_ticks_usec()
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "Actual Camera " + label)
	events.append({"event": "capture_" + label, "readback_ms": (Time.get_ticks_usec() - started) / 1000.0})


func stop_audio() -> void:
	var audio: Node = root.get_node("SFXManager")
	for event_id in audio.players.keys(): audio.stop(event_id)
	for voice in audio.world_3d_voices:
		if is_instance_valid(voice): voice.stop()


func prepare(mode: int) -> void:
	var old: WeakRef = weakref(lab.world.floor_root)
	lab.mode.select(mode)
	var started := Time.get_ticks_usec()
	await lab.rebuild()
	await frames(2)
	check(old.get_ref() == null and lab.ready_world and lab.world.rendered_edge_failures == 0, "Lab rebuild preserves collision contracts and unloads old floor")
	events.append({"event": "load_mode_%d" % mode, "ms": (Time.get_ticks_usec() - started) / 1000.0})
	world = lab.world
	world.activate_room(1)
	world.player.set_physics_process(false)
	# Keep formal bangs / held-weapon presentation updating in frozen captures.
	world.player.set_process(true)
	world.player.global_position = Vector2(145, 224)
	world.set_process(false)
	world._update_camera_and_actor_projection(10.0)
	# Suppress fixture-only HUD that would otherwise freeze its weapon-name
	# popup when the production Camera is held still for phase comparison.
	world.ui_layer.visible = false
	if is_instance_valid(world.weapon_name_popup): world.weapon_name_popup.hide()
	lab.hud.hide()
	lab.panel.hide()
	controller = BURNING.install(world)
	controller.set_physics_process(false)
	if not model.is_empty():
		controller.effects.free()
		controller.effects = load(model).new()
		controller.add_child(controller.effects)
	effects = controller.effects
	effects.set_process(false)
	effects.rng.seed = 3871
	Engine.max_fps = 60
	await frames(10)


func point() -> Vector3:
	return world.get_gameplay_world_position(Vector2(224, 224), .20)


func blast() -> void:
	controller.explosion(point())
	check(not effects.explosion.bursts.is_empty(), "Shared explosion entry starts the floor-owned presentation")
	check(is_equal_approx(controller.hazards[-1].left, .65), "Existing gameplay hazard duration remains .65 seconds")
	check(effects.find_children("*", "CollisionObject3D", true, false).is_empty(), "Explosion particles create no gameplay collision")


func stages(mode: int) -> void:
	effects.clear()
	await capture("mode_%d_baseline" % mode)
	blast()
	var age := 0.0
	for time: float in [.02, .07, .14, .24, .36, .50, .75, 1.25, 1.9, 2.9]:
		while age + .00001 < time:
			var delta := minf(1.0 / 60.0, time - age)
			effects.step(delta)
			age += delta
		await capture("mode_%d_%04dms" % [mode, roundi(time * 1000.0)])
	check(effects.explosion.bursts.is_empty() and effects.particles.is_empty(), "Burst, smoke and embers finish cleanly")
	check(not effects.lights.any(func(light: OmniLight3D) -> bool: return light.visible), "Explosion lighting leaves no light after expiry")
	# Exact phases, local position and reset are independent of the camera angle.
	effects.explode(effects.to_local(point()), 1.65)
	effects.step(.1)
	var age_before: float = effects.explosion.bursts[0].age
	effects.step(0.0)
	check(is_equal_approx(age_before, effects.explosion.bursts[0].age), "Paused explosion clock does not advance")
	controller.clear()
	check(effects.explosion.bursts.is_empty() and controller.hazards.is_empty(), "Floor reset clears both presentation and existing hazards")
	for x: float in [-2.2, 0.0, 2.2]:
		effects.explode(effects.to_local(point()) + Vector3(x, .45, 0), 1.5)
	effects.step(.14)
	check(effects.explosion.bursts.size() == 3 and effects.lights.size() == 4, "Three train-style blasts share bounded geometry and the existing four lights")
	await capture("mode_%d_triple" % mode)
	controller.clear()
	var effect_nodes: int=effects.get_child_count()
	var plume_nodes: int=effects.explosion.get_child_count()
	for repeat in 3:
		effects.explode(effects.to_local(point()), 1.65)
		effects.step(.1)
		controller.clear()
	check(effects.get_child_count()==effect_nodes and effects.explosion.get_child_count()==plume_nodes and effects.explosion.bursts.is_empty(), "Repeated activation and reset do not accumulate effect nodes")
	if mode == 1 and native: await depth_and_light()


func picture() -> Image:
	await frames(3)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func depth_and_light() -> void:
	controller.clear()
	var before := await picture()
	effects.explode(effects.to_local(point()), 1.65)
	# Isolate real receiving-surface illumination from the visible sprite.
	effects.explosion.hide()
	for bank: MultiMesh in effects.banks: bank.visible_instance_count = 0
	for bank: MultiMesh in effects.outline_banks: bank.visible_instance_count = 0
	var lit := await picture()
	var light_state: Array[Dictionary] = []
	for light: OmniLight3D in effects.lights:
		light_state.append({"visible": light.visible, "in_tree": light.is_visible_in_tree(), "energy": light.light_energy, "world_at": str(light.global_position), "mask": light.light_cull_mask, "flash_role": light.get_meta(&"transient_explosion_light", false)})
	var at: Vector2 = world.camera_3d.unproject_position(world.get_gameplay_world_position(Vector2(224, 224), .02))
	var changed := 0
	var peak := 0.0
	for y in range(roundi(at.y) - 18, roundi(at.y) + 18):
		for x in range(roundi(at.x) - 24, roundi(at.x) + 24):
			var a := before.get_pixel(x, y)
			var b := lit.get_pixel(x, y)
			# The approved floor compresses total brightness; warm light may
			# change its hue instead of increasing its already-limited peak.
			var difference := maxf(absf(b.r-a.r), maxf(absf(b.g-a.g), absf(b.b-a.b)))
			peak = maxf(peak, difference)
			if difference > .015: changed += 1
	check(changed > 40, "Actual flash changes receiving-floor lighting without any sprite visible")
	events.append({"event": "receiving_light", "changed_floor_pixels": changed, "peak_channel_delta": peak, "lights": light_state, "screen_at": str(at), "point_world": str(point())})
	lit.save_png(output.path_join("floor_flash_only.png"))
	controller.clear()
	effects.explosion.show()
	var blocker := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4, 4.0)
	blocker.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("335577")
	blocker.material_override = material
	world.add_child(blocker)
	blocker.global_basis = world.camera_3d.global_basis
	blocker.global_position = point() + world.camera_3d.global_basis.y * 2.6 + world.camera_3d.global_basis.z * 2.0
	before = await picture()
	effects.explode(effects.to_local(point()), 1.65)
	effects.step(.20)
	var covered := await picture()
	at = world.camera_3d.unproject_position(blocker.global_position)
	var error := 0.0
	for y in range(roundi(at.y) - 8, roundi(at.y) + 8):
		for x in range(roundi(at.x) - 8, roundi(at.x) + 8):
			var a := before.get_pixel(x, y)
			var b := covered.get_pixel(x, y)
			error = maxf(error, maxf(absf(b.r-a.r), maxf(absf(b.g-a.g), absf(b.b-a.b))))
	check(error < .015, "Opaque foreground geometry occludes the actual explosion instead of receiving a screen overlay")
	events.append({"event": "opaque_depth_cover", "max_channel_error": error})
	covered.save_png(output.path_join("opaque_cover.png"))
	blocker.free()
	controller.clear()


func record_motion() -> void:
	if not native: return
	DirAccess.make_dir_recursive_absolute(output.path_join("motion"))
	effects.clear()
	effects.rng.seed = 3871
	blast()
	for frame in 72:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("motion/%04d.png" % frame))
		effects.step(1.0 / 60.0)
	controller.clear()
	events.append({"event": "motion_readbacks", "frames": 72, "simulated_fps": 60, "excluded_from_performance": true})


func replace_effects(source: Script) -> void:
	controller.clear()
	controller.effects.free()
	controller.effects = source.new()
	controller.add_child(controller.effects)
	effects = controller.effects
	effects.set_process(false)
	effects.rng.seed = 3871
	controller._sync_semantic_codes()


func sample(label: String, explosions: bool, mixed := false) -> void:
	controller.clear()
	if mixed:
		for x: float in [-1.5, -.5, .5, 1.5]: effects.emit_fire(effects.to_local(point()) + Vector3(x, 0, 1))
	await frames(20)
	var previous := Time.get_ticks_usec()
	for frame in 180:
		if explosions:
			# Same fixed 60 Hz effect phases in both repeats; no screenshots in
			# timed windows. This is sustained three-blast load, not a frame cap.
			if frame % 72 == 0:
				for x: float in [-2.2, 0.0, 2.2]:
					effects.explode(effects.to_local(point()) + Vector3(x, .45, 0), 1.5)
				events.append({"event": "triple_ignition", "phase": label, "frame": frame})
			effects.step(1.0 / 60.0)
			if mixed and frame % 12 == 0:
				effects.emit_muzzle(effects.to_local(point()) + Vector3(-2, .6, 0), Vector3.RIGHT)
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append({"phase": label, "frame": frame, "ms": (now - previous) / 1000.0})
		previous = now
	controller.clear()


func run() -> void:
	create_timer(180, true, false, true).timeout.connect(func() -> void: quit(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="): output = arg.trim_prefix("--artifact-dir=")
		if arg.begins_with("--case="): case_name = arg.trim_prefix("--case=")
		if arg.begins_with("--model="): model = arg.trim_prefix("--model=")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").contains("/.runtime/"):
		quit(2); return
	var diag := root.get_node_or_null("_DroneGameDiag")
	if diag != null: diag.free()
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 720)
	lab = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	root.add_child(lab)
	await frames(2)
	while lab.busy: await process_frame
	if not lab.ready_world: check(false, "Initial lab load"); quit(1); return
	lab.enemies.value = 0
	lab.checks.pixels.button_pressed = false
	if case_name == "performance":
		await prepare(1)
		stop_audio()
		Engine.max_fps = 0
		check(not model.is_empty(), "A/B comparison explicitly supplies a candidate before production promotion")
		var candidate: Script = load(model)
		replace_effects(ORIGINAL)
		await sample("quiet_before", false)
		await sample("old_three_blasts", true)
		replace_effects(candidate)
		await sample("new_three_blasts", true)
		replace_effects(ORIGINAL)
		await sample("old_three_blasts_repeat", true)
		replace_effects(candidate)
		await sample("new_three_blasts_repeat", true)
		replace_effects(ORIGINAL)
		await sample("old_mixed", true, true)
		replace_effects(candidate)
		await sample("new_mixed", true, true)
		await sample("quiet_after", false)
	else:
		for mode in [0, 1]:
			await prepare(mode)
			await stages(mode)
		if case_name != "stills": await record_motion()
	if native:
		check(RenderingServer.get_current_rendering_method() == "forward_plus" and world.camera_3d.get_viewport().get_visible_rect().size == Vector2(1280, 720), "Actual Forward+ Camera retains current 1280 by 720 rendering")
	var old_effect: WeakRef = weakref(effects)
	var old_plume: WeakRef = weakref(effects.explosion)
	stop_audio()
	lab.free()
	lab = null
	world = null
	controller = null
	effects = null
	await frames(8)
	await create_timer(.15, true, false, true).timeout
	check(old_effect.get_ref() == null and old_plume.get_ref() == null, "Final unload frees floor effects and plume pools")
	var timing := {}
	for phase in ["quiet_before", "old_three_blasts", "new_three_blasts", "old_three_blasts_repeat", "new_three_blasts_repeat", "old_mixed", "new_mixed", "quiet_after"]:
		var values: Array[float] = []
		for row in samples:
			if row.phase == phase: values.append(row.ms)
		if values.is_empty(): continue
		values.sort()
		timing[phase] = {"frames": values.size(), "p50_ms": values[89], "p95_ms": values[170], "p99_ms": values[178], "max_ms": values[-1]}
	var csv := FileAccess.open(output.path_join("frames.csv"), FileAccess.WRITE)
	csv.store_line("phase,frame,ms")
	for row in samples: csv.store_csv_line([row.phase, row.frame, row.ms])
	csv.close()
	var report := FileAccess.open(output.path_join("validation.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "native": native, "renderer": RenderingServer.get_current_rendering_method(), "rendering_driver": RenderingServer.get_current_rendering_driver_name(), "events": events, "timing": timing,
		"scope": "Shared production explosion entry; GameTestLab whitebox and production art, first/repeated bursts, three-blast carriage load, reset/unload. Native Forward+/Vulkan current 1280x720, private WASAPI Master=0. Manual-phase Camera readbacks excluded from separate uncapped timing. Not whole-game certification."}, "\t"))
	report.close()
	print("EXPLOSION_PARTICLES_RESULT ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
