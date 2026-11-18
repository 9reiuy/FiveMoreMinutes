extends "res://tests/explosion_particles_test.gd"
const PRODUCTION := preload("res://scripts/dream/elemental_particles_3d.gd")
const LEGACY := preload("res://tests/support/explosion_legacy_effects.gd")
const POOL := preload("res://scripts/dream/explosion_stylized_pool_3d.gd")
const GLOW := preload("res://scripts/dream/explosion_camera_glow.gd")

func picture() -> Image:
	await frames(3)
	await RenderingServer.frame_post_draw
	return world.camera_3d.get_viewport().get_texture().get_image()

func capture(title: String) -> void:
	if not native: return
	var image := await picture()
	check(image.get_size() == Vector2i(640, 360), "Formal Camera keeps 640x360")
	check(image.save_png(output.path_join(title + ".png")) == OK, "Actual Camera " + title)

func depth_and_light() -> void:
	# First isolate light from the visible geometry in the actual 640px Camera.
	controller.clear()
	var before := await picture()
	effects.explode(effects.to_local(point()), 1.65)
	effects.explosion.hide()
	var lit := await picture()
	var changed := 0
	var at: Vector2 = world.camera_3d.unproject_position(world.get_gameplay_world_position(Vector2(224, 224), .02))
	for y in range(roundi(at.y) - 18, roundi(at.y) + 18):
		for x in range(roundi(at.x) - 24, roundi(at.x) + 24):
			var a := before.get_pixel(x, y)
			var b := lit.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > .015: changed += 1
	check(changed > 40, "Actual flash changes receiving-floor lighting without effect geometry")
	events.append({"event": "receiving_light", "changed_floor_pixels": changed})
	lit.save_png(output.path_join("floor_flash_only.png"))
	controller.clear()
	effects.explosion.show()
	# A large screen-aligned slab lies ahead of the entire burst envelope.
	# The original 2m-depth narrow strip can intersect the 6m-wide shock shell.
	var blocker := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(9.0, 9.0)
	blocker.mesh = quad
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = Color("335577")
	blocker.material_override = paint
	world.add_child(blocker)
	blocker.global_basis = world.camera_3d.global_basis
	blocker.global_position = point() + world.camera_3d.global_basis.y * 1.0 + world.camera_3d.global_basis.z * 9.0
	before = await picture()
	before.save_png(output.path_join("opaque_before.png"))
	effects.explode(effects.to_local(point()), 1.65)
	effects.step(.20)
	var covered := await picture()
	at = world.camera_3d.unproject_position(blocker.global_position)
	var error := 0.0
	for y in range(roundi(at.y) - 8, roundi(at.y) + 8):
		for x in range(roundi(at.x) - 8, roundi(at.x) + 8):
			var a := before.get_pixel(x, y)
			var b := covered.get_pixel(x, y)
			error = maxf(error, maxf(absf(b.r - a.r), maxf(absf(b.g - a.g), absf(b.b - a.b))))
	check(error < .015, "Opaque foreground geometry occludes the complete burst envelope")
	events.append({"event": "opaque_depth_cover", "max_channel_error": error, "slab_world_distance": 9.0, "slab_size": "9x9"})
	covered.save_png(output.path_join("opaque_cover.png"))
	blocker.free()
	controller.clear()


func quiet() -> bool:
	var settings: Node = root.get_node("SettingsManager")
	settings._load_settings()
	settings._apply_all_audio()
	AudioServer.set_bus_mute(0, true)
	var valid: bool = settings.get_volume(&"master_volume") == 0 and AudioServer.is_bus_mute(0)
	check(valid, "Private master=0 remains muted after settings reload")
	if not valid: quit(2)
	return valid

func contracts() -> void:
	controller.clear()
	var backend: Node3D = effects.explosion
	check(backend.get_script().resource_path == "res://scripts/dream/explosion_particles_3d.gd", "Production uses the shared entry, with no candidate injection")
	check(backend.get_script().get_base_script() == POOL, "Shared entry selects the approved production backend")
	check(not backend.emit(Vector3(NAN, 0, 0), 1.0), "Nonfinite origin is refused")
	for i in 8: check(backend.emit(effects.to_local(point()), 1.0, i + 3), "Bounded burst slot %d" % i)
	check(not backend.emit(Vector3.ZERO, 1.0) and backend.bursts.size() == 8, "Ninth burst cannot grow the pool")
	controller.clear()
	var ground: Dictionary = backend._surface_at(effects.to_local(point()))
	check(absf(float(ground.height)) < .001 and bool(ground.marks), "Real room resolves its floor plane")
	ground = backend._surface_at(Vector3(5000, .2, 5000))
	check(not bool(ground.marks), "Logical void receives no floating ground decal")
	backend.set_surface_context(2.75, true)
	effects.explode(Vector3(0, 3.2, 0), 1.65)
	if native:
		var burst: Node3D = backend.pool[0]
		check(absf(backend.to_local(burst.cracks.global_position).y - 2.775) < .001, "Elevated ground survives visual strength scaling")
		var anchored: Vector3 = burst.cracks.global_position
		backend.advance(.1, Vector3(4, 0, 0))
		backend.upload()
		check(burst.cracks.global_position.is_equal_approx(anchored), "Ground crack stays anchored while smoke drifts")
	controller.clear()
	backend.set_surface_context(-.12, false)
	effects.explode(Vector3(0, .53, 0), 1.5)
	effects.step(.2)
	if native: check(not backend.pool[0].cracks.visible, "Coupling context suppresses unsupported ground cracks")
	controller.clear()
	backend.explicit_surface = false
	check(effects.lights.size() == 4 and backend.find_children("*", "Light3D", true, false).is_empty(), "No new explosion light budget")

func glow_contracts() -> void:
	if not native: return
	controller.clear()
	var camera: Camera3D = world.camera_3d
	var prior := camera.environment
	var source: Environment = prior if prior != null else camera.get_world_3d().environment
	var original_glow := source.glow_enabled
	var ambient := source.ambient_light_energy
	source.glow_enabled = false
	effects.explode(effects.to_local(point()), 1.25)
	var host: Node = camera.get_node(NodePath(String(GLOW.HOST_NAME)))
	check(camera.environment != source and camera.environment.glow_enabled and host.owners.size() == 1, "One Camera host borrows HDR glow for the active pool")
	source.ambient_light_energy = ambient + .031
	host._synchronize()
	check(is_equal_approx(camera.environment.ambient_light_energy, source.ambient_light_energy), "Non-glow scene lighting remains live during the burst")
	source.ambient_light_energy = ambient
	var other := Node.new()
	root.add_child(other)
	GLOW.request(camera, other, true)
	controller.clear()
	check(camera.environment != prior and host.owners.size() == 1, "Concurrent owner retains the same glow after one pool clears")
	GLOW.request(camera, other, false)
	other.free()
	check(camera.environment == prior and host.owners.is_empty(), "Last owner restores the exact prior Camera override")
	source.glow_enabled = true
	var intensity := source.glow_intensity
	effects.explode(effects.to_local(point()), 1.0)
	check(camera.environment == prior and is_equal_approx(source.glow_intensity, intensity), "Existing scene glow is not strengthened or replaced")
	controller.clear()
	source.glow_enabled = false
	var optics := preload("res://scripts/dream/office_light_optics.gd").new()
	optics._camera = camera
	effects.explode(effects.to_local(point()), 1.0)
	optics._sync_camera_environment(true)
	check(GLOW.scene_environment(camera) == optics._fog_environment and not optics._fog_environment.glow_enabled, "Fixture fog does not retain the temporary explosion glow")
	controller.clear()
	check(camera.environment == optics._fog_environment and not camera.environment.glow_enabled, "Burst expiry restores live fixture fog without residual glow")
	optics._sync_camera_environment(false)
	check(camera.environment == prior, "Fixture fog release returns the exact scene override")
	effects.explode(effects.to_local(point()), 1.0)
	optics._sync_camera_environment(true)
	optics._sync_camera_environment(false)
	check(GLOW.scene_environment(camera) == prior and camera.environment.glow_enabled, "Fixture fog can release while explosion glow remains active")
	controller.clear()
	check(camera.environment == prior, "Fog and burst interleaving leaves no retained override")
	optics.free()

	effects.explode(effects.to_local(point()), 1.0)
	var external := Environment.new()
	camera.environment = external
	controller.clear()
	check(camera.environment == external, "Cleanup preserves a later external Camera override")
	camera.environment = prior
	source.glow_enabled = original_glow
	source.ambient_light_energy = ambient

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output = argument.trim_prefix("--artifact-dir=")
		if argument.begins_with("--case="): case_name = argument.trim_prefix("--case=")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").contains("/.runtime/"):
		quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	if not quiet(): return
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	root.size = Vector2i(1280, 720)
	lab = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	root.add_child(lab)
	await frames(2)
	while lab.busy: await process_frame
	if not lab.ready_world: quit(1); return
	lab.enemies.value = 0
	if case_name == "performance":
		await prepare(1)
		stop_audio()
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		# Prime both render paths outside measured windows, without clearing caches.
		for script: Script in [LEGACY, PRODUCTION]:
			replace_effects(script)
			effects.explode(effects.to_local(point()), 1.5)
			for i in 40:
				effects.step(1.0 / 30.0)
				await process_frame
			controller.clear()
		replace_effects(LEGACY)
		await sample("quiet_before", false)
		await sample("old_three_blasts", true)
		replace_effects(PRODUCTION)
		await sample("new_three_blasts", true)
		replace_effects(LEGACY)
		await sample("old_three_blasts_repeat", true)
		replace_effects(PRODUCTION)
		await sample("new_three_blasts_repeat", true)
		await sample("new_mixed", true, true)
		await sample("quiet_after", false)
	else:
		for mode in [0, 1]:
			await prepare(mode)
			if not quiet(): return
			await stages(mode)
			contracts()
			glow_contracts()
	check(not native or RenderingServer.get_current_rendering_method() == "forward_plus", "Project Forward+ renderer retained")
	var effect_owner: WeakRef = weakref(effects)
	stop_audio()
	lab.free()
	await frames(8)
	check(effect_owner.get_ref() == null, "Floor unload releases production effect owner")
	var stats := {}
	for row in samples:
		if not stats.has(row.phase): stats[row.phase] = []
		stats[row.phase].append(float(row.ms))
	var timing := {}
	for phase: String in stats:
		var values: Array = stats[phase]
		values.sort()
		var over := 0
		for value: float in values:
			if value > 80: over += 1
		timing[phase] = {"frames": values.size(), "p50_ms": values[90], "p95_ms": values[171], "p99_ms": values[178], "max_ms": values[-1], "over_80ms": over}
	var csv := FileAccess.open(output.path_join("frames.csv"), FileAccess.WRITE)
	csv.store_line("phase,frame,ms")
	for row in samples: csv.store_csv_line([row.phase, row.frame, row.ms])
	csv.close()
	var report := FileAccess.open(output.path_join("validation.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "timing": timing, "events": events, "scope": "Production shared entry, whitebox and formal art, surface/void/height, Camera glow ownership and cleanup. Native 640x360 Forward+; private muted WASAPI. Timing is warm uncapped frame wall time with no readbacks, not whole-game certification."}, "\t"))
	report.close()
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	print("STYLIZED_EXPLOSION_RESULT checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
