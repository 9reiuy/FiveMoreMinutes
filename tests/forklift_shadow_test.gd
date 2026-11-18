extends "res://tests/h06_forklift_route_flash_probe.gd"
const SHADOW := preload("res://scripts/dream/props/forklift_shadow_caster.gd")
var caster: Node3D
var final_checks_done := false


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	print("FORKLIFT_SHADOW_TEST_PID ", OS.get_process_id())
	create_timer(180.0).timeout.connect(func() -> void: push_error("forklift shadow validation timed out"); quit(1))
	call_deferred("run")


func check_casters(label: String) -> void:
	check(caster.sources.size() == 5 and caster.casters.size() == 5, label + " uses the body and four original wheel meshes")
	for i in caster.sources.size():
		var source: MeshInstance3D = caster.sources[i].mesh
		var carrier: MeshInstance3D = caster.casters[i]
		check(source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and carrier.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			and carrier.material_override == caster.depth_material
			and carrier.mesh == source.mesh
			and carrier.global_transform.is_equal_approx(source.global_transform), label + " carrier %d preserves geometry/pose with its own depth material" % i)


func trace_case(label: String, count: int, fire := false, pointer_pan := false) -> void:
	if label == "before_boarding":
		caster = SHADOW.install(lift.visual)
		check_casters("initial 1-2")
	for i in count:
		if fire and i % 22 == 0: shoot(true)
		if fire and i % 22 == 3: shoot(false)
		await physics_frame
	shoot(false)
	if label == "after_boarding":
		check_casters("after E boards")
		check(lift.visual.body_mesh_instance.get_active_material(0) is StandardMaterial3D, "occupied canopy retains original opaque display material")
		await capture("01-occupied-stable-shadow")
	if label != "after_shooting_pan": return
	check_casters("after exit and shooting")
	world.restart_queued = true
	for enemy in world.enemy_root.get_children(): enemy.set_physics_process(false)
	for projectile in get_nodes_in_group(&"dream_projectiles"): projectile.queue_free()
	await frames(60)
	await capture("02-dismounted-stable-shadow")
	# Controlled native comparison. Same Camera/load/audio, no screenshot readbacks in samples.
	Engine.max_fps = 0
	for enabled in [false, true, false, true]:
		caster.set_enabled(enabled)
		await frames(45)
		await sample("shadow-carriers-on" if enabled else "original-shadow-materials")
	caster.set_enabled(true)
	# Driver material transitions and suspension must never replace shadow materials.
	park(Vector2(-18.8,-30.1),-PI)
	place_feet(lift._seat_position()/32.0+Vector2(0,-1.2))
	world.player.airborne_knockback = false
	world.player.external_knockback_left = 0.0
	world.player.knockback_recovery_left = 0.0
	check(lift.board(world.player), "driver can board again with stable shadow carriers")
	lift.visual.set_body_roll(.06)
	lift.visual.animate_drive(.5,.25,true)
	check_casters("after suspension and rear-wheel steering")
	check(lift.try_exit(), "driver can leave the shadow-enabled vehicle")
	check_casters("second dismount")
	# Reparent exactly as a streamed region transfer; carriers must not be retired on tree exit.
	var temp := Node3D.new()
	world.add_child(temp)
	lift.visual.reparent(temp,true)
	await frames(3)
	check_casters("after region visual reparent")
	lift.visual.reparent(world.blockout.floor_root,true)
	temp.queue_free()
	await frames(3)
	var canopy := lift.visual.body_mesh_instance.get_active_material(0)
	check(SHADOW.install(lift.visual) == caster, "repeat installation reuses the existing component")
	check(lift.visual.body_mesh_instance.get_active_material(0) == canopy, "shadow installation leaves visible cutout material intact")
	lift.take_damage(lift.hp-90.0)
	await frames(18)
	check(lift.smoking and lift.hp == 90.0, "low-health smoke coexists with stable shadows")
	lift.take_damage(lift.hp)
	await frames(5)
	check(lift.destroyed and caster.casters.all(func(part: MeshInstance3D) -> bool: return not part.is_visible_in_tree()), "explosion hides the vehicle and all shadow carriers")
	FileAccess.open(evidence.path_join("validation.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,
		"pid":OS.get_process_id(),"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),
		"scope":"Native 1-1 entry -> 1-2 door -> board -> drive -> exit/shoot. Shadow mesh/material/pose lifecycle, reparent, smoke/destruction; bounded matched samples, not whole-game performance certification."},"\t"))
	final_checks_done = true
	check(final_checks_done, "shadow validation completed all stages")
