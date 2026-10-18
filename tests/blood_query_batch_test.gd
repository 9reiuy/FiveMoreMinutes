extends SceneTree
class CustomBlood extends BlackBloodEffect:
	var validation_calls := 0
	func _is_ground_world_position_valid(_point: Vector2) -> bool:
		validation_calls+=1
		return false
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	root.add_child(world)
	check(world.regenerate(42001),"formal generated floor")
	for index in 4: await physics_frame
	paused = true
	var origins: Array[Vector2] = []
	for cell in world.floor_cells:
		var center := Vector2(cell)*32.0
		if not world._is_blood_ground_allowed(center): continue
		for direction in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			if world.floor_cells.has(cell+direction) and world._can_cross_floor_edge(cell,cell+direction): continue
			var near_wall := center+Vector2(direction)*13.5
			if world._is_blood_ground_allowed(near_wall): origins.append(near_wall)
			break
		if origins.size()>=16: break
	check(origins.size()>=8,"wall and border origins found")
	var times: Array = [[],[],[]]
	for trial in origins.size():
		var results: Array = []
		for group in 3:
			var legacy := group!=1
			world.set_meta(&"test_legacy_blood_queries",legacy)
			var blood := BlackBloodEffect.new(); world.world_effects_root.add_child(blood)
			blood.set_process(false); blood.set_surface_context(world,world.current_room_id)
			blood.office_pool_core = true; blood.position = origins[trial]
			blood.rotation = [0.0,0.15,-0.25][trial%3]
			blood.scale = Vector2(1.0,1.0) if trial%4 else Vector2(.9,1.1)
			var rng := RandomNumberGenerator.new(); rng.seed = trial+4185
			var started := Time.get_ticks_usec()
			blood.setup_death_pool(rng,world.WORLD_WALL_LAYER,1.5,2.0,.35,3.0)
			times[group].append(Time.get_ticks_usec()-started)
			results.append([blood._pool_growth_cells.duplicate(),blood.ground_pixels.duplicate(),blood.ground_pixel_types.duplicate(),rng.state])
			blood.free()
		check(results[0]==results[1] and results[0]==results[2],"ordered shape, initial pixels, stamp types and RNG parity %d"%trial)
	for index in 3:
		var values: Array = times[index]; values.sort()
		print("BLOOD_QUERY_BATCH legacy=",index!=1," median_us=",values[values.size()/2]," p95_us=",values[int(values.size()*.95)])
	# A tiny obstacle between corner rays must still occlude individual cells.
	# Move it between two complete operations to prove the cache is not retained.
	paused = false
	var wall := StaticBody2D.new(); wall.collision_layer = world.WORLD_WALL_LAYER; wall.collision_mask = 0
	var collision := CollisionShape2D.new(); var shape := RectangleShape2D.new()
	shape.size = Vector2(.2,.2); collision.shape = shape; wall.add_child(collision)
	world.world_effects_root.add_child(wall)
	var origin: Vector2 = world.player.global_position
	for offset in [Vector2(4,1),Vector2(4,0)]:
		wall.position = origin+offset
		await physics_frame; await physics_frame
		paused = true
		var outputs: Array = []
		for legacy in [true,false]:
			world.set_meta(&"test_legacy_blood_queries",legacy)
			var blood := BlackBloodEffect.new(); world.world_effects_root.add_child(blood)
			blood.set_process(false); blood.office_pool_core = true
			blood.set_surface_context(world,world.current_room_id); blood.position=origin
			var rng := RandomNumberGenerator.new(); rng.seed=8927
			blood.setup_death_pool(rng,world.WORLD_WALL_LAYER,1.5,2.0,.35,3.0)
			outputs.append(blood._pool_growth_cells.duplicate())
			blood.free()
		check(outputs[0]==outputs[1],"thin obstacle/moved collider full shape parity")
		if offset.y==1:
			check(not outputs[1].has(Vector2(8,2)),"subpixel obstacle blocks intermediate ray")
			check(outputs[1].has(Vector2(8,0)),"visible cell remains beside subpixel obstacle")
		else: check(not outputs[1].has(Vector2(8,0)),"moved obstacle invalidates previous safe result")
		paused = false
	wall.free()
	world.set_meta(&"test_legacy_blood_queries",false)
	var first: Dictionary = world._begin_blood_ground_query_batch()
	var second: Dictionary = world._begin_blood_ground_query_batch()
	check(first[&"point"]!=second[&"point"],"each operation owns independent query parameters")
	var custom_outputs: Array = []
	for legacy in [true,false]:
		world.set_meta(&"test_legacy_blood_queries",legacy)
		var custom := CustomBlood.new(); world.world_effects_root.add_child(custom)
		custom.set_process(false); custom.office_pool_core=true; custom.position=origins[0]
		custom.set_surface_context(world,world.current_room_id)
		var custom_rng := RandomNumberGenerator.new(); custom_rng.seed=8927
		custom.setup_death_pool(custom_rng,world.WORLD_WALL_LAYER,1.5,2.0,.35,3.0)
		custom_outputs.append([custom.validation_calls,custom._pool_growth_cells.duplicate()])
		custom.free()
	check(custom_outputs[1][0]>0,"custom subclass keeps virtual validator")
	check(custom_outputs[0]==custom_outputs[1],"custom subclass preserves original validator calls and shape")
	world.queue_free(); paused = false
	for index in 4: await process_frame
	print("BLOOD_QUERY_BATCH checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
