extends SceneTree

## Observe actual CanvasItem.draw emissions, not private cache fields. The
## subject's automatic process is disabled so each input mutation has one tick.
## Optional --subject-script=... runs the same behavioural test against a saved
## pre-fix script; it must fail the pointer/ammo redraw checks.
const CONFIG := preload("res://resources/demo_config.tres")
var checks := 0
var failures: Array[String] = []
var draw_events := 0
var crosshair: Control
var actor: Node

class PointerWorld extends Node:
	func get_gameplay_aim_position() -> Vector2:
		return Vector2.ZERO

class PointerActor extends Node:
	signal confirmed_projectile_fired
	var pointer := Vector2(100, 90)
	var hud_scale := Vector2.ONE
	var hud_offset := Vector2.ZERO
	var ammo := {"uses_ammo": true, "current": 12, "capacity": 12, "reloading": false, "reload_left": 0.0}
	func get_weapon_cooldown_progress() -> float:
		return 1.0
	func get_constrained_aim_position() -> Vector2:
		return pointer
	func get_presentation_pointer_position() -> Vector2:
		return pointer
	func get_presentation_hud_position(point: Vector2) -> Vector2:
		return point * hud_scale + hud_offset
	func get_ammo_status() -> Dictionary:
		return ammo

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func flush_draws() -> void:
	for frame in 3:
		await process_frame

func changed_and_settled(label: String) -> void:
	var previous := draw_events
	crosshair._process(0.0)
	await flush_draws()
	check(draw_events > previous, label)
	previous = draw_events
	crosshair._process(0.0)
	await flush_draws()
	check(draw_events == previous, label + ": stable state does not redraw again")

func _run() -> void:
	var subject := "res://scripts/ui/crosshair.gd"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--subject-script="):
			subject = argument.trim_prefix("--subject-script=")
	var world := PointerWorld.new()
	root.add_child(world)
	world.add_to_group(&"dream_world")
	actor = PointerActor.new()
	world.add_child(actor)
	crosshair = load(subject).new()
	crosshair.config = CONFIG.duplicate(true)
	crosshair.current_color = crosshair.config.crosshair_ready_color
	crosshair.size = Vector2(640, 360)
	crosshair.draw.connect(func() -> void: draw_events += 1)
	root.add_child(crosshair)
	crosshair.set_process(false)
	crosshair.configure(actor)
	crosshair._process(0.0)
	await flush_draws()
	check(draw_events > 0, "Initial CanvasItem draw actually occurred")
	var previous := draw_events
	crosshair._process(0.0)
	await flush_draws()
	check(draw_events == previous, "Ready weapon with unchanged pointer/ammo/colour/recoil stays cached")

	actor.pointer += Vector2(37, 21)
	await changed_and_settled("Moving only the pointer redraws a ready crosshair")
	actor.hud_scale = Vector2(0.75, 0.75)
	actor.hud_offset = Vector2(80, 45)
	await changed_and_settled("Changing only the HUD/letterbox mapping redraws the crosshair")
	check(crosshair._world_to_ui(actor.pointer).is_equal_approx(actor.pointer * actor.hud_scale + actor.hud_offset), "Existing pointer-to-HUD transformation remains intact")

	actor.ammo.current = 11
	await changed_and_settled("Ammo count redraws without a fired/recoil event")
	actor.ammo.capacity = 16
	await changed_and_settled("Ammo capacity redraws independently")
	actor.ammo.reloading = true
	actor.ammo.reload_left = crosshair.config.weapon_reload_duration
	await changed_and_settled("Starting reload redraws the text and bar")
	actor.ammo.reload_left = crosshair.config.weapon_reload_duration * 0.5
	await changed_and_settled("Reload progress redraws while pointer/colour/recoil stay unchanged")
	actor.ammo.reloading = false
	actor.ammo.current = 16
	await changed_and_settled("Reload completion redraws the final ammo and removes the bar")
	previous = draw_events
	actor.ammo.reload_left = 0.0
	crosshair._process(0.0)
	await flush_draws()
	check(draw_events == previous, "Hidden reload timer does not force redraw outside reloading")
	actor.ammo.uses_ammo = false
	await changed_and_settled("Switching off ammo display redraws")

	crosshair.queue_free()
	world.queue_free()
	await process_frame
	await process_frame
	print("CROSSHAIR_POINTER_REFRESH checks=%d failures=%d subject=%s" % [checks, failures.size(), subject])
	quit(0 if failures.is_empty() else 1)
