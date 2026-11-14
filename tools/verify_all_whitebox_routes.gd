extends SceneTree
## Reusable physical navigation probe; run standalone with --script as well.
func _init() -> void:
	if get_script().resource_path == "res://tools/verify_all_whitebox_routes.gd": call_deferred("_run")

func _run() -> void:
	var world: Node3D = load("res://scenes/testing/MegastructureWhitebox.tscn").instantiate()
	root.add_child(world)
	for frame in 8: await process_frame
	var report: Dictionary = await verify(world)
	print(JSON.stringify(report))
	quit(0 if bool(report.no_void_escape) and report.routes.all(func(item): return item.pass) else 1)

static func verify(world: Node3D) -> Dictionary:
	var tree := world.get_tree()
	var player: CharacterBody2D = world.player
	var previous_physics := player.is_physics_processing()
	player.set_physics_process(false)
	# Combat behavior is tested separately. Bodies remain in the physics world.
	for enemy in world.enemy_root.get_children():
		enemy.process_mode=Node.PROCESS_MODE_DISABLED
		enemy.set_process(false)
		enemy.set_physics_process(false)
		player.add_collision_exception_with(enemy)
	var controller: Node = world._get_dream_time_controller()
	controller.set_process(false)
	controller.set_physics_process(false)
	for projectile in tree.get_nodes_in_group(&"dream_projectiles"):
		if world.is_ancestor_of(projectile):projectile.queue_free()
	await tree.process_frame
	for pickup in world.world_weapon_root.get_children():
		pickup.thrown_active=false
		pickup.linear_velocity=Vector2.ZERO
		pickup.freeze=true
		pickup.set_process(false)
		pickup.set_physics_process(false)
	controller.reset_hit_stop()
	Engine.time_scale = 1.0
	for frame in 3:await tree.physics_frame
	var cases := [
		["left entrance to narrow lane",Vector2i(2,6),Vector2i(11,6)],
		["single horizontal lane",Vector2i(11,6),Vector2i(28,6)],
		["first alcove and return",Vector2i(14,3),Vector2i(16,6)],
		["second alcove and return",Vector2i(19,9),Vector2i(21,6)],
		["third alcove and return",Vector2i(24,3),Vector2i(26,6)],
		["upper final flank",Vector2i(28,6),Vector2i(35,4)],
		["lower final flank",Vector2i(28,6),Vector2i(35,8)],
		["right-side exit",Vector2i(35,4),Vector2i(36,6)]]
	var results: Array = []
	for test in cases:
		var path: Array[Vector2i] = _free_path(world, test[1], test[2])
		var passed := not path.is_empty()
		var distance := 0.0
		if passed:
			player.global_position = Vector2(path[0])*32.0
			for cell in path:
				var target := Vector2(cell)*32.0
				var reached := false
				for step in 30:
					var before := player.global_position
					var offset := target - before
					if offset.length() < 3.0: reached = true; break
					player.velocity = offset.normalized()*minf(200.0,offset.length()*60.0)
					player.move_and_slide()
					distance += before.distance_to(player.global_position)
					await tree.physics_frame
				if not reached: passed = false; break
		var blockers: Array=[]
		for index in player.get_slide_collision_count():
			var hit := player.get_slide_collision(index)
			blockers.append({"node":str(hit.get_collider().get_path()),"normal":str(hit.get_normal())})
		results.append({"name":test[0],"pass":passed,"path_cells":path.size(),"walked_pixels":distance,"end":str(player.global_position),"blockers":blockers,"time_scale":Engine.time_scale,"hitstop":controller.hitstop_active})
	# South exterior away from the elevator opening: walk into the real wall.
	player.global_position = Vector2(36,10)*32.0
	for step in 60:
		player.velocity = Vector2(200,0)
		player.move_and_slide()
		await tree.physics_frame
	var contained: bool = world.floor_cells.has(world._cell_for_gameplay_position(player.global_position))
	player.velocity = Vector2.ZERO
	player.set_physics_process(previous_physics)
	return {"routes":results,"no_void_escape":contained,"door_policy":"Open continuous funnels; exact production player-body sweeps"}

static func _free_path(world: Node3D, start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var reached := {start:true}
	var previous: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var current := queue[index]; index += 1
		if current == finish: break
		for direction in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			var next: Vector2i = current+direction
			if reached.has(next) or not world.floor_cells.has(next): continue
			if not world._can_cross_floor_edge(current,next,true): continue
			# Sweep the actual production body, including its offset and margins.
			# Endpoint circles can miss a jamb between two otherwise clear cells.
			var pose: Transform2D = world.player.global_transform
			pose.origin = Vector2(current)*32.0
			if world.player.test_move(pose,Vector2(direction)*32.0): continue
			reached[next]=true; previous[next]=current; queue.append(next)
	var path: Array[Vector2i] = []
	if not reached.has(finish): return path
	var current := finish
	while current != start:
		path.push_front(current); current=previous[current]
	path.push_front(start)
	return path
