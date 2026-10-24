extends SceneTree
class OffsetBridge extends "res://scripts/dream/dream_3d_actor_depth_bridge.gd":
	var test_heading := 0.0
	func _weapon_capture_delta(_camera: Camera3D) -> float: return test_heading
	func _active_world_camera() -> Camera3D: return null
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func run() -> void:
	var bridge := OffsetBridge.new()
	bridge.set_process(false)
	root.add_child(bridge)
	bridge.configured = true
	bridge.character_projection = true
	var player = load("res://scenes/entities/dream_player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(player)
	player.configure_weapon("lucille", load("res://resources/demo_config.tres"), {})
	player.set_meta(&"depth_visual_bridge", weakref(bridge))
	for heading in [-PI * 0.75, -PI * 0.5, -PI * 0.25, 0.0, PI * 0.25, PI * 0.5]:
		bridge.test_heading = heading
		check(bridge.compensate_weapon_pixel_offset(Vector2(0, 18)).rotated(heading).distance_to(Vector2(0, 18)) < 0.001, "Shoulder drop remains vertical at heading %s" % heading)
		for swing in [-1.2, 0.0, 1.2]:
			var grips: Array[Vector2] = []
			for direction in [Vector2.RIGHT, Vector2.LEFT]:
				player.last_aim_direction = direction
				player.set_meta(&"aim_direction_override", direction)
				player.apply_melee_swing_snapshot({"weapon_id": "lucille", "direction": direction, "elapsed": 0.12, "duration": 0.24, "angle": swing, "opacity": 1.0})
				var origin: Vector2 = player.get_projectile_origin()
				player.hand_presentation.apply()
				check(player.get_projectile_origin().distance_to(origin) < 0.001, "Pixel correction never changes gameplay marker")
				var hand: Sprite2D = player.hand_presentation.grip_right
				grips.append((hand.global_position - player.weapon_root.global_position).rotated(heading))
			check(((grips[0] + grips[1]) * 0.5).distance_to(Vector2(0, 18)) < 0.001, "Opposite grips centre on body, not a sideways drift %s/%s" % [heading, swing])
	player.remove_meta(&"depth_visual_bridge")
	player.free()
	bridge.free()
	print("HAND_OFFSET_SYMMETRY checks=", checks, " failures=", failures.size())
	await process_frame
	quit(0 if failures.is_empty() else 1)
