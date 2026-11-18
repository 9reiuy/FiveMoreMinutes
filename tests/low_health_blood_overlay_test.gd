extends SceneTree

const OVERLAY_SCENE := preload("res://scenes/ui/low_health_blood_overlay.tscn")

var output := "res://.runtime/low_health_blood_20261119"
var checks: Array[Dictionary] = []
var native := false


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):
			output = argument.trim_prefix("--artifact-dir=")
	call_deferred("run")


func frames(count: int = 4) -> void:
	for _i in count:
		await process_frame


func check(ok: bool, description: String) -> void:
	checks.append({"pass": ok, "description": description})
	print("PASS " if ok else "FAIL ", description)


func snapshot(name: String) -> void:
	if not native:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))


func _deal_unblocked_damage(player: Node, amount: float) -> void:
	player.invulnerability_left = 0.0
	player.dash_invulnerability_left = 0.0
	player.has_shield = false
	player.dissociation_ready = false
	player.helmet_equipped = false
	player.receive_damage(amount)


func run() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	if master < 0 or not AudioServer.is_bus_mute(master):
		if master >= 0:
			AudioServer.set_bus_mute(master, true)
		push_error("Private mute check failed; aborting run.")
		quit(1)
		return

	native = DisplayServer.get_name() != "headless"
	if native:
		preload("res://tests/support/background_gpu.gd").start(self)
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(210.0, true, false, true).timeout.connect(func():
		push_error("Low-health blood overlay validation timed out")
		quit(2)
	)

	# 1. Standalone threshold math checks.
	var standalone := OVERLAY_SCENE.instantiate()
	root.add_child(standalone)
	await frames(2)
	check(not standalone.visible and not standalone.is_active(), "Standalone overlay starts hidden at full health")
	check(not standalone.is_low_health(100.0, 100.0), "100/100 is above 1/3 threshold")
	check(not standalone.is_low_health(34.0, 100.0), "34/100 is strictly above 1/3 threshold")
	check(standalone.is_low_health(30.0, 90.0), "Exact 1/3 (30/90) activates low-health overlay")
	check(standalone.is_low_health(20.0, 60.0), "Exact 1/3 (20/60) activates low-health overlay")
	check(standalone.is_low_health(33.33, 100.0), "33.33/100 activates low-health overlay")
	check(not standalone.is_low_health(0.0, 100.0), "0/100 dead state does not hold persistent blood overlay")
	check(not standalone.is_low_health(10.0, 0.0), "Zero maximum HP safely disables overlay")
	standalone.set_health(30.0, 90.0, true)
	check(standalone.visible and standalone.is_active(), "Immediate <= 1/3 health makes overlay visible cleanly")
	check(standalone.get_displayed_intensity() >= 0.70, "Entry at <= 1/3 starts with readable perimeter intensity")
	standalone.set_health(10.0, 100.0, true)
	check(standalone.get_severity() > 0.65 and standalone.get_displayed_intensity() > 0.88, "Lower HP increases severity and blood perimeter intensity")
	standalone.set_health(90.0, 90.0, true)
	check(not standalone.visible and not standalone.is_active(), "Immediate heal above 1/3 hides overlay")
	standalone.queue_free()
	await frames(2)

	# 2. Production Main -> Dream3D_RandomDungeon integration checks.
	var main: Node = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	main.persistent_day_state = main._create_initial_state()
	main.persistent_day_state["tutorial_completed"] = true
	seed(120)
	main._show_dream("basic")
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if is_instance_valid(main._supported_dream_world) and not main.transition_running and not main._supported_dream_world.floor_transition_in_progress:
			break

	var world: Node = main._supported_dream_world
	check(is_instance_valid(world) and world.scene_file_path == "res://scenes/dream/Dream3D_RandomDungeon.tscn", "Production Main entry reaches Dream3D_RandomDungeon")
	if not is_instance_valid(world):
		quit(1)
		return
	world.persist_profile = false
	await create_timer(1.2, true, false, true).timeout

	var hud: Control = world.run_interface.hud
	var overlay: Control = hud.get_node_or_null("LowHealthBloodOverlay")
	var meter: Control = hud.get_node_or_null("LiquidHealthMeter")
	check(is_instance_valid(overlay) and is_instance_valid(meter), "Production DreamHUD contains LowHealthBloodOverlay and LiquidHealthMeter")
	if not is_instance_valid(overlay):
		quit(1)
		return

	check(overlay.get_viewport() == root and overlay.z_index < 0, "Overlay renders on root UI behind crosshair and HUD counters")
	check(not meter.visible and not meter.is_visible_in_tree(), "Production LiquidHealthMeter HUD bar is hidden")
	check(not overlay.is_active() and not overlay.visible, "Full HP starts with blood overlay completely hidden")
	await snapshot("01_main_full_hp")

	var player: Node = world.player
	var max_hp: float = player.maximum_health

	# Damage to ~50% HP (> 1/3).
	_deal_unblocked_damage(player, player.current_health - max_hp * 0.50)
	await create_timer(0.45, true, false, true).timeout
	check(player.current_health > max_hp / 3.0 and not overlay.is_active() and not overlay.visible, "50% HP remains above 1/3 threshold with overlay hidden")
	await snapshot("02_main_half_hp")

	# Damage to ~32% HP (<= 1/3 threshold).
	_deal_unblocked_damage(player, player.current_health - max_hp * 0.32)
	await create_timer(0.45, true, false, true).timeout
	check(overlay.visible and overlay.is_active() and overlay.get_displayed_intensity() >= 0.70, "Dropping to <= 1/3 HP activates screen-edge blood overlay")
	check(is_zero_approx(meter.current_fill.y) and is_zero_approx(meter.current_fill.z), "Overlay threshold aligns with final 1/3 cell of LiquidHealthMeter")
	await snapshot("03_main_one_third_hp")

	# Damage to critical ~14% HP.
	_deal_unblocked_damage(player, player.current_health - max_hp * 0.14)
	await create_timer(0.55, true, false, true).timeout
	check(overlay.get_severity() > 0.50 and overlay.get_displayed_intensity() > 0.85, "Critical HP ramps perimeter intensity smoothly")
	var phase_before: float = float(overlay._pulse_phase)
	await create_timer(0.25, true, false, true).timeout
	check(not is_equal_approx(float(overlay._pulse_phase), phase_before), "Active low-health overlay advances biological heartbeat pulse")
	await snapshot("04_main_critical_hp")

	# Pause freezes pulse progression.
	var paused_phase: float = float(overlay._pulse_phase)
	paused = true
	await create_timer(0.15, true, false, true).timeout
	check(float(overlay._pulse_phase) == paused_phase, "Game pause freezes blood heartbeat pulse")
	paused = false

	# Heal back above 1/3 HP.
	player.heal(max_hp * 0.50)
	await create_timer(0.55, true, false, true).timeout
	check(player.current_health > max_hp / 3.0 and not overlay.visible and not overlay.is_active() and not overlay.is_processing(), "Healing above 1/3 HP smoothly hides blood overlay and idles processing")
	await snapshot("05_main_healed_hp")

	# Fatal damage fades overlay out on death.
	_deal_unblocked_damage(player, player.current_health - max_hp * 0.20)
	await create_timer(0.40, true, false, true).timeout
	check(overlay.is_active(), "Overlay reactivates when injured back below 1/3")
	_deal_unblocked_damage(player, 1000.0)
	await create_timer(0.55, true, false, true).timeout
	check(player.dead and overlay.get_target_intensity() == 0.0 and not overlay.is_active(), "Fatal damage cleanly fades out persistent blood overlay")
	await snapshot("06_main_dead_fadeout")

	var old_overlay_id := overlay.get_instance_id()
	main.queue_free()
	await frames(12)
	check(not is_instance_id_valid(old_overlay_id), "Leaving Main cleanly frees LowHealthBloodOverlay")

	# 3. TutorialRoom integration check.
	var tutorial: Node3D = load("res://scenes/dream/Dream3D_TutorialRoom.tscn").instantiate()
	root.add_child(tutorial)
	await frames(12)
	var tut_ui: Node = tutorial.control_hint.get_parent() if is_instance_valid(tutorial.control_hint) else null
	var tut_overlay: Control = tut_ui.get_node_or_null("LowHealthBloodOverlay") if is_instance_valid(tut_ui) else null
	var tut_meter: Control = tut_ui.get_node_or_null("LiquidHealthMeter") if is_instance_valid(tut_ui) else null
	check(is_instance_valid(tut_overlay), "TutorialRoom contains LowHealthBloodOverlay under GameplayUI")
	check(is_instance_valid(tut_meter) and not tut_meter.visible, "TutorialRoom LiquidHealthMeter HUD bar is hidden")
	if is_instance_valid(tut_overlay):
		check(tut_overlay.get_viewport() == root, "TutorialRoom blood overlay draws on root HUD viewport")
		check(not tut_overlay.visible and not tut_overlay.is_active(), "TutorialRoom starts hidden at full health")
		_deal_unblocked_damage(tutorial.player, tutorial.player.maximum_health * 0.70)
		await create_timer(0.40, true, false, true).timeout
		check(tut_overlay.visible and tut_overlay.is_active(), "TutorialRoom activates low-health blood overlay when injured <= 1/3")
		tutorial.player.heal(1000.0)
		await create_timer(0.50, true, false, true).timeout
		check(not tut_overlay.visible and not tut_overlay.is_active(), "TutorialRoom hides low-health blood overlay after healing")
	tutorial.queue_free()
	if is_instance_valid(tut_ui) and tut_ui.get_parent() == root:
		tut_ui.queue_free()
	await frames(12)

	var failed := checks.filter(func(row): return not row.pass).size()
	var result := {
		"pid": OS.get_process_id(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"audio": AudioServer.get_driver_name(),
		"native": native,
		"checks": checks,
		"failed": failed,
	}
	var out_file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	if out_file != null:
		out_file.store_string(JSON.stringify(result, "\t"))
	print("LOW_HEALTH_BLOOD checks=", checks.size(), " failures=", failed)
	quit(1 if failed > 0 else 0)
