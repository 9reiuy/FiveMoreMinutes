extends SceneTree
const POLICY = preload("res://scripts/dream/office_sparse_lighting.gd")
class WorldStub extends Node3D:
	var shadow_manager: Node
	var player: Node2D
	var wall_height := 3.0
	var dynamic_shadows_enabled := true
	var current_room_id := 0
	var token := 1
	func get_current_floor_token() -> int: return token
	func get_gameplay_world_position(p: Vector2) -> Vector3: return Vector3(p.x / 32, 0, p.y / 32)
class ManagerStub extends Node:
	var sun: DirectionalLight3D
	var sparse_lighting_enabled := false
	func set_sparse_lighting_enabled(value: bool) -> void: sparse_lighting_enabled = value
class PowerStub extends Node:
	var powered := true
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := WorldStub.new(); root.add_child(world)
	world.player = Node2D.new(); world.add_child(world.player)
	world.shadow_manager = ManagerStub.new(); world.add_child(world.shadow_manager)
	world.shadow_manager.sun = DirectionalLight3D.new(); world.shadow_manager.add_child(world.shadow_manager.sun)
	var lighting := Node3D.new(); lighting.name = "Lighting"; world.add_child(lighting)
	var environment := WorldEnvironment.new(); environment.name = "WorldEnvironment"; environment.environment = Environment.new(); lighting.add_child(environment)
	var original: Environment = environment.environment
	var lamp := SpotLight3D.new(); world.add_child(lamp)
	var policy := POLICY.new(); world.add_child(policy); policy.configure(world)
	check(policy.main is DirectionalLight3D and not policy.is_processing(), "Fixed directional key has no follow callback")
	check(not lamp.visible and policy.main.visible and world.shadow_manager.sparse_lighting_enabled, "Sparse defaults replace room lamps")
	lamp.show(); check(not lamp.visible, "Late visibility cannot re-enable lamp")
	var start: Transform3D = policy.main.global_transform
	world.current_room_id = 99; policy._before_draw()
	check(policy.main.global_transform.is_equal_approx(start), "Room ID has no effect on shadow source")
	world.player.position = Vector2(9000,9000)
	await process_frame; policy._before_draw()
	check(policy.main.global_transform.is_equal_approx(start), "Walking/dash/teleport cannot move the light")
	check(policy.main.global_basis.is_equal_approx(start.basis), "Fixed world-space direction")
	var cabinet := PowerStub.new(); world.add_child(cabinet); cabinet.add_to_group(&"floor_power_switches")
	cabinet.set_meta(&"wall_attachment_floor",1); cabinet.powered = false; policy._sync_power()
	check(not policy.main.visible and environment.environment == original, "Power switch darkens ambient and main")
	world.token = 2; policy._sync_power()
	check(policy.main.visible, "Old rollback floor switch cannot darken new floor")
	cabinet.set_meta(&"wall_attachment_floor",2); policy._sync_power()
	check(not policy.main.visible, "Restored old floor power applies after token refresh")
	cabinet.powered = true; policy._sync_power()
	policy.set_suspended(true)
	check(not policy.main.visible and environment.environment == original, "Cab uses original ambient")
	policy.set_suspended(false)
	check(policy.main.visible, "Exit restores sparse source")
	policy.prepare_loading_pose()
	check(policy._floor_token == 2 and policy.main.global_transform.is_equal_approx(start), "Loading records new floor without moving the light")
	var functional := Node3D.new(); functional.name = "NightLighting"; world.add_child(functional)
	var muzzle := OmniLight3D.new(); functional.add_child(muzzle)
	policy._before_draw(); check(muzzle.visible, "Functional muzzle retained")
	var late := OmniLight3D.new(); world.add_child(late); policy._before_draw()
	check(not late.visible, "New ordinary source suppressed")
	late.free(); policy._before_draw()
	policy.set_enabled(false)
	check(lamp.visible and not policy.main.visible and environment.environment == original, "Legacy rollback restores original light/environment")
	policy.set_enabled(true); check(not lamp.visible, "Sparse re-enable safe")
	# Simulate a rollback reparent: the signal must detach and re-register once.
	world.remove_child(lamp); root.add_child(lamp)
	check(lamp.visible, "Detached light no longer belongs to this policy")
	root.remove_child(lamp); world.add_child(lamp); policy._before_draw()
	check(not lamp.visible, "Reattached source inherits active policy")
	var count: int = RenderingServer.frame_pre_draw.get_connections().size()
	world.free(); await process_frame
	check(RenderingServer.frame_pre_draw.get_connections().size() == count - 1, "Teardown releases callback")
	print("SPARSE_POLICY checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
