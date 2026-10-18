extends SceneTree
const GLASS = preload("res://scripts/dream/continuous_office_glass.gd")
var failures: Array[String] = []
var checks := 0
var screenshots := false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("FAIL ",message)

func _initialize() -> void:
	screenshots = OS.get_cmdline_user_args().has("--capture")
	call_deferred("run")

func run() -> void:
	if "--background-gpu" in OS.get_cmdline_user_args(): preload("res://tests/support/background_gpu.gd").start(self)
	var scene: PackedScene = load("res://scenes/dream/Dream3D_RandomDungeon.tscn")
	var world = scene.instantiate()
	world.compact_combat_layout = not OS.get_cmdline_user_args().has("--original-layout")
	world.generate_on_ready = false
	world.enable_game_start_cab_exit = false
	world.persist_profile = false
	root.add_child(world)
	root.size = Vector2i(1280,720)
	for type in ["A1","B2","C3","V3"]:
		world.native_skeleton_type = type
		check(world.regenerate(42001),type+" full scene generation")
		for frame in 15:
			await process_frame
		world.player.invulnerability_left = 10000
		var start: Vector2 = world.player.global_position
		Input.action_press("move_right")
		for frame in 12:
			await physics_frame
			await process_frame
		Input.action_release("move_right")
		check(world.player.global_position.distance_to(start) > 5,type+" normal player input moves")
		var budget := 0
		for encounter in world.room_encounters.values():
			budget += int(encounter.get("planned_enemy_count",0))
		check(world.enemy_root.get_child_count() == budget,type+" formal enemy budget without old-layer duplicates")
		var expected := 0
		for plan in world.room_layout_plans.values():
			expected += plan.get("furniture_placements",[]).size()
		for item in world.furniture_root.get_children():
			if item.has_meta(&"approved_art_addition"): expected+=1
		check(world.furniture_root.get_child_count() == expected,type+" no silently dropped furniture")
		check(world.built_glass.size() == world.glass_wall_edges.size(),type+" all independent glass cells built")
		check(world.rendered_edge_failures == 0,type+" all rendered boundaries agree")
		check(world.enemy_root.get_child_count() > 0,type+" enemies running")
		var carriers := 0
		for enemy in world.enemy_root.get_children():
			if enemy.get_meta(&"employee_badge_carrier",false):
				carriers += 1
			var room_id: int = enemy.get_meta(&"dream_room_id",-1)
			check(room_id != world.spawn_room_id,type+" safe reception has no enemies")
		check(carriers == 1,type+" badge carrier preserved")
		var first_pane: Node3D
		for child in world.wall_root.get_children():
			if child is GLASS:
				first_pane = child
				break
		check(first_pane != null,type+" glass exists")
		if first_pane != null:
			var e: Dictionary = first_pane.edge_data
			var neighbors: Array = []
			for child in world.wall_root.get_children():
				if child is GLASS and child != first_pane and child.edge_data.get("preview_glass_group","") == e.get("preview_glass_group",""):
					neighbors.append(child)
			var width: int = int(e.preview_run_width)
			check(width == 1,type+" glass damage unit is one cell")
			check(is_equal_approx(first_pane.glass_pane.mesh.size.x,1.0),type+" continuous glass has no cell gap")
			for mesh in first_pane.frame_root.get_children():
				if mesh is MeshInstance3D and absf(mesh.position.x) > .4:
					check(mesh.visible == (bool(e.run_first) if mesh.position.x < 0 else bool(e.run_last)),type+" posts only at run endpoints")
			var actual_size: Vector2 = first_pane.collision_shape_2d.shape.size
			check(is_equal_approx(actual_size.y if String(e.axis) == "V" else actual_size.x,width*32.0),type+" full-span glass collider")
			first_pane.take_damage(2.0)
			await process_frame
			check(first_pane.collision_body_2d.collision_layer == 0,type+" broken cell movement collision removed")
			for neighbor in neighbors:
				check(not neighbor.is_shattered,type+" neighboring pane intact")
				check(world.edge_states[neighbor.edge_key] == &"GLASS_WINDOW",type+" neighboring gameplay edge intact")
				check(neighbor.collision_body_2d.collision_layer != 0,type+" neighboring movement collision retained")
			for i in width:
				var segment: Dictionary = e.duplicate()
				segment["y" if String(e.axis) == "V" else "x"] += i
				check(world.edge_states[world._edge_key(segment)] == &"OPEN",type+" shattered span walkable")
		if screenshots:
			world.player.invulnerability_left = 0
			for enemy in world.enemy_root.get_children():
				enemy.set_physics_process(false)
				enemy.set_process(false)
			var source: Dictionary = world.skeleton_source
			var id := "west" if type == "B2" else "main"
			var target: Vector2i = world.ADAPTER.cell(source.anchors[id])
			for section in source.doors:
				if not section.get("officeFrontage",false):
					continue
				var at := Vector2i(int(section.line),int(section.start)+int(section.width)/2) if section.vertical else Vector2i(int(section.start)+int(section.width)/2,int(section.line))
				var step := Vector2i.RIGHT if section.vertical else Vector2i.DOWN
				var candidate := at+step*2
				var room_id: int = world.room_cells.get(candidate,-1)
				if room_id >= 0 and world.rooms[room_id].archetype == "open_office":
					target = candidate
				else:
					target = at-step*3
				break
			world.player.global_position = Vector2(target)*32.0
			world.player.set("flashlight_enabled",false)
			for frame in 30:
				await process_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://.runtime/compact_review")
			var capture_mode := "after" if world.compact_combat_layout else "before"
			root.get_texture().get_image().save_png("res://.runtime/compact_review/%s_%s.png" % [capture_mode,type])
			if world.compact_combat_layout:
				DirAccess.make_dir_recursive_absolute("res://.runtime/sample_size_review")
				for room_key in ["entry","meeting","deep","archive","pantry"]:
					if not source.anchors.has(room_key): continue
					world.player.global_position=Vector2(world.ADAPTER.cell(source.anchors[room_key]))*32.0
					for frame in 12: await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://.runtime/sample_size_review/%s_%s.png" % [type,room_key])
	print("NATIVE FORMAL RUNTIME checks=",checks," failures=",failures.size())
	world.queue_free()
	# Let existing async capture/timer callbacks finish before quitting.
	await create_timer(1.0).timeout
	for frame in 4:
		await process_frame
	quit(0 if failures.is_empty() else 1)
