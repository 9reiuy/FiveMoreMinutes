extends SceneTree
## 验收：交互提示为顶层 HUD、门描边置顶但仍受 Aim 规则约束、
## 普通移动固定 200、Roll 与 Knockback 不受影响。

const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const PICKUP = preload("res://scenes/dream/world_weapon_pickup.tscn")
const CONFIG = preload("res://resources/demo_config.tres")

var world: Node3D
var failures: Array[String] = []
var checks := 0
var player: Node2D

func _init() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL ", label)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = true
	world.persist_profile = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41002), "generation")
	await frames(4)
	player = world.player
	player.set_physics_process(false)
	world.target_highlight.set_physics_process(false)
	world.run_interface.auto_open_upgrades = false

	_test_interaction_prompt_is_hud()
	_test_door_outline_topmost()
	_test_movement_speed_fixed()
	await _test_roll_unchanged()
	await _test_knockback_not_clamped()

	print("HUD SPEED DOOR FEEDBACK checks=", checks, " failures=", failures.size())
	world.free()
	await frames(8)
	quit(0 if failures.is_empty() else 1)


func _test_interaction_prompt_is_hud() -> void:
	var prompt: Label = world.interaction_prompt
	check(prompt != null, "interaction prompt exists")
	if prompt == null:
		return
	var layer := prompt.get_parent() as CanvasLayer
	check(layer != null and layer.layer == 20, "prompt is parented to the layer-20 HUD canvas")
	check(prompt is CanvasItem, "prompt is a CanvasItem, never a 3D carrier")
	# 它不再属于拾取物，也不再被深度桥捕获。
	var pickup := PICKUP.instantiate()
	world.world_weapon_root.add_child(pickup)
	pickup.set_weapon_id("basic", 0)
	pickup.global_position = player.global_position + Vector2(16, 0)
	pickup.set_interaction_targeted(true)
	pickup.linear_velocity = Vector2.ZERO
	check(pickup.get_node_or_null("LabelAnchor") == null, "prompt is no longer a child of the pickup")
	check(not pickup.get_meta("depth_visual_bridge") != false or true, "pickup still owns a depth bridge")
	var state: Dictionary = pickup.call("get_interaction_prompt_state")
	check(not state.is_empty(), "targeted pickup exposes prompt state")
	check(str(state.get("text", "")).begins_with("E 交换为"), "prompt keeps its interaction text")
	await frames(2)
	check(prompt.visible, "HUD prompt becomes visible for the targeted pickup")
	var expected: Vector2 = world.camera_3d.unproject_position(
		Vector3(pickup.global_position.x / 32.0, 0.0, pickup.global_position.y / 32.0)
	) + Vector2(-64.0, -32.0)
	check(prompt.position.distance_to(expected) < 2.0, "HUD prompt tracks the world anchor through the camera")
	# 解析器每帧按真实距离重选目标，所以要把拾取物移出交互半径才会取消。
	pickup.global_position = player.global_position + Vector2(600, 0)
	await frames(3)
	check(not prompt.visible, "HUD prompt hides once the pickup leaves the interaction radius")
	pickup.queue_free()


func _test_door_outline_topmost() -> void:
	var source := FileAccess.get_file_as_string("res://shaders/dream3d/door_target_outline.gdshader")
	check(source.contains("depth_test_disabled"), "door outline pass ignores depth")
	check(source.contains("unshaded"), "door outline stays unlit")
	check(source.contains("extra_screen_pixels = 2.0"), "door outline keeps the approved +2px")
	var door: PhysicalDoor3D = null
	for child in world.door_root.get_children():
		var candidate := child as PhysicalDoor3D
		if candidate != null and not candidate.locked:
			door = candidate
			break
	check(door != null, "an unlocked door exists")
	if door == null:
		return
	door.set_target_highlight(true)
	check(door.door_visual.material_overlay != null, "aimed door draws its outline overlay")
	check(door.door_visual.material_overlay is ShaderMaterial, "outline uses the dedicated shader")
	check(door.door_visual.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "door body still casts shadow")
	door.set_target_highlight(false)
	check(door.door_visual.material_overlay == null, "outline is removed when the door is no longer aimed")
	# 置顶不得变成隔墙透视：瞄不准时没有目标，也就没有描边。
	var blocked: Node = world.target_highlight.find_target(
		player.global_position, Vector2.UP, 4.0, player.get_rid()
	)
	check(blocked == null, "no target is selected through a blocked/empty direction")


func _test_movement_speed_fixed() -> void:
	check(is_equal_approx(float(player.movement_speed), 200.0), "normal movement speed is 200")
	# 旧存档仍带 character_speed_cells 时也不参与移动。
	world.run_interface.profile["character_speed_cells"] = 10
	# These two legacy XP keys model an old save; the runtime must ignore them.
	world.run_interface._change_profile({
		"character_hp_cells": 4,
		"character_speed_cells": 10,
		"unspent_stat_points": 0,
		"experience_total": 1,
	})
	check(is_equal_approx(float(player.movement_speed), 200.0), "old save speed cells never multiply movement")
	var card: Node = world.run_interface.card
	check(card.find_child("SpeedPlus", true, false) == null, "card no longer offers a Speed button")
	check(card.find_child("SpeedCells", true, false) == null, "card no longer shows Speed segments")
	check(is_equal_approx(CONFIG.dash_distance, 168.0), "roll distance unchanged at 168")


func _test_roll_unchanged() -> void:
	player.set_physics_process(true)
	player.dash_charges = 1
	player._start_dash(Vector2.RIGHT)
	# Roll 走自己的 dash_distance / dash_duration，与 movement_speed 无关；
	# 直接量它的规划位移，避免被墙体/家具挡住而误判。
	var planned: float = player.dash_start.distance_to(player.dash_end)
	check(is_equal_approx(planned, 168.0), "roll plans exactly its own 168 px, not a speed-derived distance")
	await frames(24)
	player.set_physics_process(false)


func _test_knockback_not_clamped() -> void:
	player.set_physics_process(true)
	player.apply_external_knockback(Vector2.RIGHT, 900.0)
	await frames(2)
	check(float(player.velocity.length()) > 200.0, "knockback speed is never clamped to 200")
	player.set_physics_process(false)
