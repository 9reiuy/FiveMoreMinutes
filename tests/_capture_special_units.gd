extends SceneTree
## 真实游戏内取画面：送餐机器人（楼层内）+ 巡逻无人机（楼层外靠窗）。
## 直接加载正式地牢场景（游戏自己的相机、灯光、2D 玩法层、弹道桥），
## 只跳过菜单与电梯转场。玩家关闭自动开火；每张图前补满玩家血量并清空
## 场上子弹，避免展示单位把玩家打死。

const OUT_DIR := "E:/GameProjects/AIWorkspaces/special_units_capture"
const ROBOT_MAX_HP := 60.0

func _init() -> void:
	call_deferred("run")


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


## 帧缓冲偶发读到半帧（画面撕裂/尺寸变化），失败就等一下重试。
func shot(name: String, expected := Vector2i(1280, 720)) -> void:
	for attempt in range(6):
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if img != null and Vector2i(img.get_width(), img.get_height()) == expected:
			var path := "%s/%s.png" % [OUT_DIR, name]
			img.save_png(path)
			print("SHOT ", path)
			return
		await wait(0.4)
	print("SHOT_FAIL ", name)


## 清掉所有飞行中的子弹：展示单位之间会互相打死，也会打死玩家。
func clear_projectiles(world: Node) -> void:
	var gameplay_world: Node = world.get("gameplay_world")
	if gameplay_world == null:
		return
	for child in gameplay_world.get_children():
		if child.is_in_group(&"dream_projectiles"):
			child.free()


func _stabilise(world: Node, player: Node, robot: Node, robot_hp := 34.0) -> bool:
	clear_projectiles(world)
	player.set("current_health", player.get("maximum_health"))
	if robot == null or not is_instance_valid(robot) or bool(robot.get("dead")):
		return false
	robot.set("hp", robot_hp)
	robot.set("alert", true)
	robot.set("deploy", 1.0)
	var bar: Node3D = robot.get("health_bar_3d")
	if bar != null and bar.has_method("redraw"):
		bar.call("redraw", robot_hp, ROBOT_MAX_HP)
	return true


func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	Engine.max_fps = 60
	seed(4242)
	var world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.disable_player_combat = true
	root.add_child(world)
	await wait(0.4)
	world.regenerate(90210)
	await wait(1.5)

	var player = world.get("player")
	if player == null or not is_instance_valid(player):
		print("FAIL no player")
		quit(1)
		return

	# 选一个「有朝相机玻璃立面」的战斗房间。
	var target_room := -1
	var facade := {}
	for room in world.rooms:
		var id := int(room["id"])
		if id == int(world.spawn_room_id) or id == int(world.boss_room_id):
			continue
		if not bool(world.call("_is_combat_room", room)):
			continue
		world.current_room_id = id
		var candidate: Dictionary = world.call("_exterior_window_facade", room)
		if not candidate.is_empty():
			target_room = id
			facade = candidate
			break
	print("TARGET room=", target_room, " facade=", facade.get("key", "none"))
	if target_room < 0:
		print("FAIL no facade")
		quit(1)
		return

	var boundary: Vector2 = facade["boundary"]
	var inward: Vector2 = facade["inward"]
	print("FACADE boundary=", boundary, " inward=", inward)

	# 无人机先立起来：它在窗外固定位置，玩家站位要反过来迁就它。
	world.current_room_id = target_room
	var drone: Node3D = null
	for _attempt in range(400):
		world.current_room_id = target_room
		world.call("_spawn_exterior_drones")
		if world._exterior_drone_root.get_child_count() > 0:
			var candidate := world._exterior_drone_root.get_child(0) as Node3D
			if candidate != null and Vector2(candidate.get("boundary_2d")) == boundary:
				drone = candidate
				break
	print("DRONE pos=", drone.global_position if drone != null else Vector3.ZERO,
		" boundary=", drone.get("boundary_2d") if drone != null else Vector2.ZERO,
		" inward=", drone.get("inward_normal") if drone != null else Vector2.ZERO)
	if drone == null:
		print("FAIL no drone")
		quit(1)
		return

	# 相机是固定俯角的透视投影，窗外高处的无人机会被投影到很靠上的位置；
	# 这里沿法线扫站位，找到让无人机落在画面中下部的那一格。
	var cam: Camera3D = world.get("camera_3d")
	var chosen := 2.5
	for k in [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.5, 8.0]:
		player.global_position = boundary + inward * 32.0 * float(k)
		await wait(0.45)
		var sp: Vector2 = cam.unproject_position(drone.global_position)
		print("PLACEMENT k=", k, " drone_screen=", sp)
		if sp.y > 90.0 and sp.y < 430.0 and sp.x > 60.0 and sp.x < 1220.0:
			chosen = float(k)
			break
		chosen = float(k)
	player.global_position = boundary + inward * 32.0 * chosen
	await wait(0.6)
	var drone_screen: Vector2 = cam.unproject_position(drone.global_position)
	print("CHOSEN k=", chosen, " drone_screen=", drone_screen)

	# 送餐机器人：放在玩家斜前方，武器全展开。
	var visuals: Node3D = world.call("_hotel_robot_visual_container")
	var robot_home: Vector2 = player.global_position + Vector2(96.0, -64.0)
	world.call("_spawn_hotel_robot", target_room, robot_home, visuals)
	var robot: Node = _find_robot(world)
	print("ROBOT ", robot)
	_stabilise(world, player, robot)
	await wait(0.5)
	_stabilise(world, player, robot)
	await shot("01_robot_in_room")

	await wait(0.25)
	_stabilise(world, player, robot)
	await shot("02_robot_and_drone")

	# 探照灯拉满亮度：应该看到一束朝室内打的光，而不是照地板的圆斑。
	drone.set("_spot_elapsed", 0.0)
	await wait(0.3)
	_stabilise(world, player, robot)
	await shot("03_drone_spotlight")

	# 近景：清掉无人机（敌方子弹会误伤机器人），换一台未警戒的机器人，
	# 展示收起武器的待机姿态 + 常驻血条。
	for child in world._exterior_drone_root.get_children():
		child.free()
	clear_projectiles(world)
	await wait(0.6)
	if robot == null or not is_instance_valid(robot) or bool(robot.get("dead")):
		world.call("_spawn_hotel_robot", target_room, robot_home, visuals)
		robot = _find_robot(world)
	if robot != null:
		robot.set("hp", 34.0)
		robot.set("alert", false)
		robot.set("deploy", 0.0)
		var bar: Node3D = robot.get("health_bar_3d")
		if bar != null:
			bar.visible = true
			if bar.has_method("redraw"):
				bar.call("redraw", 34.0, ROBOT_MAX_HP)
	await wait(0.5)
	_stabilise(world, player, robot, 34.0)
	await shot("04_closeup_robot")

	world.queue_free()
	await wait(0.2)
	print("CAPTURE DONE")
	quit(0)


func _find_robot(world: Node) -> Node:
	for child in world.enemy_root.get_children():
		if String(child.name).begins_with("HotelDeliveryRobot"):
			return child
	return null
