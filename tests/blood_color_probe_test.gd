extends SceneTree

## Blood 颜色链路运行时探针（只读诊断，不改任何色值）。
## 阶段：BlackBloodEffect draw RGB → SubViewport capture RGB → 屏幕最终 RGB。
## 需要窗口模式（headless 无渲染，get_image 为空）。

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const GROUND := Color("d96b18")
const AIRBORNE := Color("ff9a2e")


func _init() -> void:
	call_deferred("_run")


var failures := 0
var checks := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL ", label)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _run() -> void:
	var world := SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.show_debug_markers = false
	root.add_child(world)
	await frames(2)
	world.regenerate(41004)
	var player: Node2D = world.player
	player.set_physics_process(false)
	world.target_highlight.set_physics_process(false)
	var anchor := Vector2(world.rooms[int(world.spawn_room_id)]["center_cell"]) * 32.0 + Vector2(16, 16)
	player.global_position = anchor
	# 血迹放在玩家正北 120px 的空旷点：手电可直射，且远离其它 carrier 与玩家。
	for index in range(6):
		world.spawn_black_blood(anchor + Vector2(float(index) * 5.0, -120.0))
	await frames(45)   # 等 settle（0.38s）+ capture 刷新

	var stain: Node = null
	for child in world.world_effects_root.get_children():
		if child.is_in_group(&"black_blood_stains"):
			stain = child
			break
	if stain == null:
		print("PROBE FAIL: no blood stain found")
		quit(1)
		return
	var reference: Variant = stain.get_meta("depth_visual_bridge")
	var bridge: Node3D = reference.get_ref()
	var viewport: SubViewport = bridge.get("render_viewport")
	print("PROBE viewport use_hdr_2d=", viewport.use_hdr_2d, " transparent_bg=", viewport.transparent_bg,
		" size=", viewport.size, " update_mode=", viewport.render_target_update_mode)
	print("PROBE stain visible=", stain.visible, " self_modulate=", stain.get("self_modulate"),
		" modulate=", stain.modulate)

	var image := viewport.get_texture().get_image()
	print("PROBE capture format=", image.get_format(), " size=", image.get_size())
	var min_rgb := Vector3(9.0, 9.0, 9.0)
	var max_rgb := Vector3(-1.0, -1.0, -1.0)
	var opaque := 0
	var ground_hits := 0
	var airborne_hits := 0
	var samples: Array[Color] = []
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x, y)
			if c.a <= 0.5:
				continue
			opaque += 1
			min_rgb = Vector3(minf(min_rgb.x, c.r), minf(min_rgb.y, c.g), minf(min_rgb.z, c.b))
			max_rgb = Vector3(maxf(max_rgb.x, c.r), maxf(max_rgb.y, c.g), maxf(max_rgb.z, c.b))
			if samples.size() < 10 and c.r > 0.5:
				samples.append(c)
			if _near(c, GROUND):
				ground_hits += 1
			if _near(c, AIRBORNE):
				airborne_hits += 1
	print("PROBE capture opaque_px=", opaque, " min=", min_rgb, " max=", max_rgb)
	print("PROBE capture ground_hits=", ground_hits, " airborne_hits=", airborne_hits,
		" (target ", GROUND, " / ", AIRBORNE, ")")
	for index in range(samples.size()):
		var c := samples[index]
		print("PROBE capture sample[%d] = (%.3f, %.3f, %.3f) bytes=(%d,%d,%d) a=%.2f" % [
			index, c.r, c.g, c.b, roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0), c.a])

	# 屏幕最终 RGB：全屏扫描最饱和红像素（血迹 texel 落在 capture(64,96)，偏离
	# carrier 原点约 1 世界单位，固定 ±14px 窗口会只采到地板）。
	var sprite: Sprite3D = bridge.get("actor_sprite")
	print("PROBE sprite pos=", sprite.global_position, " visible=", sprite.visible,
		" shaded=", sprite.shaded, " pixel_size=", sprite.pixel_size)

	var _scan := func(tag: String) -> void:
		await RenderingServer.frame_post_draw
		var screen := root.get_texture().get_image()
		var best := Color.BLACK
		var best_score := -9.9
		var best_at := Vector2i.ZERO
		var reddish := 0
		for y in range(0, screen.get_height(), 2):
			for x in range(0, screen.get_width(), 2):
				var c := screen.get_pixel(x, y)
				var score := c.r - c.g
				if score > 0.06 and c.r > 0.08:
					reddish += 1
				if score > best_score:
					best_score = score
					best = c
					best_at = Vector2i(x, y)
		print("PROBE screen[%s]: best(r-g=%.3f)=(%.3f,%.3f,%.3f) bytes=(%d,%d,%d) at=%s reddish_px=%d" % [
			tag, best_score, best.r, best.g, best.b,
			roundi(best.r * 255), roundi(best.g * 255), roundi(best.b * 255), best_at, reddish])

	await _scan.call("lights_on")
	await capture_screen("blood_probe_lights_on.png")

	# 暗状态（只留 ambient）：隔离直接光照的贡献。
	var flashlight: SpotLight3D = world.night_lighting.flashlight
	var ceiling: Array = world.ceiling_light_root.get_children()
	flashlight.visible = false
	for light in ceiling:
		light.visible = false
	await frames(5)
	await _scan.call("ambient_only")
	await capture_screen("blood_probe_ambient.png")
	flashlight.visible = true
	for light in ceiling:
		light.visible = true
	print("PROBE DONE")

	# —— 阶段 2：共享载体的颜色与正式血色探针 ——
	var enemy := _spawn_enemy(world, anchor + Vector2(130, 30))
	var furniture := _spawn_furniture(world, anchor + Vector2(-130, 30))
	var weapon := _spawn_weapon(world, anchor + Vector2(0, 130))
	var casing := await _spawn_casing(world, anchor + Vector2(70, 130))
	await frames(10)
	var carriers := {
		"player": player_depth_bridge_3d(world),
		"enemy": _bridge_of(enemy),
		"weapon": _bridge_of(weapon),
		"furniture": _bridge_of(furniture),
		"casing": _bridge_of(casing),
		"blood": _bridge_of(stain),
	}
	for carrier_name in carriers:
		var carrier_bridge: Node3D = carriers[carrier_name]
		var result := await _carrier_color_check(world, carrier_bridge)
		print("CARRIER %s abs_dist=%.3f chroma_dist=%.3f chroma_ok=%s capture_dom=(%.3f,%.3f,%.3f) screen=(%.3f,%.3f,%.3f)" % [
			carrier_name, result.get("dist", 9.9), result.get("chroma", 9.9), result.get("chroma_ok", false),
			result.get("dom", Color.BLACK).r, result.get("dom", Color.BLACK).g, result.get("dom", Color.BLACK).b,
			result.get("screen", Color.BLACK).r, result.get("screen", Color.BLACK).g, result.get("screen", Color.BLACK).b])

	# —— 硬判据：手电直射血迹，全屏峰值红像素的 G/R 必须接近源色 #D96B18 的
	# 0.494（亮度无关的色相指标；颜色空间偏移态实测 G/R ≈ 0.13）。——
	world.night_lighting.set_process(false)
	var blood_aim := anchor + Vector2(10.0, -120.0)
	player.global_position = anchor
	world.night_lighting.aim_flashlight(player.global_position, blood_aim)
	await frames(10)
	await RenderingServer.frame_post_draw
	var screen := root.get_texture().get_image()
	var peak := Color.BLACK
	var peak_score := -9.9
	for y in range(0, screen.get_height(), 2):
		for x in range(0, screen.get_width(), 2):
			var c := screen.get_pixel(x, y)
			var score := c.r - c.g
			if score > peak_score and c.r > 0.15:
				peak_score = score
				peak = c
	var gr := peak.g / maxf(peak.r, 0.0001)
	check(peak_score > 0.3 and gr >= 0.30 and gr <= 0.60,
		"blood hue preserved (peak=(%.3f,%.3f,%.3f) G/R=%.3f)" % [peak.r, peak.g, peak.b, gr])
	print("BLOOD HUE peak=(%.3f,%.3f,%.3f) G/R=%.3f (target 0.494)" % [peak.r, peak.g, peak.b, gr])
	world.night_lighting.set_process(true)
	print("BLOOD PROBE checks=", checks, " failures=", failures)
	print("PROBE DONE")
	quit(1 if failures > 0 else 0)


func player_depth_bridge_3d(world: Node) -> Node3D:
	return world.player_depth_bridge


func _bridge_of(node: Node) -> Node3D:
	var reference: Variant = node.get_meta("depth_visual_bridge")
	return reference.get_ref()


func _spawn_enemy(world: Node, pos: Vector2) -> Node2D:
	var enemy := preload("res://scenes/entities/employee_enemy.tscn").instantiate()
	world.enemy_root.add_child(enemy)
	enemy.global_position = pos
	enemy.set_meta("dream_room_id", world.spawn_room_id)
	world.register_depth_visual(enemy, [^"Shadow", ^"CharacterVisual", ^"WeaponRoot"])
	return enemy


func _spawn_furniture(world: Node, pos: Vector2) -> Node2D:
	var furniture := preload("res://scenes/dream/props/trash_can_01.tscn").instantiate()
	world.furniture_root.add_child(furniture)
	furniture.global_position = pos
	furniture.set_meta("dream_room_id", world.spawn_room_id)
	world.register_depth_visual(furniture, [^"Shadow", ^"Sprite2D"])
	return furniture


func _spawn_weapon(world: Node, pos: Vector2) -> Node2D:
	var pickup := preload("res://scenes/dream/world_weapon_pickup.tscn").instantiate()
	world.world_weapon_root.add_child(pickup)
	pickup.global_position = pos
	var paths: Array[NodePath] = [NodePath("Shadow"), NodePath("WeaponSprite")]
	world._spawn_depth_bridge(pickup, paths)
	return pickup


func _spawn_casing(world: Node, pos: Vector2) -> Node2D:
	world.spawn_shell_ejection(pos, Vector2.RIGHT, &"basic")
	await frames(2)
	for node in world.world_effects_root.get_children():
		if node.has_meta("depth_visual_bridge") and not node.is_in_group(&"black_blood_stains"):
			return node
	return null


## 取 capture 中饱和度最高的不透明像素颜色，再在 carrier 屏幕包围盒内找与之
## 距离最近的像素：距离小 = 屏幕还原了 capture 颜色（颜色空间无偏移）。
func _carrier_color_check(world: Node, bridge: Node3D) -> Dictionary:
	var viewport: SubViewport = bridge.get("render_viewport")
	var capture := viewport.get_texture().get_image()
	var dom := Color.BLACK
	var spread := -1.0
	for y in range(capture.get_height()):
		for x in range(capture.get_width()):
			var c := capture.get_pixel(x, y)
			if c.a <= 0.5:
				continue
			var channel_spread := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
			if channel_spread > spread:
				spread = channel_spread
				dom = c
	# 全屏搜索最小距离像素：不依赖任何 unproject/视口坐标换算假设。
	var sprite: Sprite3D = bridge.get("actor_sprite")
	print("CHECK ", sprite.get_parent().name, " sprite_pos=", sprite.global_position, " dom=", dom)
	await RenderingServer.frame_post_draw
	var screen := root.get_texture().get_image()
	# 两个指标：绝对距离（受亮度影响）与色度距离（每像素按自身 max 归一，
	# 亮度不变，专测"色相是否被颜色空间改变"——夜晚暗光下这才是正确指标）。
	var dom_max := maxf(dom.r, maxf(dom.g, dom.b))
	var dom_chroma := Vector3(dom.r / dom_max, dom.g / dom_max, dom.b / dom_max)
	var best := Color.BLACK
	var best_dist := 9.9
	var best_chroma := 9.9
	for y in range(0, screen.get_height(), 2):
		for x in range(0, screen.get_width(), 2):
			var c := screen.get_pixel(x, y)
			var dist := (absf(c.r - dom.r) + absf(c.g - dom.g) + absf(c.b - dom.b)) / 3.0
			if dist < best_dist:
				best_dist = dist
				best = c
			var c_max := maxf(c.r, maxf(c.g, c.b))
			if c_max < 0.05:
				continue
			var chroma := Vector3(c.r / c_max, c.g / c_max, c.b / c_max)
			var chroma_dist := (absf(chroma.x - dom_chroma.x) + absf(chroma.y - dom_chroma.y) + absf(chroma.z - dom_chroma.z)) / 3.0
			if chroma_dist < best_chroma:
				best_chroma = chroma_dist
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/carrier_check_last.png")
	return {
		"dist": best_dist, "matched": best_dist < 0.15, "dom": dom, "screen": best,
		"chroma": best_chroma, "chroma_ok": best_chroma < 0.08,
	}


func capture_screen(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + label)


func _near(c: Color, target: Color, tolerance: float = 0.03) -> bool:
	return absf(c.r - target.r) <= tolerance and absf(c.g - target.g) <= tolerance \
		and absf(c.b - target.b) <= tolerance and c.a > 0.5
