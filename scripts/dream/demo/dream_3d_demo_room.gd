extends Node3D
## 演示房间（Demo Room）
##
## 目的：给开发者日志 / 验收一个**固定、干净、可复现**的拍摄舞台。
##
## 做法：仍然复用正式楼层 `Dream3D_RandomDungeon.tscn`（因为战斗判定、HUD、死亡 CRT、
## 燃烧/灭火器、武器都挂在那套世界上），但把随机结果固定下来：
##   · 固定种子 → 每次都是同一间房、同一套已批准的办公室陈设
##   · 只清空中央演区的家具与静态碰撞，边缘保留桌子/隔断/绿植作为装饰与景深
##   · 玩家固定放在演区中心，手电筒常亮，Superhot 慢动作关闭
##
## 注意：这里不新造家具实例。道具都是 RigidBody2D + 2D→3D 显示桥，运行时新生成会缺 3D 外观，
## 所以装饰一律沿用房间自己的陈设，只做「挪位置」不做「凭空造」。

const WORLD_SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const CELL := 32.0

## 固定种子：42001 的最大房间是 26×28 格的开放式办公区，四面有墙，适合当舞台
@export var stage_seed := 42001
## 演区半径：这个圆内不保留家具，保证子弹路径干净
@export var clear_radius := 152.0
## 演区之外保留装饰的范围（房间外不变）
@export var decorate_radius := 320.0

var world: Node3D
var player: Node2D
var arena: Dictionary = {}
var arena_center := Vector2.ZERO
var ready_for_capture := false

func _ready() -> void:
	world = WORLD_SCENE.instantiate()
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.active_seed = stage_seed
	add_child(world)
	player = world.player
	# 生成在 world._ready 里同步完成，等两帧让显示桥/相机就位
	await get_tree().process_frame
	await get_tree().process_frame
	_stage()
	ready_for_capture = true

## 固定舞台：选房 → 清中央 → 摆玩家 → 固定灯光
func _stage() -> void:
	arena = _pick_arena()
	arena_center = Vector2(arena.get("center_cell", Vector2i.ZERO)) * CELL
	_clear_stage()
	_place_player()
	_fix_lighting()
	_relocate_decor()
	print("DEMO_ROOM arena=%d center=%s cleared_radius=%.0f" % [
		int(arena.get("id", -1)), str(arena_center), clear_radius])

func _pick_arena() -> Dictionary:
	var building: Rect2i = world.building_rect
	var best: Dictionary = {}
	var best_score := -1.0
	for r in world.rooms:
		var rect: Rect2i = r.get("grid_rect", Rect2i())
		var usable: Array = r.get("usable_cells", [])
		if usable.size() < 70 or rect.size.x < 10 or rect.size.y < 10:
			continue
		if not building.encloses(rect.grow(-3)):
			continue
		var arch := String(r.get("archetype", ""))
		var bonus := 40.0 if arch in ["open_office", "office", "conference"] else 0.0
		var score := float(usable.size()) + bonus
		if score > best_score:
			best_score = score
			best = r
	if best.is_empty() and world.rooms.size() > 0:
		best = world.rooms[0]
	return best

## 清空演区内的家具与静态碰撞；演区外保留（当装饰与景深）
func _clear_stage() -> void:
	var removed := 0
	for root_node in [world.furniture_root, world.collision_root]:
		if root_node == null:
			continue
		for c in root_node.get_children():
			if not (c is Node2D):
				continue
			var d: float = (c as Node2D).global_position.distance_to(arena_center)
			if d > clear_radius:
				continue
			c.queue_free()
			removed += 1
	print("DEMO_ROOM cleared=%d" % removed)

func _place_player() -> void:
	var target := arena_center
	for ring in range(0, 6):
		var cell := Vector2i((target / CELL).floor())
		if _cell_clear(cell):
			break
		for k in 12:
			var p: Vector2 = arena_center + Vector2.RIGHT.rotated(float(k) * PI / 6.0) * (CELL * float(ring + 1))
			if _cell_clear(Vector2i((p / CELL).floor())):
				target = p
				break
	player.global_position = target
	if player is CollisionObject2D:
		PhysicsServer2D.body_set_state(
			player.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, target)
		)

func _cell_clear(cell: Vector2i) -> bool:
	if not world.floor_cells.has(cell):
		return false
	return bool(world.call("_content_position_is_clear", Vector2(cell) * CELL, 13.0, true))

## 固定灯光与时间：手电常亮、关掉静止慢动作
func _fix_lighting() -> void:
	if world.night_lighting != null and world.night_lighting.has_method("set_flashlight_enabled"):
		world.night_lighting.call("set_flashlight_enabled", true)
	var tc := get_node_or_null("/root/DreamTimeController")
	if tc != null and "slow_time_enabled" in tc:
		tc.set("slow_time_enabled", false)
	Engine.time_scale = 1.0

## 装饰：把演区边缘的一圈家具朝中心收 26px，形成围合感，但不进入弹道
func _relocate_decor() -> void:
	var moved := 0
	for c in world.furniture_root.get_children():
		if not (c is Node2D):
			continue
		var node := c as Node2D
		var d := node.global_position.distance_to(arena_center)
		if d > decorate_radius or d < clear_radius:
			continue
		var dir := (arena_center - node.global_position).normalized()
		var target := node.global_position + dir * 18.0
		if not _cell_clear(Vector2i((target / CELL).floor())):
			continue
		node.global_position = target
		if node is CollisionObject2D:
			PhysicsServer2D.body_set_state(
				node.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, target)
			)
		moved += 1
		if moved >= 8:
			break
	print("DEMO_ROOM decor_moved=%d" % moved)
