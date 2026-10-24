extends SceneTree
const SWEEP := preload("res://scripts/dream/melee_sweep.gd")
var checks := 0
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var player: Node = load("res://scenes/entities/dream_player.tscn").instantiate()
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	var hair: Node = player.get_node("CharacterVisual/BodyPivot/Head/SideBangs")
	hair.set_physics_process(false)
	player.equip_weapon("lucille",load("res://resources/demo_config.tres"),{})
	player.get_active_weapon().set_process(false)
	player.get_active_weapon().set_physics_process(false)
	player.set_meta(&"presentation_pointer_position",func() -> Vector2: return player.global_position + Vector2.RIGHT*200)
	for direction in 8:
		player.finish_melee_swing_snapshot()
		for i in 300: hair.step_actor(1.0/60)
		hair.bend = 0.0
		hair.bend_velocity = 0.0
		hair.segment_angles = Vector3.ZERO
		hair.segment_velocities = Vector3.ZERO
		var peak := 0.0
		for frame in 24:
			var elapsed := (frame+1)/60.0
			if elapsed < .24:
				player.apply_melee_swing_snapshot({"weapon_id":"lucille", "direction":Vector2.RIGHT.rotated(direction*PI/4),
					"elapsed":elapsed,"duration":.24,"angle":SWEEP.angle_at(SWEEP.strike_progress(elapsed,.04,.10),deg_to_rad(160)),
					"opacity":1.0-clampf((elapsed-.14)/.10,0.0,1.0)})
			else: player.finish_melee_swing_snapshot()
			hair.step_actor(1.0/60)
			peak = maxf(peak,absf(hair.segment_angles.z))
			check(absf(hair.bend)<=hair.MAX_ANGLE and hair.segment_angles.is_finite(),"Bounded hair during swing %d/%d" % [direction,frame])
		check(peak > .10,"Stationary attack visibly drives hair direction %d" % direction)
		check(player.velocity == Vector2.ZERO,"Hair does not move gameplay actor %d" % direction)
		for i in 360: hair.step_actor(1.0/60)
		check(hair.segment_angles.length()<.001,"Hair settles after recovery %d" % direction)
		check(hair.overlay_curve.polygon==hair.curve.polygon,"Healing overlay shares attack curve %d" % direction)
	var carrier: Node3D = load("res://scripts/dream/melee_sweep_visual_3d.gd").new()
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(carrier)
	world.rotation.y = PI/4
	var limits := PackedFloat32Array()
	limits.resize(33)
	limits.fill(56.0)
	var snapshot := {"reach":56.0,"origin":Vector2(100,200),"direction":Vector2.RIGHT,"arc":deg_to_rad(160),"sweep":.5,"opacity":1.0,"weapon_id":"lucille","visual_height":.37}
	carrier.sync_snapshot(world,snapshot,limits)
	check(is_equal_approx(world.to_local(carrier.global_position).y,.358),"Arc uses held reference plane, not former head-height constant")
	check(Vector2(world.to_local(carrier.global_position).x,world.to_local(carrier.global_position).z).is_equal_approx(Vector2(100,200)/32),"Map rotation preserves arc gameplay origin")
	check(carrier.mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Arc adds no shadow box")
	check(not carrier.material.shader.code.contains("depth_test_disabled"),"Wall and cabinet depth test stays enabled")
	check(is_equal_approx(hair.MAX_ANGLE*2,deg_to_rad(135)),"Original hair fan unchanged")
	world.free()
	player.queue_free()
	for i in 4: await process_frame
	print("MELEE_PRESENTATION checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
